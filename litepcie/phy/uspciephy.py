#
# This file is part of LitePCIe.
#
# Copyright (c) 2020-2023 Enjoy-Digital <enjoy-digital.fr>
# Copyright (c) 2022 Sylvain Munaut <tnt@246tNt.com>
# SPDX-License-Identifier: BSD-2-Clause

import os

from migen import *
from migen.genlib.cdc import MultiReg

from litex.gen import *

from litex.soc.interconnect.csr import *

from litepcie.common import *
from litepcie.phy.common import *
from litepcie.phy.xilinx.axis_adapters import MAxisCQAdapter, MAxisRCAdapter, SAxisCCAdapter, SAxisRQAdapter

# USPCIEPHY ----------------------------------------------------------------------------------------

class USPCIEPHY(LiteXModule):
    endianness    = "little"
    qword_aligned = False
    def __init__(self, platform, pads, speed="gen3", data_width=64, cd="sys",
        # PCIe hardblock parameters.
        pcie_data_width = None,
        bar0_size       = 0x100000,
        mode            = "Endpoint",
        use_support_wrapper = False,
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
            CSRField("rate", size=3, values=[
                ("``0b001``", "2.5 GT/s."),
                ("``0b010``", "5.0 GT/s."),
                ("``0b100``", "8.0 GT/s."),
            ]),
            CSRField("width", size=4, values=[
                ("``0b0001``", "1-Lane link."),
                ("``0b0010``", "2-Lane link."),
                ("``0b0100``", "4-Lane link."),
                ("``0b1000``", "8-Lane link."),
            ]),
            CSRField("ltssm", size=6, description="LTSSM State"),
        ])
        self._msi_enable        = CSRStatus(description="MSI Enable Status. ``1``: MSI is enabled.")
        self._bus_master_enable = CSRStatus(description="Bus Mastering Status. ``1``: Bus Mastering enabled.")
        self._max_request_size  = CSRStatus(16, description="Negiotiated Max Request Size (in bytes).")
        self._max_payload_size  = CSRStatus(16, description="Negiotiated Max Payload Size (in bytes).")

        # Parameters/Locals ------------------------------------------------------------------------
        assert mode in ["Endpoint", "RootPort"]
        self.mode = mode

        if pcie_data_width is None: pcie_data_width = data_width
        self.platform         = platform
        self.data_width       = data_width
        self.pcie_data_width  = pcie_data_width

        self.id               = Signal(16)
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)
        self.max_request_size = Signal(16)
        self.max_payload_size = Signal(16)

        self.config           = {}
        self.external_hard_ip = False
        self.use_support_wrapper = use_support_wrapper

        # # #

        self.speed  = speed
        self.nlanes = nlanes = len(pads.tx_p)

        assert speed           in ["gen2", "gen3"]
        assert nlanes          in [1, 2, 4, 8]
        assert data_width      in [64, 128, 256]
        assert pcie_data_width in [64, 128, 256]

        # Clocking / Reset -------------------------------------------------------------------------
        self.pcie_refclk    = pcie_refclk    = Signal()
        self.pcie_refclk_gt = pcie_refclk_gt = Signal()
        self.pcie_rst_n     = pcie_rst_n     = Signal(reset=1)
        if hasattr(pads, "rst_n"):
            self.comb += pcie_rst_n.eq(pads.rst_n)
        self.specials += Instance("IBUFDS_GTE3",
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

        # MSI CDC ----------------------------------------------------------------------------------
        if self.mode == "Endpoint":
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
        else:
            cfg_msi = None

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
        link_status_sys      = self.add_resync(self._link_status.fields.status, "sys")
        link_phy_down_sys    = self.add_resync(self._link_status.fields.phy_down, "sys")
        link_phy_status_sys  = self.add_resync(self._link_status.fields.phy_status, "sys")
        link_width_sys       = self.add_resync(self._link_status.fields.width, "sys")
        link_rate_sys        = self.add_resync(self._link_status.fields.rate, "sys")
        link_ltssm_sys       = self.add_resync(self._link_status.fields.ltssm, "sys")
        cfg_max_payload_sys  = self.add_resync(cfg_max_payload_size, "sys")
        cfg_max_read_req_sys = self.add_resync(cfg_max_read_req, "sys")
        cfg_function_status_sys = self.add_resync(cfg_function_status, "sys")
        msi_enable_sys       = self.add_resync(self._msi_enable.status, "sys")

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

        rq_tuser_width = 137 if pcie_data_width == 512 else 60

        m_axis_rc_tuser = Signal(85)
        m_axis_cq_tuser = Signal(85)
        m_axis_rc_tlast = Signal()
        m_axis_cq_tlast = Signal()
        s_axis_rq_tdata_raw  = Signal(pcie_data_width)
        s_axis_rq_tkeep_raw  = Signal(pcie_data_width//32)
        s_axis_rq_tuser_raw  = Signal(rq_tuser_width)
        s_axis_rq_tlast_raw  = Signal()
        s_axis_rq_tvalid_raw = Signal()
        s_axis_rq_tready_raw = Signal()
        m_axis_rc_tdata_raw  = Signal(pcie_data_width)
        m_axis_rc_tkeep_raw  = Signal(pcie_data_width//32)
        m_axis_rc_tuser_raw  = Signal(85)
        m_axis_rc_tuser_full = Signal(256)
        m_axis_rc_tlast_raw  = Signal()
        m_axis_rc_tvalid_raw = Signal()
        m_axis_rc_tready_raw = Signal(4)
        m_axis_cq_tdata_raw  = Signal(pcie_data_width)
        m_axis_cq_tkeep_raw  = Signal(pcie_data_width//32)
        m_axis_cq_tuser_raw  = Signal(85)
        m_axis_cq_tuser_full = Signal(256)
        m_axis_cq_tlast_raw  = Signal()
        m_axis_cq_tvalid_raw = Signal()
        m_axis_cq_tready_raw = Signal(4)
        s_axis_cc_tdata_raw  = Signal(pcie_data_width)
        s_axis_cc_tkeep_raw  = Signal(pcie_data_width//32)
        s_axis_cc_tuser_raw  = Signal(33)
        s_axis_cc_tlast_raw  = Signal()
        s_axis_cc_tvalid_raw = Signal()
        s_axis_cc_tready_raw = Signal()

        if self.mode == "Endpoint":
            msi_ports = dict(
                o_cfg_interrupt_msi_enable    = msi_enable_sys,
                i_cfg_interrupt_msi_int_valid = cfg_msi.valid,
                i_cfg_interrupt_msi_int       = cfg_msi.dat,
                o_cfg_interrupt_msi_sent      = cfg_msi.ready,
                o_cfg_interrupt_msi_fail      = Open(),
            )
        else:
            msi_ports = dict(
                o_cfg_interrupt_msi_enable    = Open(),
                i_cfg_interrupt_msi_int_valid = 0,
                i_cfg_interrupt_msi_int       = 0,
                o_cfg_interrupt_msi_sent      = Open(),
                o_cfg_interrupt_msi_fail      = Open(),
            )

        if self.mode == "RootPort":
            cfg_msg_received      = Signal()
            cfg_msg_received_type = Signal(5)
            cfg_msg_received_data = Signal(8)
            cfg_msg_ports = dict(
                o_cfg_msg_received      = cfg_msg_received,
                o_cfg_msg_received_data = cfg_msg_received_data,
                o_cfg_msg_received_type = cfg_msg_received_type,
            )
        else:
            cfg_msg_ports = dict(
                o_cfg_msg_received      = Open(),
                o_cfg_msg_received_data = Open(8),
                o_cfg_msg_received_type = Open(5),
            )

        # Direct pcie_us MSI adaptation (equivalent to legacy support wrapper).
        cfg_interrupt_msi_enable_x4 = Signal(4)
        cfg_interrupt_msi_sent      = Signal()
        cfg_interrupt_msi_fail      = Signal()
        cfg_interrupt_msi_mmenable  = Signal(12)
        cfg_interrupt_msi_int_enc   = Signal(32)
        cfg_interrupt_msi_int_valid = Signal()
        cfg_interrupt_msi_int_valid_r = Signal()
        cfg_interrupt_msi_int_valid_sh = Signal(2)
        cfg_interrupt_msi_int_valid_edge = Signal()
        cfg_interrupt_msi_int_valid_edge1 = Signal()
        cfg_interrupt_msi_int_enc_lat = Signal(32)
        cfg_interrupt_msi_int_enc_mux = Signal(32)
        self.comb += cfg_interrupt_msi_int_valid.eq(
            cfg_msi.valid & ~(cfg_interrupt_msi_sent | cfg_interrupt_msi_fail)
            if self.mode == "Endpoint" else 0
        )
        self.sync.pcie += [
            cfg_interrupt_msi_int_valid_r.eq(cfg_interrupt_msi_int_valid),
            cfg_interrupt_msi_int_valid_sh.eq(Cat(cfg_interrupt_msi_int_valid, cfg_interrupt_msi_int_valid_sh[0])),
        ]
        self.comb += cfg_interrupt_msi_int_valid_edge.eq(cfg_interrupt_msi_int_valid_sh == 0b01)
        self.comb += Case(cfg_interrupt_msi_mmenable[0:3], {
            0b000: cfg_interrupt_msi_int_enc.eq(0x00000001),
            0b001: cfg_interrupt_msi_int_enc.eq(0x00000002),
            0b010: cfg_interrupt_msi_int_enc.eq(0x00000010),
            0b011: cfg_interrupt_msi_int_enc.eq(0x00000100),
            0b100: cfg_interrupt_msi_int_enc.eq(0x00010000),
            "default": cfg_interrupt_msi_int_enc.eq(0x80000000),
        })
        self.sync.pcie += [
            If(cfg_interrupt_msi_int_valid_edge,
                cfg_interrupt_msi_int_enc_lat.eq(cfg_interrupt_msi_int_enc)
            ).Elif(cfg_interrupt_msi_sent,
                cfg_interrupt_msi_int_enc_lat.eq(0)
            ),
            If(ResetSignal("pcie"),
                cfg_interrupt_msi_int_valid_edge1.eq(0)
            ).Else(
                cfg_interrupt_msi_int_valid_edge1.eq(cfg_interrupt_msi_int_valid_edge)
            )
        ]
        self.comb += cfg_interrupt_msi_int_enc_mux.eq(Mux(cfg_interrupt_msi_int_valid_edge1, cfg_interrupt_msi_int_enc_lat, 0))
        self.comb += [
            msi_enable_sys.eq(cfg_interrupt_msi_enable_x4[0]),
            m_axis_rc_tuser_raw.eq(m_axis_rc_tuser_full[:85]),
            m_axis_cq_tuser_raw.eq(m_axis_cq_tuser_full[:85]),
        ]
        if self.mode == "Endpoint":
            self.comb += cfg_msi.ready.eq(cfg_interrupt_msi_sent)

        self.pcie_phy_params = dict(
            # Parameters ---------------------------------------------------------------------------
            p_LINK_CAP_MAX_LINK_WIDTH          = nlanes,
            p_C_DATA_WIDTH                     = pcie_data_width,
            p_KEEP_WIDTH                       = pcie_data_width//8,
            p_PCIE_GT_DEVICE                   = "GTH",
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
            o_user_lnk_up                      = link_status_sys,
            o_user_app_rdy                     = Open(),

            # (FPGA -> Host) Requester Request
            o_pcie_tfc_nph_av                  = Open(2),
            o_pcie_tfc_npd_av                  = Open(2),
            o_pcie_rq_tag_av                   = Open(2),
            o_pcie_rq_seq_num                  = Open(4),
            o_pcie_rq_seq_num_vld              = Open(),
            o_pcie_rq_tag                      = Open(6),
            o_pcie_rq_tag_vld                  = Open(),
            i_s_axis_rq_tvalid                 = s_axis_rq_tvalid_raw,
            i_s_axis_rq_tlast                  = s_axis_rq_tlast_raw,
            o_s_axis_rq_tready                 = s_axis_rq_tready_raw,
            i_s_axis_rq_tdata                  = s_axis_rq_tdata_raw,
            i_s_axis_rq_tkeep                  = s_axis_rq_tkeep_raw,
            i_s_axis_rq_tuser                  = s_axis_rq_tuser_raw,

            # (Host -> FPGA) Completer Request
            i_pcie_cq_np_req                   = 1,
            o_pcie_cq_np_req_count             = Open(6),
            o_m_axis_cq_tvalid                 = m_axis_cq_tvalid_raw,
            o_m_axis_cq_tlast                  = m_axis_cq_tlast_raw,
            i_m_axis_cq_tready                 = m_axis_cq_tready_raw,
            o_m_axis_cq_tdata                  = m_axis_cq_tdata_raw,
            o_m_axis_cq_tkeep                  = m_axis_cq_tkeep_raw,
            o_m_axis_cq_tuser                  = m_axis_cq_tuser_raw,

            # (Host -> FPGA) Requester Completion
            o_m_axis_rc_tvalid                 = m_axis_rc_tvalid_raw,
            o_m_axis_rc_tlast                  = m_axis_rc_tlast_raw,
            i_m_axis_rc_tready                 = m_axis_rc_tready_raw,
            o_m_axis_rc_tdata                  = m_axis_rc_tdata_raw,
            o_m_axis_rc_tkeep                  = m_axis_rc_tkeep_raw,
            o_m_axis_rc_tuser                  = m_axis_rc_tuser_raw,

            # (FPGA -> Host) Completer Completion
            i_s_axis_cc_tvalid                 = s_axis_cc_tvalid_raw,
            i_s_axis_cc_tlast                  = s_axis_cc_tlast_raw,
            o_s_axis_cc_tready                 = s_axis_cc_tready_raw,
            i_s_axis_cc_tdata                  = s_axis_cc_tdata_raw,
            i_s_axis_cc_tkeep                  = s_axis_cc_tkeep_raw,
            i_s_axis_cc_tuser                  = s_axis_cc_tuser_raw,

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
            i_cfg_msg_transmit                 = 0,
            i_cfg_msg_transmit_data            = 0,
            i_cfg_msg_transmit_type            = 0,
            o_cfg_msg_transmit_done            = Open(),

            # Configuration Control Interface ------------------------------------------------------
            # Hot config
            o_pl_received_hot_rst              = Open(),
            i_pl_transmit_hot_rst              = 0,

            # Identification & Routing -------------------------------------------------------------
            i_cfg_dsn                          = serial_number,
            i_cfg_ds_bus_number                = bus_number,
            i_cfg_ds_device_number             = device_number,
            i_cfg_ds_function_number           = function_number,
            i_cfg_ds_port_number               = 0,
            i_cfg_subsys_vend_id               = 0x10ee,

            # Power-Down Request TLP ---------------------------------------------------------------
            i_cfg_power_state_change_ack       = 0,
            o_cfg_power_state_change_interrupt = Open(),

            # Interrupt Signals --------------------------------------------------------------------
            i_cfg_interrupt_int                = 0,
            i_cfg_interrupt_pending            = 0,
            o_cfg_interrupt_sent               = Open(),

            o_cfg_interrupt_msi_mmenable       = Open(12),
            o_cfg_interrupt_msi_mask_update    = Open(),
            o_cfg_interrupt_msi_data           = Open(32),
            o_cfg_interrupt_msi_vf_enable      = Open(8),

            # Error Reporting Interface ------------------------------------------------------------
            o_cfg_phy_link_down                = link_phy_down_sys,
            o_cfg_phy_link_status              = link_phy_status_sys,
            o_cfg_negotiated_width             = link_width_sys,
            o_cfg_current_speed                = link_rate_sys,
            o_cfg_max_payload                  = cfg_max_payload_sys,
            o_cfg_max_read_req                 = cfg_max_read_req_sys,
            o_cfg_function_status              = cfg_function_status_sys,
            o_cfg_function_power_state         = Open(12),
            o_cfg_vf_status                    = Open(16),
            o_cfg_vf_power_state               = Open(24),
            o_cfg_link_power_state             = Open(2),

            o_cfg_err_cor_out                  = Open(),
            o_cfg_err_nonfatal_out             = Open(),
            o_cfg_err_fatal_out                = Open(),
            o_cfg_ltr_enable                   = Open(),
            o_cfg_ltssm_state                  = link_ltssm_sys,
            o_cfg_rcb_status                   = Open(4),
            o_cfg_dpa_substate_change          = Open(4),
            o_cfg_obff_enable                  = Open(2),
            o_cfg_pl_status_change             = Open(),

            o_cfg_tph_requester_enable         = Open(4),
            o_cfg_tph_st_mode                  = Open(12),
            o_cfg_vf_tph_requester_enable      = Open(8),
            o_cfg_vf_tph_st_mode               = Open(24),
        )

        self.pcie_phy_params.update(msi_ports)
        self.pcie_phy_params.update(cfg_msg_ports)

        # Direct pcie_us instantiation (US only, wrapper-less path).
        self.pcie_us_phy_params = dict(
            # PCI Express Interface ---------------------------------------------------------------
            i_sys_clk                          = pcie_refclk,
            i_sys_clk_gt                       = pcie_refclk_gt,
            i_sys_reset                        = pcie_rst_n,
            o_pci_exp_txp                      = pads.tx_p,
            o_pci_exp_txn                      = pads.tx_n,
            i_pci_exp_rxp                      = pads.rx_p,
            i_pci_exp_rxn                      = pads.rx_n,
            o_int_qpll1lock_out                = Open(),
            o_int_qpll1outrefclk_out           = Open(),
            o_int_qpll1outclk_out              = Open(),

            # AXI-S ------------------------------------------------------------------------------
            o_user_clk                         = ClockSignal("pcie"),
            o_user_reset                       = ResetSignal("pcie"),
            o_user_lnk_up                      = link_status_sys,
            o_phy_rdy_out                      = Open(),

            i_s_axis_rq_tvalid                 = s_axis_rq_tvalid_raw,
            i_s_axis_rq_tlast                  = s_axis_rq_tlast_raw,
            o_s_axis_rq_tready                 = s_axis_rq_tready_raw,
            i_s_axis_rq_tdata                  = s_axis_rq_tdata_raw,
            i_s_axis_rq_tkeep                  = s_axis_rq_tkeep_raw,
            i_s_axis_rq_tuser                  = s_axis_rq_tuser_raw,

            o_m_axis_rc_tdata                  = m_axis_rc_tdata_raw,
            o_m_axis_rc_tuser                  = m_axis_rc_tuser_full,
            o_m_axis_rc_tlast                  = m_axis_rc_tlast_raw,
            o_m_axis_rc_tkeep                  = m_axis_rc_tkeep_raw,
            o_m_axis_rc_tvalid                 = m_axis_rc_tvalid_raw,
            i_m_axis_rc_tready                 = m_axis_rc_tready_raw,

            o_m_axis_cq_tdata                  = m_axis_cq_tdata_raw,
            o_m_axis_cq_tuser                  = m_axis_cq_tuser_full,
            o_m_axis_cq_tlast                  = m_axis_cq_tlast_raw,
            o_m_axis_cq_tkeep                  = m_axis_cq_tkeep_raw,
            o_m_axis_cq_tvalid                 = m_axis_cq_tvalid_raw,
            i_m_axis_cq_tready                 = m_axis_cq_tready_raw,

            i_s_axis_cc_tdata                  = s_axis_cc_tdata_raw,
            i_s_axis_cc_tuser                  = s_axis_cc_tuser_raw,
            i_s_axis_cc_tlast                  = s_axis_cc_tlast_raw,
            i_s_axis_cc_tkeep                  = s_axis_cc_tkeep_raw,
            i_s_axis_cc_tvalid                 = s_axis_cc_tvalid_raw,
            o_s_axis_cc_tready                 = s_axis_cc_tready_raw,

            # Sequence & Tag ---------------------------------------------------------------------
            o_pcie_rq_seq_num                  = Open(4),
            o_pcie_rq_seq_num_vld              = Open(),
            o_pcie_rq_tag                      = Open(6),
            o_pcie_rq_tag_vld                  = Open(),
            o_pcie_cq_np_req_count             = Open(6),
            i_pcie_cq_np_req                   = 1,
            o_pcie_rq_tag_av                   = Open(2),

            # Error reporting / status -----------------------------------------------------------
            o_cfg_phy_link_down                = link_phy_down_sys,
            o_cfg_phy_link_status              = link_phy_status_sys,
            o_cfg_negotiated_width             = link_width_sys,
            o_cfg_current_speed                = link_rate_sys,
            o_cfg_max_payload                  = cfg_max_payload_sys,
            o_cfg_max_read_req                 = cfg_max_read_req_sys,
            o_cfg_function_status              = cfg_function_status_sys,
            o_cfg_function_power_state         = Open(12),
            o_cfg_vf_status                    = Open(16),
            o_cfg_vf_power_state               = Open(24),
            o_cfg_link_power_state             = Open(2),
            o_cfg_err_cor_out                  = Open(),
            o_cfg_err_nonfatal_out             = Open(),
            o_cfg_err_fatal_out                = Open(),
            o_cfg_ltr_enable                   = Open(),
            o_cfg_ltssm_state                  = link_ltssm_sys,
            o_cfg_rcb_status                   = Open(4),
            o_cfg_dpa_substate_change          = Open(4),
            o_cfg_obff_enable                  = Open(2),
            o_cfg_pl_status_change             = Open(),
            o_cfg_tph_requester_enable         = Open(4),
            o_cfg_tph_st_mode                  = Open(12),
            o_cfg_vf_tph_requester_enable      = Open(8),
            o_cfg_vf_tph_st_mode               = Open(24),

            # Management -------------------------------------------------------------------------
            i_cfg_mgmt_addr                    = 0,
            i_cfg_mgmt_write                   = 0,
            i_cfg_mgmt_write_data              = 0,
            i_cfg_mgmt_byte_enable             = 0,
            i_cfg_mgmt_read                    = 0,
            o_cfg_mgmt_read_data               = Open(32),
            o_cfg_mgmt_read_write_done         = Open(),
            i_cfg_mgmt_type1_cfg_reg_access    = 0,

            # Flow / messages -------------------------------------------------------------------
            o_pcie_tfc_nph_av                  = Open(2),
            o_pcie_tfc_npd_av                  = Open(2),
            o_cfg_msg_received                 = cfg_msg_ports["o_cfg_msg_received"],
            o_cfg_msg_received_data            = cfg_msg_ports["o_cfg_msg_received_data"],
            o_cfg_msg_received_type            = cfg_msg_ports["o_cfg_msg_received_type"],
            i_cfg_msg_transmit                 = 0,
            i_cfg_msg_transmit_type            = 0,
            i_cfg_msg_transmit_data            = 0,
            o_cfg_msg_transmit_done            = Open(),
            o_cfg_fc_ph                        = Open(8),
            o_cfg_fc_pd                        = Open(12),
            o_cfg_fc_nph                       = Open(8),
            o_cfg_fc_npd                       = Open(12),
            o_cfg_fc_cplh                      = Open(8),
            o_cfg_fc_cpld                      = Open(12),
            i_cfg_fc_sel                       = 0,
            i_cfg_per_func_status_control      = 0,
            o_cfg_per_func_status_data         = Open(16),

            # Control / power -------------------------------------------------------------------
            i_cfg_hot_reset_in                 = 0,
            o_cfg_hot_reset_out                = Open(),
            i_cfg_per_function_number          = 0,
            i_cfg_per_function_output_request  = 0,
            o_cfg_per_function_update_done     = Open(),
            i_cfg_power_state_change_ack       = 0,
            o_cfg_power_state_change_interrupt = Open(),
            i_cfg_err_cor_in                   = 0,
            i_cfg_err_uncor_in                 = 0,
            o_cfg_flr_in_process               = Open(4),
            i_cfg_flr_done                     = 0,
            o_cfg_vf_flr_in_process            = Open(8),
            i_cfg_vf_flr_done                  = 0,
            o_cfg_local_error                  = Open(),
            i_cfg_link_training_enable         = 1,
            i_cfg_config_space_enable          = 1,
            i_cfg_req_pm_transition_l23_ready  = 0,

            # Identification --------------------------------------------------------------------
            i_cfg_dsn                          = serial_number,
            i_cfg_ds_bus_number                = bus_number,
            i_cfg_ds_device_number             = device_number,
            i_cfg_ds_function_number           = function_number,
            i_cfg_ds_port_number               = 0,
            i_cfg_subsys_vend_id               = 0x10ee,

            # Interrupts ------------------------------------------------------------------------
            i_cfg_interrupt_int                              = 0,
            i_cfg_interrupt_pending                          = 0,
            o_cfg_interrupt_sent                             = Open(),
            o_cfg_interrupt_msi_enable                       = cfg_interrupt_msi_enable_x4,
            i_cfg_interrupt_msi_int                          = cfg_interrupt_msi_int_enc_mux,
            o_cfg_interrupt_msi_sent                         = cfg_interrupt_msi_sent,
            o_cfg_interrupt_msi_fail                         = cfg_interrupt_msi_fail,
            o_cfg_interrupt_msi_vf_enable                    = Open(8),
            o_cfg_interrupt_msi_mmenable                     = cfg_interrupt_msi_mmenable,
            o_cfg_interrupt_msi_mask_update                  = Open(),
            o_cfg_interrupt_msi_data                         = Open(32),
            i_cfg_interrupt_msi_select                       = 0,
            i_cfg_interrupt_msi_pending_status               = cfg_interrupt_msi_int_enc_lat,
            i_cfg_interrupt_msi_attr                         = 0,
            i_cfg_interrupt_msi_tph_present                  = 0,
            i_cfg_interrupt_msi_tph_type                     = 0,
            i_cfg_interrupt_msi_tph_st_tag                   = 0,
            i_cfg_interrupt_msi_pending_status_function_num  = 0,
            i_cfg_interrupt_msi_pending_status_data_enable   = 0,
            i_cfg_interrupt_msi_function_number              = 0,

            # Perst pass-through -----------------------------------------------------------------
            o_pcie_perstn0_out                 = Open(),
            i_pcie_perstn1_in                  = 0,
            o_pcie_perstn1_out                 = Open(),
        )

        self.m_axis_cq_adapt = m_axis_cq_adapt = ClockDomainsRenamer("pcie")(MAxisCQAdapter(pcie_data_width))
        self.comb += [
            m_axis_cq_adapt.s_axis_tdata.eq(m_axis_cq_tdata_raw),
            m_axis_cq_adapt.s_axis_tkeep.eq(m_axis_cq_tkeep_raw),
            m_axis_cq_adapt.s_axis_tuser.eq(m_axis_cq_tuser_raw),
            m_axis_cq_adapt.s_axis_tlast.eq(m_axis_cq_tlast_raw),
            m_axis_cq_adapt.s_axis_tvalid.eq(m_axis_cq_tvalid_raw),
            m_axis_cq_tready_raw.eq(m_axis_cq_adapt.s_axis_tready),

            m_axis_cq.dat.eq(m_axis_cq_adapt.m_axis_tdata),
            m_axis_cq.be.eq(m_axis_cq_adapt.m_axis_tkeep),
            m_axis_cq_tuser.eq(m_axis_cq_adapt.m_axis_tuser),
            m_axis_cq_tlast.eq(m_axis_cq_adapt.m_axis_tlast),
            m_axis_cq.valid.eq(m_axis_cq_adapt.m_axis_tvalid),
            m_axis_cq_adapt.m_axis_tready.eq(m_axis_cq.ready),
            m_axis_cq.first.eq(m_axis_cq_tuser[14]),
            m_axis_cq.last.eq(m_axis_cq_tlast),
        ]

        self.m_axis_rc_adapt = m_axis_rc_adapt = ClockDomainsRenamer("pcie")(MAxisRCAdapter(pcie_data_width))
        self.comb += [
            m_axis_rc_adapt.s_axis_tdata.eq(m_axis_rc_tdata_raw),
            m_axis_rc_adapt.s_axis_tkeep.eq(m_axis_rc_tkeep_raw),
            m_axis_rc_adapt.s_axis_tuser.eq(m_axis_rc_tuser_raw),
            m_axis_rc_adapt.s_axis_tlast.eq(m_axis_rc_tlast_raw),
            m_axis_rc_adapt.s_axis_tvalid.eq(m_axis_rc_tvalid_raw),
            m_axis_rc_tready_raw.eq(m_axis_rc_adapt.s_axis_tready),

            m_axis_rc.dat.eq(m_axis_rc_adapt.m_axis_tdata),
            m_axis_rc.be.eq(m_axis_rc_adapt.m_axis_tkeep),
            m_axis_rc_tuser.eq(m_axis_rc_adapt.m_axis_tuser),
            m_axis_rc_tlast.eq(m_axis_rc_adapt.m_axis_tlast),
            m_axis_rc.valid.eq(m_axis_rc_adapt.m_axis_tvalid),
            m_axis_rc_adapt.m_axis_tready.eq(m_axis_rc.ready),
            m_axis_rc.first.eq(m_axis_rc_adapt.m_axis_sop),
            m_axis_rc.last.eq(m_axis_rc_tlast),
        ]

        self.s_axis_cc_adapt = s_axis_cc_adapt = ClockDomainsRenamer("pcie")(SAxisCCAdapter(pcie_data_width))
        self.comb += [
            s_axis_cc_adapt.s_axis_tdata.eq(s_axis_cc.dat),
            s_axis_cc_adapt.s_axis_tkeep.eq(s_axis_cc.be),
            s_axis_cc_adapt.s_axis_tlast.eq(s_axis_cc.last),
            s_axis_cc_adapt.s_axis_tuser.eq(Constant(0b0000)),
            s_axis_cc_adapt.s_axis_tvalid.eq(s_axis_cc.valid),
            s_axis_cc.ready.eq(s_axis_cc_adapt.s_axis_tready),

            s_axis_cc_tdata_raw.eq(s_axis_cc_adapt.m_axis_tdata),
            s_axis_cc_tkeep_raw.eq(s_axis_cc_adapt.m_axis_tkeep),
            s_axis_cc_tlast_raw.eq(s_axis_cc_adapt.m_axis_tlast),
            s_axis_cc_tuser_raw.eq(s_axis_cc_adapt.m_axis_tuser),
            s_axis_cc_tvalid_raw.eq(s_axis_cc_adapt.m_axis_tvalid),
            s_axis_cc_adapt.m_axis_tready.eq(s_axis_cc_tready_raw),
        ]

        self.s_axis_rq_adapt = s_axis_rq_adapt = ClockDomainsRenamer("pcie")(SAxisRQAdapter(pcie_data_width))
        self.comb += [
            s_axis_rq_adapt.s_axis_tdata.eq(s_axis_rq.dat),
            s_axis_rq_adapt.s_axis_tkeep.eq(s_axis_rq.be),
            s_axis_rq_adapt.s_axis_tlast.eq(s_axis_rq.last),
            s_axis_rq_adapt.s_axis_tuser.eq(Constant(0b0000)),
            s_axis_rq_adapt.s_axis_tvalid.eq(s_axis_rq.valid),
            s_axis_rq.ready.eq(s_axis_rq_adapt.s_axis_tready),

            s_axis_rq_tdata_raw.eq(s_axis_rq_adapt.m_axis_tdata),
            s_axis_rq_tkeep_raw.eq(s_axis_rq_adapt.m_axis_tkeep),
            s_axis_rq_tlast_raw.eq(s_axis_rq_adapt.m_axis_tlast),
            s_axis_rq_tuser_raw.eq(s_axis_rq_adapt.m_axis_tuser),
            s_axis_rq_tvalid_raw.eq(s_axis_rq_adapt.m_axis_tvalid),
            s_axis_rq_adapt.m_axis_tready.eq(s_axis_rq_tready_raw),
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
            # Link / clocks (speed-dependent).
            link_speed   = {"gen2": "5.0_GT/s", "gen3": "8.0_GT/s"}[self.speed]
            axisten_freq = {"gen2": 125,        "gen3": 250       }[self.speed]
            coreclk_freq = {"gen2": 250,        "gen3": 500       }[self.speed]

            # Device identification.
            device_id_base = {"gen2": 8020, "gen3": 8030}[self.speed]
            device_id      = device_id_base + self.nlanes

            # Port type / class code (mode-dependent).
            port_type  = "PCI_Express_Endpoint_device"
            class_code = None
            if self.mode == "RootPort":
                port_type  = "Root_Port_of_PCI_Express_Root_Complex"
                class_code = 0x060400

            # BAR0.
            bar0_scale = "Megabytes"
            bar0_size  = max(self.bar0_size/MB, 1)

            # AXI-S / interface.
            axisten_if_width       = f"{self.pcie_data_width}_bit"
            axisten_rc_straddle    = False
            enable_client_tag      = True

            # Power management.
            aspm_support = "No_ASPM"

            # PLL selection.
            plltype = "QPLL1"

            config = {
                # Core.
                "Component_Name"               : "pcie_us",
                "DEVICE_PORT_TYPE"             : port_type,
                "PF0_DEVICE_ID"                : device_id,

                # Link.
                "PL_LINK_CAP_MAX_LINK_WIDTH"   : f"X{self.nlanes}",
                "PL_LINK_CAP_MAX_LINK_SPEED"   : link_speed,

                # AXI-S.
                "axisten_if_width"             : axisten_if_width,
                "AXISTEN_IF_RC_STRADDLE"       : axisten_rc_straddle,
                "axisten_freq"                 : axisten_freq,
                "coreclk_freq"                 : coreclk_freq,
                "axisten_if_enable_client_tag" : enable_client_tag,

                # Power / features.
                "aspm_support"                 : aspm_support,
                "plltype"                      : plltype,

                # BAR0.
                "pf0_bar0_scale"               : bar0_scale,
                "pf0_bar0_size"                : bar0_size,

                # Interrupts.
                "PF0_INTERRUPT_PIN"            : "NONE",
            }

            if class_code is not None:
                config["PF0_CLASS_CODE"] = class_code

            # User/Custom config.
            config.update(self.config)

            # Tcl generation.
            ip_tcl = []
            ip_tcl.append("create_ip -vendor xilinx.com -name pcie3_ultrascale -module_name pcie_us")
            ip_tcl.append("set obj [get_ips pcie_us]")
            ip_tcl.append("set_property -dict [list \\")
            for config, value in config.items():
                ip_tcl.append("CONFIG.{} {} \\".format(config, '{{' + str(value) + '}}'))
            ip_tcl.append(f"] $obj")
            ip_tcl.append("synth_ip $obj")
            platform.toolchain.pre_synthesis_commands += ip_tcl

        verilog_path = os.path.join(os.path.abspath(os.path.dirname(__file__)), "xilinx")

        if self.use_support_wrapper:
            platform.add_source(os.path.join(verilog_path, "pcie_us_support.v"))


    # External Hard IP -----------------------------------------------------------------------------
    def use_external_hard_ip(self, hard_ip_path, hard_ip_filename):
        self.external_hard_ip = True
        self.add_sources(self.platform, hard_ip_path, hard_ip_filename)

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        if not self.external_hard_ip:
            self.add_sources(self.platform)
        if self.use_support_wrapper:
            self.specials += Instance("pcie_support", **self.pcie_phy_params)
        else:
            self.specials += Instance("pcie_us", **self.pcie_us_phy_params)
