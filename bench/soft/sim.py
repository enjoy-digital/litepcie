#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY link simulation (Verilator): an upstream (endpoint) and a downstream (root)
Physical Layer trained through two serdes models, then framed packets exchanged, a Link Retrain
(Recovery) and packets again. The LTSSM states are displayed, the run ends with "SIM OK" (or a
timeout/error message).

Usage: python3 bench/soft/sim.py [--timer-scale 100] [--packets 64] [--trace]
"""

import argparse

from migen import *
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.gen import *

from litex.build.generic_platform import *
from litex.build.sim import SimPlatform
from litex.build.sim.config import SimConfig

from litex.soc.interconnect import stream
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder import Builder
from litex.soc.cores.clock import *

from litepcie.phy.soft.common       import STP, END, lane_layout
from litepcie.phy.soft.ltssm        import LTSSM_STATES
from litepcie.phy.soft.pipe         import PCIePhysicalLayer
from litepcie.phy.soft.serdes.model import PCIeSerDesModel

# IOs ----------------------------------------------------------------------------------------------

_io = [
    ("sys_clk", 0, Pins(1)),
    ("sys_rst", 0, Pins(1)),
]

# Platform -----------------------------------------------------------------------------------------

class Platform(SimPlatform):
    default_clk_name = "sys_clk"

    def __init__(self):
        SimPlatform.__init__(self, "SIM", _io)

# Packets ------------------------------------------------------------------------------------------

PACKET_SYMBOLS = 16 # STP + 14 payload Symbols + END (4 words).

def packet_symbol(packet, index):
    """(value, k) of Symbol index of packet (payload: packet number then non-zero counter)."""
    if index == 0:
        return STP.value, 1
    if index == PACKET_SYMBOLS - 1:
        return END.value, 1
    if index == 1:
        return 0x80 | (packet & 0x7f), 0
    return index + 1, 0

class PacketGenerator(LiteXModule):
    """Framed packets (first/last) on source while enabled, up to count packets."""
    def __init__(self, count):
        self.enable  = Signal()
        self.source  = source = stream.Endpoint(lane_layout(4))
        self.packets = Signal(max=count + 1)

        # # #

        word = Signal(2)
        packet_lsb = self.packets[:7]
        words = []
        for w in range(4):
            data = 0
            ctrl = 0
            for i in range(4):
                value, k = packet_symbol(0, 4*w + i)
                data |= value << 8*i
                ctrl |= k << i
            words.append((data, ctrl))
        self.comb += [
            source.valid.eq(self.enable & (self.packets != count)),
            source.first.eq(word == 0),
            source.last.eq(word == 3),
            Case(word, {w: [source.data.eq(d), source.ctrl.eq(c)] for w, (d, c) in enumerate(words)}),
            If(word == 0, source.data[8:16].eq(0x80 | packet_lsb)),
        ]
        self.sync += If(source.valid & source.ready,
            word.eq(word + 1),
            If(word == 3, self.packets.eq(self.packets + 1)),
        )

class PacketChecker(LiteXModule):
    """Checks the received Symbol stream (any word phase, Logical Idle skipped) against the
    generator's packets: packets and errors counted."""
    def __init__(self):
        self.sink    = sink = stream.Endpoint(lane_layout(4))
        self.packets = Signal(16)
        self.errors  = Signal(16)
        self.reset   = Signal()

        # # #

        self.comb += sink.ready.eq(1)
        index   = Signal(4)
        index_c = index
        packets_c = self.packets
        errors_c  = self.errors
        for i in range(4):
            sym  = sink.data[8*i:8*(i+1)]
            k    = sink.ctrl[i]
            idle = ~k & (sym == 0)
            # Expected Symbol at index_c.
            expected_d = Signal(8)
            expected_k = Signal()
            cases = {}
            for idx in range(PACKET_SYMBOLS):
                value, kk = packet_symbol(0, idx)
                cases[idx] = [expected_d.eq(value), expected_k.eq(kk)]
            self.comb += Case(index_c, cases)
            self.comb += If(index_c == 1, expected_d.eq(0x80 | packets_c[:7]))
            index_n   = Signal(4)
            packets_n = Signal(16)
            errors_n  = Signal(16)
            self.comb += [
                index_n.eq(index_c),
                packets_n.eq(packets_c),
                errors_n.eq(errors_c),
                If(sink.valid & ~idle,
                    If((sym != expected_d) | (k != expected_k),
                        errors_n.eq(errors_c + 1)
                    ),
                    If(index_c == PACKET_SYMBOLS - 1,
                        index_n.eq(0),
                        packets_n.eq(packets_c + 1),
                    ).Else(
                        index_n.eq(index_c + 1)
                    )
                )
            ]
            index_c, packets_c, errors_c = index_n, packets_n, errors_n
        self.sync += If(self.reset,
            index.eq(0),
            self.packets.eq(0),
            self.errors.eq(0),
        ).Else(
            index.eq(index_c),
            self.packets.eq(packets_c),
            self.errors.eq(errors_c),
        )

