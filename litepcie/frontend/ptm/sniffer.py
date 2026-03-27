#
# This file is part of LitePCIe-PTM.
#
# Copyright (c) 2023 NetTimeLogic
# Copyright (c) 2019-2023 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.common     import phy_layout
from litepcie.tlp.common import fmt_type_dict

from litepcie.tlp.depacketizer import LitePCIeTLPDepacketizer

# Helpers ------------------------------------------------------------------------------------------

def K(x, y):
    """K code generator ex: K(28, 5) is COM Symbol"""
    return (y << 5) | x

def D(x, y):
    """D code generator"""
    return (y << 5) | x

# Symbols (6.3.5) ----------------------------------------------------------------------------------

class Symbol:
    """Symbol definition with name, 8-bit value and description"""
    def __init__(self, name, value, description=""):
        self.name        = name
        self.value       = value
        self.description = description

SKP =  Symbol("SKP", K(28, 1), "Skip")
SDP =  Symbol("SDP", K(28, 2), "Start Data Packet")
EDB =  Symbol("EDB", K(28, 3), "End Bad")
SUB =  Symbol("SUB", K(28, 4), "Decode Error Substitution")
COM =  Symbol("COM", K(28, 5), "Comma")
RSD =  Symbol("RSD", K(28, 6), "Reserved")
SHP =  Symbol("SHP", K(27, 7), "Start Header Packet")
END =  Symbol("END", K(29, 7), "End")
SLC =  Symbol("SLC", K(30, 7), "Start Link Command")
EPF =  Symbol("EPF", K(23, 7), "End Packet Framing")

symbols = [SKP, SDP, EDB, SUB, COM, RSD, SHP, END, SLC, EPF]

# Endianness Swap ----------------------------------------------------------------------------------

class EndiannessSwap(LiteXModule):
    """Swap the data bytes/ctrl bits of stream"""
    def __init__(self, sink, source):
        assert len(sink.data) == len(source.data)
        assert len(sink.ctrl) == len(source.ctrl)
        self.comb += sink.connect(source, omit={"data", "ctrl"})
        n = len(sink.ctrl)
        for i in range(n):
            self.comb += source.data[8*i:8*(i+1)].eq(sink.data[8*(n-1-i):8*(n-1-i+1)])
            self.comb += source.ctrl[i].eq(sink.ctrl[n-1-i])

# Scrambler Unit (Appendix B) ----------------------------------------------------------------------

