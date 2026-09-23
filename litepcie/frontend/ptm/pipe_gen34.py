#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Passive PCIe Gen3/Gen4 PTM response decoding at the PIPE interface.

The PCIE4/PCIE4C receive PIPE is 32 bits per lane at Gen3 and 64 bits at
Gen4. Each lane carries independent 128b/130b blocks; data bytes are striped
across the lanes after descrambling and removal of ordered sets.
"""

import os

from migen import *
from migen.genlib.cdc import MultiReg
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.gen import LiteXModule, Reduce
from litex.soc.interconnect import stream

from litepcie.frontend.ptm.pipe import PTM_RESPONSE_LAYOUT, add_ptm_cdc_constraints


# 128b/130b Scrambler ----------------------------------------------------------------------------


def _lfsr23(state):
    """Return 128 output bits and the next x^23+x^21+x^16+x^8+x^5+x^2+1 state.

    The bit ordering follows PCIe's LSB-first byte transmission. Construct
    parallel XOR masks at elaboration time to keep the 250 MHz path balanced.
    """
    masks = [1 << bit for bit in range(23)]
    outputs = []
    for _ in range(128):
        feedback = masks[22]
        outputs.append(feedback)
        masks = [0] + masks[:-1]
        for bit in range(23):
            if (0x210125 >> bit) & 1:
                masks[bit] ^= feedback

    def expression(mask):
        return Reduce("XOR", [state[bit] for bit in range(23) if mask & (1 << bit)])

    return Cat(*(expression(mask) for mask in outputs)), Cat(*(expression(mask) for mask in masks))


class PCIe128b130bLaneReceiver(LiteXModule):
    """Assemble and descramble one lane, acquiring the LFSR at an SOS block."""
    def __init__(self, data_width=32):
        assert data_width in (32, 64)
        self.valid       = Signal()
        self.start_block = Signal()
        self.header      = Signal(2)
        self.data        = Signal(data_width)
        self.link_up     = Signal()
        self.sos         = Signal()
        self.locked      = Signal()
        self.out_valid   = Signal()
        self.out_data    = Signal(128)

        # # #

        segments = 128 // data_width
        position = Signal(max=segments)
        assembling = Signal(128, reset_less=True)
        block = Signal(128, reset_less=True)
        block_header = Signal(2)
        block_valid = Signal()
        header = Signal(2)
        complete = Cat(assembling[data_width:], self.data)
        self.sync += [
            block_valid.eq(0),
            If(~self.link_up,
                position.eq(0),
            ).Elif(self.valid,
                If(self.start_block,
                    assembling.eq(self.data << (128-data_width)),
                    header.eq(self.header),
                    position.eq(1),
                ).Elif(position != 0,
                    If(position == segments-1,
                        block.eq(complete),
                        block_header.eq(header),
                        block_valid.eq(1),
                        position.eq(0),
                    ).Else(
                        assembling.eq(complete),
                        position.eq(position + 1),
                    ),
                ),
            ),
        ]

        # An SOS has a leading 0xaa and carries the 23-bit LFSR seed after
        # its 0xe1 marker. The marker can move within the 16-byte block.
        seed = Signal(23)
        found_seed = Signal()
        for byte in range(1, 13):
            self.comb += If(block[8*byte:8*(byte+1)] == 0xe1,
                seed.eq(Cat(block[8*(byte+3):8*(byte+4)],
                    block[8*(byte+2):8*(byte+3)],
                    block[8*(byte+1):8*(byte+2)])[:23]),
                found_seed.eq(1),
            )
        sos = (block_header == 2) & (block[:8] == 0xaa) & found_seed
        state = Signal(23)
        mask, advanced = _lfsr23(state)
        self.sync += [
            self.sos.eq(0),
            self.out_valid.eq(0),
            If(~self.link_up,
                self.locked.eq(0),
            ).Elif(block_valid,
                If(sos,
                    state.eq(seed),
                    self.locked.eq(1),
                    self.sos.eq(1),
                ).Else(
                    If(self.locked,
                        state.eq(advanced),
                        If(block_header == 1,
                            self.out_data.eq(block ^ mask),
                            self.out_valid.eq(1),
                        ),
                    ),
                ),
            ),
        ]


# PTM Message Recognition -------------------------------------------------------------------------


class PCIePTM128b130bMatcher(LiteXModule):
    """Find PTM Responses in adjacent deskewed, lane-striped data blocks.

    Gen3/4 STP is a two-byte token. Its 11-bit dword length includes the
    token, sequence number and TLP. A PTM Response is 4 dwords (no time) or
    7 dwords (time and propagation delay). TLP starts after the sequence
    number, four bytes after STP. TLP header checks make payload matches very
    unlikely; hardware validation should still include adversarial traffic.
    """
    def __init__(self, nlanes):
        assert nlanes in (4, 8)
        self.valid    = Signal()
        self.data     = Signal(128*nlanes)
        self.source   = stream.Endpoint(PTM_RESPONSE_LAYOUT)
        self.overflow = Signal()

        # # #

        block_bytes = 16*nlanes
        previous = Signal.like(self.data)
        have_previous = Signal()
        window = Signal(256*nlanes, reset_less=True)
        scan = Signal()
        self.sync += [
            scan.eq(0),
            If(self.valid,
                window.eq(Cat(previous, self.data)),
                previous.eq(self.data),
                scan.eq(have_previous),
                have_previous.eq(1),
            ),
        ]

        matches = []
        # An STP token starts on a dword boundary. Scan the older block only;
        # the newer one supplies the tail of a cross-block PTM packet.
        for start in range(0, block_bytes, 4):
            def byte(offset):
                return window[8*(start+offset):8*(start+offset+1)]

            with_time = byte(4) == 0x74
            no_time = byte(4) == 0x34
            length = byte(0)[4:8] == Mux(with_time, 7, 4)
            matches.append(
                (byte(0)[:4] == 0xf) & length & (byte(1)[:7] == 0) &
                (with_time | no_time) & (byte(5) == 0) &
                (byte(6) == 0) & (byte(7) == with_time) &
                (byte(10) == 0) & (byte(11) == 0x53)
            )
        match_bits = Signal(len(matches))
        window_d = Signal.like(window)
        scan_d = Signal()
        self.sync += [
            match_bits.eq(Cat(*matches)),
            window_d.eq(window),
            scan_d.eq(scan),
        ]
        selected = [
            match_bits[index] & ~Reduce("OR", [match_bits[bit] for bit in range(index)])
            if index else match_bits[0]
            for index in range(len(matches))
        ]
        times = []
        delays = []
        for index, chosen in enumerate(selected):
            start = 4*index
            def byte(offset):
                return window_d[8*(start+offset):8*(start+offset+1)]

            with_time = chosen & (byte(4) == 0x74)
            times.append(Mux(with_time,
                Cat(*(byte(offset) for offset in reversed(range(12, 20)))), 0))
            delays.append(Mux(with_time,
                Cat(*(byte(offset) for offset in reversed(range(20, 24)))), 0))

        master_time = Signal(64)
        link_delay = Signal(32)
        self.comb += [
            master_time.eq(Reduce("OR", times)),
            link_delay.eq(Reduce("OR", delays)),
        ]
        fifo = stream.SyncFIFO(PTM_RESPONSE_LAYOUT, depth=8, buffered=True)
        self.fifo = fifo
        self.comb += [
            fifo.sink.valid.eq(scan_d & Reduce("OR", [match_bits[i] for i in range(len(match_bits))])),
            fifo.sink.message_code.eq(0x53),
            fifo.sink.master_time.eq(master_time),
            fifo.sink.link_delay.eq(link_delay),
            fifo.source.connect(self.source),
            self.overflow.eq(fifo.sink.valid & ~fifo.sink.ready),
        ]


class PCIePTM128b130bReceiver(LiteXModule):
    """Decode and deskew four or eight PCIE4/PCIE4C receive lanes."""
    def __init__(self, nlanes=8, data_width=32):
        assert nlanes in (4, 8)
        assert data_width in (32, 64)
        self.valid       = Signal(reset=1)
        self.lane_valid  = Signal(nlanes, reset=(1 << nlanes)-1)
        self.start_block = Signal(nlanes)
        self.header      = Signal(2*nlanes)
        self.data        = Signal(data_width*nlanes)
        self.link_up     = Signal()
        self.locked      = Signal()
        self.overflow    = Signal()
        self.source      = stream.Endpoint(PTM_RESPONSE_LAYOUT)

        # # #

        lanes = []
        fifos = []
        overflow_d = Signal()
        self.sync += overflow_d.eq(self.overflow)
        for index in range(nlanes):
            lane = PCIe128b130bLaneReceiver(data_width)
            fifo = ResetInserter()(stream.SyncFIFO([("data", 128)], depth=8))
            self.submodules += lane, fifo
            self.comb += [
                lane.valid.eq(self.valid & self.lane_valid[index]),
                lane.start_block.eq(self.start_block[index]),
                lane.header.eq(self.header[2*index:2*(index+1)]),
                lane.data.eq(self.data[data_width*index:data_width*(index+1)]),
                lane.link_up.eq(self.link_up & ~overflow_d),
                fifo.reset.eq(~self.link_up | lane.sos | overflow_d),
                fifo.sink.valid.eq(lane.out_valid),
                fifo.sink.data.eq(lane.out_data),
            ]
            lanes.append(lane)
            fifos.append(fifo)

        locked = self.locked
        ready = Reduce("AND", [fifo.source.valid for fifo in fifos])
        self.comb += locked.eq(self.link_up & Reduce("AND", [lane.locked for lane in lanes]))
        matcher = ResetInserter()(PCIePTM128b130bMatcher(nlanes))
        self.matcher = matcher
        self.comb += [
            matcher.valid.eq(locked & ready),
            matcher.reset.eq(~self.link_up | overflow_d),
            self.overflow.eq(matcher.overflow | Reduce("OR", [
                fifo.sink.valid & ~fifo.sink.ready for fifo in fifos
            ])),
            matcher.source.connect(self.source),
        ]
        for fifo in fifos:
            self.comb += fifo.source.ready.eq(locked & ready)
        # PIPE carries lane-major data; PCIe bytes are striped across lanes.
        self.comb += matcher.data.eq(Cat(*(
            fifo.source.data[8*byte:8*(byte+1)]
            for byte in range(16) for fifo in fifos
        )))


# Native PIPE Tap ---------------------------------------------------------------------------------


class USPPCIePTMGen34Sniffer(LiteXModule):
    """PCIE4/PCIE4C Gen3/Gen4 native PIPE tap; lane reversal disabled."""
    def __init__(self, phy):
        if not phy.with_ptm or phy.mode != "Endpoint" or phy.speed not in ("gen3", "gen4"):
            raise ValueError("PTM requires an enabled Gen3/Gen4 Endpoint PHY")
        nlanes = phy.nlanes
        if nlanes not in (4, 8):
            raise ValueError("Gen3/Gen4 PTM receive supports x4/x8")
        data_width = 32 if phy.speed == "gen3" else 64
        self.source     = stream.Endpoint(PTM_RESPONSE_LAYOUT)
        self.cd_sniffer = ClockDomain()

        # # #

        self.specials += AsyncResetSynchronizer(self.cd_sniffer, ResetSignal("pcie"))
        raw_data = Signal(data_width*nlanes)
        raw_ctrl = Signal(5*nlanes+1)
        placeholder_data, placeholder_ctrl = Signal.like(raw_data), Signal.like(raw_ctrl)
        self.sync.pcie += [
            placeholder_data.eq(placeholder_data + 1),
            placeholder_ctrl.eq(placeholder_ctrl + 1),
        ]
        self.specials += Instance("pipe_sniffer_tap", name="pcie_ptm_pipe_tap",
            p_DATA_WIDTH=len(raw_data), p_CTRL_WIDTH=len(raw_ctrl),
            i_clk_in=ClockSignal("pcie"), o_clk_out=ClockSignal("sniffer"),
            i_rx_data_in=placeholder_data, o_rx_data_out=raw_data,
            i_rx_ctrl_in=placeholder_ctrl, o_rx_ctrl_out=raw_ctrl,
        )
        phy.platform.add_source(os.path.join(os.path.dirname(__file__), "pipe_sniffer_tap.v"))
        connections = [("PIPECLK", "clk_in"), ("PIPECLKEN", f"rx_ctrl_in[{5*nlanes}]")]
        for lane in range(nlanes):
            for bit in range(32):
                connections.append((f"PIPERX{lane:02}DATA[{bit}]",
                    f"rx_data_in[{data_width*lane+bit}]"))
                if data_width == 64:
                    connections.append((f"PIPERX{lane+8:02}DATA[{bit}]",
                        f"rx_data_in[{data_width*lane+32+bit}]"))
            connections += [
                (f"PIPERX{lane:02}VALID", f"rx_ctrl_in[{lane}]"),
                (f"PIPERX{lane:02}DATAVALID", f"rx_ctrl_in[{nlanes+lane}]"),
                (f"PIPERX{lane:02}STARTBLOCK[0]", f"rx_ctrl_in[{2*nlanes+lane}]"),
            ]
            for bit in range(2):
                connections.append((f"PIPERX{lane:02}SYNCHEADER[{bit}]",
                    f"rx_ctrl_in[{3*nlanes+2*lane+bit}]"))
        # Validate all pins before modifying any net, including the Gen4
        # second-bank pins that carry the upper half of lanes 0..7.
        commands = [
            'set ptm_hard [get_cells -hier -filter {REF_NAME == PCIE40E4 || REF_NAME == PCIE4CE4}]',
            'if {[llength $ptm_hard] != 1} {error {PTM PIPE tap requires exactly one native PCIe block}}',
        ]
        for index, (source, target) in enumerate(connections):
            commands += [
                f'set ptm_net_{index} [get_nets -of_objects [get_pins [format {{%s/{source}}} $ptm_hard]]]',
                f'if {{[llength $ptm_net_{index}] != 1}} {{error {{PTM PIPE tap: missing {source}}}}}',
                f'if {{[llength [get_pins -quiet {{pcie_ptm_pipe_tap/{target}}}]] != 1}} '
                f'{{error {{PTM PIPE tap: missing {target}}}}}',
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

        link_up, ltssm, width = Signal(), Signal(6), Signal(3)
        self.specials += [
            MultiReg(phy.pcie_usp_phy_params["o_user_lnk_up"], link_up, "sniffer"),
            MultiReg(phy.pcie_usp_phy_params["o_cfg_ltssm_state"], ltssm, "sniffer"),
            MultiReg(phy.pcie_usp_phy_params["o_cfg_negotiated_width"], width, "sniffer"),
        ]
        self.receiver = receiver = ClockDomainsRenamer("sniffer")(
            PCIePTM128b130bReceiver(nlanes, data_width))
        self.comb += [
            receiver.data.eq(raw_data),
            receiver.valid.eq(raw_ctrl[5*nlanes]),
            receiver.lane_valid.eq(raw_ctrl[:nlanes] & raw_ctrl[nlanes:2*nlanes]),
            receiver.start_block.eq(raw_ctrl[2*nlanes:3*nlanes]),
            receiver.header.eq(raw_ctrl[3*nlanes:5*nlanes]),
            receiver.link_up.eq(link_up & (ltssm == 0x10) & (width == (nlanes.bit_length()-1))),
        ]
        self.cdc = cdc = stream.ClockDomainCrossing(PTM_RESPONSE_LAYOUT,
            cd_from="sniffer", cd_to="sys")
        self.comb += [receiver.source.connect(cdc.sink), cdc.source.connect(self.source)]