# Link Simulation ----------------------------------------------------------------------------------

class PCIeLinkSim(SoCMini):
    def __init__(self, timer_scale=100, packets=64, max_cycles=2**24, ts1_min=1024):
        sys_clk_freq = int(125e6)
        platform     = Platform()
        SoCMini.__init__(self, platform, clk_freq=sys_clk_freq)

        # Clocks: link clocks = sys (125 MHz), lane clock = sys/2 (62.5 MHz, 2.5 GT/s).
        self.crg = CRG(platform.request("sys_clk"))
        self.cd_lane = ClockDomain()
        lane_clk = Signal()
        self.sync += lane_clk.eq(~lane_clk)
        self.comb += self.cd_lane.clk.eq(lane_clk)
        self.specials += AsyncResetSynchronizer(self.cd_lane, ResetSignal("sys"))

        # SerDes models and Physical Layers.
        self.serdes_up = serdes_up = PCIeSerDesModel(tx_cd="lane", rx_cd="lane", rx_symbol_shift=1)
        self.serdes_dn = serdes_dn = PCIeSerDesModel(tx_cd="lane", rx_cd="lane", rx_symbol_shift=3)
        serdes_up.connect(serdes_dn)
        renamer = ClockDomainsRenamer({"pcie_pipe": "lane", "pcie_link": "sys"})
        self.phy_up = phy_up = renamer(PCIePhysicalLayer(serdes_up, sys_clk_freq, upstream=True,
            timer_scale=timer_scale, ts1_min=ts1_min))
        self.phy_dn = phy_dn = renamer(PCIePhysicalLayer(serdes_dn, sys_clk_freq, upstream=False,
            timer_scale=timer_scale, ts1_min=ts1_min))
        self.comb += phy_dn.link_number.eq(0x05)

        # Packets: upstream -> downstream and downstream -> upstream.
        self.gen_up = gen_up = PacketGenerator(packets)
        self.gen_dn = gen_dn = PacketGenerator(packets)
        self.chk_up = chk_up = PacketChecker() # Checks what the upstream receives.
        self.chk_dn = chk_dn = PacketChecker()
        self.comb += [
            gen_up.source.connect(phy_up.sink),
            gen_dn.source.connect(phy_dn.sink),
            phy_up.source.connect(chk_up.sink),
            phy_dn.source.connect(chk_dn.sink),
        ]

        # Timer/Displays.
        timer = Signal(32)
        self.sync += timer.eq(timer + 1)
        names = {v: k for k, v in LTSSM_STATES.items()}
        for phy, label in [(phy_up, "UP  "), (phy_dn, "DOWN")]:
            state_r = Signal(6, reset=0x3f)
            self.sync += state_r.eq(phy.ltssm.state)
            self.sync += If(phy.ltssm.state != state_r,
                Case(phy.ltssm.state, {code: Display(f"[%08d] {label} {name}", timer) for code, name in names.items()})
            )

        # Sequence.
        both_l0 = Signal()
        self.comb += both_l0.eq(phy_up.ltssm.l0 & phy_dn.ltssm.l0)
        done_up = (chk_dn.packets == packets)
        done_dn = (chk_up.packets == packets)
        self.fsm = fsm = FSM(reset_state="TRAIN")
        fsm.act("TRAIN",
            If(both_l0,
                Display("[%08d] L0 reached, link %d lane %d", timer, phy_up.ltssm.link, phy_up.ltssm.lane),
                NextState("DATA"),
            )
        )
        fsm.act("DATA",
            gen_up.enable.eq(1),
            gen_dn.enable.eq(1),
            If(done_up & done_dn,
                Display("[%08d] DATA OK: %d/%d packets, %d/%d errors", timer,
                    chk_dn.packets, chk_up.packets, chk_dn.errors, chk_up.errors),
                NextState("RETRAIN"),
            )
        )
        fsm.act("RETRAIN",
            phy_up.retrain.eq(1),
            NextState("RECOVERY"),
        )
        fsm.act("RECOVERY",
            If(~both_l0,
                NextState("WAIT-L0")
            )
        )
        fsm.act("WAIT-L0",
            chk_up.reset.eq(1),
            chk_dn.reset.eq(1),
            If(both_l0,
                Display("[%08d] RECOVERY OK", timer),
                NextState("DATA2"),
            )
        )
        gen2_up = PacketGenerator(packets)
        gen2_dn = PacketGenerator(packets)
        self.submodules += gen2_up, gen2_dn
        fsm.act("DATA2",
            gen2_up.source.connect(phy_up.sink),
            gen2_dn.source.connect(phy_dn.sink),
            gen2_up.enable.eq(1),
            gen2_dn.enable.eq(1),
            If(done_up & done_dn,
                Display("[%08d] DATA2 OK: %d/%d packets, %d/%d errors", timer,
                    chk_dn.packets, chk_up.packets, chk_dn.errors, chk_up.errors),
                If((chk_dn.errors == 0) & (chk_up.errors == 0),
                    Display("SIM OK"),
                ).Else(
                    Display("SIM ERRORS"),
                ),
                Finish(),
            )
        )
        self.sync += If(timer == max_cycles,
            Display("[%08d] TIMEOUT (state up %d, down %d)", timer, phy_up.ltssm.state, phy_dn.ltssm.state),
            Finish(),
        )

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Soft PCIe PHY link simulation.")
    parser.add_argument("--trace",       action="store_true",  help="Enable VCD tracing.")
    parser.add_argument("--trace-start", default=0,            help="Cycle to start VCD tracing.")
    parser.add_argument("--trace-end",   default=-1,           help="Cycle to end VCD tracing.")
    parser.add_argument("--timer-scale", default=100, type=int, help="LTSSM timers scale (1: specification values).")
    parser.add_argument("--ts1-min",     default=1024, type=int, help="TS1 transmitted in Polling.Active (specification: 1024).")
    parser.add_argument("--packets",     default=64,  type=int, help="Packets exchanged in each direction.")
    parser.add_argument("--max-cycles",  default=2**24, type=int, help="Simulation timeout (sys clock cycles).")
    parser.add_argument("--output-dir",  default="build/soft_sim", help="Build directory.")
    args = parser.parse_args()

    sim_config = SimConfig(default_clk="sys_clk")
    soc = PCIeLinkSim(
        timer_scale = args.timer_scale,
        packets     = args.packets,
        max_cycles  = args.max_cycles,
        ts1_min     = args.ts1_min,
    )
    builder = Builder(soc, output_dir=args.output_dir, compile_software=False)
    builder.build(sim_config=sim_config,
        opt_level   = "O0",
        interactive = False,
        trace       = args.trace,
        trace_start = int(args.trace_start),
        trace_end   = int(args.trace_end),
    )

if __name__ == "__main__":
    main()