@ResetInserter()
@CEInserter()
class ScramblerUnit(Module):
    """Scrambler Unit

    This module generates the scrambled datas for the USB3.0 link (X^16 + X^5 + X^4 + X^3 + 1 polynom).
    """
    def __init__(self, reset=0xffff):
        self.value = Signal(32)

        # # #

        new = Signal(16)
        cur = Signal(16, reset=reset)

        self.comb += [
            new[0].eq(cur[0]  ^ cur[6] ^ cur[8]  ^ cur[10]),
            new[1].eq(cur[1]  ^ cur[7] ^ cur[9]  ^ cur[11]),
            new[2].eq(cur[2]  ^ cur[8] ^ cur[10] ^ cur[12]),
            new[3].eq(cur[3]  ^ cur[6] ^ cur[8]  ^ cur[9]  ^ cur[10] ^ cur[11] ^ cur[13]),
            new[4].eq(cur[4]  ^ cur[6] ^ cur[7]  ^ cur[8]  ^ cur[9]  ^ cur[11] ^ cur[12] ^ cur[14]),
            new[5].eq(cur[5]  ^ cur[6] ^ cur[7]  ^ cur[9]  ^ cur[12] ^ cur[13] ^ cur[15]),
            new[6].eq(cur[0]  ^ cur[6] ^ cur[7]  ^ cur[8]  ^ cur[10] ^ cur[13] ^ cur[14]),
            new[7].eq(cur[1]  ^ cur[7] ^ cur[8]  ^ cur[9]  ^ cur[11] ^ cur[14] ^ cur[15]),
            new[8].eq(cur[0]  ^ cur[2] ^ cur[8]  ^ cur[9]  ^ cur[10] ^ cur[12] ^ cur[15]),
            new[9].eq(cur[1]  ^ cur[3] ^ cur[9]  ^ cur[10] ^ cur[11] ^ cur[13]),
            new[10].eq(cur[0] ^ cur[2] ^ cur[4]  ^ cur[10] ^ cur[11] ^ cur[12] ^ cur[14]),
            new[11].eq(cur[1] ^ cur[3] ^ cur[5]  ^ cur[11] ^ cur[12] ^ cur[13] ^ cur[15]),
            new[12].eq(cur[2] ^ cur[4] ^ cur[6]  ^ cur[12] ^ cur[13] ^ cur[14]),
            new[13].eq(cur[3] ^ cur[5] ^ cur[7]  ^ cur[13] ^ cur[14] ^ cur[15]),
            new[14].eq(cur[4] ^ cur[6] ^ cur[8]  ^ cur[14] ^ cur[15]),
            new[15].eq(cur[5] ^ cur[7] ^ cur[9]  ^ cur[15]),

            self.value[0].eq(cur[15]),
            self.value[1].eq(cur[14]),
            self.value[2].eq(cur[13]),
            self.value[3].eq(cur[12]),
            self.value[4].eq(cur[11]),
            self.value[5].eq(cur[10]),
            self.value[6].eq(cur[9]),
            self.value[7].eq(cur[8]),
            self.value[8].eq(cur[7]),
            self.value[9].eq(cur[6]),
            self.value[10].eq(cur[5]),
            self.value[11].eq(cur[4]  ^ cur[15]),
            self.value[12].eq(cur[3]  ^ cur[14] ^ cur[15]),
            self.value[13].eq(cur[2]  ^ cur[13] ^ cur[14] ^ cur[15]),
            self.value[14].eq(cur[1]  ^ cur[12] ^ cur[13] ^ cur[14]),
            self.value[15].eq(cur[0]  ^ cur[11] ^ cur[12] ^ cur[13]),
            self.value[16].eq(cur[10] ^ cur[11] ^ cur[12] ^ cur[15]),
            self.value[17].eq(cur[9]  ^ cur[10] ^ cur[11] ^ cur[14]),
            self.value[18].eq(cur[8]  ^ cur[9]  ^ cur[10] ^ cur[13]),
            self.value[19].eq(cur[7]  ^ cur[8]  ^ cur[9]  ^ cur[12]),
            self.value[20].eq(cur[6]  ^ cur[7]  ^ cur[8]  ^ cur[11]),
            self.value[21].eq(cur[5]  ^ cur[6]  ^ cur[7]  ^ cur[10]),
            self.value[22].eq(cur[4]  ^ cur[5]  ^ cur[6]  ^ cur[9]  ^ cur[15]),
            self.value[23].eq(cur[3]  ^ cur[4]  ^ cur[5]  ^ cur[8]  ^ cur[14]),
            self.value[24].eq(cur[2]  ^ cur[3]  ^ cur[4]  ^ cur[7]  ^ cur[13] ^ cur[15]),
            self.value[25].eq(cur[1]  ^ cur[2]  ^ cur[3]  ^ cur[6]  ^ cur[12] ^ cur[14]),
            self.value[26].eq(cur[0]  ^ cur[1]  ^ cur[2]  ^ cur[5]  ^ cur[11] ^ cur[13] ^ cur[15]),
            self.value[27].eq(cur[0]  ^ cur[1]  ^ cur[4]  ^ cur[10] ^ cur[12] ^ cur[14]),
            self.value[28].eq(cur[0]  ^ cur[3]  ^ cur[9]  ^ cur[11] ^ cur[13]),
            self.value[29].eq(cur[2]  ^ cur[8]  ^ cur[10] ^ cur[12]),
            self.value[30].eq(cur[1]  ^ cur[7]  ^ cur[9]  ^ cur[11]),
            self.value[31].eq(cur[0]  ^ cur[6]  ^ cur[8]  ^ cur[10]),
        ]
        self.sync += cur.eq(new)

