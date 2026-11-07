#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""SoftPCIEPHY end-to-end simulation (Verilator): a scripted root (soft Physical and Data Link Layers
in the downstream role, TLPs compared Symbol-exact) enumerates a LitePCIe endpoint on SoftPCIEPHY:
configuration space, BAR0 accesses through LitePCIeEndpoint/LitePCIeWishboneMaster to a SRAM (byte
order checked against the wire), Unsupported Requests, MSI, device reads and writes through
LitePCIeWishboneSlave. Ends with "SIM OK" (or a mismatch/timeout message).

Usage: python3 bench/soft/sim_endpoint.py [--data-width 64] [--trace]
"""

import argparse

from migen import *
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.gen import *

from litex.build.generic_platform import *
from litex.build.sim import SimPlatform
from litex.build.sim.config import SimConfig

from litex.soc.interconnect import wishbone
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder import Builder
from litex.build.io import CRG

from litepcie.core.endpoint       import LitePCIeEndpoint
from litepcie.frontend.wishbone   import LitePCIeWishboneMaster, LitePCIeWishboneSlave
from litepcie.phy.soft            import SoftPCIEPHY
from litepcie.phy.soft.pipe       import PCIePhysicalLayer
from litepcie.phy.soft.dll.core   import DataLinkLayer
from litepcie.phy.soft.lanes      import PCIeMultiLanePhysicalLayer
from litepcie.phy.soft.tl.wide    import DWsToBeats, BeatsToDWs
from litepcie.phy.soft.serdes.model import PCIeSerDesModel

# IOs/Platform -------------------------------------------------------------------------------------

_io = [
    ("sys_clk", 0, Pins(1)),
    ("sys_rst", 0, Pins(1)),
]

class Platform(SimPlatform):
    default_clk_name = "sys_clk"

    def __init__(self):
        SimPlatform.__init__(self, "SIM", _io)

# TLP helpers (DWs in wire order, byte 0 on bits 7:0) ----------------------------------------------

def dws(*data):
    data = bytes(data)
    assert len(data) % 4 == 0
    return [int.from_bytes(data[i:i+4], "little") for i in range(0, len(data), 4)]

def le32(value):
    return value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff

def be32(value):
    return (value >> 24) & 0xff, (value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff

EP_BUS, EP_DEVFN = 0x01, 0x00
EP_ID            = (EP_BUS << 8) | EP_DEVFN
BAR0             = 0xf0000000
BAR0_SIZE        = 0x100000

def cfg(adr, tag, data=None, fn=0, type=0x04, be=0xf):
    fmt = 0x40 if data is not None else 0x00
    tlp = (fmt | type, 0, 0, 1,  0, 0, tag, be,  EP_BUS, EP_DEVFN | fn, 0, adr & 0xfc)
    return dws(*tlp, *(le32(data) if data is not None else ()))

def mwr32(adr, data, tag=0):
    return dws(0x40, 0, 0, 1,  0, 0, tag, 0x0f,  *be32(adr),  *le32(data))

def mrd32(adr, tag):
    return dws(0x00, 0, 0, 1,  0, 0, tag, 0x0f,  *be32(adr))

def cpl(tag, status=0, data=None, cmp_id=EP_ID, req_id=0, byte_count=4, lower=0):
    fmt = 0x4a if data is not None else 0x0a
    tlp = (fmt, 0, 0, 1 if data is not None else 0,
        cmp_id >> 8, cmp_id & 0xff, (status << 5) | (byte_count >> 8), byte_count & 0xff,
        req_id >> 8, req_id & 0xff, tag, lower)
    return dws(*tlp, *(le32(data) if data is not None else ()))

def exact(words):
    return [(w, 0xffffffff) for w in words]

# Script -------------------------------------------------------------------------------------------

TRIG_NONE, TRIG_MSI, TRIG_WB_READ, TRIG_WB_WRITE = 0, 1, 2, 3

SRAM_WORD  = 8           # SRAM word index preloaded (BAR0 offset 0x20).
SRAM_VALUE = 0xdeadbeef
WB_ADDRESS = 0x00001000  # Root address of the device-initiated accesses.
WB_DATA    = 0xcafe1234
WB_WRITE   = 0x55667788
MSI_ADDR   = 0xfee00000
MSI_DATA   = 0x4021

def script(vendor_device, bar0_mask, nlanes=1):
    t = iter(range(256))
    tag = lambda: next(t)
    s = []
    def step(name, tx=None, rx=None, trigger=TRIG_NONE, patch_tag=False):
        s.append(dict(name=name, tx=tx or [], rx=rx or [], trigger=trigger, patch_tag=patch_tag))
    def cfg_rd(name, adr, value):
        n = tag()
        step(name, cfg(adr, n), exact(cpl(n, data=value)))
    def cfg_wr(name, adr, value):
        n = tag()
        step(name, cfg(adr, n, value), exact(cpl(n)))
    cfg_rd("Vendor/Device ID",    0x00, vendor_device)
    cfg_rd("Capabilities Ptr",    0x34, 0x40)
    cfg_wr("BAR0 sizing write",   0x10, 0xffffffff)
    cfg_rd("BAR0 sizing read",    0x10, bar0_mask)
    cfg_wr("BAR0 assignment",     0x10, BAR0)
    cfg_rd("BAR0 readback",       0x10, BAR0)
    cfg_wr("Command: MSE, BME",   0x04, 0x00000006)
    cfg_rd("Command/Status",      0x04, 0x00100006)
    cfg_rd("PCIe Capability",     0x60, 0x00020010)
    cfg_rd("Link Status",         0x70, 0x10010000 | (nlanes << 20))
    cfg_wr("Device Control: MPS 256", 0x68, 0x00002830)
    # BAR0: SRAM preloaded word read: the wire bytes are the register little-endian (byte order).
    n = tag()
    step("MRd32 preloaded", mrd32(BAR0 + 4*SRAM_WORD, n), exact(cpl(n, data=SRAM_VALUE, lower=4*SRAM_WORD & 0x7f)))
    step("MWr32", mwr32(BAR0 + 0x10, 0x11223344))
    n = tag()
    step("MRd32 readback", mrd32(BAR0 + 0x10, n), exact(cpl(n, data=0x11223344, lower=0x10)))
    # Unsupported Requests.
    n = tag()
    step("IORd: UR", dws(0x02, 0, 0, 1,  0, 0, n, 0x0f,  0, 0, 0, 0), exact(cpl(n, status=1)))
    n = tag()
    step("MRd64: UR", dws(0x20, 0, 0, 1,  0, 0, n, 0x0f,  0, 0, 0, 1,  0, 0, 0, 0), exact(cpl(n, status=1)))
    n = tag()
    step("CfgRd function 1: UR", cfg(0x00, n, fn=1), exact(cpl(n, status=1)))
    n = tag()
    step("CfgRd1: UR", cfg(0x00, n, type=0x05), exact(cpl(n, status=1)))
    step("Message dropped", dws(0x34, 0, 0, 0,  0, 0, 0, 0x14,  0, 0, 0, 0,  0, 0, 0, 0))
    cfg_rd("Device Status: UR Detected", 0x68, 0x00082830)
    # MSI.
    cfg_wr("MSI Address",   0x4c, MSI_ADDR)
    cfg_wr("MSI Data",      0x54, MSI_DATA)
    cfg_wr("MSI Enable",    0x48, 0x00010000)
    step("MSI", rx=exact(dws(0x40, 0, 0, 1,  EP_BUS, EP_DEVFN, 0, 0x0f,  *be32(MSI_ADDR),  *le32(MSI_DATA))), trigger=TRIG_MSI)
    # Device-initiated accesses (tag from the request).
    tag_mask = 0xff00ffff
    rd = dws(0x00, 0, 0, 1,  EP_BUS, EP_DEVFN, 0, 0x0f,  *be32(WB_ADDRESS))
    step("Device MRd32", rx=[(rd[0], 0xffffffff), (rd[1], tag_mask), (rd[2], 0xffffffff)], trigger=TRIG_WB_READ)
    step("Device CplD", tx=cpl(0, data=WB_DATA, cmp_id=0, req_id=EP_ID), patch_tag=True)
    wr = dws(0x40, 0, 0, 1,  EP_BUS, EP_DEVFN, 0, 0x0f,  *be32(WB_ADDRESS),  *le32(WB_WRITE))
    step("Device MWr32", rx=[(wr[0], 0xffffffff), (wr[1], tag_mask), (wr[2], 0xffffffff), (wr[3], 0xffffffff)], trigger=TRIG_WB_WRITE)
    return s

# Root ---------------------------------------------------------------------------------------------

class ScriptedRoot(LiteXModule):
    """Plays the script on the Data Link Layer streams: transmits a step's TLP (after its trigger)
    then compares the received TLP, any other TLP is an error."""
    def __init__(self, dll, steps, timer):
        self.trigger    = Signal(2)  # o (Pulse)
        self.done       = Signal()   # o
        self.errors     = Signal(16) # o
        self.wait_count = Signal(16) # i: a step with "wait" waits for this count to reach its value.

        # # #

        tx_rom, rx_rom, rx_mask = [], [], []
        table = []
        for s in steps:
            table.append((len(tx_rom), len(s["tx"]), len(rx_rom), len(s["rx"]), s.get("trigger", TRIG_NONE),
                int(s.get("patch_tag", False)), s.get("wait", 0)))
            tx_rom += s["tx"]
            rx_rom += [v for v, m in s["rx"]]
            rx_mask += [m for v, m in s["rx"]]
        tx_rom_a  = Array(Constant(v, 32) for v in tx_rom or [0])
        rx_rom_a  = Array(Constant(v, 32) for v in rx_rom or [0])
        rx_mask_a = Array(Constant(v, 32) for v in rx_mask or [0])
        field = lambda i, width: Array(Constant(e[i], width) for e in table)
        f_tx_start, f_tx_len = field(0, 12), field(1, 12)
        f_rx_start, f_rx_len = field(2, 12), field(3, 12)
        f_trigger, f_patch   = field(4, 2),  field(5, 1)
        f_wait               = field(6, 16)

        step   = Signal(max=len(steps) + 1)
        index  = Signal(12)
        tag    = Signal(8)
        rx     = dll.source
        tx     = dll.sink
        self.comb += rx.ready.eq(1)
        adr_tx = f_tx_start[step] + index
        adr_rx = f_rx_start[step] + index
        expected = Signal(32)
        mask     = Signal(32)
        self.comb += [
            expected.eq(rx_rom_a[adr_rx[:12]]),
            mask.eq(rx_mask_a[adr_rx[:12]]),
        ]
        tx_word  = Signal(32)
        self.comb += [
            tx_word.eq(tx_rom_a[adr_tx[:12]]),
            If(f_patch[step] & (index == 2),
                tx_word[16:24].eq(tag)
            )
        ]

        names = {i: Display(f"[%08d] step {i}: {s['name']}", timer) for i, s in enumerate(steps)}
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(dll.dl_active,
                NextState("STEP")
            )
        )
        fsm.act("STEP",
            NextValue(index, 0),
            If(step == len(steps),
                NextState("DONE")
            ).Else(
                self.trigger.eq(f_trigger[step]),
                If(f_wait[step] != 0,
                    NextState("WAIT")
                ).Elif(f_tx_len[step] != 0,
                    NextState("TX")
                ).Else(
                    NextState("RX")
                )
            )
        )
        fsm.act("WAIT",
            If(self.wait_count >= f_wait[step],
                NextValue(step, step + 1),
                NextState("STEP")
            )
        )
        fsm.act("TX",
            tx.valid.eq(1),
            tx.first.eq(index == 0),
            tx.last.eq(index == f_tx_len[step] - 1),
            tx.data.eq(tx_word),
            If(tx.ready,
                NextValue(index, index + 1),
                If(tx.last,
                    NextValue(index, 0),
                    NextState("RX")
                )
            )
        )
        rx_end = index == f_rx_len[step] - 1
        fsm.act("RX",
            If(f_rx_len[step] == 0,
                NextValue(step, step + 1),
                NextState("STEP")
            ).Elif(rx.valid,
                NextValue(index, index + 1),
                If(index == 1, NextValue(tag, rx.data[16:24])),
                If(((rx.data ^ expected) & mask) != 0,
                    NextValue(self.errors, self.errors + 1),
                ),
                If(rx.last != rx_end,
                    NextValue(self.errors, self.errors + 1),
                ),
                If(rx.last | rx_end,
                    NextValue(step, step + 1),
                    NextState("STEP")
                )
            )
        )
        fsm.act("DONE",
            self.done.eq(1),
            If(rx.valid,
                NextValue(self.errors, self.errors + 1),
            )
        )
        self.step = step

        # Displays.
        self.sync += [
            If(fsm.ongoing("STEP") & (step != len(steps)), Case(step, names)),
            If(fsm.ongoing("RX") & (f_rx_len[step] != 0) & rx.valid,
                If(((rx.data ^ expected) & mask) != 0,
                    Display("[%08d] step %d DW %d: received %08x, expected %08x", timer, step, index, rx.data, expected),
                ),
                If(rx.last != rx_end,
                    Display("[%08d] step %d DW %d: unexpected TLP length", timer, step, index),
                ),
            ),
            If(fsm.ongoing("DONE") & rx.valid,
                Display("[%08d] unexpected TLP %08x", timer, rx.data),
            ),
        ]

# Simulation SoC -----------------------------------------------------------------------------------

class SoftPHYEndpointSim(SoCMini):
    def __init__(self, data_width=64, timer_scale=100, ts1_min=64, max_cycles=2**22, nlanes=1, dead_lanes=0, width=None):
        sys_clk_freq = int(125e6)
        platform     = Platform()
        SoCMini.__init__(self, platform, clk_freq=sys_clk_freq)

        # Clocks: "pcie_link" = sys (125 MHz), "pcie_pipe" = sys/2 (62.5 MHz, 2.5 GT/s).
        self.crg = CRG(platform.request("sys_clk"))
        self.cd_pcie_link = ClockDomain()
        self.cd_pcie_pipe = ClockDomain()
        lane_clk = Signal()
        self.sync += lane_clk.eq(~lane_clk)
        self.comb += [
            self.cd_pcie_link.clk.eq(ClockSignal("sys")),
            self.cd_pcie_link.rst.eq(ResetSignal("sys")),
            self.cd_pcie_pipe.clk.eq(lane_clk),
        ]
        self.specials += AsyncResetSynchronizer(self.cd_pcie_pipe, ResetSignal("sys"))

        timer = Signal(32)
        self.sync += timer.eq(timer + 1)

        # Link.
        kwargs = dict(tx_cd="pcie_pipe", rx_cd="pcie_pipe")
        shifts_ep   = [(i + 1) % 4 for i in range(nlanes)]
        shifts_root = [(i*3 + 2) % 4 for i in range(nlanes)]
        self.serdes_ep   = serdes_ep   = PCIeSerDesModel(nlanes, rx_symbol_shift=shifts_ep,   rx_word_delay=[i % 3 for i in range(nlanes)], **kwargs)
        self.serdes_root = serdes_root = PCIeSerDesModel(nlanes, rx_symbol_shift=shifts_root, rx_word_delay=[(i + 1) % 2 for i in range(nlanes)], **kwargs)
        serdes_ep.connect(serdes_root)

        # Endpoint: LitePCIe on SoftPCIEPHY, BAR0 to a SRAM, device accesses to the root.
        self.pcie_phy = phy = SoftPCIEPHY(platform, None,
            data_width  = data_width,
            bar0_size   = BAR0_SIZE,
            serdes      = serdes_ep,
            link_freq   = sys_clk_freq,
            timer_scale = timer_scale,
            ts1_min     = ts1_min,
        )
        self.pcie_endpoint = endpoint = LitePCIeEndpoint(phy, endianness=phy.endianness)
        self.wb_master = LitePCIeWishboneMaster(endpoint, qword_aligned=phy.qword_aligned)
        self.sram      = sram = wishbone.SRAM(256, init=[0]*SRAM_WORD + [SRAM_VALUE])
        self.comb += self.wb_master.wishbone.connect(sram.bus)
        self.wb_slave = wb_slave = LitePCIeWishboneSlave(endpoint, qword_aligned=phy.qword_aligned)

        # Root.
        root_phy_cls = PCIeMultiLanePhysicalLayer if nlanes > 1 else PCIePhysicalLayer
        self.root_phy = root_phy = root_phy_cls(serdes_root, sys_clk_freq, upstream=False,
            timer_scale=timer_scale, ts1_min=ts1_min)
        root_dll_kwargs = dict(ndw=nlanes, nlanes=nlanes, rx_depth=2048*nlanes, tx_depth=1024*nlanes) if nlanes > 1 else {}
        self.root_dll = root_dll = ClockDomainsRenamer("pcie_link")(DataLinkLayer(sys_clk_freq, **root_dll_kwargs))
        self.comb += [
            root_phy.link_number.eq(0x00),
            root_dll.link_up.eq(root_phy.ltssm.link_up),
            root_dll.l0.eq(root_phy.ltssm.l0),
            root_dll.phy_sink.connect(root_phy.sink),
            root_phy.source.connect(root_dll.phy_source),
        ]
        steps = script(((0x7020 + nlanes) << 16) | 0x10ee, phy.bar0_mask, nlanes=width or nlanes)
        if dead_lanes:
            self.comb += phy.phy_layer.lane_disable.eq(dead_lanes)
        # The script works on DWs, the wide Data Link Layer through converters.
        root_side = root_dll
        if nlanes > 1:
            class RootSide: pass
            root_side = RootSide()
            root_tx = ClockDomainsRenamer("pcie_link")(DWsToBeats(nlanes))
            root_rx = ClockDomainsRenamer("pcie_link")(BeatsToDWs(nlanes))
            self.submodules += root_tx, root_rx
            self.comb += [
                root_tx.source.connect(root_dll.sink),
                root_dll.source.connect(root_rx.sink),
            ]
            root_side.sink   = root_tx.sink
            root_side.source = root_rx.source
            root_side.dl_active = root_dll.dl_active
        self.root = root = ClockDomainsRenamer("pcie_link")(ScriptedRoot(root_side, steps, timer))

        rx_probe, tx_probe = root.fsm.ongoing("RX"), root.fsm.ongoing("TX")

        # Triggers.
        msi_pending = Signal()
        self.sync += [
            If(root.trigger == TRIG_MSI, msi_pending.eq(1)),
            If(phy.msi.valid & phy.msi.ready, msi_pending.eq(0)),
        ]
        self.comb += phy.msi.valid.eq(msi_pending)
        wb_read  = Signal()
        wb_write = Signal()
        wb_errors = Signal(8)
        wb = wb_slave.wishbone
        self.sync += [
            If(root.trigger == TRIG_WB_READ,  wb_read.eq(1)),
            If(root.trigger == TRIG_WB_WRITE, wb_write.eq(1)),
            If(wb.ack,
                If(wb_read,
                    wb_read.eq(0),
                    Display("[%08d] device read: %08x", timer, wb.dat_r),
                    If(wb.dat_r != WB_DATA, wb_errors.eq(wb_errors + 1)),
                ).Else(
                    wb_write.eq(0),
                )
            )
        ]
        self.comb += [
            wb.cyc.eq(wb_read | wb_write),
            wb.stb.eq(wb_read | wb_write),
            wb.we.eq(~wb_read),
            wb.adr.eq(WB_ADDRESS >> 2),
            wb.sel.eq(0xf),
            wb.dat_w.eq(WB_WRITE),
        ]

        # Status / end.
        ltssm_r = Signal(6, reset=0x3f)
        self.sync += ltssm_r.eq(phy.phy_layer.ltssm.state)
        self.sync += If((phy.phy_layer.ltssm.state == 0x10) & (ltssm_r != 0x10),
            Display("[%08d] Endpoint L0", timer)
        )
        dl_r = Signal()
        self.sync += dl_r.eq(phy.dll.dl_active)
        self.sync += If(phy.dll.dl_active & ~dl_r, Display("[%08d] Endpoint DL_Active", timer))
        wait = Signal(10)
        self.sync += [
            If(root.done,
                wait.eq(wait + 1),
                If(wait == 512,
                    Display("[%08d] id %04x, MPS %d, MRRS %d, replays %d/%d, receiver errors %d/%d", timer,
                        phy.id, phy.max_payload_size, phy.max_request_size,
                        phy.dll.tx.replay.replays, root_dll.tx.replay.replays, phy.dll.rx.errors, root_dll.rx.errors),
                    If((root.errors == 0) & (wb_errors == 0),
                        Display("SIM OK")
                    ).Else(
                        Display("SIM ERRORS: %d, %d", root.errors, wb_errors)
                    ),
                    Finish(),
                )
            ),
            If(timer == max_cycles,
                Display("[%08d] TIMEOUT: ltssm %x/%x, DL_Active %d/%d, root step %d rx %d tx %d, ready %d, id %04x", timer,
                    phy.phy_layer.ltssm.state, root_phy.ltssm.state, phy.dll.dl_active, root_dll.dl_active,
                    root.step, rx_probe, tx_probe, root_dll.sink.ready, phy.id),
                Finish(),
            )
        ]

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="SoftPCIEPHY end-to-end simulation.")
    parser.add_argument("--trace",       action="store_true",   help="Enable VCD tracing.")
    parser.add_argument("--data-width",  default=64, type=int,  help="LitePCIe data width (64, 128 or 256).")
    parser.add_argument("--nlanes",      default=1, type=int,   help="Link width (above 1: data width of 32 bits per lane).")
    parser.add_argument("--dead-lanes",  default="0",           help="Endpoint lanes out of service (mask).")
    parser.add_argument("--width",       default=None, type=int, help="Negotiated width expected in Link Status.")
    parser.add_argument("--timer-scale", default=100, type=int, help="LTSSM timers scale.")
    parser.add_argument("--ts1-min",     default=64, type=int,  help="TS1 transmitted in Polling.Active (specification: 1024).")
    parser.add_argument("--max-cycles",  default=2**22, type=int, help="Simulation timeout (sys clock cycles).")
    parser.add_argument("--output-dir",  default="build/soft_sim_endpoint", help="Build directory.")
    args = parser.parse_args()

    soc = SoftPHYEndpointSim(
        data_width  = args.data_width,
        nlanes      = args.nlanes,
        dead_lanes  = int(args.dead_lanes, 0),
        width       = args.width,
        timer_scale = args.timer_scale,
        ts1_min     = args.ts1_min,
        max_cycles  = args.max_cycles,
    )
    builder = Builder(soc, output_dir=args.output_dir, compile_software=False)
    builder.build(sim_config=SimConfig(default_clk="sys_clk"), opt_level="O0", interactive=False, trace=args.trace)

if __name__ == "__main__":
    main()
