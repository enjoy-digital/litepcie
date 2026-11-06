#
# This file is part of LitePCIe.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY lane datapaths (PCIe Base 4.2.7 clock tolerance compensation, 4.2.4.3 Electrical
Idle inference helpers): SKP Ordered Set insertion/removal, 8b/10b error substitution, Electrical
Idle filtering, and the TX/RX lane datapaths (scrambling, clock domain crossing).

Lane words are 4 Symbols (lane_layout(4)). The TX datapath runs in the lane clock domain, the RX
datapath descrambles and removes the SKP Ordered Sets in the recovered clock domain then crosses to
the lane clock domain. Removing the whole SKP Ordered Set (4 Symbols) keeps the word phase of the
received stream, which is otherwise arbitrary: the consumers (Training Sequence checkers, packet
framing) work at any Symbol position.

Ported from the USB3 PIPE project datapaths.
"""

from migen import *
from migen.genlib.cdc import MultiReg, PulseSynchronizer

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common    import COM, SKP, ERR, SKP_OS, lane_layout
from litepcie.phy.soft.coding    import RX8b10bChecker
from litepcie.phy.soft.scrambler import Scrambler, Descrambler

# Helpers ------------------------------------------------------------------------------------------

def ordered_set_words(ordered_set):
    """(data, ctrl) 32-bit words of an Ordered Set (Symbol 0 on bits 7:0)."""
    symbols = ordered_set.to_symbols()
    assert len(symbols) % 4 == 0
    words = []
    for i in range(0, len(symbols), 4):
        data = sum(value << 8*j for j, (value, k) in enumerate(symbols[i:i+4]))
        ctrl = sum(k     <<   j for j, (value, k) in enumerate(symbols[i:i+4]))
        words.append((data, ctrl))
    return words

SKP_OS_WORD = ordered_set_words(SKP_OS)[0]

# TX SKP Inserter (4.2.7) --------------------------------------------------------------------------

# One SKP Ordered Set every 352 words (1408 Symbols, within the 1180 to 1538 Symbols of 4.2.7).
SKP_INTERVAL_WORDS = 352

class TXSKPInserter(LiteXModule):
    """TX SKP Inserter

    Schedules a SKP Ordered Set (COM + 3 SKP) every interval words and inserts it between packets
    and Ordered Sets (sink first/last delimit them). Up to 2 Ordered Sets are kept pending while a
    packet is being transmitted. When disabled, nothing is scheduled and the count restarts.
    """
    def __init__(self, interval=SKP_INTERVAL_WORDS):
        self.enable = Signal(reset=1) # i
        self.sink   = sink   = stream.Endpoint(lane_layout(4))
        self.source = source = stream.Endpoint(lane_layout(4))

        # # #

        count    = Signal(max=interval)
        grant    = Signal(reset=1)
        queue    = Signal()
        dequeue  = Signal()
        pending  = Signal(2)

        # Schedule a SKP Ordered Set every interval words.
        self.sync += [
            queue.eq(0),
            If(~self.enable,
                count.eq(0)
            ).Elif(sink.valid & sink.ready,
                count.eq(count + 1),
                If(count == (interval - 1),
                    count.eq(0),
                    queue.eq(1)
                )
            )
        ]

        # Grant: not inside a packet/Ordered Set.
        self.sync += [
            If(sink.valid & sink.ready,
                If(sink.last,
                    grant.eq(1)
                ).Elif(sink.first,
                    grant.eq(0)
                )
            )
        ]

        # Pending Ordered Sets (saturating).
        self.sync += [
            If(~self.enable,
                pending.eq(0)
            ).Elif(queue & ~dequeue & (pending != 2),
                pending.eq(pending + 1)
            ).Elif(~queue & dequeue,
                pending.eq(pending - 1)
            )
        ]

        # Insertion.
        self.comb += [
            If(grant & (pending != 0),
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(1),
                source.data.eq(SKP_OS_WORD[0]),
                source.ctrl.eq(SKP_OS_WORD[1]),
                dequeue.eq(source.ready)
            ).Else(
                sink.connect(source)
            )
        ]

# RX SKP Remover (4.2.7) ---------------------------------------------------------------------------

class RXSKPRemover(LiteXModule):
    """RX SKP Remover

    Removes the SKP Ordered Sets from the RX stream: the SKP Symbols and the COM Symbol directly
    followed by a SKP (looked ahead in the next word for Symbol 3: one word of latency, the last
    word of a stream is only output when the next one arrives). The remaining Symbols are repacked
    in 4-Symbol words.
    """
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(lane_layout(4))
        self.source = source = stream.Endpoint(lane_layout(4))
        self.skip   = Signal() # o: Symbols removed from the current word.

        # # #

        # Lookahead: the word being processed is the previous one -------------------------------
        prev_valid = Signal()
        prev_data  = Signal(32)
        prev_ctrl  = Signal(4)

        # Find the Symbols to remove -------------------------------------------------------------
        skp  = Signal(5) # Symbols 0-3 of the previous word, Symbol 0 of the current one.
        com  = Signal(4)
        drop = Signal(4)
        for i in range(4):
            self.comb += [
                skp[i].eq(prev_ctrl[i] & (prev_data[8*i:8*(i+1)] == SKP.value)),
                com[i].eq(prev_ctrl[i] & (prev_data[8*i:8*(i+1)] == COM.value)),
            ]
        self.comb += skp[4].eq(sink.ctrl[0] & (sink.data[0:8] == SKP.value))
        for i in range(4):
            self.comb += drop[i].eq(skp[i] | (com[i] & skp[i+1]))

        # Select the kept Data/Ctrl fragments ------------------------------------------------------
        frag = stream.Endpoint(lane_layout(4) + [("bytes", 3)])
        cases = {}
        for i in range(2**4):
            datas = []
            ctrls = []
            for j in range(4):
                if (i & 2**j) == 0:
                    datas.append(prev_data[8*j:8*(j+1)])
                    ctrls.append(prev_ctrl[j])
            cases[i] = [
                frag.data.eq(Cat(*datas) if len(datas) else 0),
                frag.ctrl.eq(Cat(*ctrls) if len(ctrls) else 0),
                frag.bytes.eq(len(ctrls)),
            ]
        self.comb += Case(drop, cases)

        # The previous word is processed when the current one is present (lookahead).
        process = Signal()
        self.comb += [
            frag.valid.eq(prev_valid & sink.valid),
            process.eq(frag.valid & frag.ready),
            sink.ready.eq(~prev_valid | process),
            self.skip.eq(process & (drop != 0)),
        ]
        self.sync += [
            If(sink.valid & sink.ready,
                prev_valid.eq(1),
                prev_data.eq(sink.data),
                prev_ctrl.eq(sink.ctrl),
            ).Elif(process,
                prev_valid.eq(0)
            )
        ]

        # Register the fragments (timing) ---------------------------------------------------------
        self.pipe = pipe = stream.PipeValid(lane_layout(4) + [("bytes", 3)])
        self.comb += frag.connect(pipe.sink)
        frag_data  = pipe.source.data
        frag_ctrl  = pipe.source.ctrl
        frag_bytes = pipe.source.bytes

        # Store Data/Ctrl in a 64/8-bit Shift Register ---------------------------------------------
        sr_data  = Signal(64, reset_less=True)
        sr_ctrl  = Signal(8,  reset_less=True)
        sr_bytes = Signal(4)
        cases = {}
        cases[0] = [
            sr_data.eq(sr_data),
            sr_ctrl.eq(sr_ctrl),
        ]
        for i in range(1, 5):
            cases[i] = [
                sr_data.eq(Cat(sr_data[8*i:], frag_data[0:8*i])),
                sr_ctrl.eq(Cat(sr_ctrl[1*i:], frag_ctrl[0:1*i])),
            ]
        # Accept a fragment (up to 4 bytes) only if it fits in the Shift Register, taking into
        # account the word output on the same cycle.
        self.comb += pipe.source.ready.eq((sr_bytes <= 4) | (source.ready & (sr_bytes <= 8)))
        self.sync += [
            If(pipe.source.valid & pipe.source.ready,
                If(source.valid & source.ready,
                    sr_bytes.eq(sr_bytes + frag_bytes - 4)
                ).Else(
                    sr_bytes.eq(sr_bytes + frag_bytes)
                ),
                Case(frag_bytes, cases)
            ).Elif(source.valid & source.ready,
                sr_bytes.eq(sr_bytes - 4)
            )
        ]

        # Output Data/Ctrl when there is a full 32/4-bit word --------------------------------------
        self.comb += source.valid.eq(sr_bytes >= 4)
        cases = {}
        for i in range(4, 9):
            cases[i] = [
                source.data.eq(sr_data[8*(8-i):8*(8-i+4)]),
                source.ctrl.eq(sr_ctrl[1*(8-i):1*(8-i+4)]),
            ]
        self.comb += Case(sr_bytes, cases)

# RX Error Substitution ----------------------------------------------------------------------------

class RXErrorSubstitution(LiteXModule):
    """RX Error Substitution

    Substitutes the received 8b/10b decode errors (and disparity errors with with_disparity) with
    the ERR K Symbol (reserved K28.4), so that the framing/Data Link Layer see a corrupted packet.
    """
    def __init__(self, decoders, clock_domain="sys", with_disparity=True):
        n = len(decoders)
        self.sink   = stream.Endpoint(lane_layout(n))
        self.source = stream.Endpoint(lane_layout(n))
        self.error  = Signal() # o: Error in the current word.

        # # #

        self.comb += self.sink.connect(self.source)
        # Without the disparity check, the decoders' invalid outputs are enough (no code table).
        if with_disparity:
            checker = RX8b10bChecker(decoders)
            if clock_domain != "sys":
                checker = ClockDomainsRenamer(clock_domain)(checker)
            self.checker = checker
        errors = []
        for i in range(n):
            error = decoders[i].invalid
            if with_disparity:
                error = error | checker.invalid[i] | checker.disparity_error[i]
            errors.append(error)
            self.comb += [
                If(error,
                    self.source.ctrl[i].eq(1),
                    self.source.data[8*i:8*(i+1)].eq(ERR.value),
                )
            ]
        self.comb += self.error.eq(self.sink.valid & Reduce("OR", errors))

# RX Idle Filter -----------------------------------------------------------------------------------

class RXIdleFilter(LiteXModule):
    """RX Electrical Idle Filter

    Resynchronizes the transceiver's Electrical Idle detection and only reports Electrical Idle
    after idle_cycles consecutive idle cycles (filters the detector toggling).
    """
    def __init__(self, rx_elecidle, idle_cycles=10):
        self.idle = Signal() # o

        # # #

        rx_elecidle_r = Signal(reset=1)
        count         = Signal(max=idle_cycles + 1, reset=idle_cycles) # Idle at reset.
        self.specials += MultiReg(rx_elecidle, rx_elecidle_r, reset=1)
        self.sync += [
            If(rx_elecidle_r,
                If(count != idle_cycles,
                    count.eq(count + 1)
                )
            ).Else(
                count.eq(0)
            )
        ]
        self.comb += self.idle.eq(count == idle_cycles)

# TX Lane Datapath ---------------------------------------------------------------------------------

class TXLaneDatapath(LiteXModule):
    """TX Lane Datapath: SKP Ordered Set insertion (between packets/Ordered Sets) then scrambling,
    in the lane clock domain. skp_enable gates the SKP scheduling, scrambling_enable is Disable
    Scrambling."""
    def __init__(self, skp_interval=SKP_INTERVAL_WORDS):
        self.sink   = sink   = stream.Endpoint(lane_layout(4))
        self.source = source = stream.Endpoint(lane_layout(4))
        self.skp_enable        = Signal(reset=1) # i
        self.scrambling_enable = Signal(reset=1) # i

        # # #

        self.skp_inserter = skp_inserter = TXSKPInserter(interval=skp_interval)
        self.scrambler    = scrambler    = Scrambler()
        self.comb += [
            skp_inserter.enable.eq(self.skp_enable),
            scrambler.enable.eq(self.scrambling_enable),
            sink.connect(skp_inserter.sink),
            skp_inserter.source.connect(scrambler.sink),
            scrambler.source.connect(source),
        ]

# RX Lane Datapath ---------------------------------------------------------------------------------

class RXLaneDatapath(LiteXModule):
    """RX Lane Datapath: descrambling and SKP Ordered Set removal in the recovered clock domain
    (cd_from, continuous stream), then clock domain crossing to the lane clock domain (cd_to)
    without back-pressure: the elastic buffer. Words are dropped when the FIFO is full (partner
    faster than the local clock without enough SKP Ordered Sets), counted in overflows (cd_to)."""
    def __init__(self, cd_from="rx", cd_to="sys", depth=16):
        self.sink   = sink   = stream.Endpoint(lane_layout(4))
        self.source = source = stream.Endpoint(lane_layout(4))
        self.scrambling_enable = Signal(reset=1) # i (cd_to clock domain)
        self.overflows         = Signal(16)      # o (cd_to clock domain)

        # # #

        self.descrambler  = descrambler  = ClockDomainsRenamer(cd_from)(Descrambler())
        self.skp_remover  = skp_remover  = ClockDomainsRenamer(cd_from)(RXSKPRemover())
        self.buffer       = buffer       = ClockDomainsRenamer(cd_from)(stream.Buffer(lane_layout(4), pipe_ready=True))
        self.cdc          = cdc          = ClockDomainsRenamer({"write": cd_from, "read": cd_to})(
            stream.AsyncFIFO(lane_layout(4), depth, buffered=True))

        scrambling_enable = Signal(reset=1)
        self.specials += MultiReg(self.scrambling_enable, scrambling_enable, cd_from)
        self.comb += [
            descrambler.enable.eq(scrambling_enable),
            sink.connect(descrambler.sink),
            descrambler.source.connect(skp_remover.sink),
            skp_remover.source.connect(buffer.sink),
            buffer.source.connect(cdc.sink, omit={"ready"}),
            buffer.source.ready.eq(1),
            cdc.source.connect(source),
        ]

        # Overflows (dropped words), counted in cd_to.
        overflow     = Signal()
        overflow_ps  = PulseSynchronizer(cd_from, cd_to)
        self.submodules += overflow_ps
        self.comb += [
            overflow.eq(buffer.source.valid & ~cdc.sink.ready),
            overflow_ps.i.eq(overflow),
        ]
        sync_to = getattr(self.sync, cd_to)
        sync_to += If(overflow_ps.o, self.overflows.eq(self.overflows + 1))