# Scrambler (Appendix B) ---------------------------------------------------------------------------

class Scrambler(Module):
    """Scrambler

    This module scrambles the TX data/ctrl stream. K codes shall not be scrambled.
    """
    def __init__(self, reset=0x7dbd):
        self.enable = Signal(reset=1)
        self.sink   =   sink = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        self.submodules.unit = unit = ScramblerUnit(reset=reset)
        self.comb += unit.ce.eq(sink.valid & sink.ready)
        self.comb += sink.connect(source)
        for i in range(4):
            self.comb += [
                If(~self.enable | sink.ctrl[i], # K codes shall not be scrambled.
                    source.data[8*i:8*(i+1)].eq(sink.data[8*i:8*(i+1)])
                ).Else(
                    source.data[8*i:8*(i+1)].eq(sink.data[8*i:8*(i+1)] ^ unit.value[8*i:8*(i+1)])
                )
            ]

# Raw Descrambler (Scrambler + Auto-Synchronization) (Appendix B) ----------------------------------

class RawDescrambler(Module):
    """Descrambler

    This module descrambles the RX data/ctrl stream. K codes shall not be scrambled. The descrambler
    automatically synchronizes itself to the incoming stream and resets the scrambler unit when COM
    characters are seen.
    """
    def __init__(self, reset=0xffff):
        self.enable = Signal(reset=1)
        self.sink   =   sink = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        scrambler = Scrambler(reset=reset)
        self.submodules += scrambler
        self.comb += scrambler.enable.eq(self.enable)

        # Synchronize on COM
        for i in range(4):
            self.comb += [
                If(sink.valid &
                   sink.ready &
                   (sink.data[8*i:8*(i+1)] == COM.value) &
                   sink.ctrl[i],
                   scrambler.unit.reset.eq(1)
                )
            ]

        # Descramble data
        self.comb += [
            sink.connect(scrambler.sink),
            scrambler.source.connect(source)
        ]

# Raw Word Aligner ---------------------------------------------------------------------------------

class RawWordAligner(LiteXModule):
    """Raw Word Aligner

    Align RX Words by analyzing the location of the COM/K-codes (configurable) in the RX stream.
    """
    def __init__(self):
        self.enable = Signal(reset=1)
        self.sink   = sink   = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        update      = Signal()
        alignment   = Signal(2)
        alignment_d = Signal(2)

        buf = stream.Buffer([("data", 32), ("ctrl", 4)])
        self.submodules += buf
        self.comb += [
            sink.connect(buf.sink),
            source.valid.eq(sink.valid & buf.source.valid),
            buf.source.ready.eq(sink.valid & source.ready),
        ]

        # Alignment detection
        for i in reversed(range(4)):
            self.comb += [
                If(sink.valid & sink.ready,
                    If(sink.ctrl[i] & (sink.data[8*i:8*(i+1)] == COM.value),
                        update.eq(1),
                        alignment.eq(i)
                    )
                )
            ]
        self.sync += [
            If(sink.valid & sink.ready,
                If(self.enable & update,
                    alignment_d.eq(alignment)
                )
            )
        ]

        # Data selection
        data = Cat(buf.source.data, sink.data)
        ctrl = Cat(buf.source.ctrl, sink.ctrl)
        cases = {}
        for i in range(4):
            cases[i] = [
                source.data.eq(data[8*i:]),
                source.ctrl.eq(ctrl[1*i:]),
            ]
        self.comb += Case(alignment_d, cases)

# Raw Datapath -------------------------------------------------------------------------------------

