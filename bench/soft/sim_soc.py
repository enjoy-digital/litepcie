#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""SoftPCIEPHY SoC simulation (Verilator): the same integration as the Acorn target (SoC add_pcie,
64-bit DMA addressing, loopback) against a host model and the register sequence of the Linux driver:
enumeration, BAR0 CSR accesses, DMA Reader/Writer tables, DMA loopback through host memory (Memory
Read Requests answered with Completions split at the 64-byte Read Completion Boundary), MSIs counted,
destination buffers compared to the source ones. Ends with "SIM OK".

Usage: python3 bench/soft/sim_soc.py [--dma-size 1024] [--dma-buffers 4] [--mps 256] [--nlanes 4] [--dead-lanes 0xe] [--full-rate] [--trace]
With --gen3: the root changes the speed to 8.0 GT/s (equalization) before the script.
"""

import os
import sys
import argparse

from migen import *
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.gen import *

from litex.build.io import CRG
from litex.build.generic_platform import Pins
from litex.build.sim.config import SimConfig

from litex.soc.interconnect import stream
from litex.soc.integration import export
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder import Builder

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim_endpoint import Platform as _Platform, ScriptedRoot, dws, le32, be32, cfg, cpl, exact

from litepcie.phy.soft              import SoftPCIEPHY
from litepcie.phy.soft.pipe         import PCIePhysicalLayer
from litepcie.phy.soft.dll.core     import DataLinkLayer
from litepcie.phy.soft.lanes        import PCIeMultiLanePhysicalLayer
from litepcie.phy.soft.tl.wide      import DWsToBeats, BeatsToDWs
from litepcie.phy.soft.serdes.model import PCIeSerDesModel
from litepcie.phy.soft.tl.core      import TLPArbiter

class Platform(_Platform):
    def add_false_path_constraint(self, from_, to):
        pass # add_pcie's constraints: no meaning in simulation.

# Constants ----------------------------------------------------------------------------------------

BAR0      = 0xf0000000
BAR0_SIZE = 0x20000 # As the Acorn target.
MSI_ADDR  = 0xfee00000
MSI_DATA  = 0x4021
HOST_BASE = 0x123400000  # Above 4 GB: 64-bit requests (4DW headers).
HOST_DWS  = 2**14        # Host memory (64 KB).
RCB_DWS   = 16           # Read Completion Boundary: 64 bytes.

def host_word(i):
    """Source pattern (DW index), wire order: no two equal consecutive words."""
    return (i*0x9e3779b1 + 0x01234567) & 0xffffffff

# Host Model ---------------------------------------------------------------------------------------

class HostModel(LiteXModule):
    """Host memory and requests handling on the root Data Link Layer stream. sink: received requests
    (MWr to the memory or MSI, MRd from the memory); source: Completions."""
    def __init__(self, timer, src_dws, dst_offset, dma_dws):
        self.sink       = sink   = stream.Endpoint([("data", 32)])
        self.source     = source = stream.Endpoint([("data", 32)])
        self.msi_count  = Signal(16)
        self.mwr_count  = Signal(32) # Memory Write payload DWs.
        self.cpl_count  = Signal(32) # Completions.
        self.max_cpl    = Signal(8)
        self.errors     = Signal(16)
        self.compare    = Signal()   # i: compare the destination buffers with the source ones.
        self.compare_done = Signal() # o

        # # #

        mem = Memory(32, HOST_DWS, init=[host_word(i) for i in range(src_dws)])
        wr  = mem.get_port(write_capable=True)
        rd  = mem.get_port(async_read=True)
        cmp_a = mem.get_port(async_read=True)
        self.specials += mem, wr, rd, cmp_a

        # Requests ---------------------------------------------------------------------------------
        req = stream.SyncFIFO([("adr", 14), ("len", 11), ("tag", 8), ("req_id", 16)], 16, buffered=True)
        self.req = req
        dw0, dw1 = Signal(32), Signal(32)
        adr_hi   = Signal(32)
        adr      = Signal(32)
        be32_sw = lambda d: Cat(d[24:32], d[16:24], d[8:16], d[0:8])
        full_adr = Cat(Constant(0, 2), adr[2:32], adr_hi)
        offset   = Signal(14)
        is_msi   = Signal()
        self.comb += [
            offset.eq((full_adr - HOST_BASE)[2:16]),
            is_msi.eq((adr_hi == 0) & (adr == MSI_ADDR)),
        ]
        length = Cat(dw0[24:32], dw0[16:18])
        self.fsm = fsm = FSM(reset_state="DW0")
        fsm.act("DW0",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(dw0, sink.data),
                NextValue(adr_hi, 0),
                NextState("DW1"),
            )
        )
        fsm.act("DW1",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(dw1, sink.data),
                If(dw0[5],
                    NextState("ADR-HI")
                ).Else(
                    NextState("ADR-LO")
                )
            )
        )
        fsm.act("ADR-HI",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(adr_hi, be32_sw(sink.data)),
                NextState("ADR-LO"),
            )
        )
        fsm.act("ADR-LO",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(adr, be32_sw(sink.data)),
                If(sink.last,
                    NextState("MRD")
                ).Else(
                    NextState("MWR")
                )
            )
        )
        fsm.act("MRD",
            req.sink.valid.eq(1),
            req.sink.adr.eq(offset),
            req.sink.len.eq(Mux(length == 0, 1024, length)),
            req.sink.tag.eq(dw1[16:24]),
            req.sink.req_id.eq(Cat(dw1[8:16], dw1[0:8])),
            If(req.sink.ready,
                NextState("DW0")
            )
        )
        word = Signal(14)
        fsm.act("MWR",
            sink.ready.eq(1),
            wr.adr.eq(offset + word),
            wr.dat_w.eq(sink.data),
            If(sink.valid,
                wr.we.eq(~is_msi),
                NextValue(word, word + 1),
                NextValue(self.mwr_count, self.mwr_count + ~is_msi),
                If(is_msi,
                    NextValue(self.msi_count, self.msi_count + 1),
                    If(sink.data[0:16] != MSI_DATA,
                        NextValue(self.errors, self.errors + 1),
                    )
                ),
                If(sink.last,
                    NextValue(word, 0),
                    NextState("DW0"),
                )
            )
        )

        # Completions: split at the RCB, in order --------------------------------------------------
        c_adr, c_left, c_chunk, c_word = Signal(14), Signal(11), Signal(11), Signal(11)
        to_rcb  = Signal(11)
        chunk   = Signal(11)
        self.comb += [
            to_rcb.eq(RCB_DWS - c_adr[0:4]),
            chunk.eq(Mux(c_left < to_rcb, c_left, to_rcb)),
            rd.adr.eq(c_adr),
        ]
        byte_count = Cat(Constant(0, 2), c_left)[0:12]
        lower      = Cat(Constant(0, 2), c_adr[0:5])
        tag, req_id = req.source.tag, req.source.req_id
        self.cfsm = cfsm = FSM(reset_state="IDLE")
        cfsm.act("IDLE",
            If(req.source.valid,
                NextValue(c_adr, req.source.adr),
                NextValue(c_left, req.source.len),
                NextState("H0"),
            )
        )
        cfsm.act("H0",
            source.valid.eq(1), source.first.eq(1),
            source.data.eq(Cat(Constant(0x4a, 8), Constant(0, 8), Cat(chunk[8:10], Constant(0, 6)), chunk[0:8])),
            If(source.ready,
                NextValue(c_chunk, chunk),
                NextValue(c_word, 0),
                NextValue(self.cpl_count, self.cpl_count + 1),
                If(chunk > self.max_cpl, NextValue(self.max_cpl, chunk)),
                NextState("H1"),
            )
        )
        cfsm.act("H1",
            source.valid.eq(1),
            source.data.eq(Cat(Constant(0, 16), Cat(byte_count[8:12], Constant(0, 4)), byte_count[0:8])),
            If(source.ready, NextState("H2"))
        )
        cfsm.act("H2",
            source.valid.eq(1),
            source.data.eq(Cat(req_id[8:16], req_id[0:8], tag, lower)),
            If(source.ready, NextState("DATA"))
        )
        cfsm.act("DATA",
            source.valid.eq(1),
            source.data.eq(rd.dat_r),
            source.last.eq(c_word == c_chunk - 1),
            If(source.ready,
                NextValue(c_adr, c_adr + 1),
                NextValue(c_word, c_word + 1),
                NextValue(c_left, c_left - 1),
                If(source.last,
                    If(c_left == 1,
                        req.source.ready.eq(1),
                        NextState("IDLE"),
                    ).Else(
                        NextState("H0"),
                    )
                )
            )
        )

        # Compare ----------------------------------------------------------------------------------
        cmp_index = Signal(14)
        cmp_b     = mem.get_port(async_read=True)
        self.specials += cmp_b
        self.comb += [
            cmp_a.adr.eq(cmp_index),
            cmp_b.adr.eq(cmp_index + dst_offset),
        ]
        self.cmpfsm = cmpfsm = FSM(reset_state="WAIT")
        cmpfsm.act("WAIT",
            NextValue(cmp_index, 0),
            If(self.compare,
                NextState("RUN")
            )
        )
        cmpfsm.act("RUN",
            NextValue(cmp_index, cmp_index + 1),
            If(cmp_a.dat_r != cmp_b.dat_r,
                NextValue(self.errors, self.errors + 1),
            ),
            If(cmp_index == dma_dws - 1,
                NextState("DONE"),
            )
        )
        cmpfsm.act("DONE",
            self.compare_done.eq(1)
        )
        self.sync += If(cmpfsm.ongoing("RUN") & (cmp_a.dat_r != cmp_b.dat_r) & (self.errors < 4),
            Display("[%08d] host memory: word %d: source %08x, destination %08x", timer, cmp_index, cmp_a.dat_r, cmp_b.dat_r)
        )

# SoC ----------------------------------------------------------------------------------------------

class SoftPHYSoCSim(SoCMini):
    mem_map = {"csr": 0x00000000}

    def __init__(self, csrs=None, dma_size=1024, dma_buffers=4, mps=256, timer_scale=100, ts1_min=64, max_cycles=2**24, nlanes=1, dead_lanes=0, full_rate=False, gen3=False, mmio_reads=0, speed_down_at=0, independent_link=False):
        sys_clk_freq = int(125e6)
        platform     = Platform()
        SoCMini.__init__(self, platform, clk_freq=sys_clk_freq, csr_data_width=32, ident="soft sim", ident_version=False)

        # Clocks: "pcie_link" = sys (125 MHz), "pcie_pipe" = sys/2 (62.5 MHz, 2.5 GT/s) or sys (5.0 GT/s).
        # independent_link: "pcie_link" (and "pcie_pipe", derived from it) on a clock unrelated to sys, as on hardware
        # (sys from a local oscillator, pcie_link from the host's reference clock): the crossings between the
        # LitePCIe SoC and the PHY see two asynchronous clocks (the frequencies are set by main).
        self.crg = CRG(platform.request("sys_clk"))
        self.cd_pcie_link = ClockDomain()
        self.cd_pcie_pipe = ClockDomain()
        if independent_link:
            platform.add_extension([("link_clk", 0, Pins(1))])
            link_clk = platform.request("link_clk")
        else:
            link_clk = ClockSignal("sys")
        lane_clk = Signal()
        lane_sync = getattr(self.sync, "pcie_link" if independent_link else "sys")
        lane_sync += lane_clk.eq(~lane_clk)
        lane_fast = Signal() # 8.0 GT/s: lanes at the link clock too (the rates differ by their words).
        self.comb += [
            self.cd_pcie_link.clk.eq(link_clk),
            self.cd_pcie_link.rst.eq(ResetSignal("sys")),
            self.cd_pcie_pipe.clk.eq(link_clk if full_rate else Mux(lane_fast, link_clk, lane_clk)),
        ]
        self.specials += AsyncResetSynchronizer(self.cd_pcie_pipe, ResetSignal("sys"))
        # 8.0 GT/s datapath: the lane clock in simulation.
        self.cd_pcie_g3 = ClockDomain()
        self.comb += [self.cd_pcie_g3.clk.eq(self.cd_pcie_pipe.clk), self.cd_pcie_g3.rst.eq(self.cd_pcie_pipe.rst)]
        timer = Signal(32)
        self.sync += timer.eq(timer + 1)

        # Link.
        kwargs = dict(tx_cd="pcie_pipe", rx_cd="pcie_pipe")
        serdes_ep   = PCIeSerDesModel(nlanes, rx_symbol_shift=[(i + 1) % 4 for i in range(nlanes)], rx_word_delay=[i % 2 for i in range(nlanes)], **kwargs)
        serdes_root = PCIeSerDesModel(nlanes, rx_symbol_shift=[(i + 2) % 4 for i in range(nlanes)], rx_word_delay=[(i + 1) % 2 for i in range(nlanes)], **kwargs)
        self.submodules += serdes_ep, serdes_root
        serdes_ep.connect(serdes_root)

        # Device: as the Acorn target.
        ndw  = 2*nlanes if gen3 else nlanes
        wide = (nlanes > 1) or gen3 # Multi-lane path, also x1 at 8.0 GT/s.
        self.pcie_phy = phy = SoftPCIEPHY(platform, None,
            data_width  = 64 if nlanes == 1 else 32*ndw,
            speed       = "gen3" if gen3 else "gen1",
            bar0_size   = BAR0_SIZE,
            serdes      = serdes_ep,
            link_freq   = sys_clk_freq,
            timer_scale = timer_scale,
            ts1_min     = ts1_min,
        )
        self.add_pcie(phy=phy, ndmas=1, address_width=64, with_dma_loopback=True)
        if dead_lanes:
            self.comb += phy.phy_layer.lane_disable.eq(dead_lanes)

        if csrs is None:
            return # First pass: CSR map only.

        # Root.
        root_cls = PCIeMultiLanePhysicalLayer if wide else PCIePhysicalLayer
        root_kw  = dict(early_idle=True) if wide else {}
        if gen3:
            root_kw.update(gen3_capable=True, ndw=ndw)
        self.root_phy = root_phy = root_cls(serdes_root, sys_clk_freq, upstream=False,
            timer_scale=timer_scale, ts1_min=ts1_min, **root_kw)
        dll_kw = dict(ndw=ndw, nlanes=nlanes, rx_depth=2048*ndw, tx_depth=1024*ndw,
            framing="both" if gen3 else "8b10b") if wide else {}
        self.root_dll = root_dll = ClockDomainsRenamer("pcie_link")(DataLinkLayer(sys_clk_freq, **dll_kw))
        if gen3:
            # Speed change directed by the root on its first L0, lanes clock at sys from 5.0 GT/s.
            l0_seen = Signal()
            self.sync.pcie_link += If(root_phy.ltssm.l0, l0_seen.eq(1))
            # Speed change down to 2.5 GT/s at speed_down_at (Target Link Speed of the root lowered).
            down_pulse = Signal()
            down_at = speed_down_at
            if down_at:
                self.comb += down_pulse.eq(timer == down_at + 1)
                self.sync += If(timer == down_at, root_phy.ltssm.max_rate.eq(0), Display("[%08d] Root: speed change down", timer))
            g3_seen = Signal()
            self.sync += If(root_phy.ltssm.rate == 2, g3_seen.eq(1))
            self.comb += [
                root_phy.speed_change.eq((root_phy.ltssm.l0 & ~l0_seen) | down_pulse),
                lane_fast.eq((serdes_ep.applied_rate != 0) & (serdes_root.applied_rate != 0)),
                root_dll.gen3.eq(root_phy.ltssm.rate == 2),
            ]
            rate_r = Signal(2)
            self.sync += rate_r.eq(root_phy.ltssm.rate)
            self.sync += If(root_phy.ltssm.rate != rate_r, Display("[%08d] Root rate %d", timer, root_phy.ltssm.rate))
        self.comb += [
            root_dll.link_up.eq(root_phy.ltssm.link_up),
            root_dll.l0.eq(root_phy.ltssm.l0),
            root_dll.phy_sink.connect(root_phy.sink),
            root_phy.source.connect(root_dll.phy_source),
        ]

        # Host model and script on the root Data Link Layer: Completions to the script, requests to
        # the host model; transmit arbitrated per TLP.
        dma_dws    = dma_size*dma_buffers//4
        dst_offset = HOST_DWS//2
        self.host  = host = ClockDomainsRenamer("pcie_link")(HostModel(timer, dma_dws, dst_offset, dma_dws))
        class Port: pass
        port = Port()
        port.dl_active = root_dll.dl_active & (((root_phy.ltssm.rate == 2) | g3_seen) if gen3 else 1)
        port.sink      = stream.Endpoint([("data", 32)])
        port.source    = stream.Endpoint([("data", 32)])
        steps = script(csrs, phy.bar0_mask, dma_size, dma_buffers, mps, mmio_reads)
        self.root = root = ClockDomainsRenamer("pcie_link")(ScriptedRoot(port, steps, timer))
        self.comb += root.wait_count.eq(host.msi_count)
        if wide:
            root_tx = ClockDomainsRenamer("pcie_link")(DWsToBeats(ndw))
            root_rx = ClockDomainsRenamer("pcie_link")(BeatsToDWs(ndw))
            self.submodules += root_tx, root_rx
            self.comb += [root_tx.source.connect(root_dll.sink), root_dll.source.connect(root_rx.sink)]
            root_tx_sink, root_rx_source = root_tx.sink, root_rx.source
        else:
            root_tx_sink, root_rx_source = root_dll.sink, root_dll.source
        self.tx_arbiter = ClockDomainsRenamer("pcie_link")(TLPArbiter([host.source, port.sink], root_tx_sink))
        rx = root_rx_source
        rx_is_cpl = Signal()
        rx_cpl_r  = Signal()
        rx_first  = Signal(reset=1)
        self.sync.pcie_link += If(rx.valid & rx.ready,
            rx_first.eq(rx.last),
            If(rx_first, rx_cpl_r.eq(rx.data[0:5] == 0b01010)),
        )
        self.comb += [
            rx_is_cpl.eq(Mux(rx_first, rx.data[0:5] == 0b01010, rx_cpl_r)),
            If(rx_is_cpl,
                port.source.valid.eq(rx.valid),
                port.source.data.eq(rx.data),
                port.source.first.eq(rx.first),
                port.source.last.eq(rx.last),
                rx.ready.eq(port.source.ready),
            ).Else(
                rx.connect(host.sink),
            )
        ]

        # Displays / end.
        self.comb += host.compare.eq(root.done)
        dl_r = Signal()
        self.sync += dl_r.eq(phy.dll.dl_active)
        self.sync += If(phy.dll.dl_active & ~dl_r, Display("[%08d] Device DL_Active", timer))
        self.sync += [
            If(root.done & host.compare_done,
                Display("[%08d] DMA: %d DWs written to host memory, %d MSIs, %d completions (max %d DWs)", timer,
                    host.mwr_count, host.msi_count, host.cpl_count, host.max_cpl),
                Display("[%08d] MPS %d, MRRS %d, id %04x, replays %d/%d, receiver errors %d/%d", timer,
                    phy.max_payload_size, phy.max_request_size, phy.id,
                    phy.dll.tx.replay.replays, root_dll.tx.replay.replays, phy.dll.rx.errors, root_dll.rx.errors),
                If((root.errors == 0) & (host.errors == 0) & (host.mwr_count >= dma_dws),
                    Display("SIM OK")
                ).Else(
                    Display("SIM ERRORS: script %d, host %d", root.errors, host.errors)
                ),
                Finish(),
            ),
            If(timer == max_cycles,
                Display("[%08d] TIMEOUT: root step %d, %d MSIs, %d DWs, ltssm %x, replays %d/%d", timer,
                    root.step, host.msi_count, host.mwr_count, phy.phy_layer.ltssm.state,
                    phy.dll.tx.replay.replays, root_dll.tx.replay.replays),
                Finish(),
            )
        ]

# Script (litepcie/software/kernel/main.c sequence) ------------------------------------------------

def mwr32(adr, data):
    return dws(0x40, 0, 0, 1,  0, 0, 0, 0x0f,  *be32(adr),  *le32(data))

def mrd32(adr, tag):
    return dws(0x00, 0, 0, 1,  0, 0, tag, 0x0f,  *be32(adr))

def script(csrs, bar0_mask, dma_size, dma_buffers, mps, mmio_reads=0):
    t = iter(range(10000))
    tag = lambda: next(t) & 0xff
    s = []
    def cfg_wr(name, adr, value):
        n = tag()
        s.append(dict(name=name, tx=cfg(adr, n, value), rx=exact(cpl(n))))
    def csr_wr(name, value, offset=0):
        s.append(dict(name=f"{name} <= {value:08x}", tx=mwr32(BAR0 + csrs[name] + offset, value), rx=[]))
    def csr_rd(name, value):
        n = tag()
        adr = BAR0 + csrs[name]
        s.append(dict(name=f"{name} read", tx=mrd32(adr, n), rx=exact(cpl(n, data=value, lower=adr & 0x7f))))

    # Enumeration.
    cfg_wr("BAR0 assignment",   0x10, BAR0)
    cfg_wr("Command: MSE, BME", 0x04, 0x00000006)
    mps_field = {128: 0, 256: 1, 512: 2}[mps]
    cfg_wr(f"Device Control: MPS {mps}", 0x68, 0x00002810 | (mps_field << 5))
    cfg_wr("MSI Address",       0x4c, MSI_ADDR)
    cfg_wr("MSI Data",          0x54, MSI_DATA)
    cfg_wr("MSI Enable",        0x48, 0x00010000)

    # CSRs: scratch reset value (byte order as the driver's readl), write, read back.
    csr_rd("ctrl_scratch", 0x12345678)
    csr_wr("ctrl_scratch", 0xa5a50001)
    csr_rd("ctrl_scratch", 0xa5a50001)

    # MSIs: DMA Writer and Reader interrupts enabled.
    csr_wr("pcie_msi_enable", 0xffffffff)
    csr_wr("pcie_dma0_loopback_enable", 1)

    # DMA tables and start (driver: litepcie_dma_writer_start/litepcie_dma_reader_start).
    DMA_LAST_DISABLE = 1 << 25
    dst = HOST_BASE + 4*(HOST_DWS//2)
    for name, base in [("writer", dst), ("reader", HOST_BASE)]:
        prefix = f"pcie_dma0_{name}"
        csr_wr(f"{prefix}_enable", 0)
        csr_wr(f"{prefix}_table_reset", 1)
        csr_wr(f"{prefix}_table_loop_prog_n", 0)
        for i in range(dma_buffers):
            adr = base + i*dma_size
            csr_wr(f"{prefix}_table_value", DMA_LAST_DISABLE | dma_size)
            csr_wr(f"{prefix}_table_value", adr & 0xffffffff, offset=4)
            csr_wr(f"{prefix}_table_we", adr >> 32)
        csr_wr(f"{prefix}_table_loop_prog_n", 1)
    csr_wr("pcie_dma0_writer_enable", 1)
    csr_wr("pcie_dma0_reader_enable", 1)

    # BAR0 reads while the DMA runs (the driver polls the DMA status registers).
    for i in range(mmio_reads):
        csr_rd("ctrl_scratch", 0xa5a50001)

    # All the Writer buffers done at least once (one MSI per buffer on each of the Reader and Writer),
    # then stopped; a read flushes the posted writes.
    s.append(dict(name="Waiting for the DMA MSIs", tx=[], rx=[], wait=2*dma_buffers + 2))
    csr_wr("pcie_dma0_reader_enable", 0)
    csr_wr("pcie_dma0_writer_enable", 0)
    csr_rd("ctrl_scratch", 0xa5a50001)
    return s

# Build --------------------------------------------------------------------------------------------

def csr_map(soc):
    """CSR name: BAR0 offset, from the first pass CSR map (as the driver's csr.h)."""
    soc.finalize()
    csv = export.get_csr_csv(soc, soc.csr_regions, soc.constants, soc.mem_regions)
    csrs = {}
    for line in csv.splitlines():
        fields = line.split(",")
        if fields[0] == "csr_register":
            csrs[fields[1]] = int(fields[2], 0)
    return csrs

def main():
    parser = argparse.ArgumentParser(description="SoftPCIEPHY SoC simulation.")
    parser.add_argument("--trace",       action="store_true",   help="Enable VCD tracing.")
    parser.add_argument("--dma-size",    default=1024, type=int, help="DMA buffer size (bytes).")
    parser.add_argument("--dma-buffers", default=4,    type=int, help="DMA buffers.")
    parser.add_argument("--nlanes",      default=1,    type=int, help="Lanes of the design.")
    parser.add_argument("--dead-lanes",  default="0",  help="Device lanes out of service (mask), for a narrower link.")
    parser.add_argument("--full-rate",   action="store_true", help="Lanes at the 5.0 GT/s rate.")
    parser.add_argument("--gen3",        action="store_true", help="Speed change to 8.0 GT/s.")
    parser.add_argument("--mps",         default=256,  type=int, help="Max Payload Size (128, 256, 512).")
    parser.add_argument("--mmio-reads",  default=0,    type=int, help="BAR0 reads while the DMA runs.")
    parser.add_argument("--speed-down-at", default=0,  type=int, help="With --gen3: speed change down to 2.5 GT/s at this cycle (0: none).")
    parser.add_argument("--timer-scale", default=100,  type=int, help="LTSSM timers scale.")
    parser.add_argument("--ts1-min",     default=64,   type=int, help="TS1 transmitted in Polling.Active (specification: 1024).")
    parser.add_argument("--max-cycles",  default=2**22, type=int, help="Simulation timeout (sys clock cycles).")
    parser.add_argument("--sys-link-ratio", default=None, type=float, help="sys/pcie_link frequency ratio, on unrelated clocks (ex: 0.8333).")
    parser.add_argument("--output-dir",  default="build/soft_sim_soc", help="Build directory.")
    args = parser.parse_args()

    csrs = csr_map(SoftPHYSoCSim(nlanes=args.nlanes, gen3=args.gen3))
    soc  = SoftPHYSoCSim(csrs,
        nlanes      = args.nlanes,
        dead_lanes  = int(args.dead_lanes, 0),
        full_rate   = args.full_rate,
        gen3        = args.gen3,
        dma_size    = args.dma_size,
        dma_buffers = args.dma_buffers,
        mps         = args.mps,
        mmio_reads  = args.mmio_reads,
        speed_down_at = args.speed_down_at,
        timer_scale = args.timer_scale,
        ts1_min     = args.ts1_min,
        max_cycles  = args.max_cycles,
        independent_link = args.sys_link_ratio is not None,
    )
    if args.sys_link_ratio is None:
        sim_config = SimConfig(default_clk="sys_clk")
    else:
        # Verilator clockers have integer ps periods: keep sys/link as a small fraction of round periods.
        from fractions import Fraction
        ratio      = Fraction(args.sys_link_ratio).limit_denominator(16) # sys freq / link freq = link period / sys period.
        unit       = 2400 # ps.
        sim_config = SimConfig()
        sim_config.add_clocker("sys_clk",  freq_hz=1e12/(ratio.denominator*unit))
        sim_config.add_clocker("link_clk", freq_hz=1e12/(ratio.numerator*unit))
    builder = Builder(soc, output_dir=args.output_dir, compile_software=False)
    builder.build(sim_config=sim_config, opt_level="O0", interactive=False, trace=args.trace)

if __name__ == "__main__":
    main()
