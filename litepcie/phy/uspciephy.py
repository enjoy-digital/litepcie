#
# This file is part of LitePCIe.
#
# Copyright (c) 2020 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os

from migen import *

from litex.soc.interconnect.csr import *

from litepcie.common import *

# AXISRX128BAligner --------------------------------------------------------------------------------

class AXISRX128BAligner(Module):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(phy_layout(128))
        self.source = source = stream.Endpoint(phy_layout(128))
        self.first_dword = Signal(2)

        # # #

        dat_last = Signal(64)
        be_last  = Signal(8)
        self.sync += [
            If(sink.valid & sink.ready,
                dat_last.eq(sink.dat[64:]),
                be_last.eq( sink.be[8:]),
            )
        ]

        self.submodules.fsm = fsm = FSM(reset_state="ALIGNED")
        fsm.act("ALIGNED",
            sink.connect(source, omit={"first"}),
            # If "first" on DWORD2 and "last" on the same cycle, switch to UNALIGNED.
            If(sink.valid & sink.last & sink.first & (self.first_dword == 2),
                source.be[8:].eq(0),
                If(source.ready,
                    NextState("UNALIGNED")
                )
            )
        )
        fsm.act("UNALIGNED",
            sink.connect(source, omit={"first", "dat", "be"}),
            source.dat.eq(Cat(dat_last, sink.dat)),
            source.be.eq( Cat(be_last,  sink.be)),
            # If "last" and not "first" on the same cycle, switch to ALIGNED.
            If(sink.valid & sink.last & ~sink.first,
                source.be[8:].eq(0),
                If(source.ready,
                    NextState("ALIGNED")
                )
            )
        )

# USPCIEPHY ----------------------------------------------------------------------------------------

