import os
from litex.gen import *

from litex.soc.interconnect.csr import *

from litepcie.common import *


class S7PCIEPHY(Module, AutoCSR):
    def __init__(self, platform, data_width=64, link_width=2, bar0_size=1*MB):
        pads = platform.request("pcie_x"+str(link_width))
        self.data_width = data_width
        self.link_width = link_width

        self.sink = stream.Endpoint(phy_layout(data_width))
        self.source = stream.Endpoint(phy_layout(data_width))
        self.interrupt = stream.Endpoint(interrupt_layout())

        self.id = Signal(16)

        self._lnk_up = CSRStatus()
        self._msi_enable = CSRStatus()
        self._bus_master_enable = CSRStatus()
        self._max_request_size = CSRStatus(16)
        self._max_payload_size = CSRStatus(16)
        self.max_request_size = self._max_request_size.status
        self.max_payload_size = self._max_payload_size.status

        self.bar0_size = bar0_size
        self.bar0_mask = get_bar_mask(bar0_size)

        # # #

        clk100 = Signal()
        self.specials += Instance("IBUFDS_GTE2",
                i_CEB=0,
                i_I=pads.clk_p,
                i_IB=pads.clk_n,
                o_O=clk100,
                o_ODIV2=Signal()
        )

        bus_number = Signal(8)
        device_number = Signal(5)
        function_number = Signal(3)
        command = Signal(16)
        dcommand = Signal(16)

        xc7_transceivers = {
            "xc7k": "GTX",
            "xc7a": "GTP"
        }

        self.specials += Instance("pcie_phy",
                p_C_DATA_WIDTH=data_width,
                p_C_PCIE_GT_DEVICE=xc7_transceivers[platform.device[:4]],
                p_C_BAR0=get_bar_mask(self.bar0_size),

                i_sys_clk=clk100,
                i_sys_rst_n=pads.rst_n,

                o_pci_exp_txp=pads.tx_p,
                o_pci_exp_txn=pads.tx_n,

                i_pci_exp_rxp=pads.rx_p,
                i_pci_exp_rxn=pads.rx_n,

                o_user_clk=ClockSignal("clk125"),
                o_user_reset=ResetSignal("clk125"),
                o_user_lnk_up=self._lnk_up.status,

                #o_tx_buf_av=,
                #o_tx_terr_drop=,
                #o_tx_cfg_req=,
                i_tx_cfg_gnt=1,

                i_s_axis_tx_tvalid=self.sink.valid,
                i_s_axis_tx_tlast=self.sink.last,
                o_s_axis_tx_tready=self.sink.ready,
                i_s_axis_tx_tdata=self.sink.dat,
                i_s_axis_tx_tkeep=self.sink.be,
                i_s_axis_tx_tuser=0,

                i_rx_np_ok=1,
                i_rx_np_req=1,

                o_m_axis_rx_tvalid=self.source.valid,
                o_m_axis_rx_tlast=self.source.last,
                i_m_axis_rx_tready=self.source.ready,
                o_m_axis_rx_tdata=self.source.dat,
                o_m_axis_rx_tkeep=self.source.be,
                o_m_axis_rx_tuser=Signal(4),

                #o_cfg_to_turnoff=,
                o_cfg_bus_number=bus_number,
                o_cfg_device_number=device_number,
                o_cfg_function_number=function_number,
                o_cfg_command=command,
                o_cfg_dcommand=dcommand,
                o_cfg_interrupt_msienable=self._msi_enable.status,

                i_cfg_interrupt=self.interrupt.valid,
                o_cfg_interrupt_rdy=self.interrupt.ready,
                i_cfg_interrupt_di=self.interrupt.dat,

                i_SHARED_QPLL_PD=0,
                i_SHARED_QPLL_RST=0,
                i_SHARED_QPLL_REFCLK=0,
                #o_SHARED_QPLL_OUTCLK=,
                #o_SHARED_QPLL_OUTREFCLK=,
                #o_SHARED_QPLL_LOCK=,
        )

        # id
        self.comb += self.id.eq(Cat(function_number, device_number, bus_number))

        # config
        def convert_size(command, size):
            cases = {}
            value = 128
            for i in range(6):
                cases[i] = size.eq(value)
                value = value*2
            return Case(command, cases)

        self.sync += [
            self._bus_master_enable.status.eq(command[2]),
            convert_size(dcommand[12:15], self.max_request_size),
            convert_size(dcommand[5:8], self.max_payload_size)
        ]

        litepcie_phy_path = os.path.abspath(os.path.dirname(__file__))
        platform.add_source_dir(os.path.join(litepcie_phy_path, "xilinx", "7-series", "common"))
        if platform.device[:4] == "xc7k":
            platform.add_source_dir(os.path.join(litepcie_phy_path, "xilinx", "7-series", "kintex7"))
        elif platform.device[:4] == "xc7a":
            platform.add_source_dir(os.path.join(litepcie_phy_path, "xilinx", "7-series", "artix7"))
