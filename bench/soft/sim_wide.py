#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY wide Data Link Layers simulation with Verilator: two Data Link Layers of ndw DWs per
cycle on ideal lanes, TLPs of all the lengths around the beat boundaries both ways (compared to a
table), with a lane corruption every N TLPs (Naks and replays).

python3 bench/soft/sim_wide.py --ndw 4 --nlanes 4 [--tlps 200] [--corrupt-every 7]
"""

import random
import argparse

from migen import *

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

def main():
    parser = argparse.ArgumentParser(description="Soft PCIe PHY wide Data Link Layers simulation.")
    parser.add_argument("--ndw",           default=4, type=int, help="DWs per cycle.")
    parser.add_argument("--nlanes",        default=4, type=int, help="Link width.")
    parser.add_argument("--tlps",          default=200, type=int, help="TLPs exchanged in each direction.")
    parser.add_argument("--corrupt-every", default=0, type=int, help="Corrupt every Nth TLP from a to b (power of 2).")
    parser.add_argument("--output-dir",    default="build/soft_sim_wide", help="Build directory.")
    args = parser.parse_args()
    sim_config = SimConfig(default_clk="sys_clk")
    soc = WideDLLSim(args.ndw, args.nlanes, args.tlps, args.corrupt_every)
    builder = Builder(soc, output_dir=args.output_dir, compile_software=False)
    builder.build(sim_config=sim_config, opt_level="O0", interactive=False)

if __name__ == "__main__":
    main()
