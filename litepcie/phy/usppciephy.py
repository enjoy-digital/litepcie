#
# This file is part of LitePCIe.
#
# Copyright (c) 2020-2023 Enjoy-Digital <enjoy-digital.fr>
# Copyright (c) 2022 Sylvain Munaut <tnt@246tNt.com>
# Copyright (c) 2024 John Simons <jammsimons@gmail.com>
# SPDX-License-Identifier: BSD-2-Clause

import os

from migen import *
from migen.genlib.cdc import MultiReg

from litex.gen import *

from litex.soc.interconnect.csr import *

from litepcie.common import *
from litepcie.phy.common import *

# USPPCIEPHY ---------------------------------------------------------------------------------------

class USPPCIEPHY(LiteXModule):
    endianness    = "little"
    qword_aligned = False
    def __init__(self, platform, pads, speed="gen3", data_width=64, cd="sys",
        # PCIe hardblock parameters.
        ip_name         = "pcie4_uscale_plus",
        pcie_data_width = None,
        bar0_size       = 0x100000,
    ):
        # Streams ----------------------------------------------------------------------------------
        self.req_sink   = stream.Endpoint(phy_layout(data_width))
        self.cmp_sink   = stream.Endpoint(phy_layout(data_width))
        self.req_source = stream.Endpoint(phy_layout(data_width))
        self.cmp_source = stream.Endpoint(phy_layout(data_width))
        self.msi        = stream.Endpoint(msi_layout())

        # Registers --------------------------------------------------------------------------------
        self._link_status = CSRStatus(fields=[
            CSRField("status", size=1, values=[
                ("``0b0``", "Link Down."),
                ("``0b1``", "Link Up."),
            ]),
            CSRField("phy_down", size=1, values=[
                ("``0b0``", "PHY Link Up."),
                ("``0b1``", "PHY Link Down."),
            ]),
            CSRField("phy_status", size=2, values=[
                ("``00b``", "No receivers detected."),
                ("``01b``", "Link training in progress."),
                ("``10b``", "Link up, DL initialization in progress."),
                ("``11b``", "Link up, DL initialization completed."),
            ]),
            CSRField("rate", size=2, values=[
                ("``0b00``", "2.5 GT/s."),
                ("``0b01``", "5.0 GT/s."),
                ("``0b10``", "8.0 GT/s."),
            ]),
            CSRField("width", size=3, values=[
                ("``0b000``", "1-Lane link."),
                ("``0b001``", "2-Lane link."),
                ("``0b010``", "4-Lane link."),
                ("``0b011``", "8-Lane link."),
                ("``0b100``", "16-Lane link."),
            ]),
            CSRField("ltssm", size=6, description="LTSSM State"),
        ])
        self._msi_enable        = CSRStatus(description="MSI Enable Status. ``1``: MSI is enabled.")
        self._bus_master_enable = CSRStatus(description="Bus Mastering Status. ``1``: Bus Mastering enabled.")
        self._max_request_size  = CSRStatus(16, description="Negiotiated Max Request Size (in bytes).")
        self._max_payload_size  = CSRStatus(16, description="Negiotiated Max Payload Size (in bytes).")

        # Parameters/Locals ------------------------------------------------------------------------
        if pcie_data_width is None: pcie_data_width = data_width
        self.platform         = platform
        self.data_width       = data_width
        self.pcie_data_width  = pcie_data_width
        assert ip_name  in ["pcie4_uscale_plus", "pcie4c_uscale_plus"]
        self.ip_name          = ip_name

        self.id               = Signal(16)
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)
        self.max_request_size = Signal(16)
        self.max_payload_size = Signal(16)

        self.config           = {}
        self.external_hard_ip = False

        # # #

        self.speed  = speed
        self.nlanes = nlanes = len(pads.tx_p)

        assert speed           in ["gen3", "gen4"]
        assert nlanes          in [1, 2, 4, 8, 16]
        assert data_width      in [64, 128, 256, 512]
        assert pcie_data_width in [64, 128, 256, 512]

        # Clocking / Reset -------------------------------------------------------------------------
        self.pcie_refclk    = pcie_refclk    = Signal()
        self.pcie_refclk_gt = pcie_refclk_gt = Signal()
        self.pcie_rst_n     = pcie_rst_n     = Signal(reset=1)
        if hasattr(pads, "rst_n"):
            self.comb += pcie_rst_n.eq(pads.rst_n)
        self.specials += Instance("IBUFDS_GTE4",
            p_REFCLK_HROW_CK_SEL = 0,
            i_CEB   = 0,
            i_I     = pads.clk_p,
            i_IB    = pads.clk_n,
            o_O     = pcie_refclk_gt,
            o_ODIV2 = pcie_refclk
        )
        platform.add_period_constraint(pads.clk_p, 1e9/100e6)
        self.cd_pcie = ClockDomain()

        # TX (FPGA --> HOST) CDC / Data Width Conversion -------------------------------------------
        self.cc_datapath = PHYTXDatapath(
            core_data_width = data_width,
            pcie_data_width = pcie_data_width,
            clock_domain    = cd)
        self.comb += self.cmp_sink.connect(self.cc_datapath.sink)
        s_axis_cc = self.cc_datapath.source

        self.rq_datapath = PHYTXDatapath(
            core_data_width = data_width,
            pcie_data_width = pcie_data_width,
            clock_domain    = cd)
        self.comb += self.req_sink.connect(self.rq_datapath.sink)
        s_axis_rq = self.rq_datapath.source

        # RX (HOST --> FPGA) CDC / Data Width Conversion -------------------------------------------
        self.cq_datapath = PHYRXDatapath(
            core_data_width = data_width,
            pcie_data_width = pcie_data_width,
            clock_domain    = cd)
        m_axis_cq = self.cq_datapath.sink
        self.comb += self.cq_datapath.source.connect(self.req_source)

        self.rc_datapath = PHYRXDatapath(
            core_data_width = data_width,
            pcie_data_width = pcie_data_width,
            clock_domain    = cd)
        m_axis_rc = self.rc_datapath.sink
        self.comb += self.rc_datapath.source.connect(self.cmp_source)

        # MSI CDC (FPGA --> HOST) ------------------------------------------------------------------
        if cd == "pcie":
            cfg_msi = self.msi
        else:
            self.msi_cdc = msi_cdc = stream.ClockDomainCrossing(
                layout          = msi_layout(),
                cd_from         = cd,
                cd_to           = "pcie",
                with_common_rst = True,
            )
            self.comb += self.msi.connect(msi_cdc.sink)
            cfg_msi = msi_cdc.source

        # Hard IP Configuration --------------------------------------------------------------------

        def convert_size(command, size, max_size):
            cases = {}
            value = 128
            for i in range(6):
                cases[i] = size.eq(value)
                value = min(value*2, max_size)
            return Case(command, cases)

        serial_number   = Signal(64)
        bus_number      = Signal(8)
        device_number   = Signal(5)
        function_number = Signal(3)

        cfg_function_status  = Signal(16)
        cfg_max_payload_size = Signal(3)
        cfg_max_read_req     = Signal(3)

        self.comb += [
            convert_size(cfg_max_read_req,     self.max_request_size, max_size=512),
            convert_size(cfg_max_payload_size, self.max_payload_size, max_size=512),
            self.id.eq(Cat(function_number, device_number, bus_number))
        ]
        self.comb += [
            self._bus_master_enable.status.eq(cfg_function_status),
            self._max_request_size.status.eq(self.max_request_size),
            self._max_payload_size.status.eq(self.max_payload_size),
        ]

        self.m_axis_cq = m_axis_cq
        self.s_axis_cc = s_axis_cc
        self.s_axis_rq = s_axis_rq
        self.m_axis_rc = m_axis_rc

        # Hard IP ----------------------------------------------------------------------------------

        m_axis_rc_tuser = Signal(22)
        m_axis_cq_tuser = Signal(22)
        m_axis_rc_tlast = Signal()
        m_axis_cq_tlast = Signal()
        self.pcie_phy_params = dict(
            # Parameters ---------------------------------------------------------------------------
            p_LINK_CAP_MAX_LINK_WIDTH          = nlanes,
            p_C_DATA_WIDTH                     = pcie_data_width,
            p_KEEP_WIDTH                       = pcie_data_width//8,
            p_PCIE_GT_DEVICE                   = "GTY",
            p_PCIE_USE_MODE                    = "2.0",

            # PCI Express Interface ----------------------------------------------------------------
            # Clk / Rst
            i_sys_clk                          = pcie_refclk,
            i_sys_clk_gt                       = pcie_refclk_gt,
            i_sys_rst_n                        = pcie_rst_n,

            # TX
            o_pci_exp_txp                      = pads.tx_p,
            o_pci_exp_txn                      = pads.tx_n,
            # RX
            i_pci_exp_rxp                      = pads.rx_p,
            i_pci_exp_rxn                      = pads.rx_n,

            # AXI-S Interface ----------------------------------------------------------------------
            # Common
            o_user_clk_out                     = ClockSignal("pcie"),
            o_user_reset_out                   = ResetSignal("pcie"),
            o_user_lnk_up                      = self.add_resync(self._link_status.fields.status, "sys"),
            o_user_app_rdy                     = Open(),

            # (FPGA -> Host) Requester Request
            o_pcie_tfc_nph_av                  = Open(2),
            o_pcie_tfc_npd_av                  = Open(2),
            o_pcie_rq_tag_av                   = Open(2),
            o_pcie_rq_seq_num                  = Open(4),
            o_pcie_rq_seq_num_vld              = Open(),
            o_pcie_rq_tag                      = Open(6),
            o_pcie_rq_tag_vld                  = Open(),
            i_s_axis_rq_tvalid                 = s_axis_rq.valid,
            i_s_axis_rq_tlast                  = s_axis_rq.last,
            o_s_axis_rq_tready                 = s_axis_rq.ready,
            i_s_axis_rq_tdata                  = s_axis_rq.dat,
            i_s_axis_rq_tkeep                  = s_axis_rq.be,
            i_s_axis_rq_tuser                  = Constant(0b0000), # Discontinue, Streaming-AXIS, EP(Poisioning), TP(TLP-Digest)

            # (Host -> FPGA) Completer Request
            i_pcie_cq_np_req                   = 1,
            o_pcie_cq_np_req_count             = Open(6),
            o_m_axis_cq_tvalid                 = m_axis_cq.valid,
            o_m_axis_cq_tlast                  = m_axis_cq_tlast,
            i_m_axis_cq_tready                 = m_axis_cq.ready,
            o_m_axis_cq_tdata                  = m_axis_cq.dat,
            o_m_axis_cq_tkeep                  = m_axis_cq.be,
            o_m_axis_cq_tuser                  = m_axis_cq_tuser,

            # (Host -> FPGA) Requester Completion
            o_m_axis_rc_tvalid                 = m_axis_rc.valid,
            o_m_axis_rc_tlast                  = m_axis_rc_tlast,
            i_m_axis_rc_tready                 = m_axis_rc.ready,
            o_m_axis_rc_tdata                  = m_axis_rc.dat,
            o_m_axis_rc_tkeep                  = m_axis_rc.be,
            o_m_axis_rc_tuser                  = m_axis_rc_tuser,

            # (FPGA -> Host) Completer Completion
            i_s_axis_cc_tvalid                 = s_axis_cc.valid,
            i_s_axis_cc_tlast                  = s_axis_cc.last,
            o_s_axis_cc_tready                 = s_axis_cc.ready,
            i_s_axis_cc_tdata                  = s_axis_cc.dat,
            i_s_axis_cc_tkeep                  = s_axis_cc.be,
            i_s_axis_cc_tuser                  = Constant(0b0000), # Discontinue, Streaming-AXIS, EP(Poisioning), TP(TLP-Digest)

            # Management Interface -----------------------------------------------------------------
            o_cfg_mgmt_do                      = Open(32),
            o_cfg_mgmt_rd_wr_done              = Open(),
            i_cfg_mgmt_di                      = 0,
            i_cfg_mgmt_byte_en                 = 0,
            i_cfg_mgmt_dwaddr                  = 0,
            i_cfg_mgmt_wr_en                   = 0,
            i_cfg_mgmt_rd_en                   = 0,

            # Flow Control & Status ----------------------------------------------------------------
            o_cfg_fc_cpld                      = Open(12),
            o_cfg_fc_cplh                      = Open(8),
            o_cfg_fc_npd                       = Open(12),
            o_cfg_fc_nph                       = Open(8),
            o_cfg_fc_pd                        = Open(12),
            o_cfg_fc_ph                        = Open(8),
            i_cfg_fc_sel                       = 0, # Use PF0

            # Configuration Tx/Rx Message ----------------------------------------------------------
            o_cfg_msg_received                 = Open(),
            o_cfg_msg_received_data            = Open(8),
            o_cfg_msg_received_type            = Open(5),

            i_cfg_msg_transmit                 = 0,
            i_cfg_msg_transmit_data            = 0,
            i_cfg_msg_transmit_type            = 0,
            o_cfg_msg_transmit_done            = Open(),

            # Configuration Control Interface ------------------------------------------------------
            # Hot config
            o_pl_received_hot_rst              = Open(),
            i_pl_transmit_hot_rst              = 0,

            # Indentication & Routing
            i_cfg_dsn                          = serial_number,
            i_cfg_ds_bus_number                = bus_number,
            i_cfg_ds_device_number             = device_number,
            i_cfg_ds_function_number           = function_number,
            i_cfg_ds_port_number               = 0,
            i_cfg_subsys_vend_id               = 0x10ee,

            #  power-down request TLP
            i_cfg_power_state_change_ack       = 0,
            o_cfg_power_state_change_interrupt = Open(),

            # Interrupt Signals (Legacy & MSI) -----------------------------------------------------

            i_cfg_interrupt_int                = 0,
            i_cfg_interrupt_pending            = 0,
            o_cfg_interrupt_sent               = Open(),

            o_cfg_interrupt_msi_enable         = self.add_resync(self._msi_enable.status, "sys"),
            i_cfg_interrupt_msi_int_valid      = cfg_msi.valid,
            i_cfg_interrupt_msi_int            = cfg_msi.dat,
            o_cfg_interrupt_msi_sent           = cfg_msi.ready,
            o_cfg_interrupt_msi_fail           = Open(),

            o_cfg_interrupt_msi_mmenable       = Open(12),
            o_cfg_interrupt_msi_mask_update    = Open(),
            o_cfg_interrupt_msi_data           = Open(32),
            o_cfg_interrupt_msi_vf_enable      = Open(8),

            # Error Reporting Interface ------------------------------------------------------------
            o_cfg_phy_link_down                = self.add_resync(self._link_status.fields.phy_down,   "sys"),
            o_cfg_phy_link_status              = self.add_resync(self._link_status.fields.phy_status, "sys"),
            o_cfg_negotiated_width             = self.add_resync(self._link_status.fields.width,      "sys"),
            o_cfg_current_speed                = self.add_resync(self._link_status.fields.rate,       "sys"),
            o_cfg_max_payload                  = self.add_resync(cfg_max_payload_size, "sys"),
            o_cfg_max_read_req                 = self.add_resync(cfg_max_read_req,     "sys"),
            o_cfg_function_status              = self.add_resync(cfg_function_status,  "sys"),
            o_cfg_function_power_state         = Open(12),
            o_cfg_vf_status                    = Open(16),
            o_cfg_vf_power_state               = Open(24),
            o_cfg_link_power_state             = Open(2),

            o_cfg_err_cor_out                  = Open(),
            o_cfg_err_nonfatal_out             = Open(),
            o_cfg_err_fatal_out                = Open(),
            o_cfg_ltr_enable                   = Open(),
            o_cfg_ltssm_state                  = self.add_resync(self._link_status.fields.ltssm, "sys"),
            o_cfg_rcb_status                   = Open(4),
            o_cfg_dpa_substate_change          = Open(4),
            o_cfg_obff_enable                  = Open(2),
            o_cfg_pl_status_change             = Open(),

            o_cfg_tph_requester_enable         = Open(4),
            o_cfg_tph_st_mode                  = Open(12),
            o_cfg_vf_tph_requester_enable      = Open(8),
            o_cfg_vf_tph_st_mode               = Open(24),
        )
        self.comb += [
            m_axis_cq.first.eq(m_axis_cq_tuser[14]),
            m_axis_cq.last.eq (m_axis_cq_tlast),
            m_axis_rc.first.eq(m_axis_rc_tuser[14]),
            m_axis_rc.last.eq (m_axis_rc_tlast),
        ]

    # Resync Helper --------------------------------------------------------------------------------
    def add_resync(self, sig, clk="sys"):
        _sig = Signal.like(sig)
        self.specials += MultiReg(_sig, sig, clk)
        return _sig

    # LTSSM Tracer ---------------------------------------------------------------------------------
    def add_ltssm_tracer(self):
        self.ltssm_tracer = LTSSMTracer(self._link_status.fields.ltssm)

    # Hard IP sources ------------------------------------------------------------------------------
    def update_config(self, config):
        self.config.update(config)

    def add_sources(self, platform, phy_path=None, phy_filename=None):
        if phy_filename is not None:
            platform.add_ip(os.path.join(phy_path, phy_filename))
        else:
            # FIXME: Add missing parameters?
            config = {
                # Generic Config.
                # ---------------
                "Component_Name"               : "pcie_usp",
                "PL_LINK_CAP_MAX_LINK_WIDTH"   : f"X{self.nlanes}",
                "PL_LINK_CAP_MAX_LINK_SPEED"   : {"gen3": "8.0_GT/s", "gen4": "16.0_GT/s"}[self.speed],
                "axisten_if_width"             : f"{self.pcie_data_width}_bit",
                "AXISTEN_IF_RC_STRADDLE"       : False,
                "PF0_DEVICE_ID"                : {"gen3": 9030, "gen4": 9040}[self.speed] + self.nlanes,
                "axisten_freq"                 : 250, # CHECKME.
                "axisten_if_enable_client_tag" : True,
                "aspm_support"                 : "No_ASPM",
                "coreclk_freq"                 : 500, # CHECKME.
                "plltype"                      : "QPLL0",

                # BAR0 Config.
                # ------------
                "pf0_bar0_scale"               : "Megabytes",               # FIXME.
                "pf0_bar0_size"                : max(self.bar0_size/MB, 1), # FIXME.

                # Interrupt Config.
                # -----------------
                "PF0_INTERRUPT_PIN"            : "NONE",
            }

            # User/Custom Config.
            config.update(self.config)

            # Tcl generation.
            ip_tcl  = []
            ip_tcl.append(f"create_ip -vendor xilinx.com -name {self.ip_name} -module_name pcie_usp")
            ip_tcl.append("set obj [get_ips pcie_usp]")
            ip_tcl.append("set_property -dict [list \\")
            for config, value in config.items():
                ip_tcl.append("CONFIG.{} {} \\".format(config, '{{' + str(value) + '}}'))
            ip_tcl.append(f"] $obj")
            ip_tcl.append("synth_ip $obj")
            platform.toolchain.pre_synthesis_commands += ip_tcl

        verilog_path = os.path.join(os.path.abspath(os.path.dirname(__file__)), "xilinx_usp")
        platform.add_source(os.path.join(verilog_path, "axis_iff.v"))

        platform.add_source(os.path.join(verilog_path, f"s_axis_rq_adapt_{self.pcie_data_width}b.v"))
        platform.add_source(os.path.join(verilog_path, f"m_axis_rc_adapt_{self.pcie_data_width}b.v"))
        platform.add_source(os.path.join(verilog_path, f"m_axis_cq_adapt_{self.pcie_data_width}b.v"))
        platform.add_source(os.path.join(verilog_path, f"s_axis_cc_adapt_{self.pcie_data_width}b.v"))
        platform.add_source(os.path.join(verilog_path, "pcie_usp_support.v"))

    # External Hard IP -----------------------------------------------------------------------------
    def use_external_hard_ip(self, hard_ip_path, hard_ip_filename):
        self.external_hard_ip = True
        self.add_sources(self.platform, hard_ip_path, hard_ip_filename)

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        if not self.external_hard_ip:
            self.add_sources(self.platform)
        self.specials += Instance("pcie_support", **self.pcie_phy_params)

# USPHBMPCIEPHY ------------------------------------------------------------------------------------

class USPHBMPCIEPHY(USPPCIEPHY):
    def __init__(self, *args, **kwargs):
        USPPCIEPHY.__init__(self, *args, **kwargs, ip_name="pcie4c_uscale_plus")
