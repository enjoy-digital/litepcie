#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY wide Data Link Layers simulation with Verilator: two Data Link Layers of ndw DWs per
cycle on ideal lanes, TLPs of all the lengths around the beat boundaries both ways (compared to a
table), with a lane corruption every N TLPs (Naks and replays).

python3 bench/soft/sim_wide.py --ndw 4 --nlanes 4 [--tlps 200] [--corrupt-every 8]

With --phy: two multi-lane Physical Layers on transceiver models with Symbol shifts and skew per lane,
training to L0 (with --gen2 and a speed change to 5.0 GT/s), TLPs at full rate, Link Retrain.
"""

import random
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

from litepcie.phy.soft.common   import STP
from litepcie.phy.soft.dll.core import DataLinkLayer
from litepcie.phy.soft.lanes    import PCIeMultiLanePhysicalLayer
from litepcie.phy.soft.ltssm    import LTSSM_STATES
from litepcie.phy.soft.serdes.model import PCIeSerDesModel

_io = [
    ("sys_clk", 0, Pins(1)),
    ("sys_rst", 0, Pins(1)),
]

class Platform(SimPlatform):
    default_clk_name = "sys_clk"

    def __init__(self):
        SimPlatform.__init__(self, "SIM", _io)

def mwr_tlp(rng, ndws, tag):
    """Memory Write TLP DW words (byte 0 on bits 7:0): 3DW header + ndws DWs."""
    header = bytes([0x40, 0x00, (ndws >> 8) & 0x3, ndws & 0xff])
    header += bytes([0x01, 0x00, tag & 0xff, 0x0f])
    header += bytes([0x00, 0x00, 0x10, 0x00])
    data = header + bytes(rng.getrandbits(8) for _ in range(4*ndws))
    return [int.from_bytes(data[i:i+4], "little") for i in range(0, len(data), 4)]

def beats_table(rng, ndw, count, max_dws=64):
    """TLPs as beats: lengths around the beat boundaries, then random ones up to max_dws."""
    lengths = (list(range(1, 3*ndw + 4)) + [rng.randrange(1, max_dws) for _ in range(count)])[:count]
    table   = []
    for i, length in enumerate(lengths):
        tlp = mwr_tlp(rng, length, i)
        for j in range(0, len(tlp), ndw):
            beat = tlp[j:j+ndw]
            table.append(dict(
                data  = sum(dw << (32*k) for k, dw in enumerate(beat)),
                dws   = len(beat),
                first = int(j == 0),
                last  = int(j + ndw >= len(tlp)),
            ))
    return table

class BeatsGenerator(LiteXModule):
    def __init__(self, table, ndw):
        self.enable = Signal()
        self.source = source = stream.Endpoint([("data", 32*ndw), ("dws", bits_for(ndw))])
        self.done   = Signal()
        layout_w    = 32*ndw + bits_for(ndw) + 2
        init        = [b["data"] | (b["dws"] << (32*ndw)) | (b["first"] << (32*ndw + bits_for(ndw))) | (b["last"] << (32*ndw + bits_for(ndw) + 1)) for b in table]
        mem         = Memory(layout_w, len(table), init=init)
        port        = mem.get_port(async_read=True)
        self.specials += mem, port
        index = Signal(max=len(table) + 1)
        self.comb += [
            port.adr.eq(index),
            self.done.eq(index == len(table)),
            source.valid.eq(self.enable & ~self.done),
            source.data.eq(port.dat_r[0:32*ndw]),
            source.dws.eq(port.dat_r[32*ndw:32*ndw + bits_for(ndw)]),
            source.first.eq(port.dat_r[32*ndw + bits_for(ndw)]),
            source.last.eq(port.dat_r[32*ndw + bits_for(ndw) + 1]),
        ]
        self.sync += If(source.valid & source.ready, index.eq(index + 1))

class BeatsChecker(LiteXModule):
    def __init__(self, table, ndw):
        self.sink   = sink = stream.Endpoint([("data", 32*ndw), ("dws", bits_for(ndw))])
        self.errors = Signal(32)
        self.beats  = Signal(32)
        self.done   = Signal()
        layout_w    = 32*ndw + bits_for(ndw) + 2
        init        = [b["data"] | (b["dws"] << (32*ndw)) | (b["first"] << (32*ndw + bits_for(ndw))) | (b["last"] << (32*ndw + bits_for(ndw) + 1)) for b in table]
        mem         = Memory(layout_w, len(table), init=init)
        port        = mem.get_port(async_read=True)
        self.specials += mem, port
        index = Signal(max=len(table) + 1)
        mask  = Signal(32*ndw)
        self.comb += [
            port.adr.eq(index),
            self.done.eq(index == len(table)),
            sink.ready.eq(1),
            Case(sink.dws, {n: mask.eq((1 << 32*n) - 1) for n in range(0, ndw + 1)}),
        ]
        exp_data  = port.dat_r[0:32*ndw]
        exp_dws   = port.dat_r[32*ndw:32*ndw + bits_for(ndw)]
        exp_first = port.dat_r[32*ndw + bits_for(ndw)]
        exp_last  = port.dat_r[32*ndw + bits_for(ndw) + 1]
        self.sync += If(sink.valid,
            self.beats.eq(self.beats + 1),
            index.eq(index + 1),
            If(((sink.data & mask) != exp_data) | (sink.dws != exp_dws) | (sink.first != exp_first) | (sink.last != exp_last),
                self.errors.eq(self.errors + 1)
            )
        )

class WideDLLSim(SoCMini):
    def __init__(self, ndw, nlanes, tlps, corrupt_every, max_cycles=2**22):
        sys_clk_freq = int(125e6)
        platform = Platform()
        SoCMini.__init__(self, platform, clk_freq=sys_clk_freq)
        self.crg = CRG(platform.request("sys_clk"))

        timer = Signal(32)
        self.sync += timer.eq(timer + 1)

        kwargs = dict(ndw=ndw, nlanes=nlanes, tx_depth=4096, rx_depth=4096)
        self.dll_a = a = DataLinkLayer(sys_clk_freq, **kwargs)
        self.dll_b = b = DataLinkLayer(sys_clk_freq, **kwargs)
        self.comb += [
            a.link_up.eq(1), a.l0.eq(1), b.link_up.eq(1), b.l0.eq(1),
            a.phy_sink.ready.eq(1), b.phy_sink.ready.eq(1),
            a.phy_source.valid.eq(1), b.phy_source.valid.eq(1),
        ]

        # Lanes, a bit flipped in every corrupt_every-th TLP from a to b.
        tlp_count = Signal(16)
        corrupt   = Signal()
        is_stp    = a.phy_sink.valid & a.phy_sink.ctrl[0] & (a.phy_sink.data[0:8] == STP.value)
        self.sync += If(is_stp, tlp_count.eq(tlp_count + 1))
        if corrupt_every:
            self.comb += corrupt.eq(is_stp & ((tlp_count & (corrupt_every - 1)) == (corrupt_every - 1)))
        self.comb += [
            If(a.phy_sink.valid,
                b.phy_source.data.eq(a.phy_sink.data ^ (corrupt << 45)),
                b.phy_source.ctrl.eq(a.phy_sink.ctrl),
            ),
            If(b.phy_sink.valid,
                a.phy_source.data.eq(b.phy_sink.data),
                a.phy_source.ctrl.eq(b.phy_sink.ctrl),
            ),
        ]

        # TLPs both ways.
        table_ab = beats_table(random.Random(1), ndw, tlps)
        table_ba = beats_table(random.Random(2), ndw, tlps)
        self.gen_a = gen_a = BeatsGenerator(table_ab, ndw)
        self.gen_b = gen_b = BeatsGenerator(table_ba, ndw)
        self.chk_b = chk_b = BeatsChecker(table_ab, ndw)
        self.chk_a = chk_a = BeatsChecker(table_ba, ndw)
        self.comb += [
            gen_a.source.connect(a.sink),
            gen_b.source.connect(b.sink),
            b.source.connect(chk_b.sink),
            a.source.connect(chk_a.sink),
            gen_a.enable.eq(a.dl_active & b.dl_active),
            gen_b.enable.eq(a.dl_active & b.dl_active),
        ]

        done = Signal()
        self.comb += done.eq(chk_a.done & chk_b.done)
        done_r = Signal()
        self.sync += [
            done_r.eq(done),
            If(done & ~done_r,
                Display("[%08d] replays %d/%d, errors %d/%d, beats %d/%d, mismatches %d/%d", timer,
                    a.tx.replay.replays, b.tx.replay.replays, a.rx.errors, b.rx.errors,
                    chk_a.beats, chk_b.beats, chk_a.errors, chk_b.errors),
                If((chk_a.errors == 0) & (chk_b.errors == 0),
                    Display("SIM OK")
                ).Else(
                    Display("SIM ERRORS")
                ),
                Finish(),
            ),
            If(timer == max_cycles,
                Display("[%08d] TIMEOUT dl_active %d/%d beats %d/%d mismatches %d/%d replays %d/%d", timer, a.dl_active, b.dl_active,
                    chk_a.beats, chk_b.beats, chk_a.errors, chk_b.errors, a.tx.replay.replays, b.tx.replay.replays),
                Finish(),
            ),
        ]

class MultiLanePHYSim(SoCMini):
    def __init__(self, nlanes, tlps, gen2=False, timer_scale=100, max_cycles=2**23, rate_stall=0, dead_lanes=0, ndw=None):
        ndw = nlanes if ndw is None else ndw
        sys_clk_freq = int(125e6)
        platform = Platform()
        SoCMini.__init__(self, platform, clk_freq=sys_clk_freq)
        self.crg = CRG(platform.request("sys_clk"))

        # Clocks: link = sys (125 MHz), lanes = sys/2 at 2.5 GT/s, sys at 5.0 GT/s.
        self.cd_lane = ClockDomain()
        lane_clk = Signal()
        lane_5g  = Signal()
        self.sync += lane_clk.eq(~lane_clk)
        self.comb += self.cd_lane.clk.eq(Mux(lane_5g, ClockSignal("sys"), lane_clk))
        self.specials += AsyncResetSynchronizer(self.cd_lane, ResetSignal("sys"))
        timer = Signal(32)
        self.sync += timer.eq(timer + 1)

        # Transceiver models: Symbol shifts and word delays per lane, not the same both ways.
        shifts_up = [(i*3 + 1) % 4 for i in range(nlanes)]
        shifts_dn = [(i*5 + 3) % 4 for i in range(nlanes)]
        delays_up = [(i*2) % 3 for i in range(nlanes)]
        delays_dn = [(nlanes - i) % 3 for i in range(nlanes)]
        stalls_up = [(i*7 + 3)*rate_stall % 61 for i in range(nlanes)]
        stalls_dn = [(i*5 + 1)*rate_stall % 53 for i in range(nlanes)]
        self.serdes_up = serdes_up = PCIeSerDesModel(nlanes, tx_cd="lane", rx_cd="lane", rx_symbol_shift=shifts_up, rx_word_delay=delays_up, rx_rate_stall=stalls_up)
        self.serdes_dn = serdes_dn = PCIeSerDesModel(nlanes, tx_cd="lane", rx_cd="lane", rx_symbol_shift=shifts_dn, rx_word_delay=delays_dn, rx_rate_stall=stalls_dn)
        serdes_up.connect(serdes_dn)
        self.comb += lane_5g.eq(serdes_up.applied_rate & serdes_dn.applied_rate)
        renamer = ClockDomainsRenamer({"pcie_pipe": "lane", "pcie_link": "sys"})
        kwargs  = dict(timer_scale=timer_scale, gen2_capable=gen2, ndw=ndw)
        self.phy_up = phy_up = renamer(PCIeMultiLanePhysicalLayer(serdes_up, sys_clk_freq, upstream=True,  **kwargs))
        self.phy_dn = phy_dn = renamer(PCIeMultiLanePhysicalLayer(serdes_dn, sys_clk_freq, upstream=False, early_idle=True, **kwargs))
        self.comb += [
            phy_dn.link_number.eq(0x05),
            phy_up.lane_disable.eq(dead_lanes),
        ]

        # Data Link Layers.
        dll_kwargs = dict(ndw=ndw, nlanes=nlanes, tx_depth=4096, rx_depth=4096)
        self.dll_up = dll_up = DataLinkLayer(sys_clk_freq, **dll_kwargs)
        self.dll_dn = dll_dn = DataLinkLayer(sys_clk_freq, **dll_kwargs)
        for dll, phy in [(dll_up, phy_up), (dll_dn, phy_dn)]:
            self.comb += [
                dll.link_up.eq(phy.ltssm.link_up),
                dll.l0.eq(phy.ltssm.l0),
                dll.phy_sink.connect(phy.sink),
                phy.source.connect(dll.phy_source),
                phy.link_error.eq(dll.link_error),
            ]

        # TLPs both ways.
        table_ud = beats_table(random.Random(1), ndw, tlps)
        table_du = beats_table(random.Random(2), ndw, tlps)
        self.gen_up = gen_up = BeatsGenerator(table_ud, ndw)
        self.gen_dn = gen_dn = BeatsGenerator(table_du, ndw)
        self.chk_dn = chk_dn = BeatsChecker(table_ud, ndw)
        self.chk_up = chk_up = BeatsChecker(table_du, ndw)
        self.comb += [
            gen_up.source.connect(dll_up.sink),
            gen_dn.source.connect(dll_dn.sink),
            dll_dn.source.connect(chk_dn.sink),
            dll_up.source.connect(chk_up.sink),
        ]

        # Displays.
        names = {v: k for k, v in LTSSM_STATES.items()}
        for phy, label in [(phy_up, "UP  "), (phy_dn, "DOWN")]:
            state_r = Signal(6, reset=0x3f)
            self.sync += state_r.eq(phy.ltssm.state)
            self.sync += If(phy.ltssm.state != state_r,
                Case(phy.ltssm.state, {code: Display(f"[%08d] {label} {name}", timer) for code, name in names.items()})
            )

        # Sequence.
        both_l0 = phy_up.ltssm.l0 & phy_dn.ltssm.l0
        ready   = both_l0 & dll_up.dl_active & dll_dn.dl_active
        done    = chk_up.done & chk_dn.done
        half    = (chk_up.beats > len(table_du)//2) & (chk_dn.beats > len(table_ud)//2)
        self.fsm = fsm = FSM(reset_state="TRAIN")
        fsm.act("TRAIN",
            If(both_l0,
                Display("[%08d] L0 reached, link %d, lanes ok %x/%x, width x%d/x%d", timer, phy_up.ltssm.link, phy_up.lanes_ok, phy_dn.lanes_ok, phy_up.width, phy_dn.width),
                NextState("SPEED-CHANGE" if gen2 else "WAIT-READY")
            )
        )
        fsm.act("SPEED-CHANGE",
            phy_dn.speed_change.eq(1),
            NextState("SPEED-LEAVE"),
        )
        fsm.act("SPEED-LEAVE",
            If(~both_l0, NextState("SPEED-WAIT"))
        )
        fsm.act("SPEED-WAIT",
            If(both_l0,
                Display("[%08d] SPEED OK: rate %d/%d", timer, phy_up.ltssm.rate, phy_dn.ltssm.rate),
                NextState("WAIT-READY")
            )
        )
        fsm.act("WAIT-READY",
            If(ready,
                Display("[%08d] DL_Active, deskew locked %d/%d", timer, phy_up.deskew.locked, phy_dn.deskew.locked),
                NextState("DATA")
            )
        )
        fsm.act("DATA",
            gen_up.enable.eq(1),
            gen_dn.enable.eq(1),
            If(half,
                phy_up.retrain.eq(1),
                Display("[%08d] Link Retrain with traffic", timer),
                NextState("DATA-2")
            )
        )
        fsm.act("DATA-2",
            gen_up.enable.eq(1),
            gen_dn.enable.eq(1),
            If(done,
                Display("[%08d] replays %d/%d, errors %d/%d, beats %d/%d, mismatches %d/%d, 8b10b ok, overflows %d", timer,
                    dll_up.tx.replay.replays, dll_dn.tx.replay.replays, dll_up.rx.errors, dll_dn.rx.errors,
                    chk_up.beats, chk_dn.beats, chk_up.errors, chk_dn.errors, serdes_up.lanes[0].rx_overflows),
                If((chk_up.errors == 0) & (chk_dn.errors == 0),
                    Display("SIM OK")
                ).Else(
                    Display("SIM ERRORS")
                ),
                Finish(),
            )
        )
        self.sync += If(timer == max_cycles,
            Display("[%08d] TIMEOUT state %d/%d locked %d/%d lanes %x/%x dl %d/%d beats %d/%d mismatches %d/%d replays %d/%d errors %d/%d", timer,
                phy_up.ltssm.state, phy_dn.ltssm.state, phy_up.deskew.locked, phy_dn.deskew.locked, phy_up.lanes_ok, phy_dn.lanes_ok,
                dll_up.dl_active, dll_dn.dl_active, chk_up.beats, chk_dn.beats, chk_up.errors, chk_dn.errors,
                dll_up.tx.replay.replays, dll_dn.tx.replay.replays, dll_up.rx.errors, dll_dn.rx.errors),
            Finish(),
        )

def main():
    parser = argparse.ArgumentParser(description="Soft PCIe PHY wide Data Link Layers simulation.")
    parser.add_argument("--ndw",           default=None, type=int, help="DWs per cycle (default: the lanes).")
    parser.add_argument("--nlanes",        default=4, type=int, help="Link width.")
    parser.add_argument("--tlps",          default=200, type=int, help="TLPs exchanged in each direction.")
    parser.add_argument("--corrupt-every", default=0, type=int, help="Corrupt every Nth TLP from a to b (power of 2).")
    parser.add_argument("--phy",           action="store_true", help="With the multi-lane Physical Layers and transceiver models.")
    parser.add_argument("--gen2",          action="store_true", help="With --phy: speed change to 5.0 GT/s.")
    parser.add_argument("--rate-stall",    default=0, type=int, help="With --phy: receivers stopped after a rate change, differently per lane.")
    parser.add_argument("--dead-lanes",    default="0", help="With --phy: lanes out of service on the upstream side (mask).")
    parser.add_argument("--max-cycles",    default=2**22, type=int, help="Simulation timeout.")
    parser.add_argument("--output-dir",    default="build/soft_sim_wide", help="Build directory.")
    args = parser.parse_args()
    sim_config = SimConfig(default_clk="sys_clk")
    if args.phy:
        soc = MultiLanePHYSim(args.nlanes, args.tlps, gen2=args.gen2, max_cycles=args.max_cycles, rate_stall=args.rate_stall, dead_lanes=int(args.dead_lanes, 0), ndw=args.ndw)
    else:
        soc = WideDLLSim(args.ndw or args.nlanes, args.nlanes, args.tlps, args.corrupt_every)
    builder = Builder(soc, output_dir=args.output_dir, compile_software=False)
    builder.build(sim_config=sim_config, opt_level="O0", interactive=False)

if __name__ == "__main__":
    main()