class RawDatapath(LiteXModule):
    """Raw Datapath

    This module realizes the:
    - Data-width adaptation (from transceiver's data-width to 32-bit).
    - Clock domain crossing (from transceiver's RX clock to system clock).
    - Words alignment.

    """
    def __init__(self, clock_domain="sys", phy_dw=16):
        self.sink   = stream.Endpoint([("data", phy_dw), ("ctrl", phy_dw//8)])
        self.source = stream.Endpoint([("data",     32), ("ctrl",         4)])

        # # #

        # Data-width adaptation
        converter = stream.StrideConverter(
            [("data", phy_dw), ("ctrl", phy_dw//8)],
            [("data",     32), ("ctrl",         4)],
            reverse=False)
        converter = stream.BufferizeEndpoints({"sink":   stream.DIR_SINK})(converter)
        converter = ClockDomainsRenamer(clock_domain)(converter)
        self.converter = converter

        # Clock domain crossing
        cdc = stream.AsyncFIFO([("data", 32), ("ctrl", 4)], 8, buffered=True)
        cdc = ClockDomainsRenamer({"write": clock_domain, "read": "sys"})(cdc)
        self.cdc = cdc

        # Words alignment
        word_aligner = RawWordAligner()
        word_aligner = stream.BufferizeEndpoints({"source": stream.DIR_SOURCE})(word_aligner)
        self.word_aligner = word_aligner

        # Flow
        self.submodules += stream.Pipeline(
            self.sink,
            converter,
            cdc,
            word_aligner,
            self.source,
        )

# Raw Lane Datapath --------------------------------------------------------------------------------

class RawLaneDatapath(LiteXModule):
    """Per-lane raw datapath kept in the sniffer clock domain."""
    def __init__(self):
        self.sink   = stream.Endpoint([("data", 16), ("ctrl", 2)])
        self.source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        converter = stream.StrideConverter(
            [("data", 16), ("ctrl", 2)],
            [("data", 32), ("ctrl", 4)],
            reverse=False)
        converter = stream.BufferizeEndpoints({"sink": stream.DIR_SINK})(converter)
        self.converter = converter

        word_aligner = RawWordAligner()
        word_aligner = stream.BufferizeEndpoints({"source": stream.DIR_SOURCE})(word_aligner)
        self.word_aligner = word_aligner

        self.descrambler = descrambler = RawDescrambler()

        self.submodules += stream.Pipeline(
            self.sink,
            converter,
            word_aligner,
            descrambler,
            self.source,
        )

# TLP Aligner --------------------------------------------------------------------------------------

class TLPAligner(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        first        = Signal()
        alignment    = Signal(2)
        sink_ctrl_d  = Signal(4)
        sink_ctrl_dd = Signal(4)
        sink_data_d  = Signal(32)
        sink_data_dd = Signal(32)

        self.comb += sink.ready.eq(1)
        self.sync += [
            If(sink.valid,
                sink_data_d.eq(sink.data),
                sink_data_dd.eq(sink_data_d),
                sink_ctrl_d.eq(sink.ctrl),
                sink_ctrl_dd.eq(sink_ctrl_d)
            )
        ]

        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(sink.valid,
                If(sink.ctrl[0] & (sink.data[0*8:1*8] == 0xfb),
                   NextValue(alignment, 0b00),
                   NextState("RECEIVE-0")
                ),
                If(sink.ctrl[1] & (sink.data[1*8:2*8] == 0xfb),
                   NextValue(alignment, 0b01),
                   NextState("RECEIVE-0")
                ),
                If(sink.ctrl[2] & (sink.data[2*8:3*8] == 0xfb),
                   NextValue(alignment, 0b10),
                   NextState("RECEIVE-0")
                ),
                If(sink.ctrl[3] & (sink.data[3*8:4*8] == 0xfb),
                   NextValue(alignment, 0b11),
                   NextState("RECEIVE-0")
                )
            ),
        )
        fsm.act("RECEIVE-0",
            If(sink.valid,
                NextValue(first, 1),
                NextState("RECEIVE-1")
            )
        )
        fsm.act("RECEIVE-1",
            If(sink.valid,
                source.valid.eq(1),
                NextValue(first, 0),
                Case(alignment, {
                    0b00 : [
                        source.data[8*0:8*1].eq(sink_data_dd[8*3:8*4]),
                        source.data[8*1:8*2].eq(sink_data_d [8*0:8*1]),
                        source.data[8*2:8*3].eq(sink_data_d [8*1:8*2]),
                        source.data[8*3:8*4].eq(sink_data_d [8*2:8*3]),
                        source.ctrl[0].eq(sink_ctrl_dd[3]),
                        source.ctrl[1].eq(sink_ctrl_d [0]),
                        source.ctrl[2].eq(sink_ctrl_d [1]),
                        source.ctrl[3].eq(sink_ctrl_d [2]),
                    ],
                    0b01 : [
                        source.data[8*0:8*1].eq(sink_data_d[8*0:8*1]),
                        source.data[8*1:8*2].eq(sink_data_d[8*1:8*2]),
                        source.data[8*2:8*3].eq(sink_data_d[8*2:8*3]),
                        source.data[8*3:8*4].eq(sink_data_d[8*3:8*4]),
                        source.ctrl[0].eq(sink_ctrl_d[0]),
                        source.ctrl[1].eq(sink_ctrl_d[1]),
                        source.ctrl[2].eq(sink_ctrl_d[2]),
                        source.ctrl[3].eq(sink_ctrl_d[3]),
                    ],
                    0b10 : [
                        source.data[8*0:8*1].eq(sink_data_d[8*1:8*2]),
                        source.data[8*1:8*2].eq(sink_data_d[8*2:8*3]),
                        source.data[8*2:8*3].eq(sink_data_d[8*3:8*4]),
                        source.data[8*3:8*4].eq(sink.data  [8*0:8*1]),
                        source.ctrl[0].eq(sink_ctrl_d[1]),
                        source.ctrl[1].eq(sink_ctrl_d[2]),
                        source.ctrl[2].eq(sink_ctrl_d[3]),
                        source.ctrl[3].eq(sink.ctrl  [0]),
                    ],
                    0b11 : [
                        source.data[8*0:8*1].eq(sink_data_d[8*2:8*3]),
                        source.data[8*1:8*2].eq(sink_data_d[8*3:8*4]),
                        source.data[8*2:8*3].eq(sink.data  [8*0:8*1]),
                        source.data[8*3:8*4].eq(sink.data  [8*1:8*2]),
                        source.ctrl[0].eq(sink_ctrl_d[2]),
                        source.ctrl[1].eq(sink_ctrl_d[3]),
                        source.ctrl[2].eq(sink.ctrl  [0]),
                        source.ctrl[3].eq(sink.ctrl  [1]),
                    ],
                }),
            ),
            If(sink.valid & ~first,
                If(sink_ctrl_dd[0] & (sink_data_dd[0*8:1*8] == 0xfd),
                   source.last.eq(1),
                   NextState("IDLE")
                ),
                If(sink_ctrl_dd[1] & (sink_data_dd[1*8:2*8] == 0xfd),
                   source.last.eq(1),
                   NextState("IDLE")
                ),
                If(sink_ctrl_dd[2] & (sink_data_dd[2*8:3*8] == 0xfd),
                   source.last.eq(1),
                   NextState("IDLE")
                ),
                If(sink_ctrl_dd[3] & (sink_data_dd[3*8:4*8] == 0xfd),
                   source.last.eq(1),
                   NextState("IDLE")
                )
            ),
        )


# TLP Endianness Swap ------------------------------------------------------------------------------

class TLPEndiannessSwap(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        self.submodules += EndiannessSwap(sink, source)

# TLP Filter/Formater ------------------------------------------------------------------------------

class TLPFilterFormater(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint(phy_layout(64))

        # # #

        # Signals.
        count = Signal(32)

        # Always accept incoming data.
        self.comb += sink.ready.eq(1)

        # Data-FIFO (For eventual source unavailability absorbtion).
        self.fifo = fifo = stream.SyncFIFO(phy_layout(32), depth=4, buffered=True)

        # Data-Width Converter: 32-bit to 64-bit.
        self.conv = conv = stream.StrideConverter(
            description_from = phy_layout(32),
            description_to   = phy_layout(64),
            reverse          = False
        )
        self.comb += [
            fifo.sink.be.eq(0b1111),
            fifo.source.connect(conv.sink),
            conv.source.connect(self.source),
        ]

        # FSM.
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(sink.valid,
                # PTM Request.
                If(sink.data[24:32] == fmt_type_dict["ptm_req"],
                    fifo.sink.valid.eq(1),
                    fifo.sink.dat.eq(sink.data),
                    NextValue(count, 3 - 1), # 3DWs Header.
                    NextState("RECEIVE")
                # PTM Response.
                ).Elif(sink.data[24:32] == fmt_type_dict["ptm_res"],
                    fifo.sink.valid.eq(1),
                    fifo.sink.dat.eq(sink.data),
                    NextValue(count, 4 - 1), # 4DWs Header.
                    NextState("RECEIVE")
                ).Else(
                    NextState("END")
                )
            )
        )
        fsm.act("RECEIVE",
            If(sink.valid,
                fifo.sink.valid.eq(1),
                fifo.sink.dat.eq(sink.data),
                NextValue(count, count - 1),
                If(count == 0,
                    fifo.sink.last.eq(1),
                    NextState("END")
                ),
                If(sink.last,
                    fifo.sink.last.eq(1),
                    NextState("IDLE")
                )
            )
        )
        fsm.act("END",
            If(sink.valid & sink.last,
                NextState("IDLE")
            )
        )

# Link Stream Packer -------------------------------------------------------------------------------

class LinkStreamPacker(LiteXModule):
    """Reconstruct the logical PCIe byte stream from independently aligned PIPE lanes."""
    def __init__(self, nlanes):
        assert nlanes in [1, 2, 4, 8, 16]

        self.sinks  = [stream.Endpoint([("data", 32), ("ctrl", 4)]) for _ in range(nlanes)]
        self.width  = max(64, 32*nlanes)
        self.lane_reverse = Signal()
        self.source = stream.Endpoint([("data", self.width), ("ctrl", self.width//8)])

        # # #

        beat_data         = Signal(32*nlanes)
        beat_ctrl         = Signal(4*nlanes)
        beat_data_reverse = Signal(32*nlanes)
        beat_ctrl_reverse = Signal(4*nlanes)
        beat_data_muxed   = Signal(32*nlanes)
        beat_ctrl_muxed   = Signal(4*nlanes)
        beat_valid = Signal()

        for lane, sink in enumerate(self.sinks):
            self.comb += sink.ready.eq(1)
            for symbol in range(4):
                dst = symbol*nlanes + lane
                reverse_dst = symbol*nlanes + (nlanes - 1 - lane)
                self.comb += [
                    beat_data[8*dst:8*(dst + 1)].eq(sink.data[8*symbol:8*(symbol + 1)]),
                    beat_ctrl[dst].eq(sink.ctrl[symbol]),
                    beat_data_reverse[8*reverse_dst:8*(reverse_dst + 1)].eq(sink.data[8*symbol:8*(symbol + 1)]),
                    beat_ctrl_reverse[reverse_dst].eq(sink.ctrl[symbol]),
                ]

        beat_valid_expr = 1
        for sink in self.sinks:
            beat_valid_expr = beat_valid_expr & sink.valid
        self.comb += beat_valid.eq(beat_valid_expr)
        self.comb += [
            beat_data_muxed.eq(Mux(self.lane_reverse, beat_data_reverse, beat_data)),
            beat_ctrl_muxed.eq(Mux(self.lane_reverse, beat_ctrl_reverse, beat_ctrl)),
        ]

        if self.width == 64 and nlanes == 1:
            lower_data  = Signal(32)
            lower_ctrl  = Signal(4)
            lower_valid = Signal()

            self.comb += [
                self.source.data[ 0:32].eq(lower_data),
                self.source.data[32:64].eq(beat_data_muxed),
                self.source.ctrl[0:4].eq(lower_ctrl),
                self.source.ctrl[4:8].eq(beat_ctrl_muxed),
            ]

            self.sync += [
                If(self.source.valid & self.source.ready,
                    self.source.valid.eq(0)
                ),
                If(beat_valid,
                    If(lower_valid,
                        self.source.valid.eq(1),
                        lower_valid.eq(0)
                    ).Else(
                        lower_data.eq(beat_data_muxed),
                        lower_ctrl.eq(beat_ctrl_muxed),
                        lower_valid.eq(1)
                    )
                )
            ]
        else:
            self.comb += [
                self.source.valid.eq(beat_valid),
                self.source.data.eq(beat_data_muxed),
                self.source.ctrl.eq(beat_ctrl_muxed),
            ]

# PTM Packet Parser --------------------------------------------------------------------------------

class PTMPacketParser(LiteXModule):
    """Decode PTM Request/Response packets directly from the reconstructed PCIe byte stream."""
    def __init__(self, data_width):
        assert data_width in [64, 128, 256, 512]

        self.sink   = sink   = stream.Endpoint([("data", data_width), ("ctrl", data_width//8)])
        self.source = source = stream.Endpoint([("message_code", 8), ("master_time", 64), ("link_delay", 32)])

        # # #

        bytes_per_beat = data_width//8
        max_packet_len = 20

        beat_m1_data  = Signal(data_width,     reset_less=True)
        beat_m1_ctrl  = Signal(bytes_per_beat, reset_less=True)
        beat_m1_valid = Signal()
        beat_m0_data  = Signal(data_width,     reset_less=True)
        beat_m0_ctrl  = Signal(bytes_per_beat, reset_less=True)
        beat_m0_valid = Signal()

        source_valid_r = Signal()
        message_code_r = Signal(8,  reset_less=True)
        master_time_r  = Signal(64, reset_less=True)
        link_delay_r   = Signal(32, reset_less=True)

        packet_found       = Signal()
        packet_message     = Signal(8)
        packet_master_time = Signal(64)
        packet_link_delay  = Signal(32)

        self.comb += [
            sink.ready.eq(1),
            source.valid.eq(source_valid_r),
            source.message_code.eq(message_code_r),
            source.master_time.eq(master_time_r),
            source.link_delay.eq(link_delay_r),
        ]

        data_bytes = []
        ctrl_bits  = []
        valid_bits = []
        for beat_data, beat_ctrl, beat_valid in [
            (beat_m1_data, beat_m1_ctrl, beat_m1_valid),
            (beat_m0_data, beat_m0_ctrl, beat_m0_valid),
            (sink.data,     sink.ctrl,   sink.valid),
        ]:
            for i in range(bytes_per_beat):
                data_bytes.append(beat_data[8*i:8*(i + 1)])
                ctrl_bits.append(beat_ctrl[i])
                valid_bits.append(beat_valid)

        candidates = []
        for end in range(2*bytes_per_beat, 3*bytes_per_beat):
            for start in reversed(range(max(0, end - max_packet_len - 1), end)):
                packet_len = end - start - 1
                if packet_len < 12:
                    continue

                cond = (
                    valid_bits[start] &
                    valid_bits[end]   &
                    ctrl_bits[start]  &
                    ctrl_bits[end]    &
                    (data_bytes[start] == SHP.value) &
                    (data_bytes[end]   == END.value)
                )
                for i in range(start + 1, end):
                    cond = cond & valid_bits[i] & ~ctrl_bits[i]

                fmt_type = data_bytes[start + 1]
                cond = cond & (
                    (fmt_type == fmt_type_dict["ptm_req"]) |
                    (fmt_type == fmt_type_dict["ptm_res"])
                )

                message_code = data_bytes[start + 8]

                if packet_len >= 16:
                    master_time = Cat(*[
                        data_bytes[start + 1 + byte]
                        for byte in reversed(range(8, 16))
                    ])
                else:
                    master_time = Constant(0, 64)

                if packet_len >= 20:
                    link_delay = Cat(*[
                        data_bytes[start + 1 + byte]
                        for byte in reversed(range(16, 20))
                    ])
                else:
                    link_delay = Constant(0, 32)

                candidates.append((cond, message_code, master_time, link_delay))

        detect_stmts = [
            packet_found.eq(0),
            packet_message.eq(0),
            packet_master_time.eq(0),
            packet_link_delay.eq(0),
        ]
        for cond, message_code, master_time, link_delay in reversed(candidates):
            detect_stmts = [
                If(cond,
                    packet_found.eq(1),
                    packet_message.eq(message_code),
                    packet_master_time.eq(master_time),
                    packet_link_delay.eq(link_delay),
                ).Else(
                    *detect_stmts
                )
            ]
        self.comb += detect_stmts

        self.sync += [
            If(source_valid_r & source.ready,
                source_valid_r.eq(0)
            ),
            If(sink.valid,
                beat_m1_data.eq(beat_m0_data),
                beat_m1_ctrl.eq(beat_m0_ctrl),
                beat_m1_valid.eq(beat_m0_valid),
                beat_m0_data.eq(sink.data),
                beat_m0_ctrl.eq(sink.ctrl),
                beat_m0_valid.eq(1),
                If(packet_found,
                    source_valid_r.eq(1),
                    message_code_r.eq(packet_message),
                    master_time_r.eq(packet_master_time),
                    link_delay_r.eq(packet_link_delay),
                )
            )
        ]

# PCIe PTM Sniffer ---------------------------------------------------------------------------------

class PCIePTMSniffer(LiteXModule):
    def __init__(self, rx_rst_n, rx_clk, rx_data, rx_ctrl, rx_valid=None, lane_reverse=0, nlanes=1, lane_data_width=32):
        self.source = source = stream.Endpoint([("message_code", 8), ("master_time", 64), ("link_delay", 32)])
        assert nlanes in [1, 2, 4, 8, 16]
        assert lane_data_width in [16, 32]
        assert len(rx_data) == lane_data_width*nlanes
        assert len(rx_ctrl) == 2*nlanes
        if rx_valid is not None:
            assert len(rx_valid) == nlanes

        # # #

        if rx_valid is None:
            rx_valid = Constant(2**nlanes - 1, nlanes)

        # Clocking.
        self.cd_sniffer = ClockDomain()
        self.comb += self.cd_sniffer.clk.eq(rx_clk)
        self.comb += self.cd_sniffer.rst.eq(~rx_rst_n)

        # Per-lane raw sniffing.
        lane_datapaths = []
        for lane in range(nlanes):
            datapath = ClockDomainsRenamer("sniffer")(RawLaneDatapath())
            lane_datapaths.append(datapath)
            self.submodules += datapath
            setattr(self, f"lane_datapath{lane}", datapath)
            self.comb += [
                datapath.sink.valid.eq(rx_valid[lane]),
                datapath.sink.data.eq(rx_data[lane_data_width*lane:lane_data_width*lane + 16]),
                datapath.sink.ctrl.eq(rx_ctrl[2*lane:2*lane + 2]),
            ]

        # Reconstruct the logical link byte stream and decode PTM packets directly from it.
        self.link_stream = link_stream = ClockDomainsRenamer("sniffer")(LinkStreamPacker(nlanes))
        self.ptm_parser  = ptm_parser  = ClockDomainsRenamer("sniffer")(PTMPacketParser(link_stream.width))
        self.submodules += link_stream, ptm_parser
        for lane, datapath in enumerate(lane_datapaths):
            self.comb += datapath.source.connect(link_stream.sinks[lane])
        self.comb += [
            link_stream.lane_reverse.eq(lane_reverse),
            link_stream.source.connect(ptm_parser.sink),
        ]

        # PTM CDC.
        self.cdc = cdc = stream.ClockDomainCrossing(
            layout  = self.source.description,
            cd_from = "sniffer",
            cd_to   = "sys",
        )
        self.comb += [
            ptm_parser.source.connect(cdc.sink),
            cdc.source.connect(self.source)
        ]

    def add_sources(self, platform):
        cdir = os.path.abspath(os.path.dirname(__file__))
        platform.add_source(os.path.join(cdir, "sniffer_tap.v"))
