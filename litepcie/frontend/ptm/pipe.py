#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Passive Gen1/Gen2 receive decoding before the PCIe hard block.

The original x1 decoder remains in sniffer.py. These modules work at the PIPE
clock, before the filtered PTM messages cross into the system clock domain.
"""

import os

from migen import *
from migen.genlib.cdc import MultiReg
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.gen import LiteXModule, Reduce
from litex.soc.interconnect import stream

COM, SKP, STP, END, EDB = 0xbc, 0x1c, 0xfb, 0xfd, 0xfe
PTM_RESPONSE_LAYOUT = [("message_code", 8), ("master_time", 64), ("link_delay", 32)]

# Scrambler Helpers --------------------------------------------------------------------------------


def _lfsr8(state):
    # PCIe Gen1/Gen2: x^16 + x^5 + x^4 + x^3 + 1, output MSB first.
    # Build XOR masks in Python so synthesis sees a parallel network, rather
    # than eight nested copies of the bit-serial recurrence.
    bits = [1 << bit for bit in range(16)]
    output = []
    for _ in range(8):
        feedback = bits[15]
        output.append(feedback)
        bits = [feedback] + bits[:-1]
        for tap in (3, 4, 5):
            bits[tap] ^= feedback

    def expression(mask):
        return Reduce("XOR", [state[bit] for bit in range(16) if mask & (1 << bit)])

    return Cat(*(expression(mask) for mask in bits)), Cat(*(expression(mask) for mask in output))

# Lane Descrambler ---------------------------------------------------------------------------------


class PCIe8b10bLaneDescrambler(LiteXModule):
    """Decode two consecutive 8b/10b-decoded symbols from one PIPE lane.

    COM resets the LFSR after that symbol. SKP neither scrambles nor advances
    it. Other K symbols advance the LFSR but are not XORed with its output.
    ``valid`` permits PIPE capture bubbles without advancing either symbol.
    """
    def __init__(self):
        self.valid   = Signal(reset=1)
        self.data    = Signal(16)
        self.ctrl    = Signal(2)
        self.decoded = Signal(16)
        self.state   = Signal(16, reset=0xffff)

        # # #

        current = self.state
        for byte in range(2):
            data, ctrl = self.data[8*byte:8*(byte+1)], self.ctrl[byte]
            advanced, mask = _lfsr8(current)
            after = Signal(16)
            self.comb += [
                self.decoded[8*byte:8*(byte+1)].eq(Mux(ctrl, data, data ^ mask)),
                after.eq(Mux(ctrl & (data == COM), 0xffff,
                    Mux(ctrl & (data == SKP), current, advanced))),
            ]
            current = after
        self.sync += If(self.valid, self.state.eq(current))

# Lane Symbol Buffer -------------------------------------------------------------------------------


class PCIeLaneSymbolBuffer(LiteXModule):
    """Small two-symbol elastic buffer; compact SKP independently per lane.

    The caller controls dequeue length (0, 1 or 2). Overflow is reported, so
    the receiver can discard alignment and reacquire at a subsequent COM.
    """
    def __init__(self, depth=16):
        assert depth >= 4 and depth & (depth - 1) == 0
        self.valid         = Signal()
        self.data          = Signal(16)
        self.ctrl          = Signal(2)
        self.pop           = Signal(2)
        self.head          = [Signal(9), Signal(9)]
        self.discard_first = Signal()
        self.level         = Signal(max=depth+1)
        self.overflow      = Signal()

        # # #

        write = Signal(max=depth)
        read = Signal(max=depth)
        write_next = Signal.like(write)
        read_next = Signal.like(read)
        keep = [Signal() for _ in range(2)]
        count = Signal(2)
        self.comb += [
            write_next.eq(write + 1), read_next.eq(read + 1),
            *[keep[i].eq(
                self.valid & (~self.discard_first if i == 0 else 1) &
                ~(self.ctrl[i] & (self.data[8*i:8*(i+1)] == SKP)))
              for i in range(2)],
            count.eq(keep[0] + keep[1]),
            self.overflow.eq(((self.level == depth) & (count != 0)) |
                ((self.level == depth-1) & (count == 2))),
        ]
        symbols = [Cat(self.data[8*i:8*(i+1)], self.ctrl[i]) for i in range(2)]
        # Consecutive symbols always occupy opposite parity banks. A single
        # write port per bank lets synthesis use distributed RAM instead of
        # a two-write register array and its large write-enable/read muxes.
        first = Mux(keep[0], symbols[0], symbols[1])
        reads = []
        for parity in range(2):
            memory = Memory(9, depth//2)
            wr = memory.get_port(write_capable=True)
            rd = memory.get_port(async_read=True)
            self.specials += memory, wr, rd
            starts_here = write[0] == parity
            self.comb += [
                wr.adr.eq(Mux(starts_here, write[1:], write_next[1:])),
                wr.dat_w.eq(Mux(starts_here, first, symbols[1])),
                wr.we.eq(~self.overflow & Mux(starts_here, count != 0, count == 2)),
                rd.adr.eq(Mux(read[0] == parity, read[1:], read_next[1:])),
            ]
            reads.append(rd.dat_r)
        self.comb += [
            self.head[0].eq(Mux(read[0], reads[1], reads[0])),
            self.head[1].eq(Mux(read[0], reads[0], reads[1])),
        ]
        self.sync += If(~self.overflow,
            write.eq(write + count), read.eq(read + self.pop),
            self.level.eq(self.level + count - self.pop),
        )

# PTM Symbol Receiver ------------------------------------------------------------------------------


class PCIePTMSymbolReceiver(LiteXModule):
    """Extract PTM responses from a deskewed/de-striped Gen1/Gen2 symbol stream.

    ``data`` contains up to 16 bytes, in wire order, with associated K bits.
    Each valid beat has ``nbytes`` symbols. PTM packets are recognized by both
    their link-local message format and message code; DMA payloads cannot
    impersonate a packet start because STP must be a K symbol.
    """
    def __init__(self, max_bytes=16):
        assert max_bytes in (2, 4, 8, 16)
        self.valid    = Signal()
        self.nbytes   = Signal(max=max_bytes+1, reset=max_bytes)
        self.data     = Signal(8*max_bytes)
        self.ctrl     = Signal(max_bytes)
        self.source   = stream.Endpoint(PTM_RESPONSE_LAYOUT)
        self.overflow = Signal()

        # # #

        # Decode K symbols in parallel with input capture. Their registered
        # positions then drive header/history bookkeeping in the next stage.
        data, nbytes, valid = Signal.like(self.data), Signal.like(self.nbytes), Signal()
        self.sync += [data.eq(self.data), nbytes.eq(self.nbytes), valid.eq(self.valid)]
        # Keep enough history for a complete response even when its start and
        # final payload byte fall at opposite ends of successive wide beats.
        history_bytes = 48
        history = Signal(8*history_bytes, reset_less=True)
        window = Signal(8*(history_bytes+max_bytes))
        self.comb += window.eq(Cat(history, data))
        # The shift amount is self-sized in Verilog: use explicit byte-to-bit
        # concatenation, not a multiplication that can truncate to operand width.
        self.sync += If(valid,
            history.eq(window >> Cat(C(0, 3), nbytes)),
        )
        start = Signal()
        start_index = Signal(max=max_bytes)
        bad_end = Signal()
        good_end = Signal()
        end_index = Signal(max=max_bytes)
        for byte in range(max_bytes):
            symbol = self.data[8*byte:8*(byte+1)]
            self.comb += If((byte < self.nbytes) & self.ctrl[byte],
                If(symbol == STP, start.eq(1), start_index.eq(byte)),
                If(symbol == EDB, bad_end.eq(1)),
                If(symbol == END, good_end.eq(1)),
            )
        for byte in reversed(range(max_bytes)):
            self.comb += If((byte < self.nbytes) & self.ctrl[byte] &
                (self.data[8*byte:8*(byte+1)] == END), end_index.eq(byte))
        flags = []
        for flag in (start, start_index, bad_end, good_end, end_index):
            captured = Signal.like(flag)
            self.sync += captured.eq(flag)
            flags.append(captured)
        start, start_index, bad_end, good_end, end_index = flags
        pending = Signal()
        age = Signal(max=history_bytes+max_bytes+1)
        offset = Signal(6, reset=history_bytes+3)
        packet = Signal(160, reset_less=True)
        aligned_packet = Signal(160)
        # Track the header offset alongside age, so the alignment shifter
        # does not also carry an age-subtraction path in the same cycle.
        self.comb += aligned_packet.eq(window >> Cat(C(0, 3), offset))
        fifo = stream.SyncFIFO(PTM_RESPONSE_LAYOUT, depth=8, buffered=True)
        self.fifo = fifo
        self.comb += fifo.source.connect(self.source)
        valid_d, start_d, bad_end_d, good_end_d, complete_d = [Signal() for _ in range(5)]
        self.sync += [
            valid_d.eq(valid), start_d.eq(start),
            bad_end_d.eq(bad_end), good_end_d.eq(good_end),
            complete_d.eq(pending & ((age + nbytes) >= 23) & ~bad_end &
                (~good_end | ((age + end_index) >= 23))),
            packet.eq(aligned_packet),
        ]
        is_response = (((packet[:8] == 0x34) | (packet[:8] == 0x74)) & (packet[56:64] == 0x53) &
            (packet[16:18] == 0) & (packet[24:32] == Mux(packet[6], 1, 0)))
        complete = valid & pending & ((age + nbytes) >= 23) & ~bad_end
        candidate = Signal()
        master_time = Signal(64)
        link_delay = Signal(32)
        decoded_time = Signal(64)
        decoded_delay = Signal(32)
        self.comb += [
            decoded_time.eq(Mux(packet[:8] == 0x74,
                Cat(*(packet[8*i:8*(i+1)] for i in reversed(range(8, 16)))), 0)),
            decoded_delay.eq(Mux(packet[:8] == 0x74,
                Cat(*(packet[8*i:8*(i+1)] for i in reversed(range(16, 20)))), 0)),
            fifo.sink.valid.eq(valid_d & good_end_d & ~bad_end_d & (candidate | (complete_d & is_response))),
            fifo.sink.message_code.eq(0x53),
            fifo.sink.master_time.eq(Mux(candidate, master_time, decoded_time)),
            fifo.sink.link_delay.eq(Mux(candidate, link_delay, decoded_delay)),
            self.overflow.eq(fifo.sink.valid & ~fifo.sink.ready),
        ]
        self.sync += If(valid,
            If(pending, age.eq(age + nbytes), offset.eq(offset - nbytes)),
            If(complete | bad_end | good_end, pending.eq(0)),
            If(start,
                pending.eq(1), age.eq(nbytes - start_index),
                offset.eq(history_bytes + 3 - nbytes + start_index),
            ),
        )
        self.sync += If(valid_d,
            If(complete_d & is_response,
                candidate.eq(1), master_time.eq(decoded_time), link_delay.eq(decoded_delay)),
            If(good_end_d | bad_end_d | start_d, candidate.eq(0)),
        )

# Multi-Lane PTM Receiver --------------------------------------------------------------------------


class PCIePTM8b10bReceiver(LiteXModule):
    """Passive multi-lane Gen1/Gen2 PTM receiver, two symbols/lane/clock.

    Link width is an actual lane count. Logical lane zero is at physical lane
    zero normally and at the highest physical lane when RX reversal is active.
    Alignment is reacquired at COM after reset, width/reversal changes or FIFO
    overflow. The consumer can monitor ``locked`` before requesting PTM.
    """
    def __init__(self, nlanes=4):
        assert nlanes in (1, 2, 4, 8)
        self.valid      = Signal(reset=1)
        self.lane_valid = Signal(nlanes, reset=(1 << nlanes) - 1)
        self.link_up    = Signal()
        self.lanes      = Signal(max=nlanes+1, reset=nlanes)
        self.reverse    = Signal()
        self.data       = Signal(16*nlanes)
        self.ctrl       = Signal(2*nlanes)
        self.locked     = Signal()
        self.overflow   = Signal()
        self.source     = stream.Endpoint(PTM_RESPONSE_LAYOUT)

        # # #

        previous_lanes = Signal.like(self.lanes)
        previous_reverse = Signal()
        reset = Signal(reset=1)
        valid_width = Reduce("OR", [self.lanes == n for n in (1, 2, 4, 8) if n <= nlanes])
        self.sync += reset.eq(~self.link_up | ~valid_width |
            (self.lanes != previous_lanes) | (self.reverse != previous_reverse) | self.overflow)
        self.sync += [previous_lanes.eq(self.lanes), previous_reverse.eq(self.reverse)]

        # Capture raw PIPE pins before descrambling: transceiver clock-to-out
        # and routing otherwise consume the combinational decoder's budget.
        input_data, input_ctrl = Signal.like(self.data), Signal.like(self.ctrl)
        input_valid, input_lane_valid = Signal(), Signal.like(self.lane_valid)
        self.sync += [
            input_data.eq(self.data), input_ctrl.eq(self.ctrl),
            input_valid.eq(self.valid), input_lane_valid.eq(self.lane_valid),
        ]
        buffers = []
        for lane in range(nlanes):
            descrambler = PCIe8b10bLaneDescrambler()
            buffer = ResetInserter()(PCIeLaneSymbolBuffer())
            self.submodules += descrambler, buffer
            decoded, control, valid = Signal(16), Signal(2), Signal()
            capturing, discard_first = Signal(), Signal()
            com0 = descrambler.ctrl[0] & (descrambler.data[:8] == COM)
            com1 = descrambler.ctrl[1] & (descrambler.data[8:] == COM)
            lane_valid = input_valid & input_lane_valid[lane] & self.link_up & ~reset
            self.sync += [
                decoded.eq(descrambler.decoded), control.eq(descrambler.ctrl),
                valid.eq(lane_valid & (capturing | com0 | com1)),
                discard_first.eq(~capturing & ~com0),
                If(reset, capturing.eq(0)).Elif(lane_valid & (com0 | com1), capturing.eq(1)),
            ]
            self.comb += [
                descrambler.valid.eq(input_valid & input_lane_valid[lane]),
                descrambler.data.eq(input_data[16*lane:16*(lane+1)]),
                descrambler.ctrl.eq(input_ctrl[2*lane:2*(lane+1)]),
                buffer.valid.eq(valid & ~reset),
                buffer.discard_first.eq(discard_first),
                buffer.data.eq(decoded),
                buffer.ctrl.eq(control),
                buffer.reset.eq(reset),
            ]
            buffers.append(buffer)
        self.buffers = buffers

        # Separate the buffer read mux from reversal and width conversion.
        captured_heads = [[Signal(9, reset_less=True) for _ in range(nlanes)] for _ in range(2)]
        captured_lanes = Signal.like(self.lanes)
        captured_reverse, captured_valid = Signal(), Signal()
        for symbol in range(2):
            for lane in range(nlanes):
                self.sync += captured_heads[symbol][lane].eq(buffers[lane].head[symbol])

        at_com = []
        ready = []
        heads = [[], []]
        overflow = []
        for lane in range(nlanes):
            physical = Mux(self.reverse, nlanes-1-lane, lane)
            level = Array(buffer.level for buffer in buffers)[physical]
            captured_physical = Mux(captured_reverse, nlanes-1-lane, lane)
            head0 = Array(captured_heads[0])[captured_physical]
            head1 = Array(captured_heads[1])[captured_physical]
            active = lane < self.lanes
            # Capture starts on COM in each lane, so a nonempty buffer is
            # aligned while acquiring lock. No read-pointer/COM feedback path.
            at_com.append(~active | (level != 0))
            ready.append(~active | (level >= 2))
            overflow.append(active & Array(buffer.overflow for buffer in buffers)[physical])
            heads[0].append(head0)
            heads[1].append(head1)
        all_com = Reduce("AND", at_com)
        all_ready = Reduce("AND", ready)
        # An overflowing lane suppresses its writes immediately. Register the
        # aggregate flush so FIFO occupancy does not drive every lane's reset
        # and read-pointer feedback in the same cycle.
        self.sync += self.overflow.eq(Reduce("OR", overflow))
        self.sync += If(reset, self.locked.eq(0)).Elif(all_com, self.locked.eq(1))
        for physical, buffer in enumerate(buffers):
            logical = Mux(self.reverse, nlanes-1-physical, physical)
            self.comb += If((logical < self.lanes) & ~reset,
                If(self.locked,
                    If(all_ready, buffer.pop.eq(2)),
                ),
            )

        receiver = ResetInserter()(PCIePTMSymbolReceiver(max_bytes=2*nlanes))
        self.receiver = receiver
        # Register the reconstructed beat before header parsing. In particular,
        # don't put the elastic-buffer read mux and header alignment shifter
        # in one 250 MHz timing path.
        beat_data, beat_ctrl = Signal(16*nlanes), Signal(2*nlanes)
        self.sync += [
            captured_valid.eq(self.locked & all_ready & ~reset),
            captured_lanes.eq(self.lanes), captured_reverse.eq(self.reverse),
            receiver.valid.eq(captured_valid & ~reset),
            receiver.nbytes.eq(2*captured_lanes),
            receiver.data.eq(beat_data), receiver.ctrl.eq(beat_ctrl),
        ]
        self.comb += [receiver.reset.eq(reset), receiver.source.connect(self.source)]
        # PIPE is lane-major; the logical byte stream is symbol-major.
        for width in (1, 2, 4, 8):
            if width <= nlanes:
                order = [heads[symbol][lane] for symbol in range(2) for lane in range(width)]
                self.comb += If(captured_lanes == width,
                    beat_data.eq(Cat(*(symbol[:8] for symbol in order))),
                    beat_ctrl.eq(Cat(*(symbol[8] for symbol in order))),
                )


# PIPE Tap Helpers ---------------------------------------------------------------------------------

def add_checked_tap_connections(platform, connections):
    """Check all vendor nets/tap pins before reconnecting any of them."""
    commands = []
    for net, pin in connections:
        commands += [
            f'if {{[llength [get_nets -quiet {{{net}}}]] != 1}} {{error {{PTM PIPE tap: missing net {net}}}}}',
            f'if {{[llength [get_pins -quiet {{{pin}}}]] != 1}} {{error {{PTM PIPE tap: missing pin {pin}}}}}',
        ]
    for net, pin in connections:
        commands += [
            f"set ptm_pipe_driver [get_nets -of_objects [get_pins {{{pin}}}]]",
            f"disconnect_net -net $ptm_pipe_driver -objects [get_pins {{{pin}}}]",
            f"connect_net -hier -net [get_nets {{{net}}}] -objects [get_pins {{{pin}}}]",
        ]
    platform.toolchain.pre_optimize_commands += [
        command.replace("{", "{{").replace("}", "}}") for command in commands]


def add_ptm_cdc_constraints(platform):
    # Resolve clocks only after the tap has been reconnected. In particular,
    # the UltraScale+ PIPE clock is not the placeholder PCIe user clock.
    # All sniffer/sys traffic uses the asynchronous response FIFO. The
    # 7-series rate-select mux can propagate more than one PIPE clock.
    commands = [
        'set ptm_rx_clock [get_clocks -of_objects [get_pins pcie_ptm_pipe_tap/clk_out]]',
        'set ptm_sys_clock [get_clocks -of_objects [get_nets sys_clk]]',
        ('if {![llength $ptm_rx_clock] || ![llength $ptm_sys_clock]} '
         '{error {PTM PIPE tap: missing receive or system clock}}'),
        ('foreach ptm_rx $ptm_rx_clock {foreach ptm_sys $ptm_sys_clock '
         '{if {$ptm_rx ne $ptm_sys} '
         '{set_clock_groups -asynchronous -group $ptm_rx -group $ptm_sys}}}'),
    ]
    platform.toolchain.pre_optimize_commands += [
        command.replace("{", "{{").replace("}", "}}") for command in commands]


# 7-Series PIPE Tap --------------------------------------------------------------------------------

class S7PCIePTMMultiLaneSniffer(LiteXModule):
    """Experimental multi-lane 7-series receive path; x1 keeps its old decoder."""
    def __init__(self, phy):
        if not phy.with_ptm or phy.mode != "Endpoint":
            raise ValueError("PTM requires an Endpoint PHY with with_ptm=True")
        nlanes = phy.nlanes
        assert nlanes in (2, 4, 8)
        self.source     = stream.Endpoint(PTM_RESPONSE_LAYOUT)
        self.cd_sniffer = ClockDomain()

        # # #

        self.specials += AsyncResetSynchronizer(self.cd_sniffer, ResetSignal("pcie"))
        raw_data, raw_ctrl = Signal(16*nlanes), Signal(2*nlanes)
        placeholder_data, placeholder_ctrl = Signal.like(raw_data), Signal.like(raw_ctrl)
        self.sync.pclk += [placeholder_data.eq(placeholder_data + 1), placeholder_ctrl.eq(placeholder_ctrl + 1)]
        self.specials += Instance("pipe_sniffer_tap", name="pcie_ptm_pipe_tap",
            p_DATA_WIDTH = len(raw_data), p_CTRL_WIDTH = len(raw_ctrl),
            i_clk_in = ClockSignal("pclk"), o_clk_out = ClockSignal("sniffer"),
            i_rx_data_in = placeholder_data, o_rx_data_out = raw_data,
            i_rx_ctrl_in = placeholder_ctrl, o_rx_ctrl_out = raw_ctrl,
        )
        phy.platform.add_source(os.path.join(os.path.dirname(__file__), "pipe_sniffer_tap.v"))
        connections = []
        for field, bits_per_lane, net in [
            ("ctrl", 2, "gt_rx_data_k_wire_filter"),
            ("data", 16, "gt_rx_data_wire_filter"),
        ]:
            for bit in range(bits_per_lane*nlanes):
                # The vendor bus reserves 32 data / 4 K bits per lane;
                # Gen1/2 use only the lower 16 / 2 bits of each slot.
                vendor_bit = (bit // bits_per_lane)*2*bits_per_lane + bit % bits_per_lane
                connections.append((f"pcie_s7/inst/inst/gt_top_i/{net}[{vendor_bit}]",
                    f"pcie_ptm_pipe_tap/rx_{field}_in[{bit}]"))
        add_checked_tap_connections(phy.platform, connections)
        add_ptm_cdc_constraints(phy.platform)

        reversal = Signal(2)
        phy.pcie_phy_params["o_pl_lane_reversal_mode"] = reversal
        width, reversed_lanes, link_up = Signal(2), Signal(2), Signal()
        ltssm = Signal(6)
        self.specials += [
            MultiReg(phy.pcie_phy_params["o_pl_sel_lnk_width"], width, "sniffer"),
            MultiReg(reversal, reversed_lanes, "sniffer"),
            MultiReg(phy.pcie_phy_params["o_pl_ltssm_state"], ltssm, "sniffer"),
            MultiReg(phy.pcie_phy_params["o_user_lnk_up"], link_up, "sniffer"),
        ]
        self.receiver = receiver = ClockDomainsRenamer("sniffer")(PCIePTM8b10bReceiver(nlanes))
        # PG054: reversal modes 1/2/3 reverse 2/4/8 physical lanes. Reversal
        # with downshift is not supported by the hard IP (table 3-47).
        full_reversal = {2: 1, 4: 2, 8: 3}[nlanes]
        self.comb += [
            receiver.data.eq(raw_data), receiver.ctrl.eq(raw_ctrl),
            receiver.lanes.eq(1 << width), receiver.reverse.eq(reversed_lanes != 0),
            receiver.link_up.eq(link_up & (ltssm == 0x10) &
                ((reversed_lanes == 0) | (reversed_lanes == full_reversal))),
        ]
        self.cdc = cdc = stream.ClockDomainCrossing(PTM_RESPONSE_LAYOUT,
            cd_from="sniffer", cd_to="sys")
        self.comb += [receiver.source.connect(cdc.sink), cdc.source.connect(self.source)]


# UltraScale+ PIPE Tap -----------------------------------------------------------------------------

class USPPCIePTMGen2Sniffer(LiteXModule):
    """Experimental PCIE4/PCIE4C Gen2 PIPE tap, with lane reversal disabled.

    The native hard-block pins avoid dependence on generated wrapper names.
    Gen3/4 128b/130b blocks are deliberately rejected by the PHY constructor.
    """
    def __init__(self, phy):
        if not phy.with_ptm or phy.mode != "Endpoint" or phy.speed != "gen2":
            raise ValueError("PTM requires an enabled Gen2 Endpoint PHY")
        nlanes = phy.nlanes
        self.source     = stream.Endpoint(PTM_RESPONSE_LAYOUT)
        self.cd_sniffer = ClockDomain()

        # # #

        self.specials += AsyncResetSynchronizer(self.cd_sniffer, ResetSignal("pcie"))
        raw_data, raw_ctrl = Signal(16*nlanes), Signal(3*nlanes+1)
        placeholder_data, placeholder_ctrl = Signal.like(raw_data), Signal.like(raw_ctrl)
        self.sync.pcie += [placeholder_data.eq(placeholder_data + 1), placeholder_ctrl.eq(placeholder_ctrl + 1)]
        self.specials += Instance("pipe_sniffer_tap", name="pcie_ptm_pipe_tap",
            p_DATA_WIDTH=len(raw_data), p_CTRL_WIDTH=len(raw_ctrl),
            i_clk_in=ClockSignal("pcie"), o_clk_out=ClockSignal("sniffer"),
            i_rx_data_in=placeholder_data, o_rx_data_out=raw_data,
            i_rx_ctrl_in=placeholder_ctrl, o_rx_ctrl_out=raw_ctrl,
        )
        phy.platform.add_source(os.path.join(os.path.dirname(__file__), "pipe_sniffer_tap.v"))
        connections = [("PIPECLK", "clk_in"), ("PIPECLKEN", f"rx_ctrl_in[{3*nlanes}]")]
        for lane in range(nlanes):
            connections.append((f"PIPERX{lane:02}VALID", f"rx_ctrl_in[{2*nlanes+lane}]"))
            for bit in range(16):
                connections.append((f"PIPERX{lane:02}DATA[{bit}]", f"rx_data_in[{16*lane+bit}]"))
            for bit in range(2):
                connections.append((f"PIPERX{lane:02}CHARISK[{bit}]", f"rx_ctrl_in[{2*lane+bit}]"))
        commands = [
            'set ptm_hard [get_cells -hier -filter {REF_NAME == PCIE40E4 || REF_NAME == PCIE4CE4}]',
            'if {[llength $ptm_hard] != 1} {error {PTM PIPE tap requires exactly one native PCIe block}}',
        ]
        # Collect and validate everything before touching the placeholder nets.
        for index, (source, target) in enumerate(connections):
            commands += [
                f'set ptm_net_{index} [get_nets -of_objects [get_pins [format {{%s/{source}}} $ptm_hard]]]',
                f'if {{[llength $ptm_net_{index}] != 1}} {{error {{PTM PIPE tap: missing {source}}}}}',
                f'if {{[llength [get_pins -quiet {{pcie_ptm_pipe_tap/{target}}}]] != 1}} {{error {{PTM PIPE tap: missing {target}}}}}',
            ]
        commands += [
            'proc litepcie_ptm_connect {source target} {',
            '    set pin [get_pins $target]',
            '    set old [get_nets -of_objects $pin]',
            '    set protected {}',
            '    foreach net [lsort -unique [concat $old $source]] {',
            '        if {[string is true -strict [get_property DONT_TOUCH $net]]} {',
            '            lappend protected $net',
            '            set_property DONT_TOUCH false $net',
            '        }',
            '    }',
            '    set failed [catch {',
            '        disconnect_net -net $old -objects $pin',
            '        connect_net -hier -net $source -objects $pin',
            '    } message options]',
            '    foreach net $protected {set_property DONT_TOUCH true $net}',
            '    if {$failed} {return -options $options $message}',
            '}',
        ]
        for index, (_, target) in enumerate(connections):
            commands.append(f'litepcie_ptm_connect $ptm_net_{index} {{pcie_ptm_pipe_tap/{target}}}')
        phy.platform.toolchain.pre_optimize_commands += [
            command.replace("{", "{{").replace("}", "}}") for command in commands]
        add_ptm_cdc_constraints(phy.platform)
        width, link_up, ltssm = Signal(3), Signal(), Signal(6)
        self.specials += [
            MultiReg(phy.pcie_usp_phy_params["o_cfg_negotiated_width"], width, "sniffer"),
            MultiReg(phy.pcie_usp_phy_params["o_user_lnk_up"], link_up, "sniffer"),
            MultiReg(phy.pcie_usp_phy_params["o_cfg_ltssm_state"], ltssm, "sniffer"),
        ]
        self.receiver = receiver = ClockDomainsRenamer("sniffer")(PCIePTM8b10bReceiver(nlanes))
        self.comb += [
            receiver.data.eq(raw_data), receiver.ctrl.eq(raw_ctrl[:2*nlanes]),
            receiver.valid.eq(raw_ctrl[3*nlanes]),
            receiver.lane_valid.eq(raw_ctrl[2*nlanes:3*nlanes]),
            receiver.lanes.eq(1 << width), receiver.link_up.eq(link_up & (ltssm == 0x10)),
        ]
        self.cdc = cdc = stream.ClockDomainCrossing(PTM_RESPONSE_LAYOUT,
            cd_from="sniffer", cd_to="sys")
        self.comb += [receiver.source.connect(cdc.sink), cdc.source.connect(self.source)]
