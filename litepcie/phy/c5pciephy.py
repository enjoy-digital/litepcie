from migen import *

from litepcie.common import *


class C5PCIEPHY(Module):
    def __init__(self, platform, pads, data_width=64, cd="sys"):
        self.sink = stream.Endpoint(phy_layout(data_width))
        self.source = stream.Endpoint(phy_layout(data_width))
        self.msi = stream.Endpoint(msi_layout())

        # # #

        pcie_clk = Signal()
        pcie_rst_n = Signal(reset=1)

        # pcie clk
        self.specials += Instance("ALT_INBUF_DIFF",
            i_i=pads.clk_p,
            i_ibar=pads.clk_n,
            o_o=pcie_clk)

        # pcie rst
        if hasattr(pads, "rst_n"):
            self.comb += pcie_rst_n.eq(pads.rst_n)

        # pcie tx cdc (fpga --> host)
        if cd == "pcie":
            tx_st = self.sink
        else:
            tx_buffer = stream.Buffer(phy_layout(data_width))
            tx_buffer = ClockDomainsRenamer(cd)(tx_buffer)
            tx_cdc = stream.AsyncFIFO(phy_layout(data_width), 4)
            tx_cdc = ClockDomainsRenamer({"write": cd, "read": "pcie"})(tx_cdc)
            self.submodules += tx_buffer, tx_cdc
            self.comb += [
                self.sink.connect(tx_buffer.sink),
                tx_buffer.source.connect(tx_cdc.sink)
            ]
            tx_st = tx_cdc.source

        # pcie rx cdc (host --> fpga)
        if cd == "pcie":
            rx_st = self.source
        else:
            rx_cdc = stream.AsyncFIFO(phy_layout(data_width), 4)
            rx_cdc = ClockDomainsRenamer({"write": "pcie", "read": cd})(rx_cdc)
            rx_buffer = stream.Buffer(phy_layout(data_width))
            rx_buffer = ClockDomainsRenamer(cd)(rx_buffer)
            self.submodules += rx_buffer, rx_cdc
            self.comb += [
                rx_cdc.source.connect(rx_buffer.sink),
                rx_buffer.source.connect(self.source)
            ]
            rx_st = rx_cdc.sink

        # Altera Cyclone5 PCIe X4 PHY
        self.pcie_phy_params = dict(
            i_config_tl_hpg_ctrler=0,
            #o_config_tl_tl_cfg_ctl=,
            i_config_tl_cpl_err=0,
            #o_config_tl_tl_cfg_add=,
            #o_config_tl_tl_cfg_ctl_wr=,
            #o_config_tl_tl_cfg_sts_wr=,
            #o_config_tl_tl_cfg_sts=,
            i_config_tl_cpl_pending=0,
            #o_coreclkout_hip_clk=,
            i_hip_ctrl_test_in=0,
            i_hip_ctrl_simu_mode_pipe=0,
            i_hip_pipe_sim_pipe_pclk_in=0,
            #o_hip_pipe_sim_pipe_rate=0,
            #o_hip_pipe_sim_ltssmstate=,
            #o_hip_pipe_eidleinfersel0=,
            #o_hip_pipe_eidleinfersel1=,
            #o_hip_pipe_eidleinfersel2=,
            #o_hip_pipe_eidleinfersel3=,
            #o_hip_pipe_powerdown0=,
            #o_hip_pipe_powerdown1=,
            #o_hip_pipe_powerdown2=,
            #o_hip_pipe_powerdown3=,
            #o_hip_pipe_rxpolarity0=,
            #o_hip_pipe_rxpolarity1=,
            #o_hip_pipe_rxpolarity2=,
            #o_hip_pipe_rxpolarity3=,
            #o_hip_pipe_txcompl0=,
            #o_hip_pipe_txcompl1=,
            #o_hip_pipe_txcompl2=,
            #o_hip_pipe_txcompl3=,
            #o_hip_pipe_txdata0=,
            #o_hip_pipe_txdata1=,
            #o_hip_pipe_txdata2=,
            #o_hip_pipe_txdata3=,
            #o_hip_pipe_txdatak0=,
            #o_hip_pipe_txdatak1=,
            #o_hip_pipe_txdatak2=,
            #o_hip_pipe_txdatak3=,
            #o_hip_pipe_txdetectrx0=,
            #o_hip_pipe_txdetectrx1=,
            #o_hip_pipe_txdetectrx2=,
            #o_hip_pipe_txdetectrx3=,
            #o_hip_pipe_txelecidle0=,
            #o_hip_pipe_txelecidle1=,
            #o_hip_pipe_txelecidle2=,
            #o_hip_pipe_txelecidle3=,
            #o_hip_pipe_txswing0=,
            #o_hip_pipe_txswing1=,
            #o_hip_pipe_txswing2=,
            #o_hip_pipe_txswing3=,
            #o_hip_pipe_txmargin0=,
            #o_hip_pipe_txmargin1=,
            #o_hip_pipe_txmargin2=,
            #o_hip_pipe_txmargin3=,
            #o_hip_pipe_txdeemph0=,
            #o_hip_pipe_txdeemph1=,
            #o_hip_pipe_txdeemph2=,
            #o_hip_pipe_txdeemph3=,
            i_hip_pipe_phystatus0=0,
            i_hip_pipe_phystatus1=0,
            i_hip_pipe_phystatus2=0,
            i_hip_pipe_phystatus3=0,
            i_hip_pipe_rxdata0=0,
            i_hip_pipe_rxdata1=0,
            i_hip_pipe_rxdata2=0,
            i_hip_pipe_rxdata3=0,
            i_hip_pipe_rxdatak0=0,
            i_hip_pipe_rxdatak1=0,
            i_hip_pipe_rxdatak2=0,
            i_hip_pipe_rxdatak3=0,
            i_hip_pipe_rxelecidle0=0,
            i_hip_pipe_rxelecidle1=0,
            i_hip_pipe_rxelecidle2=0,
            i_hip_pipe_rxelecidle3=0,
            i_hip_pipe_rxstatus0=0,
            i_hip_pipe_rxstatus1=0,
            i_hip_pipe_rxstatus2=0,
            i_hip_pipe_rxstatus3=0,
            i_hip_pipe_rxvalid0=0,
            i_hip_pipe_rxvalid1=0,
            i_hip_pipe_rxvalid2=0,
            i_hip_pipe_rxvalid3=0,
            #o_hip_rst_reset_status=,
            #o_hip_rst_serdes_pll_locked=,
            #o_hip_rst_pld_clk_inuse=,
            i_hip_rst_pld_core_ready=0,
            #o_hip_rst_testin_zero=,
            i_hip_serial_rx_in0=pads.rx_p[0],
            i_hip_serial_rx_in1=pads.rx_p[1],
            i_hip_serial_rx_in2=pads.rx_p[2],
            i_hip_serial_rx_in3=pads.rx_p[3],
            o_hip_serial_tx_out0=pads.tx_p[0],
            o_hip_serial_tx_out1=pads.tx_p[1],
            o_hip_serial_tx_out2=pads.tx_p[2],
            o_hip_serial_tx_out3=pads.tx_p[3],
            #o_hip_status_derr_cor_ext_rcv=,
            #o_hip_status_derr_cor_ext_rpl=,
            #o_hip_status_derr_rpl=,
            #o_hip_status_dlup_exit=,
            #o_hip_status_ltssmstate=,
            #o_hip_status_ev128ns=,
            #o_hip_status_ev1us=,
            #o_hip_status_hotrst_exit=,
            #o_hip_status_int_status=,
            #o_hip_status_l2_exit=,
            #o_hip_status_lane_act=,
            #o_hip_status_ko_cpl_spc_header=,
            #o_hip_status_ko_cpl_spc_data=,
            i_hip_status_drv_derr_cor_ext_rcv=0,
            i_hip_status_drv_derr_cor_ext_rpl=0,
            i_hip_status_drv_derr_rpl=0,
            i_hip_status_drv_dlup_exit=0,
            i_hip_status_drv_ev128ns=0,
            i_hip_status_drv_ev1us=0,
            i_hip_status_drv_hotrst_exit=0,
            i_hip_status_drv_int_status=0,
            i_hip_status_drv_l2_exit=0,
            i_hip_status_drv_lane_act=0,
            i_hip_status_drv_ltssmstate=0,
            i_hip_status_drv_ko_cpl_spc_header=0,
            i_hip_status_drv_ko_cpl_spc_data=0,
            i_int_msi_app_msi_num=0,
            i_int_msi_app_msi_req=0,
            i_int_msi_app_msi_tc=0,
            #o_int_msi_app_msi_ack=0,
            i_int_msi_app_int_sts=0,
            i_lmi_lmi_addr=0,
            i_lmi_lmi_din=0,
            i_lmi_lmi_rden=0,
            i_lmi_lmi_wren=0,
            #o_lmi_lmi_ack=,
            #o_lmi_lmi_dout=,
            i_npor_npor=pcie_rst_n,
            i_npor_pin_perst=pcie_rst_n,
            i_pld_clk_clk=0,
            i_pld_clk_1_clk=0,
            i_power_mngt_pm_auxpwr=0,
            i_power_mngt_pm_data=0,
            i_power_mngt_pme_to_cr=0,
            i_power_mngt_pm_event=0,
            #o_power_mngt_pme_to_sr=,
            i_reconfig_clk_clk=0,
            i_reconfig_reset_reset_n=pcie_rst_n,
            i_refclk_clk=pcie_clk,
            #o_rx_bar_be_rx_st_bar=,
            i_rx_bar_be_rx_st_mask=0,
            o_rx_st_valid=rx_st.valid,
            o_rx_st_startofpacket=rx_st.first,
            o_rx_st_endofpacket=rx_st.last,
            i_rx_st_ready=rx_st.ready,
            #o_rx_st_error=, # CHECKME: needed?
            o_rx_st_data=rx_st.data,
            #o_tx_cred_tx_cred_datafccp=,
            #o_tx_cred_tx_cred_datafcnp=,
            #o_tx_cred_tx_cred_datafcp=,
            #o_tx_cred_tx_cred_fchipcons=,
            #o_tx_cred_tx_cred_fcinfinite=,
            #o_tx_cred_tx_cred_hdrfccp=,
            #o_tx_cred_tx_cred_hdrfcnp=,
            #o_tx_cred_tx_cred_hdrfcp=,
            #o_tx_fifo_fifo_empty=,
            i_tx_st_valid=tx_st.valid,
            i_tx_st_startofpacket=tx_st.first, # CHECKME: generated by LitePCIe?
            i_tx_st_endofpacket=tx_st.last,
            o_tx_st_ready=tx_st.ready,
            i_tx_st_error=0, # CHECKME: needed?
            i_tx_st_data=tx_st.data
        )

    def do_finalize(self):
        self.specials += Instance("pcie_phy", **self.pcie_phy_params)