class USPCIEPHY(Module, AutoCSR):
    def __init__(self, platform, pads, data_width=64, bar0_size=1*MB, cd="sys", pcie_data_width=64):
        # Streams ----------------------------------------------------------------------------------
        self.req_sink   = stream.Endpoint(phy_layout(data_width))
        self.cmp_sink   = stream.Endpoint(phy_layout(data_width))
        self.req_source = stream.Endpoint(phy_layout(data_width))
        self.cmp_source = stream.Endpoint(phy_layout(data_width))
        self.msi        = stream.Endpoint(msi_layout())

        # Registers --------------------------------------------------------------------------------
        self._link_up           = CSRStatus(description="Link Up Status. ``1``: Link is Up.")
        self._msi_enable        = CSRStatus(description="MSI Enable Status. ``1``: MSI is enabled.")
        self._bus_master_enable = CSRStatus(description="Bus Mastering Status. ``1``: Bus Mastering enabled.")
        self._max_request_size  = CSRStatus(16, description="Negiotiated Max Request Size (in bytes).")
        self._max_payload_size  = CSRStatus(16, description="Negiotiated Max Payload Size (in bytes).")

        # Parameters/Locals ------------------------------------------------------------------------
        self.platform         = platform
        self.data_width       = data_width
        self.pcie_data_width  = pcie_data_width

        self.dsn              = Signal(64)
        self.id               = Signal(16)
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)
        self.max_request_size = Signal(16)
        self.max_payload_size = Signal(16)

        self.external_hard_ip = False

        # # #

        self.nlanes = nlanes = len(pads.tx_p)

        assert nlanes          in [1, 2, 4]
        assert data_width      in [64, 128]
        assert pcie_data_width in [64, 128]

        # Clocking ---------------------------------------------------------------------------------
        pcie_refclk = Signal()
        pcie_refclk_gt = Signal()
        self.specials += Instance("IBUFDS_GTE3",
            p_REFCLK_HROW_CK_SEL = 0,
            i_CEB                = 0,
            i_I                  = pads.clk_p,
            i_IB                 = pads.clk_n,
            o_O                  = pcie_refclk_gt,
            o_ODIV2              = pcie_refclk
        )
        platform.add_period_constraint(pads.clk_p, 1e9/100e6)
        self.clock_domains.cd_pcie = ClockDomain()
        pcie_clk_freq = max(250e6, nlanes*62.5e6*64/pcie_data_width)
        platform.add_period_constraint(self.cd_pcie.clk, 1e9/pcie_clk_freq)

        # TX (FPGA --> HOST) CDC / Data Width Convertion -------------------------------------------
        if (cd == "pcie") and (data_width == pcie_data_width):
            s_axis_cc = self.cmp_sink
        else:
            cc_pipe_valid = stream.PipeValid(phy_layout(data_width))
            cc_pipe_valid = ClockDomainsRenamer(cd)(cc_pipe_valid)
            cc_cdc        = stream.AsyncFIFO(phy_layout(data_width), 8)
            cc_cdc        = ClockDomainsRenamer({"write": cd, "read": "pcie"})(cc_cdc)
            cc_converter  = stream.StrideConverter(phy_layout(data_width), phy_layout(pcie_data_width))
            cc_converter  = ClockDomainsRenamer("pcie")(cc_converter)
            cc_pipe_ready = stream.PipeValid(phy_layout(pcie_data_width))
            cc_pipe_ready = ClockDomainsRenamer("pcie")(cc_pipe_ready)
            self.submodules += cc_pipe_valid, cc_cdc, cc_converter, cc_pipe_ready
            self.comb += [
                self.cmp_sink.connect(cc_pipe_valid.sink),
                cc_pipe_valid.source.connect(cc_cdc.sink),
                cc_cdc.source.connect(cc_converter.sink),
                cc_converter.source.connect(cc_pipe_ready.sink)
            ]
            s_axis_cc = cc_pipe_ready.source

        if (cd == "pcie") and (data_width == pcie_data_width):
            s_axis_rq = self.req_sink
        else:
            rq_pipe_valid = stream.PipeValid(phy_layout(data_width))
            rq_pipe_valid = ClockDomainsRenamer(cd)(rq_pipe_valid)
            rq_cdc        = stream.AsyncFIFO(phy_layout(data_width), 4)
            rq_cdc        = ClockDomainsRenamer({"write": cd, "read": "pcie"})(rq_cdc)
            rq_converter  = stream.StrideConverter(phy_layout(data_width), phy_layout(pcie_data_width))
            rq_converter  = ClockDomainsRenamer("pcie")(rq_converter)
            rq_pipe_ready = stream.PipeValid(phy_layout(pcie_data_width))
            rq_pipe_ready = ClockDomainsRenamer("pcie")(rq_pipe_ready)
            self.submodules += rq_pipe_valid, rq_cdc, rq_converter, rq_pipe_ready
            self.comb += [
                self.req_sink.connect(rq_pipe_valid.sink),
                rq_pipe_valid.source.connect(rq_cdc.sink),
                rq_cdc.source.connect(rq_converter.sink),
                rq_converter.source.connect(rq_pipe_ready.sink)
            ]
            s_axis_rq = rq_pipe_ready.source

        # RX (HOST --> FPGA) CDC / Data Width Convertion -------------------------------------------
        if (cd == "pcie") and (data_width == pcie_data_width):
            m_axis_cq = self.req_source
        else:
            cq_pipe_ready = stream.PipeReady(phy_layout(pcie_data_width))
            cq_pipe_ready = ClockDomainsRenamer("pcie")(cq_pipe_ready)
            cq_converter  = stream.StrideConverter(phy_layout(pcie_data_width), phy_layout(data_width))
            cq_converter  = ClockDomainsRenamer("pcie")(cq_converter)
            cq_cdc        = stream.AsyncFIFO(phy_layout(data_width), 8)
            cq_cdc        = ClockDomainsRenamer({"write": "pcie", "read": cd})(cq_cdc)
            cq_pipe_valid = stream.PipeValid(phy_layout(data_width))
            cq_pipe_valid = ClockDomainsRenamer(cd)(cq_pipe_valid)
            self.submodules += cq_pipe_ready, cq_converter, cq_pipe_valid, cq_cdc
            self.comb += [
                cq_pipe_ready.source.connect(cq_converter.sink),
                cq_converter.source.connect(cq_cdc.sink),
                cq_cdc.source.connect(cq_pipe_valid.sink),
                cq_pipe_valid.source.connect(self.req_source),
            ]
            m_axis_cq = cq_pipe_ready.sink
        if pcie_data_width == 128:
            cq_aligner = AXISRX128BAligner()
            cq_aligner = ClockDomainsRenamer("pcie")(cq_aligner)
            self.submodules += cq_aligner
            self.comb += cq_aligner.source.connect(m_axis_cq)
            m_axis_cq = cq_aligner.sink

        if (cd == "pcie") and (data_width == pcie_data_width):
            m_axis_rc = self.cmp_source
        else:
            rc_pipe_ready = stream.PipeReady(phy_layout(pcie_data_width))
            rc_pipe_ready = ClockDomainsRenamer("pcie")(rc_pipe_ready)
            rc_converter  = stream.StrideConverter(phy_layout(pcie_data_width), phy_layout(data_width))
            rc_converter  = ClockDomainsRenamer("pcie")(rc_converter)
            rc_cdc        = stream.AsyncFIFO(phy_layout(data_width), 4)
            rc_cdc        = ClockDomainsRenamer({"write": "pcie", "read": cd})(rc_cdc)
            rc_pipe_valid = stream.PipeValid(phy_layout(data_width))
            rc_pipe_valid = ClockDomainsRenamer(cd)(rc_pipe_valid)
            self.submodules += rc_pipe_ready, rc_converter, rc_pipe_valid, rc_cdc
            self.comb += [
                rc_pipe_ready.source.connect(rc_converter.sink),
                rc_converter.source.connect(rc_cdc.sink),
                rc_cdc.source.connect(rc_pipe_valid.sink),
                rc_pipe_valid.source.connect(self.cmp_source),
            ]
            m_axis_rc = rc_pipe_ready.sink
        if pcie_data_width == 128:
            rc_aligner = AXISRX128BAligner()
            rc_aligner = ClockDomainsRenamer("pcie")(rc_aligner)
            self.submodules += rc_aligner
            self.comb += rc_aligner.source.connect(m_axis_rc)
            m_axis_rc = rc_aligner.sink

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
        def convert_size(command, size, max_size):
            cases = {}
            value = 128
            for i in range(6):
                cases[i] = size.eq(value)
                value = min(value*2, max_size)
            return Case(command, cases)

        link_up         = Signal()
        msi_enable      = Signal()
        serial_number   = Signal(64)
        bus_number      = Signal(8)
        device_number   = Signal(5)
        function_number = Signal(3)

        cfg_function_status  = Signal(16)
        cfg_max_payload_size = Signal(3)
        cfg_max_read_req     = Signal(3)

        self.sync.pcie += [
            convert_size(cfg_max_read_req, self.max_request_size, max_size=512),
            convert_size(cfg_max_payload_size, self.max_payload_size, max_size=512),
            self.id.eq(Cat(function_number, device_number, bus_number))
            #self.dsn.eq(serial_number)
        ]
        self.specials += [
            MultiReg(link_up, self._link_up.status),
            MultiReg(cfg_function_status, self._bus_master_enable.status),
            MultiReg(msi_enable, self._msi_enable.status),
            MultiReg(self.max_request_size, self._max_request_size.status),
            MultiReg(self.max_payload_size, self._max_payload_size.status)
        ]

        self.m_axis_cq = m_axis_cq
        self.s_axis_cc = s_axis_cc
        self.s_axis_rq = s_axis_rq
        self.m_axis_rc = m_axis_rc

        debug  = Signal(8)
        self.debug = debug

        # Hard IP ----------------------------------------------------------------------------------
        class Open(Signal): pass

        s_axis_rq_tuser = Signal(4)
        s_axis_cc_tuser = Signal(4)
        m_axis_rc_tuser = Signal(22)
        m_axis_cq_tuser = Signal(22)

        self.comb += [
            s_axis_rq_tuser.eq(0),    #{Discontinue, Streaming-AXIS, EP(Poisioning), TP(TLP-Digest)}
            s_axis_cc_tuser.eq(0),
            ]

        """ m_axis_*.first & .m_axis_*.last """
        m_axis_rc_tlast = Signal()
        m_axis_cq_tlast = Signal()
        self.comb += [
            m_axis_cq.first.eq(m_axis_cq_tuser[14]),
            m_axis_cq.last.eq (m_axis_cq_tlast),
            m_axis_rc.first.eq(m_axis_rc_tuser[14]),
            m_axis_rc.last.eq (m_axis_rc_tlast),
            ]

        self.pcie_phy_params = dict(
            # Parameters ---------------------------------------------------------------------------
            p_LINK_CAP_MAX_LINK_WIDTH                    = nlanes,
            p_C_DATA_WIDTH                               = pcie_data_width,
            p_KEEP_WIDTH                                 = pcie_data_width//8,
            p_PCIE_GT_DEVICE                             = "GTH",
            p_PCIE_USE_MODE                              = "2.0",

            # PCI Express Interface ----------------------------------------------------------------
            i_sys_clk                                    = pcie_refclk,       #100MHz
            i_sys_clk_gt                                 = pcie_refclk_gt,    #100MHz
            i_sys_rst_n                                  = 1 if not hasattr(pads, "rst_n") else pads.rst_n,

            # TX
            o_pci_exp_txp                                = pads.tx_p,
            o_pci_exp_txn                                = pads.tx_n,
            # RX
            i_pci_exp_rxp                                = pads.rx_p,
            i_pci_exp_rxn                                = pads.rx_n,

            # AXI-S Interface ----------------------------------------------------------------------
            # Common
            o_user_clk_out                               = ClockSignal("pcie"),
            o_user_reset_out                             = ResetSignal("pcie"),
            o_user_lnk_up                                = link_up,
            o_user_app_rdy                               = Open(),

            o_debug                                      = debug,

            # (FPGA -> Host) Requester Request
            o_pcie_tfc_nph_av                            = Open(2),
            o_pcie_tfc_npd_av                            = Open(2),
            o_pcie_rq_tag_av                             = Open(2),
            o_pcie_rq_seq_num                            = Open(4),
            o_pcie_rq_seq_num_vld                        = Open(),
            o_pcie_rq_tag                                = Open(6),
            o_pcie_rq_tag_vld                            = Open(),
            i_s_axis_rq_tvalid                           = s_axis_rq.valid,
            i_s_axis_rq_tlast                            = s_axis_rq.last,
            o_s_axis_rq_tready                           = s_axis_rq.ready,
            i_s_axis_rq_tdata                            = s_axis_rq.dat,
            i_s_axis_rq_tkeep                            = s_axis_rq.be,
            i_s_axis_rq_tuser                            = s_axis_rq_tuser,

            # (Host -> FPGA) Completer Request
            i_pcie_cq_np_req                             = 1,
            o_pcie_cq_np_req_count                       = Open(6),
            o_m_axis_cq_tvalid                           = m_axis_cq.valid,
            o_m_axis_cq_tlast                            = m_axis_cq_tlast,
            i_m_axis_cq_tready                           = m_axis_cq.ready,
            o_m_axis_cq_tdata                            = m_axis_cq.dat,
            o_m_axis_cq_tkeep                            = m_axis_cq.be,
            o_m_axis_cq_tuser                            = m_axis_cq_tuser,

            # (Host -> FPGA) Requester Completion
            o_m_axis_rc_tvalid                           = m_axis_rc.valid,
            o_m_axis_rc_tlast                            = m_axis_rc_tlast,
            i_m_axis_rc_tready                           = m_axis_rc.ready,
            o_m_axis_rc_tdata                            = m_axis_rc.dat,
            o_m_axis_rc_tkeep                            = m_axis_rc.be,
            o_m_axis_rc_tuser                            = m_axis_rc_tuser,

            # (FPGA -> Host) Completer Completion
            i_s_axis_cc_tvalid                           = s_axis_cc.valid,
            i_s_axis_cc_tlast                            = s_axis_cc.last,
            o_s_axis_cc_tready                           = s_axis_cc.ready,
            i_s_axis_cc_tdata                            = s_axis_cc.dat,
            i_s_axis_cc_tkeep                            = s_axis_cc.be,
            i_s_axis_cc_tuser                            = s_axis_cc_tuser,

            # Management Interface -----------------------------------------------------------------
            o_cfg_mgmt_do                                = Open(32),
            o_cfg_mgmt_rd_wr_done                        = Open(),
            i_cfg_mgmt_di                                = 0,
            i_cfg_mgmt_byte_en                           = 0,
            i_cfg_mgmt_dwaddr                            = 0,
            i_cfg_mgmt_wr_en                             = 0,
            i_cfg_mgmt_rd_en                             = 0,

            # Flow Control & Status ----------------------------------------------------------------
            o_cfg_fc_cpld                                = Open(12),
            o_cfg_fc_cplh                                = Open(8),
            o_cfg_fc_npd                                 = Open(12),
            o_cfg_fc_nph                                 = Open(8),
            o_cfg_fc_pd                                  = Open(12),
            o_cfg_fc_ph                                  = Open(8),
            i_cfg_fc_sel                                 = 0,           #PF#0

            # Configuration Tx/Rx Message ----------------------------------------------------------
            o_cfg_msg_received                           = Open(),
            o_cfg_msg_received_data                      = Open(8),
            o_cfg_msg_received_type                      = Open(5),

            i_cfg_msg_transmit                           = 0,
            i_cfg_msg_transmit_data                      = 0,
            i_cfg_msg_transmit_type                      = 0,
            o_cfg_msg_transmit_done                      = Open(),

            # Configuration Control Interface ------------------------------------------------------

            # Hot config
            o_pl_received_hot_rst                        = Open(),
            i_pl_transmit_hot_rst                        = 0,

            # Indentication & Routing
            i_cfg_dsn                                    = serial_number,
            i_cfg_ds_bus_number                          = bus_number,
            i_cfg_ds_device_number                       = device_number,
            i_cfg_ds_function_number                     = function_number,
            i_cfg_ds_port_number                         = 0,
            i_cfg_subsys_vend_id                         = 0x10EE,

            #  power-down request TLP
            i_cfg_power_state_change_ack                 = 0,
            o_cfg_power_state_change_interrupt           = Open(),

            # Interrupt Signals (Legacy & MSI) -----------------------------------------------------

            i_cfg_interrupt_int                          = 0,
            i_cfg_interrupt_pending                      = 0,
            o_cfg_interrupt_sent                         = Open(),

            o_cfg_interrupt_msi_enable                   = msi_enable,  #MSI = TRUE
            i_cfg_interrupt_msi_int_valid                = cfg_msi.valid,
            i_cfg_interrupt_msi_int                      = cfg_msi.dat,
            o_cfg_interrupt_msi_sent                     = cfg_msi.ready,
            o_cfg_interrupt_msi_fail                     = Open(),

            o_cfg_interrupt_msi_mmenable                 = Open(12),
            o_cfg_interrupt_msi_mask_update              = Open(),
            o_cfg_interrupt_msi_data                     = Open(32),
            o_cfg_interrupt_msi_vf_enable                = Open(8),

            # Error Reporting Interface ------------------------------------------------------------

            o_cfg_phy_link_down                          = Open(),
            o_cfg_phy_link_status                        = Open(2),
            o_cfg_negotiated_width                       = Open(4),
            o_cfg_current_speed                          = Open(3),
            o_cfg_max_payload                            = cfg_max_payload_size,
            o_cfg_max_read_req                           = cfg_max_read_req,
            o_cfg_function_status                        = cfg_function_status,
            o_cfg_function_power_state                   = Open(12),
            o_cfg_vf_status                              = Open(16),
            o_cfg_vf_power_state                         = Open(24),
            o_cfg_link_power_state                       = Open(2),

            o_cfg_err_cor_out                            = Open(),
            o_cfg_err_nonfatal_out                       = Open(),
            o_cfg_err_fatal_out                          = Open(),
            o_cfg_ltr_enable                             = Open(),
            o_cfg_ltssm_state                            = Open(6),
            o_cfg_rcb_status                             = Open(4),
            o_cfg_dpa_substate_change                    = Open(4),
            o_cfg_obff_enable                            = Open(2),
            o_cfg_pl_status_change                       = Open(),

            o_cfg_tph_requester_enable                   = Open(4),
            o_cfg_tph_st_mode                            = Open(12),
            o_cfg_vf_tph_requester_enable                = Open(8),
            o_cfg_vf_tph_st_mode                         = Open(24),
        )

    # Hard IP sources ------------------------------------------------------------------------------
    def add_sources(self, platform, phy_path, phy_filename):
        platform.add_ip(os.path.join(phy_path, phy_filename))
        platform.add_source(os.path.join(phy_path, "pcie_us_x{}_support.v".format(self.nlanes)))
        pass

    # External Hard IP -----------------------------------------------------------------------------
    def use_external_hard_ip(self, hard_ip_path, hard_ip_filename):
        self.external_hard_ip = True
        self.add_sources(self.platform, hard_ip_path, hard_ip_filename)
        pass

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        if not self.external_hard_ip:
            phy_path     = "xilinx_us_x{}".format(self.nlanes)
            phy_filename = "pcie_us_x{}.xci".format(self.nlanes)
            self.add_sources(self.platform,
                phy_path     = os.path.join(os.path.abspath(os.path.dirname(__file__)), phy_path),
                phy_filename = "pcie_us_x{}.xci".format(self.nlanes)
            )
        self.specials += Instance("pcie_support", **self.pcie_phy_params)
        pass
