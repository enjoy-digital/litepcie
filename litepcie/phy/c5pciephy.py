#
# This file is part of LitePCIe.
#
# Copyright (c) 2019 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Intel Cyclone V PCIe hard IP wrapper.

The PHY expects a Platform Designer system named ``pcie_phy``. The system owns the PCIe hard IP
and its transceiver reconfiguration controller and exposes the Avalon-ST application interface
used below. ``generate_hard_ip`` generates this system at build time (qsys-generate) and
``use_external_hard_ip`` takes a pre-generated one.
"""

import os
import shutil
import subprocess
from xml.etree import ElementTree as ET

from migen import *
from migen.genlib.cdc import BusSynchronizer

from litex.gen import *

from litex.soc.interconnect import stream
from litex.soc.interconnect.packet import PacketFIFO
from litex.soc.interconnect.avalon import Native2AvalonST, AvalonST2Native

from litepcie.common import *
from litepcie.phy.svpciephy import _TXQwordAligner, _RXQwordDealigner

# Quartus / Qsys Discovery -------------------------------------------------------------------------

def _find_qsys_generate():
    """Locate qsys-generate from QUARTUS_ROOTDIR, or from the Quartus installation on PATH."""
    quartus = os.environ.get("QUARTUS_ROOTDIR")
    if quartus is None:
        quartus_map = shutil.which("quartus_map")
        if quartus_map is None:
            raise OSError("Put Quartus on PATH or set QUARTUS_ROOTDIR")
        quartus = os.path.dirname(os.path.dirname(os.path.realpath(quartus_map)))
    return os.path.join(os.path.realpath(quartus), "sopc_builder", "bin", "qsys-generate")

# Platform Designer System -------------------------------------------------------------------------

def _build_qsys(device, nlanes, data_width, bar0_size):
    """Return the ``pcie_phy`` Platform Designer system (.qsys) as text.

    The system holds the native endpoint (Avalon-ST), its reconfiguration driver and the transceiver
    reconfiguration controller, and exports the interfaces C5PCIEPHY connects.
    """
    # System.
    system = ET.Element("system", name="pcie_phy")
    ET.SubElement(system, "component", name="pcie_phy", version="1.0")

    def parameters(element, **values):
        for name, value in values.items():
            ET.SubElement(element, "parameter", name=name, value=str(value))

    def module(name, kind, version="25.1", **values):
        element = ET.SubElement(system, "module",
            name    = name,
            kind    = kind,
            version = version,
            enabled = "1",
        )
        parameters(element, **values)

    parameters(system,
        device       = device,
        deviceFamily = "Cyclone V",
        hdlLanguage  = "VERILOG",
    )

    # Modules.
    rate = "Gen2 (5.0 Gbps)"
    module("app", "clock_source",
        clockFrequency        = 125000000,
        clockFrequencyKnown   = "true",
        resetSynchronousEdges = "NONE",
    )
    module("mgmt", "clock_source",
        clockFrequency        = 50000000,
        clockFrequencyKnown   = "true",
        resetSynchronousEdges = "NONE",
    )
    module("driver", "altera_pcie_reconfig_driver",
        INTENDED_DEVICE_FAMILY        = "Cyclone V",
        gen123_lane_rate_mode_hwtcl   = rate,
        number_of_reconfig_interfaces = nlanes + 1,
    )
    module("xcvr", "alt_xcvr_reconfig", "19.1",
        device_family                 = "Cyclone V",
        enable_analog                 = 1,
        enable_offset                 = 1,
        number_of_reconfig_interfaces = nlanes + 1,
    )
    bars = {
        f"bar{i}_{field}_0_hwtcl" : 0 for i in range(1, 6) for field in ("type", "size_mask")
    }
    module("hip", "altera_pcie_cv_hip_ast",
        INTENDED_DEVICE_FAMILY            = "Cyclone V",
        ast_width_hwtcl                   = f"Avalon-ST {data_width}-bit",
        lane_mask_hwtcl                   = f"x{nlanes}",
        gen12_lane_rate_mode_hwtcl        = rate,
        pll_refclk_freq_hwtcl             = "100 MHz",
        porttype_func_hwtcl               = "Native endpoint",
        vendor_id_0_hwtcl                 = 0x1172,
        device_id_0_hwtcl                 = 0xc504,
        class_code_0_hwtcl                = 0xff0000,
        revision_id_0_hwtcl               = 1,
        subsystem_device_id_0_hwtcl       = 0,
        subsystem_vendor_id_0_hwtcl       = 0,
        bar0_size_mask_0_hwtcl            = bar0_size.bit_length() - 1,
        bar0_type_0_hwtcl                 = 2,
        max_payload_size_hwtcl            = 256,
        msi_support_0_hwtcl               = "true",
        msi_multi_message_capable_0_hwtcl = 1,
        use_rx_st_be_hwtcl                = 0,
        **bars,
    )

    # Exported interfaces (inserted before the modules).
    for name, internal, kind, direction in [
        ("app_reset",      "app.clk_in_reset",   "reset",            "end"),
        ("pld_clk",        "app.clk_in",         "clock",            "end"),
        ("reconfig_clk",   "mgmt.clk_in",        "clock",            "end"),
        ("reconfig_reset", "mgmt.clk_in_reset",  "reset",            "end"),
        ("coreclkout_hip", "hip.coreclkout_hip", "clock",            "start"),
        ("refclk",         "hip.refclk",         "clock",            "end"),
        ("rx_st",          "hip.rx_st",          "avalon_streaming", "start"),
        ("tx_st",          "hip.tx_st",          "avalon_streaming", "end"),
        ("config_tl",      "hip.config_tl",      "conduit",          "end"),
        ("hip_rst",        "hip.hip_rst",        "conduit",          "end"),
        ("hip_serial",     "hip.hip_serial",     "conduit",          "end"),
        ("int_msi",        "hip.int_msi",        "conduit",          "end"),
        ("npor",           "hip.npor",           "conduit",          "end"),
        ("power_mngt",     "hip.power_mngt",     "conduit",          "end"),
    ]:
        interface = ET.Element("interface",
            name     = name,
            internal = internal,
            type     = kind,
            dir      = direction,
        )
        system.insert(list(system).index(system.find("module")), interface)

    # Connections.
    for kind, start, end in [
        ("avalon",  "driver.reconfig_mgmt",   "xcvr.reconfig_mgmt"),
        ("clock",   "mgmt.clk",               "xcvr.mgmt_clk_clk"),
        ("clock",   "app.clk",                "hip.pld_clk"),
        ("clock",   "app.clk",                "driver.pld_clk"),
        ("clock",   "mgmt.clk",               "driver.reconfig_xcvr_clk"),
        ("conduit", "hip.hip_currentspeed",   "driver.hip_currentspeed"),
        ("conduit", "hip.hip_status",         "driver.hip_status_drv"),
        ("conduit", "xcvr.reconfig_busy",     "driver.reconfig_busy"),
        ("conduit", "hip.reconfig_from_xcvr", "xcvr.reconfig_from_xcvr"),
        ("conduit", "hip.reconfig_to_xcvr",   "xcvr.reconfig_to_xcvr"),
        ("reset",   "mgmt.clk_reset",         "xcvr.mgmt_rst_reset"),
        ("reset",   "mgmt.clk_reset",         "driver.reconfig_xcvr_rst"),
    ]:
        connection = ET.SubElement(system, "connection",
            kind    = kind,
            version = "25.1",
            start   = start,
            end     = end,
        )
        if kind == "avalon":
            parameters(connection,
                arbitrationPriority = 1,
                baseAddress         = "0x0000",
                defaultConnection   = "false",
            )

    # Text.
    ET.indent(system)
    return ET.tostring(system, encoding="utf-8", xml_declaration=True).decode("utf-8")

# Configuration Space Decode -----------------------------------------------------------------------

class _C5Config(LiteXModule):
    """Decode the configuration registers exported by the Cyclone V hard IP."""
    def __init__(self):
        self.tl_cfg_add    = Signal(4)
        self.tl_cfg_ctl    = Signal(32)
        self.tl_cfg_ctl_wr = Signal()

        self.id               = Signal(16, reset_less=True)
        self.max_request_size = Signal(16, reset_less=True)
        self.max_payload_size = Signal(16, reset_less=True)

        self.bus_number      = Signal(8)
        self.device_number   = Signal(5)
        self.function_number = Signal(3)

        # # #

        def convert_size(command, size, max_size):
            cases = {}
            for n in range(6):
                cases[n] = size.eq(min(128 << n, max_size))
            return Case(command, cases)

        dcommand     = Signal(16)
        cfg_ctl_wr_d = Signal()

        # tl_cfg_ctl_wr is a toggle, not a one-cycle pulse. Its transition announces a new stable
        # tl_cfg_add/tl_cfg_ctl window. Detecting it directly is more robust than inferring the
        # update from tl_cfg_add[0], as the original wrapper did.
        self.sync += [
            cfg_ctl_wr_d.eq(self.tl_cfg_ctl_wr),
            If(self.tl_cfg_ctl_wr != cfg_ctl_wr_d,
                If(self.tl_cfg_add == 0x0,
                    # Device Control is the upper half of configuration word 0.
                    dcommand.eq(self.tl_cfg_ctl[16:32]),
                ),
                If(self.tl_cfg_add == 0xf,
                    self.device_number.eq(self.tl_cfg_ctl[0:5]),
                    self.bus_number.eq(self.tl_cfg_ctl[5:13]),
                ),
            ),
            # Clamped to 512 bytes: the core request/completion buffers are sized for it (tlp/common.py).
            convert_size(dcommand[5:8],   self.max_payload_size, max_size=512),
            convert_size(dcommand[12:15], self.max_request_size, max_size=512),
            self.id.eq(Cat(self.function_number, self.device_number, self.bus_number)),
        ]

        # The generated hard IP enables a single function.
        self.comb += self.function_number.eq(0)

# C5PCIEPHY ----------------------------------------------------------------------------------------

class C5PCIEPHY(LiteXModule):
    endianness    = "little"
    qword_aligned = True # The Avalon-ST interface presents payloads qword-aligned.

    def __init__(self, platform, pads, data_width=64, cd="sys",
        # PCIe hardblock parameters.
        bar0_size        = 0x100000,
        # Transceiver reconfiguration controller clock/reset. The clock must be free-running and
        # meet the requirements of the generated Platform Designer system.
        reconfig_clk     = None,
        reconfig_rst     = None,
        # The dedicated transceiver reference clock buffer uses the implicit negative pin.
        dedicated_refclk = False,
    ):
        # Streams ----------------------------------------------------------------------------------
        self.sink   = stream.Endpoint(phy_layout(data_width))
        self.source = stream.Endpoint(phy_layout(data_width))
        self.msi    = stream.Endpoint(msi_layout())

        # Parameters/Locals ------------------------------------------------------------------------
        self.pads             = pads
        self.platform         = platform
        self.data_width       = data_width
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)

        self.external_hard_ip = False
        self.qword_aligned    = (data_width == 64)

        # # #

        self.nlanes = nlanes = len(pads.tx_p)

        # Checks -----------------------------------------------------------------------------------
        assert nlanes in [1, 2, 4]
        assert len(pads.rx_p) == nlanes
        assert data_width in [64, 128]

        # Clocking / Reset -------------------------------------------------------------------------
        self.cd_pcie = ClockDomain()

        coreclkout_hip = Signal()
        reset_status   = Signal()
        self.comb += [
            self.cd_pcie.clk.eq(coreclkout_hip),
            self.cd_pcie.rst.eq(reset_status),
        ]

        if reconfig_clk is None:
            reconfig_clk = ClockSignal(cd)
        if reconfig_rst is None:
            reconfig_rst = ResetSignal(cd)

        # Reference Clock.
        pcie_refclk = pads.clk_p
        if not dedicated_refclk:
            pcie_refclk = Signal()
            self.specials += Instance("ALT_INBUF_DIFF",
                i_i    = pads.clk_p,
                i_ibar = pads.clk_n,
                o_o    = pcie_refclk,
            )

        # Reset (perst_n, or rst_n as on the other PHYs).
        perst_n = getattr(pads, "perst_n", getattr(pads, "rst_n", 1))

        # TX CDC (FPGA --> HOST) -------------------------------------------------------------------
        if cd == "pcie":
            tx_st = self.sink
        else:
            tx_buffer = stream.Buffer(phy_layout(data_width))
            tx_buffer = ClockDomainsRenamer(cd)(tx_buffer)
            tx_cdc    = stream.AsyncFIFO(phy_layout(data_width), 32)
            tx_cdc    = ClockDomainsRenamer({"write": cd, "read": "pcie"})(tx_cdc)
            self.submodules += tx_buffer, tx_cdc
            self.comb += [
                self.sink.connect(tx_buffer.sink),
                tx_buffer.source.connect(tx_cdc.sink),
            ]
            tx_st = tx_cdc.source

        # RX CDC (HOST --> FPGA) -------------------------------------------------------------------
        if cd == "pcie":
            rx_st = self.source
        else:
            rx_cdc    = stream.AsyncFIFO(phy_layout(data_width), 32)
            rx_cdc    = ClockDomainsRenamer({"write": "pcie", "read": cd})(rx_cdc)
            rx_buffer = stream.Buffer(phy_layout(data_width))
            rx_buffer = ClockDomainsRenamer(cd)(rx_buffer)
            self.submodules += rx_buffer, rx_cdc
            self.comb += [
                rx_cdc.source.connect(rx_buffer.sink),
                rx_buffer.source.connect(self.source),
            ]
            rx_st = rx_cdc.sink

        # MSI CDC (FPGA --> HOST) ------------------------------------------------------------------
        if cd == "pcie":
            cfg_msi = self.msi
        else:
            msi_cdc = stream.AsyncFIFO(msi_layout(), 4)
            msi_cdc = ClockDomainsRenamer({"write": cd, "read": "pcie"})(msi_cdc)
            self.submodules += msi_cdc
            self.comb += self.msi.connect(msi_cdc.sink)
            cfg_msi = msi_cdc.source

        # Configuration Space ----------------------------------------------------------------------
        config = ClockDomainsRenamer("pcie")(_C5Config())
        self.submodules += config

        self.id               = config.id
        self.max_request_size = config.max_request_size
        self.max_payload_size = config.max_payload_size
        self.bus_number       = config.bus_number
        self.device_number    = config.device_number
        self.function_number  = config.function_number

        # Configuration Space CDC (HOST --> FPGA).
        if cd != "pcie":
            self.config_cdc = BusSynchronizer(48, "pcie", cd)
            self.comb += self.config_cdc.i.eq(Cat(
                config.id,
                config.max_request_size,
                config.max_payload_size,
            ))
            self.id               = self.config_cdc.o[0:16]
            self.max_request_size = self.config_cdc.o[16:32]
            self.max_payload_size = self.config_cdc.o[32:48]

        # Qword Alignment (128-bit) ----------------------------------------------------------------
        if data_width == 128:
            self.tx_align = ClockDomainsRenamer("pcie")(_TXQwordAligner(data_width))
            self.rx_align = ClockDomainsRenamer("pcie")(_RXQwordDealigner(data_width))
            self.comb += [
                tx_st.connect(self.tx_align.sink),
                self.rx_align.source.connect(rx_st),
            ]

            # The hard IP requires valid on every ready cycle from SOP to EOP: buffer the complete
            # aligned TLP before starting its transmission. 512 beats cover a 4 KiB payload plus
            # header and alignment padding.
            self.tx_packets = ClockDomainsRenamer("pcie")(PacketFIFO(
                layout        = phy_layout(data_width),
                payload_depth = 512,
                param_depth   = 32,
                buffered      = True,
            ))
            self.comb += self.tx_align.source.connect(self.tx_packets.sink)

            tx_st = self.tx_packets.source
            rx_st = self.rx_align.sink

        # Native Stream <-> Avalon-ST --------------------------------------------------------------
        tx_n2av = Native2AvalonST(phy_layout(data_width), latency=2)
        tx_n2av = ClockDomainsRenamer("pcie")(tx_n2av)
        rx_av2n = AvalonST2Native(phy_layout(data_width), latency=3)
        rx_av2n = ClockDomainsRenamer("pcie")(rx_av2n)
        self.submodules += tx_n2av, rx_av2n
        self.comb += [
            tx_st.connect(tx_n2av.sink),
            rx_av2n.source.connect(rx_st),
        ]

        tx_avst = tx_n2av.source
        rx_avst = rx_av2n.sink

        # On the 128-bit interface, empty describes the unused upper qword on EOP.
        rx_empty = Signal()
        self.comb += rx_avst.be.eq(Mux(rx_avst.last & rx_empty,
            0xff,
            (1 << (data_width//8)) - 1,
        ))

        # Hard IP ----------------------------------------------------------------------------------
        pme_to_sr         = Signal()
        serdes_pll_locked = Signal()

        self.pcie_phy_params = dict(
            # Clocks
            i_refclk_clk                = pcie_refclk,
            i_pld_clk_clk               = ClockSignal("pcie"),
            o_coreclkout_hip_clk        = coreclkout_hip,

            # Resets
            i_npor_npor                 = perst_n,
            i_npor_pin_perst            = perst_n,
            o_hip_rst_reset_status      = reset_status,

            # Transceiver Reconfiguration Controller
            i_reconfig_clk_clk          = reconfig_clk,
            i_reconfig_reset_reset_n    = ~reconfig_rst,

            # Power Management
            i_power_mngt_pme_to_cr      = pme_to_sr,
            o_power_mngt_pme_to_sr      = pme_to_sr,

            # Configuration Space
            o_config_tl_tl_cfg_ctl      = config.tl_cfg_ctl,
            o_config_tl_tl_cfg_add      = config.tl_cfg_add,
            o_config_tl_tl_cfg_ctl_wr   = config.tl_cfg_ctl_wr,

            # Control
            o_hip_rst_serdes_pll_locked = serdes_pll_locked,
            i_hip_rst_pld_core_ready    = serdes_pll_locked,

            # RX Avalon-ST
            o_rx_st_valid               = rx_avst.valid,
            o_rx_st_startofpacket       = rx_avst.first,
            o_rx_st_endofpacket         = rx_avst.last,
            i_rx_st_ready               = rx_avst.ready,
            o_rx_st_data                = rx_avst.dat,

            # TX Avalon-ST
            i_tx_st_valid               = tx_avst.valid,
            i_tx_st_startofpacket       = tx_avst.first,
            i_tx_st_endofpacket         = tx_avst.last,
            o_tx_st_ready               = tx_avst.ready,
            i_tx_st_data                = tx_avst.dat,

            # MSI
            i_int_msi_app_msi_num       = 0,
            i_int_msi_app_msi_req       = cfg_msi.valid,
            i_int_msi_app_msi_tc        = 0,
            o_int_msi_app_msi_ack       = cfg_msi.ready,
            i_int_msi_app_int_sts       = 0,
        )

        # 128-bit Avalon-ST / Application ports.
        if data_width == 128:
            self.pcie_phy_params.update(
                o_rx_st_empty           = rx_empty,
                i_tx_st_empty           = tx_avst.last & (tx_avst.be[8:16] == 0),
                i_tx_st_error           = 0,
                i_app_reset_reset_n     = ~reset_status,
                i_config_tl_hpg_ctrler  = 0,
                i_config_tl_cpl_err     = 0,
                i_config_tl_cpl_pending = 0,
                i_power_mngt_pm_auxpwr  = 0,
                i_power_mngt_pm_data    = 0,
                i_power_mngt_pm_event   = 0,
            )

        # Serial lanes.
        for n in range(nlanes):
            self.pcie_phy_params[f"i_hip_serial_rx_in{n}"]  = pads.rx_p[n]
            self.pcie_phy_params[f"o_hip_serial_tx_out{n}"] = pads.tx_p[n]

    # Hard IP Generation ---------------------------------------------------------------------------
    def generate_hard_ip(self, output_dir):
        """Generate the ``pcie_phy`` Platform Designer system and use it as the hard IP."""
        qsys_generate = _find_qsys_generate()
        output_dir    = os.path.realpath(output_dir)
        os.makedirs(output_dir, exist_ok=True)

        # Platform Designer system.
        qsys = _build_qsys(
            device     = self.platform.device,
            nlanes     = self.nlanes,
            data_width = self.data_width,
            bar0_size  = self.bar0_size,
        )
        with open(os.path.join(output_dir, "pcie_phy.qsys"), "w", encoding="utf-8") as f:
            f.write(qsys)

        # Generation.
        subprocess.run([qsys_generate, "pcie_phy.qsys", "--synthesis=VERILOG"],
            cwd   = output_dir,
            check = True,
        )
        self.use_external_hard_ip(os.path.join(output_dir, "pcie_phy", "synthesis", "pcie_phy.qip"))

    # External Hard IP -----------------------------------------------------------------------------
    def use_external_hard_ip(self, hard_ip_path):
        qip = os.fspath(hard_ip_path)
        if qip.endswith(".qip"):
            if not os.path.isfile(qip):
                raise FileNotFoundError(f"Cyclone V PCIe hard IP is missing: {qip}")
            self.platform.add_ip(qip)
        else:
            qip = os.path.join(qip, "altera", "cyclone_v", "pcie_phy", "synthesis", "pcie_phy.qip")
            self.platform.add_source(qip, "QIP")
        self.external_hard_ip = True

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        if not self.external_hard_ip:
            raise ValueError("C5PCIEPHY requires use_external_hard_ip() with a generated Qsys IP")
        self.specials += Instance("pcie_phy", **self.pcie_phy_params)
