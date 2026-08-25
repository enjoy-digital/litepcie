#
# This file is part of LitePCIe.
#
# Copyright (c) 2019 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Intel Cyclone V PCIe hard IP wrapper.

The PHY expects a Platform Designer system named ``pcie_phy``. The system owns the PCIe hard IP
and its transceiver reconfiguration controller and exposes the Avalon-ST application interface
used below.
"""

import os

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream
from litex.soc.interconnect.avalon import Native2AvalonST, AvalonST2Native

from litepcie.common import *

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

        def convert_size(command, size):
            cases = {}
            for n in range(6):
                cases[n] = size.eq(128 << n)
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
                    dcommand.eq(self.tl_cfg_ctl[0:16]),
                ),
                If(self.tl_cfg_add == 0xf,
                    self.device_number.eq(self.tl_cfg_ctl[0:5]),
                    self.bus_number.eq(self.tl_cfg_ctl[5:13]),
                ),
            ),
            convert_size(dcommand[5:8],   self.max_payload_size),
            convert_size(dcommand[12:15], self.max_request_size),
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
        bar0_size    = 0x100000,
        # Transceiver reconfiguration controller clock/reset. The clock must be free-running and
        # meet the requirements of the generated Platform Designer system.
        reconfig_clk = None,
        reconfig_rst = None,
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

        pcie_refclk = Signal()
        self.specials += Instance("ALT_INBUF_DIFF",
            i_i    = pads.clk_p,
            i_ibar = pads.clk_n,
            o_o    = pcie_refclk,
        )

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

        # Native Stream <-> Avalon-ST --------------------------------------------------------------
        tx_n2av = Native2AvalonST(phy_layout(data_width), latency=2)
        tx_n2av = ClockDomainsRenamer("pcie")(tx_n2av)
        rx_av2n = AvalonST2Native(phy_layout(data_width), latency=2)
        rx_av2n = ClockDomainsRenamer("pcie")(rx_av2n)
        self.submodules += tx_n2av, rx_av2n
        self.comb += [
            tx_st.connect(tx_n2av.sink),
            rx_av2n.source.connect(rx_st),
        ]

        tx_avst = tx_n2av.source
        rx_avst = rx_av2n.sink

        # Hard IP ----------------------------------------------------------------------------------
        pme_to_sr         = Signal()
        serdes_pll_locked = Signal()

        self.pcie_phy_params = dict(
            # Clocks
            i_refclk_clk                = pcie_refclk,
            i_pld_clk_clk               = ClockSignal("pcie"),
            o_coreclkout_hip_clk        = coreclkout_hip,

            # Resets
            i_npor_npor                 = 1 if not hasattr(pads, "rst_n") else pads.rst_n,
            i_npor_pin_perst            = 1 if not hasattr(pads, "rst_n") else pads.rst_n,
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

        # Serial lanes.
        for n in range(nlanes):
            self.pcie_phy_params[f"i_hip_serial_rx_in{n}"]  = pads.rx_p[n]
            self.pcie_phy_params[f"o_hip_serial_tx_out{n}"] = pads.tx_p[n]

    # External Hard IP -----------------------------------------------------------------------------
    def use_external_hard_ip(self, hard_ip_path):
        qip = os.path.join(
            hard_ip_path, "altera", "cyclone_v", "pcie_phy", "synthesis", "pcie_phy.qip")
        self.platform.add_source(qip, "QIP")
        self.external_hard_ip = True

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        if not self.external_hard_ip:
            raise ValueError("C5PCIEPHY requires use_external_hard_ip() with a generated Qsys IP")
        self.specials += Instance("pcie_phy", **self.pcie_phy_params)
