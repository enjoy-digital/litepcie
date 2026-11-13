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

from litepcie.phy.soft.common       import STP, SDP, END, lane_layout
from litepcie.phy.soft.ltssm        import LTSSM_STATES
from litepcie.phy.soft.pipe         import PCIePhysicalLayer
from litepcie.phy.soft.serdes.model import PCIeSerDesModel
from litepcie.phy.soft.dll.core     import DataLinkLayer

# IOs ----------------------------------------------------------------------------------------------

_io = [
    ("sys_clk",  0, Pins(1)),
    ("sys_rst",  0, Pins(1)),
    ("lane_clk", 0, Pins(1)), # Independent lane clock (--link-freq != 125 MHz).
    ("dcu_clk",  0, Pins(1)), # ECP5 DCU clock, 2x the lane clock (--serdes ecp5).
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

# TLPs ---------------------------------------------------------------------------------------------

TLP_PAYLOAD_DWS = 4

def tlp_dw(packet, index):
    """DW index of TLP packet (Memory Write, 3DW header + TLP_PAYLOAD_DWS DWs), byte 0 on bits 7:0."""
    if index == 0:
        return int.from_bytes(bytes([0x40, 0x00, 0x00, TLP_PAYLOAD_DWS]), "little")
    if index == 1:
        return int.from_bytes(bytes([0x01, 0x00, packet & 0xff, 0x0f]), "little")
    if index == 2:
        return 0x00100000
    i = index - 3
    return ((0x80 | (packet & 0x7f)) | ((i + 1) << 8) | (0x5a << 16) | (((packet*7 + i) & 0xff) << 24))

TLP_DWS = 3 + TLP_PAYLOAD_DWS

class TLPGenerator(LiteXModule):
    """TLPs (DW words, first/last) on source while enabled, up to count TLPs."""
    def __init__(self, count):
        self.enable  = Signal()
        self.source  = source = stream.Endpoint([("data", 32)])
        self.packets = Signal(max=count + 1)

        # # #

        index = Signal(max=TLP_DWS)
        cases = {}
        for i in range(TLP_DWS):
            cases[i] = source.data.eq(tlp_dw(0, i))
        self.comb += [
            source.valid.eq(self.enable & (self.packets != count)),
            source.first.eq(index == 0),
            source.last.eq(index == TLP_DWS - 1),
            Case(index, cases),
            If(index == 1, source.data[16:24].eq(self.packets[:8])),
            If(index >= 3,
                source.data[0:8].eq(0x80 | self.packets[:7]),
                source.data[24:32].eq((self.packets*7 + (index - 3))[:8]),
            ),
        ]
        self.sync += If(source.valid & source.ready,
            If(index == TLP_DWS - 1,
                index.eq(0),
                self.packets.eq(self.packets + 1),
            ).Else(
                index.eq(index + 1)
            )
        )

class TLPChecker(LiteXModule):
    """Checks the received TLPs (DW words) against the generator's: packets and errors counted."""
    def __init__(self):
        self.sink    = sink = stream.Endpoint([("data", 32)])
        self.packets = Signal(16)
        self.errors  = Signal(16)
        self.reset   = Signal()

        # # #

        self.comb += sink.ready.eq(1)
        index    = Signal(max=TLP_DWS)
        expected = Signal(32)
        cases    = {}
        for i in range(TLP_DWS):
            cases[i] = expected.eq(tlp_dw(0, i))
        self.comb += [
            Case(index, cases),
            If(index == 1, expected[16:24].eq(self.packets[:8])),
            If(index >= 3,
                expected[0:8].eq(0x80 | self.packets[:7]),
                expected[24:32].eq((self.packets*7 + (index - 3))[:8]),
            ),
        ]
        self.sync += If(self.reset,
            index.eq(0),
            self.packets.eq(0),
            self.errors.eq(0),
        ).Elif(sink.valid,
            If((sink.data != expected) | (sink.first != (index == 0)) | (sink.last != (index == TLP_DWS - 1)),
                self.errors.eq(self.errors + 1)
            ),
            If(sink.last,
                index.eq(0),
                self.packets.eq(self.packets + 1),
            ).Else(
                index.eq(index + 1)
            )
        )

# Link Simulation ----------------------------------------------------------------------------------

class PCIeLinkSim(SoCMini):
    """with_dll: Data Link Layers on both sides (TLPs exchanged through them, replay on errors),
    corrupt_every: a raw lane word corrupted after every Nth TLP from the upstream, drop_dllp_every:
    every Nth DLLP from the downstream dropped (Acks lost: replay timer)."""
    def __init__(self, timer_scale=100, packets=64, max_cycles=2**24, ts1_min=1024, with_dll=False,
        corrupt_every=0, drop_dllp_every=0, debug=False, gen2=False, fail_5g=False, link_freq=125e6, serdes="model"):
        # link_freq != 125 MHz: the lane clock (2.5 GT/s, 62.5 MHz) is an independent clock instead of sys/2, to
        # check the Physical Layer/Data Link Layer with a link clock closer to the lane clock (ECP5).
        independent_lane = (link_freq != 125e6)
        assert not (independent_lane and gen2), "Gen2 needs the 125 MHz link clock."
        # serdes="ecp5": the ECP5 PCIeSerDes adapter (LiteICLink SerDesECP5) on a behavioral DCU model (Gen1 only).
        assert serdes in ["model", "ecp5"]
        assert not (serdes == "ecp5" and (gen2 or not independent_lane)), "ECP5: Gen1 with --link-freq != 125 MHz."
        sys_clk_freq = int(link_freq)
        platform     = Platform()
        SoCMini.__init__(self, platform, clk_freq=sys_clk_freq)

        # Clocks: link clocks = sys (link_freq, 125 MHz), lane clock = sys/2 (62.5 MHz, 2.5 GT/s).
        self.crg = CRG(platform.request("sys_clk"))
        self.cd_lane = ClockDomain()
        lane_5g = Signal()
        if independent_lane:
            # Independent lane clock (separate Verilator clocker, see main).
            self.comb += self.cd_lane.clk.eq(platform.request("lane_clk"))
        else:
            lane_clk = Signal()
            self.sync += lane_clk.eq(~lane_clk)
            # Lane clock = sys (125 MHz, 5.0 GT/s) once both sides applied the rate.
            self.comb += self.cd_lane.clk.eq(Mux(lane_5g, ClockSignal("sys"), lane_clk))
        self.specials += AsyncResetSynchronizer(self.cd_lane, ResetSignal("sys"))

        # Timer.
        timer = Signal(32)
        self.sync += timer.eq(timer + 1)

        # SerDes models and Physical Layers.
        corrupt = Signal()
        if serdes == "ecp5":
            # Two ECP5 PCIeSerDes on DCU models (serial line between them, any bit offset), domains per side.
            from litepcie.phy.soft.serdes.ecp5 import ECP5PCIeSerDes
            from litepcie.phy.soft.serdes.ecp5_model import SerDesECP5Model
            lane_clk, dcu_clk = self.cd_lane.clk, platform.request("dcu_clk")
            line_ud, line_du = Signal(20), Signal(20)
            ei_ud,   ei_du   = Signal(), Signal()
            sides = {}
            for side, bit_offset, line_out, line_in, ei_out, ei_in, side_corrupt in [
                ("u", 3, line_ud, line_du, ei_ud, ei_du, None),
                ("d", 7, line_du, line_ud, ei_du, ei_ud, corrupt)]:
                pads = Record([("tx_p", 1), ("tx_n", 1), ("rx_p", 1), ("rx_n", 1), ("perst", 1)])
                self.comb += pads.perst.eq(1)
                model_kwargs = dict(bit_offset=bit_offset, line_out=line_out, line_in=line_in, ei_out=ei_out, ei_in=ei_in,
                    corrupt=side_corrupt, dcu_clk=dcu_clk, lane_clk=lane_clk)
                serdes_cls = lambda *args, mk=model_kwargs, **kwargs: SerDesECP5Model(*args, model_kwargs=mk, **kwargs)
                names = {"pcie_pipe": f"{side}_lane", "pcie_rx0": f"{side}_rx", "pcie_tx_full": f"{side}_txf",
                    "pcie_rx_full": f"{side}_rxf", "pcie_link": "sys"}
                ser = ClockDomainsRenamer(names)(ECP5PCIeSerDes(platform, pads, link_freq=link_freq, serdes_cls=serdes_cls,
                    refclk=Signal(), with_clocking=False))
                sides[side] = (ser, {"pcie_pipe": f"{side}_lane", "pcie_link": "sys"})
            self.serdes_up, self.serdes_dn = serdes_up, serdes_dn = sides["u"][0], sides["d"][0]
            renamer_up, renamer_dn = ClockDomainsRenamer(sides["u"][1]), ClockDomainsRenamer(sides["d"][1])
        else:
            self.serdes_up = serdes_up = PCIeSerDesModel(tx_cd="lane", rx_cd="lane", rx_symbol_shift=1)
            self.serdes_dn = serdes_dn = PCIeSerDesModel(tx_cd="lane", rx_cd="lane", rx_symbol_shift=3)
            # Raw lanes, with a word corruption after every corrupt_every TLPs from the upstream.
            self.comb += [
                serdes_dn.tx[0].connect(serdes_up.rx[0]),
                serdes_up.tx[0].connect(serdes_dn.rx[0], omit={"data"}),
                serdes_dn.rx[0].data.eq(serdes_up.tx[0].data ^ (corrupt << 17)),
                serdes_dn.rx_idle.eq(serdes_up.tx_idle),
                serdes_up.rx_idle.eq(serdes_dn.tx_idle),
                serdes_up.partner_rate.eq(serdes_dn.applied_rate),
                serdes_dn.partner_rate.eq(serdes_up.applied_rate),
                serdes_up.fail_5g.eq(fail_5g),
                lane_5g.eq(serdes_up.applied_rate & serdes_dn.applied_rate),
            ]
            renamer = ClockDomainsRenamer({"pcie_pipe": "lane", "pcie_link": "sys"})
            renamer_up = renamer_dn = renamer
        self.phy_up = phy_up = renamer_up(PCIePhysicalLayer(serdes_up, sys_clk_freq, upstream=True,
            timer_scale=timer_scale, ts1_min=ts1_min, gen2_capable=gen2))
        self.phy_dn = phy_dn = renamer_dn(PCIePhysicalLayer(serdes_dn, sys_clk_freq, upstream=False,
            timer_scale=timer_scale, ts1_min=ts1_min, gen2_capable=gen2))
        self.comb += phy_dn.link_number.eq(0x05)

        # Packets: upstream -> downstream and downstream -> upstream.
        self.with_dll = with_dll
        if with_dll:
            self.dll_up = dll_up = DataLinkLayer(sys_clk_freq)
            self.dll_dn = dll_dn = DataLinkLayer(sys_clk_freq)
            for dll, phy in [(dll_up, phy_up), (dll_dn, phy_dn)]:
                self.comb += [
                    dll.link_up.eq(phy.ltssm.link_up),
                    dll.l0.eq(phy.ltssm.l0),
                    phy.link_error.eq(dll.link_error),
                    phy.source.connect(dll.phy_source),
                ]
            # DLLPs from the downstream dropped every drop_dllp_every (the SDP word and the next).
            dllp_count = Signal(16)
            dropping   = Signal()
            is_sdp     = dll_dn.phy_sink.valid & dll_dn.phy_sink.ctrl[0] & (dll_dn.phy_sink.data[0:8] == SDP.value)
            drop       = Signal()
            if drop_dllp_every:
                self.comb += drop.eq((is_sdp & (dllp_count == drop_dllp_every - 1)) | dropping)
                self.sync += [
                    If(dll_dn.phy_sink.valid & dll_dn.phy_sink.ready,
                        dropping.eq(is_sdp & (dllp_count == drop_dllp_every - 1)),
                        If(is_sdp,
                            If(dllp_count == drop_dllp_every - 1,
                                dllp_count.eq(0)
                            ).Else(
                                dllp_count.eq(dllp_count + 1)
                            )
                        )
                    )
                ]
            self.comb += [
                dll_up.phy_sink.connect(phy_up.sink),
                dll_dn.phy_sink.connect(phy_dn.sink, omit={"valid"}),
                phy_dn.sink.valid.eq(dll_dn.phy_sink.valid & ~drop),
            ]
            self.gen_up = gen_up = TLPGenerator(packets)
            self.gen_dn = gen_dn = TLPGenerator(packets)
            self.chk_up = chk_up = TLPChecker() # Checks what the upstream receives.
            self.chk_dn = chk_dn = TLPChecker()
            self.comb += [
                gen_up.source.connect(dll_up.sink),
                gen_dn.source.connect(dll_dn.sink),
                dll_up.source.connect(chk_up.sink),
                dll_dn.source.connect(chk_dn.sink),
            ]
            # Debug displays (DLLPs sent/received, DLCMSM states).
            if debug:
                for dll, label in [(dll_up, "UP  "), (dll_dn, "DOWN")]:
                    state_r = Signal(2, reset=0)
                    self.sync += state_r.eq(dll.state)
                    self.sync += If(dll.state != state_r,
                        Display(f"[%08d] {label} DLCMSM state %d", timer, dll.state)
                    )
                    self.sync += If(dll.tx.dllp_ready,
                        Display(f"[%08d] {label} DLLP sent     %012x", timer, dll.tx.dllp)
                    )
                    self.sync += If(dll.rx.dllp_valid,
                        Display(f"[%08d] {label} DLLP received %012x (crc_ok %d)", timer, dll.rx.dllp, dll.decoder.crc_ok)
                    )
                    self.sync += If(dll.rx.framer.error,
                        Display(f"[%08d] {label} framing error", timer)
                    )
                    sdp_word = dll.phy_source.valid & dll.phy_source.ready & dll.phy_source.ctrl[0] & (dll.phy_source.data[0:8] == SDP.value)
                    self.sync += If(sdp_word,
                        Display(f"[%08d] {label} SDP word in   %08x", timer, dll.phy_source.data)
                    )
            # Corruption: after every corrupt_every TLPs started by the upstream on the lane.
            if corrupt_every:
                tlp_count = Signal(16)
                arm       = Signal()
                is_stp    = phy_up.sink.valid & phy_up.sink.ready & phy_up.sink.ctrl[0] & (phy_up.sink.data[0:8] == STP.value)
                self.sync += [
                    If(is_stp,
                        If(tlp_count == corrupt_every - 1,
                            tlp_count.eq(0),
                            arm.eq(1),
                        ).Else(
                            tlp_count.eq(tlp_count + 1)
                        )
                    ),
                ]
                # Corrupt one raw word a few lane cycles after the STP (inside the TLP).
                delay = Signal(4)
                self.sync.lane += [
                    corrupt.eq(0),
                    If(arm & (delay != 3),
                        delay.eq(delay + 1)
                    ).Elif(arm,
                        corrupt.eq(1),
                        delay.eq(0),
                    )
                ]
                self.sync += If(corrupt, arm.eq(0))
        else:
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

        # Displays.
        names = {v: k for k, v in LTSSM_STATES.items()}
        for phy, label in [(phy_up, "UP  "), (phy_dn, "DOWN")]:
            state_r = Signal(6, reset=0x3f)
            self.sync += state_r.eq(phy.ltssm.state)
            self.sync += If(phy.ltssm.state != state_r,
                Case(phy.ltssm.state, {code: Display(f"[%08d] {label} {name}", timer) for code, name in names.items()})
            )

        # Sequence.
        both_l0 = Signal()
        ready   = Signal() # Data can flow (L0, and DL_Active with the Data Link Layers).
        self.comb += both_l0.eq(phy_up.ltssm.l0 & phy_dn.ltssm.l0)
        if with_dll:
            self.comb += ready.eq(both_l0 & dll_up.dl_active & dll_dn.dl_active)
            dl_active_r = Signal()
            self.sync += dl_active_r.eq(dll_up.dl_active & dll_dn.dl_active)
            self.sync += If((dll_up.dl_active & dll_dn.dl_active) & ~dl_active_r,
                Display("[%08d] DL_Active (both)", timer)
            )
        else:
            self.comb += ready.eq(both_l0)
        done_up = (chk_dn.packets == packets)
        done_dn = (chk_up.packets == packets)
        self.fsm = fsm = FSM(reset_state="TRAIN")
        fsm.act("TRAIN",
            If(both_l0,
                Display("[%08d] L0 reached, link %d lane %d", timer, phy_up.ltssm.link, phy_up.ltssm.lane),
                NextState("SPEED-CHANGE" if gen2 else "WAIT-READY"),
            )
        )
        # Speed change from the downstream, 5.0 GT/s expected or 2.5 GT/s if the upstream can't lock.
        fsm.act("SPEED-CHANGE",
            phy_dn.speed_change.eq(1),
            NextState("SPEED-LEAVE"),
        )
        fsm.act("SPEED-LEAVE",
            If(~both_l0,
                NextState("SPEED-WAIT")
            )
        )
        fsm.act("SPEED-WAIT",
            If(both_l0,
                Display("[%08d] SPEED OK: rate %d/%d", timer, phy_up.ltssm.rate, phy_dn.ltssm.rate),
                NextState("WAIT-READY"),
            )
        )
        fsm.act("WAIT-READY",
            If(ready,
                NextState("DATA")
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
            If(ready,
                Display("[%08d] RECOVERY OK", timer),
                NextState("DATA2"),
            )
        )
        gen2_up = (TLPGenerator if with_dll else PacketGenerator)(packets)
        gen2_dn = (TLPGenerator if with_dll else PacketGenerator)(packets)
        sink_up = dll_up.sink if with_dll else phy_up.sink
        sink_dn = dll_dn.sink if with_dll else phy_dn.sink
        self.submodules += gen2_up, gen2_dn
        fsm.act("DATA2",
            gen2_up.source.connect(sink_up),
            gen2_dn.source.connect(sink_dn),
            gen2_up.enable.eq(1),
            gen2_dn.enable.eq(1),
            If(done_up & done_dn,
                Display("[%08d] DATA2 OK: %d/%d packets, %d/%d errors", timer,
                    chk_dn.packets, chk_up.packets, chk_dn.errors, chk_up.errors),
                *([Display("[%08d] replays: up %d, down %d; receiver errors: up %d, down %d", timer,
                    dll_up.tx.replay.replays, dll_dn.tx.replay.replays, dll_up.rx.errors, dll_dn.rx.errors)] if with_dll else []),
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
    parser.add_argument("--with-dll",    action="store_true",  help="Data Link Layers on both sides (TLPs, Acks, replay).")
    parser.add_argument("--gen2",        action="store_true",  help="Speed change to 5.0 GT/s after the training, traffic at full rate.")
    parser.add_argument("--fail-5g",     action="store_true",  help="With --gen2: the upstream can't receive at 5.0 GT/s (fallback to 2.5 GT/s).")
    parser.add_argument("--corrupt-every", default=0, type=int, help="Corrupt a lane word after every Nth upstream TLP (--with-dll).")
    parser.add_argument("--drop-dllp-every", default=0, type=int, help="Drop every Nth downstream DLLP (--with-dll).")
    parser.add_argument("--debug",       action="store_true",  help="Display the DLLPs and Data Link Layer states (--with-dll).")
    parser.add_argument("--link-freq",   default=125e6,   type=float, help="Link clock (Hz), != 125 MHz: independent lane clock (Gen1).")
    parser.add_argument("--serdes",      default="model", choices=["model", "ecp5"], help="Lane: model, or ECP5 PCIeSerDes on a DCU model.")
    parser.add_argument("--max-cycles",  default=2**24, type=int, help="Simulation timeout (sys clock cycles).")
    parser.add_argument("--output-dir",  default="build/soft_sim", help="Build directory.")
    args = parser.parse_args()

    if args.link_freq == 125e6:
        sim_config = SimConfig(default_clk="sys_clk")
    else:
        # Verilator clockers have integer ps periods and step at their GCD: keep the lane/link period ratio
        # (62.5 MHz / link_freq) as a small fraction of a round period (the frequencies are relative, the
        # Physical/Data Link Layer timers take link_freq).
        from fractions import Fraction
        ratio  = Fraction(62.5e6/args.link_freq).limit_denominator(32) # lane freq / link freq = link period / lane period.
        unit   = 2500 # ps.
        sim_config = SimConfig()
        # Link clock: the shorter period (link_freq > 62.5 MHz).
        sim_config.add_clocker("sys_clk",  freq_hz=1e12/(ratio.numerator*unit))
        sim_config.add_clocker("lane_clk", freq_hz=1e12/(ratio.denominator*unit))
        if args.serdes == "ecp5":
            sim_config.add_clocker("dcu_clk", freq_hz=2e12/(ratio.denominator*unit)) # DCU clock: 2x the lane clock.
    soc = PCIeLinkSim(
        gen2    = args.gen2,
        fail_5g = args.fail_5g,
        timer_scale = args.timer_scale,
        packets     = args.packets,
        max_cycles  = args.max_cycles,
        ts1_min     = args.ts1_min,
        with_dll        = args.with_dll,
        corrupt_every   = args.corrupt_every,
        drop_dllp_every = args.drop_dllp_every,
        debug           = args.debug,
        link_freq       = args.link_freq,
        serdes          = args.serdes,
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
