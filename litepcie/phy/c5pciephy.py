#
# This file is part of LitePCIe.
#
# Copyright (c) 2019 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os

from migen import *
from migen.genlib.cdc import MultiReg

from litex.soc.interconnect.csr import *
from litex.soc.interconnect.avalon import *

from litepcie.common import *

# --------------------------------------------------------------------------------------------------

class C5PCIEPHY(Module, AutoCSR):
    endianness    = "little"
    qword_aligned = True
    def __init__(self, platform, pads, data_width=64, bar0_size=1*MB, cd="sys"):
        # Streams ---------------------------------------------------------------------------------
        self.sink   = stream.Endpoint(phy_layout(data_width))
        self.source = stream.Endpoint(phy_layout(data_width))
        self.msi    = stream.Endpoint(msi_layout())

        # Parameters/Locals ------------------------------------------------------------------------
        self.pads             = pads
        self.platform         = platform
        self.data_width       = data_width

        self.id               = Signal(16, reset_less=True)
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)
        self.max_request_size = Signal(16, reset_less=True)
        self.max_payload_size = Signal(16, reset_less=True)

        self.external_hard_ip = False

        # # #

        pcie_clk                       = Signal()
        pcie_rst_n                     = Signal(reset=1)
        pcie_reconfig_clk              = Signal()
        pcie_coreclkout_hip_clk        = Signal()
        pcie_pld_clk_clk               = Signal()
        pcie_pld_clk_1_clk             = Signal()

        pcie_config_tl_tl_cfg_add      = Signal(4)
        pcie_o_config_tl_tl_cfg_ctl    = Signal(32)
        pcie_hip_rst_serdes_pll_locked = Signal()
        pcie_o_power_mngt_pme_to_sr    = Signal()

         # Clocking ---------------------------------------------------------------------------------
        pcie_refclk = Signal()
        self.specials += Instance("ALT_INBUF_DIFF",
            i_i    = pads.clk_p,
            i_ibar = pads.clk_n,
            o_o    = pcie_refclk
        )

        self.clock_domains.cd_pcie = ClockDomain()

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
                tx_buffer.source.connect(tx_cdc.sink)
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
                rx_buffer.source.connect(self.source)
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

        # Hard IP Configuration --------------------------------------------------------------------
        def convert_size(command, size):
            cases = {}
            value = 128
            for i in range(6):
                cases[i] = size.eq(value)
                value = value*2
            return Case(command, cases)

        bus_number      = Signal(8)
        device_number   = Signal(5)
        function_number = Signal(3)
        dcommand        = Signal(16)

        self.bus_number      = bus_number
        self.device_number   = device_number
        self.function_number = function_number

        tl_cfg_add_reg_lsb    = Signal()
        tl_cfg_add_reg2_lsb   = Signal()
        cfgctl_addr_change    = Signal()
        cfgctl_addr_change2   = Signal()
        cfgctl_addr_strobe    = Signal()
        captured_cfg_addr_reg = Signal(4)
        captured_cfg_data_reg = Signal(32)

        self.sync.pcie += [
            convert_size(dcommand[12:15], self.max_request_size),
            convert_size(dcommand[5:8], self.max_payload_size),
            self.id.eq(Cat(function_number, device_number, bus_number))
        ]

        # To capture configuration space Register, register LSB bit of tl_cfg_add
        self.sync.pcie += [
            tl_cfg_add_reg_lsb.eq(pcie_config_tl_tl_cfg_add[0]),
            tl_cfg_add_reg2_lsb.eq(tl_cfg_add_reg_lsb)
        ]
        # Detect the address change to generate a strobe to sample the input 32-bit data
        self.sync.pcie += [
            cfgctl_addr_change.eq(tl_cfg_add_reg_lsb != tl_cfg_add_reg2_lsb),
            cfgctl_addr_change2.eq(cfgctl_addr_change),
            cfgctl_addr_strobe.eq(cfgctl_addr_change2)
        ]
        self.sync.pcie += [
            captured_cfg_addr_reg.eq(pcie_config_tl_tl_cfg_add),
            captured_cfg_data_reg.eq(pcie_o_config_tl_tl_cfg_ctl)
        ]

        # Get dcommand
        self.sync.pcie += [
            If((cfgctl_addr_strobe == 1) & (captured_cfg_addr_reg == 0),
                dcommand.eq(captured_cfg_data_reg[0:16])
            )
        ]
        # Get device_number and bus_number
        self.sync.pcie += [
            If((cfgctl_addr_strobe == 1) & (captured_cfg_addr_reg == 15),
                device_number.eq(captured_cfg_data_reg[0:5]),
                bus_number.eq(captured_cfg_data_reg[5:13])
            )
        ]

        # tl_cfg_add[6:4] should represent function number whose information is being presented on
        # tl_cfg_ctl, but only one function is enabled on IP core  in this case function_number is
        # always 0
        self.comb += function_number.eq(0)

        # Native stream <--> AvalonST --------------------------------------------------------------
        tx_n2av = Native2AvalonST(phy_layout(data_width), latency=2)
        tx_n2av = ClockDomainsRenamer("pcie")(tx_n2av)
        self.comb += tx_st.connect(tx_n2av.sink)
        self.submodules += tx_n2av

        rx_av2n = AvalonST2Native(phy_layout(data_width), latency=2)
        rx_av2n = ClockDomainsRenamer("pcie")(rx_av2n)
        self.comb += rx_av2n.source.connect(rx_st)
        self.submodules += rx_av2n

        tx_avst = tx_n2av.source
        rx_avst = rx_av2n.sink

        # Hard IP ----------------------------------------------------------------------------------
        self.pcie_phy_params = dict(
            # Clocks
            i_refclk_clk         = pcie_refclk,
            i_pld_clk_clk        = ClockSignal("pcie"),
            o_coreclkout_hip_clk = ClockSignal("pcie"),

            # Resets
            i_npor_npor      = 1 if not hasattr(pads, "rst_n") else pads.rst_n,
            i_npor_pin_perst = 1 if not hasattr(pads, "rst_n") else pads.rst_n,

            # Hard IP Reconfiguration
            i_reconfig_clk_clk       = pcie_reconfig_clk,
            i_reconfig_reset_reset_n = pcie_rst_n,

            # Power Management
            i_power_mngt_pme_to_cr = pcie_o_power_mngt_pme_to_sr,
            o_power_mngt_pme_to_sr = pcie_o_power_mngt_pme_to_sr,

            # Config (Configuration space)
            o_config_tl_tl_cfg_ctl = pcie_o_config_tl_tl_cfg_ctl,
            o_config_tl_tl_cfg_add = pcie_config_tl_tl_cfg_add,

             # Control
            o_hip_rst_serdes_pll_locked = pcie_hip_rst_serdes_pll_locked,
            i_hip_rst_pld_core_ready    = pcie_hip_rst_serdes_pll_locked,

            # RX Port
            o_rx_st_valid         = rx_avst.valid,
            o_rx_st_startofpacket = rx_avst.first,
            o_rx_st_endofpacket   = rx_avst.last,
            i_rx_st_ready         = rx_avst.ready,
            o_rx_st_data          = rx_avst.dat,

            # TX Port
            i_tx_st_valid         = tx_avst.valid,
            i_tx_st_startofpacket = tx_avst.first,
            i_tx_st_endofpacket   = tx_avst.last,
            o_tx_st_ready         = tx_avst.ready,
            i_tx_st_data          = tx_avst.dat,

            # Serial IF
            i_hip_serial_rx_in0  = pads.rx_p[0],
            i_hip_serial_rx_in1  = pads.rx_p[1],
            i_hip_serial_rx_in2  = pads.rx_p[2],
            i_hip_serial_rx_in3  = pads.rx_p[3],
            o_hip_serial_tx_out0 = pads.tx_p[0],
            o_hip_serial_tx_out1 = pads.tx_p[1],
            o_hip_serial_tx_out2 = pads.tx_p[2],
            o_hip_serial_tx_out3 = pads.tx_p[3],

            # MSI
            i_int_msi_app_msi_num = 0,
            i_int_msi_app_msi_req = cfg_msi.valid,
            i_int_msi_app_msi_tc  = 0,
            o_int_msi_app_msi_ack = cfg_msi.ready,
            i_int_msi_app_int_sts = 0
        )

    # External Hard IP -----------------------------------------------------------------------------
    def use_external_hard_ip(self, hard_ip_path):
        self.external_hard_ip = True
        self.platform.add_source(
            os.path.join("altera", "cyclone_v", "pcie_phy", "synthesis", "pcie_phy.qip"), "QIP")

    def do_finalize(self):
        if not self.external_hard_ip:
            raise ValueError("User needs to provide Hard IP source path with use_external_hard_ip")
        self.specials += Instance("pcie_phy", **self.pcie_phy_params)
