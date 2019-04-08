import os

from migen import *
from migen.genlib.cdc import MultiReg
from migen.genlib.misc import WaitTimer
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.soc.interconnect.csr import *

from litepcie.common import *


class C5PCIEPHY(Module, AutoCSR):
    def __init__(self, platform, pads, data_width=64, bar0_size=1*MB, cd="sys"):
        self.sink = stream.Endpoint(phy_layout(data_width))
        self.source = stream.Endpoint(phy_layout(data_width))
        self.msi = stream.Endpoint(msi_layout())

        self._lnk_up = CSRStatus()
        self._msi_enable = CSRStatus()
        self._bus_master_enable = CSRStatus()
        self._max_request_size = CSRStatus(16)
        self._max_payload_size = CSRStatus(16)


        self.data_width = data_width

        self.id = Signal(16)
        self.bar0_size = bar0_size
        self.bar0_mask = get_bar_mask(bar0_size)
        self.max_request_size = Signal(16)
        self.max_payload_size = Signal(16)


        # # #

        pcie_clk = Signal()
        pcie_rst_n = Signal(reset=1)
        pcie_refclk = Signal()
        pcie_reconfig_clk = Signal()
        pcie_coreclkout_hip_clk = Signal()
        pcie_pld_clk_clk = Signal()
        pcie_pld_clk_1_clk = Signal()

        pcie_config_tl_tl_cfg_add = Signal(4)
        pcie_o_config_tl_tl_cfg_ctl = Signal(32)
        pcie_hip_status_derr_cor_ext_rcv = Signal()
        pcie_hip_status_derr_cor_ext_rpl = Signal()
        pcie_hip_status_derr_rpl = Signal()
        pcie_hip_status_dlup_exit = Signal()
        pcie_hip_status_ltssmstate = Signal(5)
        pcie_hip_status_ev128ns = Signal()
        pcie_hip_status_ev1us = Signal()
        pcie_hip_status_hotrst_exit = Signal()
        pcie_hip_status_int_status = Signal(4)
        pcie_hip_status_l2_exit = Signal()
        pcie_hip_status_lane_act = Signal(4)
        pcie_hip_status_ko_cpl_spc_header = Signal(8)
        pcie_hip_status_ko_cpl_spc_data = Signal(12)
        pcie_hip_rst_serdes_pll_locked = Signal()
        pcie_o_power_mngt_pme_to_sr = Signal()




        # pcie clk
        self.specials += Instance("ALT_INBUF_DIFF",
            i_i=pads.clk_p,
            i_ibar=pads.clk_n,
            o_o=pcie_refclk)

        self.clock_domains.cd_pcie = ClockDomain()
        self.clock_domains.cd_pcie_reset_less = ClockDomain(reset_less=False)

        self.comb += [
            self.cd_pcie.clk.eq(pcie_clk),
            self.cd_pcie_reset_less.clk.eq(pcie_clk)
        ]

        # pcie reconfig
        if hasattr(pads, "CLK100_FPGA"):
            self.comb += pcie_reconfig_clk.eq(pads.CLK100_FPGA)

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

        # msi cdc (fpga --> host)
        if cd == "pcie":
            cfg_msi = self.msi
        else:
            msi_cdc = stream.AsyncFIFO(msi_layout(), 4)
            msi_cdc = ClockDomainsRenamer({"write": cd, "read": "pcie"})(msi_cdc)
            self.submodules += msi_cdc
            self.comb += self.msi.connect(msi_cdc.sink)
            cfg_msi = msi_cdc.source

        # config
        def convert_size(command, size):
            cases = {}
            value = 128
            for i in range(6):
                cases[i] = size.eq(value)
                value = value*2
            return Case(command, cases)

        lnk_up = Signal()
        msienable = Signal()
        bus_number = Signal(8)
        device_number = Signal(5)
        function_number = Signal(3)
        command = Signal(16)
        dcommand = Signal(16)

        tl_cfg_add_reg_lsb = Signal()
        tl_cfg_add_reg2_lsb = Signal()
        cfgctl_addr_change = Signal()
        cfgctl_addr_change2 = Signal()
        cfgctl_addr_strobe = Signal()
        captured_cfg_addr_reg = Signal(4)
        captured_cfg_data_reg = Signal(32)

        self.sync.pcie += [
            convert_size(dcommand[12:15], self.max_request_size),
            convert_size(dcommand[5:8], self.max_payload_size),
            self.id.eq(Cat(function_number, device_number, bus_number))
        ]
        self.specials += [
            MultiReg(lnk_up, self._lnk_up.status),
            MultiReg(command[2], self._bus_master_enable.status),
            MultiReg(msienable, self._msi_enable.status),
            MultiReg(self.max_request_size, self._max_request_size.status),
            MultiReg(self.max_payload_size, self._max_payload_size.status)
        ]

        # Did not find same signals in altera
        # Assigning master_bus_enable to 1
        self.comb += command.eq(1)

        # Capture link UP state L0
        self.sync.pcie += [
            If(pcie_hip_status_ltssmstate == 15,
               lnk_up.eq(1)
               ).Elif(pcie_hip_status_dlup_exit == 1,
                      lnk_up.eq(0)
                      )
        ]

        # To capture configuration space Register
        #  register LSB bit of tl_cfg_add
        self.sync.pcie += [
            tl_cfg_add_reg_lsb.eq(pcie_config_tl_tl_cfg_add[0]),
            tl_cfg_add_reg2_lsb.eq(tl_cfg_add_reg_lsb)
        ]
        # detect the address change to generate a strobe to sample the input 32-bit data
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
        # Get MSI enable from cfg_msicsr
        self.sync.pcie += [
            If((cfgctl_addr_strobe == 1) & (captured_cfg_addr_reg == 13),
                msienable.eq(captured_cfg_data_reg[0])
               )
        ]

        # tl_cfg_add[6:4] should represent function number whose information is
        # being presented on tl_cfg_ctl, but only one function is enabled on IP core
        # in this case function_number is always 0
        self.comb += function_number.eq(0)

        litepcie_phy_path = os.path.abspath(os.path.dirname(__file__))
        platform.add_source(os.path.join(litepcie_phy_path, "altera", "cyclone_v", "pcie_phy", "synthesis", "pcie_phy.qip"), "QIP")

        # Altera Cyclone5 PCIe X4 PHY
        self.pcie_phy_params = dict(
            # Config (Configuration space)
            i_config_tl_hpg_ctrler=0,
            o_config_tl_tl_cfg_ctl=pcie_o_config_tl_tl_cfg_ctl,
            i_config_tl_cpl_err=0,
            o_config_tl_tl_cfg_add= pcie_config_tl_tl_cfg_add,
            #o_config_tl_tl_cfg_ctl_wr=,
            #o_config_tl_tl_cfg_sts_wr=,
            #o_config_tl_tl_cfg_sts=,
            i_config_tl_cpl_pending=0,
            o_coreclkout_hip_clk=pcie_clk,
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
            o_hip_rst_serdes_pll_locked=pcie_hip_rst_serdes_pll_locked,
            #o_hip_rst_pld_clk_inuse=,
            i_hip_rst_pld_core_ready=pcie_hip_rst_serdes_pll_locked,
            #o_hip_rst_testin_zero=,
            i_hip_serial_rx_in0=pads.rx_p[0],
            i_hip_serial_rx_in1=pads.rx_p[1],
            i_hip_serial_rx_in2=pads.rx_p[2],
            i_hip_serial_rx_in3=pads.rx_p[3],
            o_hip_serial_tx_out0=pads.tx_p[0],
            o_hip_serial_tx_out1=pads.tx_p[1],
            o_hip_serial_tx_out2=pads.tx_p[2],
            o_hip_serial_tx_out3=pads.tx_p[3],
            o_hip_status_derr_cor_ext_rcv=pcie_hip_status_derr_cor_ext_rcv,
            o_hip_status_derr_cor_ext_rpl=pcie_hip_status_derr_cor_ext_rpl,
            o_hip_status_derr_rpl=pcie_hip_status_derr_rpl,
            o_hip_status_dlup_exit=pcie_hip_status_dlup_exit,
            o_hip_status_ltssmstate=pcie_hip_status_ltssmstate,
            o_hip_status_ev128ns=pcie_hip_status_ev128ns,
            o_hip_status_ev1us=pcie_hip_status_ev1us,
            o_hip_status_hotrst_exit=pcie_hip_status_hotrst_exit,
            o_hip_status_int_status=pcie_hip_status_int_status,
            o_hip_status_l2_exit=pcie_hip_status_l2_exit,
            o_hip_status_lane_act=pcie_hip_status_lane_act,
            o_hip_status_ko_cpl_spc_header=pcie_hip_status_ko_cpl_spc_header,
            o_hip_status_ko_cpl_spc_data=pcie_hip_status_ko_cpl_spc_data,
            i_hip_status_drv_derr_cor_ext_rcv=pcie_hip_status_derr_cor_ext_rcv,
            i_hip_status_drv_derr_cor_ext_rpl=pcie_hip_status_derr_cor_ext_rpl,
            i_hip_status_drv_derr_rpl=pcie_hip_status_derr_rpl,
            i_hip_status_drv_dlup_exit=pcie_hip_status_dlup_exit,
            i_hip_status_drv_ev128ns=pcie_hip_status_ev128ns,
            i_hip_status_drv_ev1us=pcie_hip_status_ev1us,
            i_hip_status_drv_hotrst_exit=pcie_hip_status_hotrst_exit,
            i_hip_status_drv_int_status=pcie_hip_status_int_status,
            i_hip_status_drv_l2_exit=pcie_hip_status_l2_exit,
            i_hip_status_drv_lane_act=pcie_hip_status_lane_act,
            i_hip_status_drv_ltssmstate=pcie_hip_status_ltssmstate,
            i_hip_status_drv_ko_cpl_spc_header=pcie_hip_status_ko_cpl_spc_header,
            i_hip_status_drv_ko_cpl_spc_data=pcie_hip_status_ko_cpl_spc_data,
            i_int_msi_app_msi_num=0,
            i_int_msi_app_msi_req=cfg_msi.valid,
            i_int_msi_app_msi_tc=0,
            o_int_msi_app_msi_ack=cfg_msi.ready,
            i_int_msi_app_int_sts=cfg_msi.dat,
            i_lmi_lmi_addr=0,
            i_lmi_lmi_din=0,
            i_lmi_lmi_rden=0,
            i_lmi_lmi_wren=0,
            #o_lmi_lmi_ack=,
            #o_lmi_lmi_dout=,
            i_npor_npor=pcie_rst_n,
            i_npor_pin_perst=pcie_rst_n,
            i_pld_clk_clk=pcie_clk,
            i_pld_clk_1_clk=pcie_clk,
            i_power_mngt_pm_auxpwr=0,
            i_power_mngt_pm_data=0,
            i_power_mngt_pme_to_cr=pcie_o_power_mngt_pme_to_sr,
            i_power_mngt_pm_event=0,
            o_power_mngt_pme_to_sr=pcie_o_power_mngt_pme_to_sr,
            i_reconfig_clk_clk=pcie_reconfig_clk,
            i_reconfig_reset_reset_n=pcie_rst_n,
            i_refclk_clk=pcie_refclk,
            #o_rx_bar_be_rx_st_bar=,
            i_rx_bar_be_rx_st_mask=0,
            o_rx_st_valid=rx_st.valid,
            o_rx_st_startofpacket=rx_st.first,
            o_rx_st_endofpacket=rx_st.last,
            i_rx_st_ready=rx_st.ready,
            #o_rx_st_error=, # CHECKME: needed?
            o_rx_st_data=rx_st.dat,
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
            i_tx_st_data=tx_st.dat,
        )


    def do_finalize(self):
        self.specials += Instance("pcie_phy", **self.pcie_phy_params)
