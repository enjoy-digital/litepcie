#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Dirk Eibach
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY lane transceiver for the Lattice ECP5 (Gen1, x1): one DCU channel (LiteICLink SerDesECP5).

The DCU runs in raw 10BSER mode with PCIE_MODE set: the 8b/10b is in the fabric (SerDesECP5, 40-bit
words on the CLKDIVF /2 of the DCU clocks, 62.5 MHz at 2.5 GT/s), the lane datapaths are the soft PHY's.

Clocks: the host's 100 MHz reference clock enters the DCU's EXTREFB and feeds the DCU TX PLL. "pcie_pipe"
is the DCU's lane clock (TX clock /2) and a fabric PLL fed by the DCU's TX clock (125 MHz) generates
"pcie_link", so both are derived from the host's reference clock (common clock architecture), as on the
Xilinx transceivers. (The EXTREFB output can't be routed to a fabric PLL input by nextpnr: tried first.)
"pcie_link" is held in reset while the DCU TX PLL isn't running.
"sys" is independent (local oscillator), the Soft PHY crosses between them.

Receiver detection follows Lattice TN1261: with the transmitter in Electrical Idle, the TX driver is put in
detection mode (FFC_PCIE_DET_EN) at least 120ns before a 4 cycles strobe (FFC_PCIE_CT); FFS_PCIE_DONE
goes low, then high when finished, and FFS_PCIE_CON tells if a receiver is connected (sequence documented
by whitequark's Yumewatari, 0BSD).
"""

from migen import *
from migen.genlib.cdc import MultiReg, PulseSynchronizer
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.gen import *

from litex.soc.cores.clock import ECP5PLL
from litex.soc.interconnect.csr import *

from litepcie.phy.soft.datapath    import RXErrorSubstitution
from litepcie.phy.soft.serdes.base import PCIeSerDes

# ECP5 Receiver Detection --------------------------------------------------------------------------

class ECP5PCIeDetect(LiteXModule):
    """DCU receiver detection sequencer, in the DCU's TX clock domain (``cd``, ``clk_freq``).

    ``request`` (pulse) starts a detection (TX must be in Electrical Idle), ``done`` pulses at the end
    with ``connected`` valid (and stable until the next request). A detection that doesn't finish
    within ``timeout`` seconds is aborted, reporting no receiver."""
    def __init__(self, clk_freq, lead_time=130e-9, strobe_cycles=4, timeout=250e-6):
        self.request   = Signal() # i (pulse)
        self.done      = Signal() # o (pulse)
        self.connected = Signal() # o
        self.det_en    = Signal() # o: FFC_PCIE_DET_EN.
        self.ct        = Signal() # o: FFC_PCIE_CT.
        self.dcu_done  = Signal() # i: FFS_PCIE_DONE (asynchronous).
        self.dcu_con   = Signal() # i: FFS_PCIE_CON  (asynchronous).
        # Bring-up counters (wrap at 256): detections requested, completed by the DCU handshake, aborted on timeout.
        self.n_requests = Signal(8)
        self.n_done     = Signal(8)
        self.n_timeouts = Signal(8)

        # # #

        lead_cycles    = max(int(lead_time*clk_freq + 0.999), 2)
        timeout_cycles = int(timeout*clk_freq)

        dcu_done = Signal(reset=1)
        dcu_con  = Signal()
        self.specials += [
            MultiReg(self.dcu_done, dcu_done, reset=1),
            MultiReg(self.dcu_con,  dcu_con),
        ]

        count   = Signal(max=max(lead_cycles, timeout_cycles, strobe_cycles) + 1)
        timeout = Signal(max=timeout_cycles + 1)
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            NextValue(count, lead_cycles - 1),
            NextValue(timeout, timeout_cycles),
            If(self.request,
                NextValue(self.n_requests, self.n_requests + 1),
                NextState("DETECT-MODE")
            )
        )
        fsm.act("DETECT-MODE", # TX driver in detection mode, then wait.
            self.det_en.eq(1),
            If(count == 0,
                NextValue(count, strobe_cycles - 1),
                NextState("STROBE")
            ).Else(
                NextValue(count, count - 1)
            )
        )
        fsm.act("STROBE",
            self.det_en.eq(1),
            self.ct.eq(1),
            If(count == 0,
                NextState("WAIT-DONE-LOW")
            ).Else(
                NextValue(count, count - 1)
            )
        )
        # The DCU drives done low asynchronously after the strobe (a few samples may still read high).
        fsm.act("WAIT-DONE-LOW",
            self.det_en.eq(1),
            If(~dcu_done,
                NextState("WAIT-DONE-HIGH")
            ).Elif(timeout == 0,
                NextState("FAIL")
            ).Else(
                NextValue(timeout, timeout - 1)
            )
        )
        fsm.act("WAIT-DONE-HIGH",
            self.det_en.eq(1),
            If(dcu_done,
                NextValue(self.connected, dcu_con),
                NextValue(self.n_done, self.n_done + 1),
                NextState("FINISH")
            ).Elif(timeout == 0,
                NextState("FAIL")
            ).Else(
                NextValue(timeout, timeout - 1)
            )
        )
        fsm.act("FAIL",
            NextValue(self.connected, 0),
            NextValue(self.n_timeouts, self.n_timeouts + 1),
            NextState("FINISH")
        )
        fsm.act("FINISH",
            self.done.eq(1),
            NextState("IDLE")
        )

# ECP5 PCIe Clocking -------------------------------------------------------------------------------

class ECP5PCIeClocking(LiteXModule):
    """"pcie_link" from a clock derived from the host's reference clock (``clk``, ``clk_freq``: the DCU TX
    clock), reset while the PLL isn't locked."""
    def __init__(self, clk, clk_freq, link_freq=125e6):
        self.cd_pcie_link = ClockDomain()
        self.locked       = Signal()

        # # #

        self.pll = pll = ECP5PLL()
        pll.register_clkin(clk, clk_freq)
        pll.create_clkout(self.cd_pcie_link, link_freq, with_reset=False)
        self.specials += AsyncResetSynchronizer(self.cd_pcie_link, ~pll.locked)
        self.comb += self.locked.eq(pll.locked)

# ECP5 PCIe SerDes ---------------------------------------------------------------------------------

class ECP5PCIeSerDes(PCIeSerDes, AutoCSR):
    """ECP5 (LFE5UM) Gen1 x1 PCIeSerDes: ``pads`` has clk_p/clk_n (reference clock), tx_p/tx_n,
    rx_p/rx_n and perst (or rst_n), as the boards' ``pcie_x1`` resource (the DCU pins are fixed).

    tx_idle_delay: lane clock cycles the TX Electrical Idle request is delayed (both edges) so that it reaches the
    line with the data: the EIOS is still in the TX pipeline (lane datapath, 8b/10b, gearbox, DCU) when the LTSSM
    asserts tx_elecidle, and FFC_EI_EN is a direct input (the Xilinx transceivers do this with
    TX_EIDLE_ASSERT_DELAY). 2 from the simulation (data takes 4 lane cycles to the line, the idle input 2), to be
    tuned on hardware through the ``tx_idle_delay`` CSR (the DCU's own pipeline is not modeled).

    analog: DCU analog/PLL/CDR/driver attributes, see LiteICLink's SerDesECP5 ``pcie_analog``: "wizard" (Lattice's
    PCI Express wizard values as in Yumewatari) or "default" (LiteICLink's 10BSER ones)."""
    def __init__(self, platform, pads, link_freq=125e6, refclk_freq=100e6, skp_interval=None, dual=0, channel=0,
        sys_clk_freq=None, serdes_cls=None, refclk=None, with_clocking=True, tx_idle_delay=2, analog="wizard"):
        # serdes_cls/refclk/with_clocking: for simulations (DCU model, clocks from the testbench).
        from liteiclink.serdes.serdes_ecp5 import SerDesECP5PLL, SerDesECP5
        serdes_cls = serdes_cls or SerDesECP5

        PCIeSerDes.__init__(self, 1)
        self.platform = platform
        self.pads     = pads
        self.perst    = Signal() # o ("sys"): PERST# asserted.

        # # #

        lane = self.lanes[0]

        # PERST# -----------------------------------------------------------------------------------
        rst_n = pads.rst_n if hasattr(pads, "rst_n") else pads.perst
        self.specials += MultiReg(~rst_n, self.perst)

        # Reference clock, DCU PLL and fabric clock ------------------------------------------------
        self.refclk = refclk = refclk if refclk is not None else Signal()
        if with_clocking:
            self.specials.extref = Instance("EXTREFB",
                i_REFCLKP     = pads.clk_p,
                i_REFCLKN     = pads.clk_n,
                o_REFCLKO     = refclk,
                p_REFCK_PWDNB = "0b1",
                p_REFCK_RTERM = "0b1", # 100 Ohm.
            )
            self.extref.attr.add(("LOC", "EXTREF{}".format(dual)))
        self.pll = pll = SerDesECP5PLL(refclk, refclk_freq=refclk_freq, linerate=2.5e9)
        self.dcu_clk_freq = dcu_clk_freq = pll.config["linerate"]/20 # DCU TX/RX clocks (gearbox side).

        # DCU channel ------------------------------------------------------------------------------
        tx_pads = Record([("p", 1), ("n", 1)])
        rx_pads = Record([("p", 1), ("n", 1)])
        self.comb += [
            pads.tx_p.eq(tx_pads.p),
            pads.tx_n.eq(tx_pads.n),
            rx_pads.p.eq(pads.rx_p),
            rx_pads.n.eq(pads.rx_n),
        ]
        tx_polarity = Signal() # "sys" (SCI reconfiguration).
        rx_polarity = Signal()
        rx_cd = "pcie_rx0" # Recovered clock.
        self.gt = gt = serdes_cls(pll, tx_pads, rx_pads,
            dual        = dual,
            channel     = channel,
            data_width  = 40,
            tx_polarity = tx_polarity,
            rx_polarity = rx_polarity,
            with_oob    = True,
            pcie        = True,
            pcie_analog = analog,
        )
        gt.add_stream_endpoints()
        # DCU TX clock /2 is the lane clock ("pcie_pipe").
        domains = {"tx": "pcie_pipe", "rx": rx_cd, "tx_full": "pcie_tx_full", "rx_full": "pcie_rx_full"}
        gt = ClockDomainsRenamer(domains)(gt)
        self.submodules += gt
        if with_clocking:
            self.clocking = ECP5PCIeClocking(gt.txoutclk, dcu_clk_freq, link_freq)
        self.specials += [
            MultiReg(lane.tx_polarity, tx_polarity, "sys"),
            MultiReg(lane.rx_polarity, rx_polarity, "sys"),
        ]

        # Controls / status -------------------------------------------------------------------------
        rx_reset = Signal()
        self.specials += MultiReg(lane.rx_reset, rx_reset, "sys")
        self.comb += [
            gt.tx_enable.eq(~self.perst),
            gt.rx_enable.eq(~self.perst & ~rx_reset),
            gt.loopback.eq(self.loopback != 0),
        ]
        # TX Electrical Idle aligned with the data (see tx_idle_delay).
        self._tx_idle_delay = CSRStorage(4, reset=tx_idle_delay,
            description="TX Electrical Idle delay (lane clock cycles) to align it with the transmitted EIOS.")
        idle_delay = Signal(4)
        self.specials += MultiReg(self._tx_idle_delay.storage, idle_delay, "pcie_pipe")
        idle_sr = Signal(15)
        self.sync.pcie_pipe += idle_sr.eq(Cat(lane.tx_elecidle, idle_sr[:-1]))
        self.comb += gt.tx_idle.eq(Mux(idle_delay == 0, lane.tx_elecidle, Array(idle_sr)[idle_delay - 1]))
        # Ready: TX only. The DCU init FSM (OOB variant) clears rx_ready whenever the receiver loses its signal
        # (partner in Electrical Idle) and relocks by itself when it comes back; the soft PHY's LTSSM is
        # disabled while not ready, so it must not follow the RX signal (the host's TS1 are what we wait for).
        self.specials += MultiReg(gt.tx_ready, lane.ready, "pcie_pipe")
        self.specials += MultiReg(gt.tx_ready, self.ready, "pcie_link")
        self.rx_ready = Signal() # o ("sys"): DCU receiver locked (status).
        self.comb += self.rx_ready.eq(gt.rx_ready)

        # DCU status for bring-up ("sys"): PLL/CDR lock, loss of signal and the init FSM state, coded as the
        # position in init_states.
        init_states = ["RESET-ALL", "WAIT-TX-PLL-LOCK", "RESET-TX-PCS", "WAIT-RX-SIGNAL", "RESET-RX-CDR",
            "WAIT-RX-CDR-LOCK", "RESET-RX-PCS", "READY"]
        self._dcu_status = CSRStatus(fields=[
            CSRField("tx_lol",     size=1, offset=0, description="DCU TX PLL loss of lock (0: locked)."),
            CSRField("rx_lol",     size=1, offset=1, description="DCU receiver CDR loss of lock."),
            CSRField("rx_los",     size=1, offset=2, description="DCU receiver loss of signal."),
            CSRField("tx_ready",   size=1, offset=3, description="DCU transmitter initialized."),
            CSRField("rx_ready",   size=1, offset=4, description="DCU receiver initialized."),
            CSRField("init_state", size=3, offset=5, description="DCU init FSM state (0 RESET-ALL ... 7 READY).",
                values=[(f"``0b{code:03b}``", name) for code, name in enumerate(init_states)]),
        ])
        init_state = Signal(3)
        for code, name in enumerate(init_states):
            self.comb += If(gt.init.fsm.ongoing(name), init_state.eq(code))
        self.comb += [
            self._dcu_status.fields.tx_lol.eq(gt.init.tx_lol),
            self._dcu_status.fields.rx_lol.eq(gt.init.rx_lol),
            self._dcu_status.fields.rx_los.eq(gt.init.rx_los),
            self._dcu_status.fields.tx_ready.eq(gt.tx_ready),
            self._dcu_status.fields.rx_ready.eq(gt.rx_ready),
            self._dcu_status.fields.init_state.eq(init_state),
        ]

        # Datapaths ---------------------------------------------------------------------------------
        err = ClockDomainsRenamer(rx_cd)(RXErrorSubstitution(gt.decoders, clock_domain=rx_cd))
        self.submodules += err
        self.comb += gt.source.connect(err.sink)
        self.add_lane_datapaths(lane, gt.sink, err.source, rx_cd=rx_cd, skp_interval=skp_interval)
        self.add_rx_errors(lane, err.error, rx_cd)
        self.add_rx_elecidle_filter(lane, gt.rx_los) # Raw DCU loss of signal (filter resynchronizes).

        # Receiver detection (DCU TX clock domain "pcie_tx_full", 125 MHz) ---------------------------
        self.detect = detect = ClockDomainsRenamer("pcie_tx_full")(ECP5PCIeDetect(clk_freq=dcu_clk_freq))
        request = PulseSynchronizer("pcie_pipe", "pcie_tx_full")
        done    = PulseSynchronizer("pcie_tx_full", "pcie_pipe")
        self.submodules += request, done
        self.comb += [
            request.i.eq(lane.tx_detect_rx),
            detect.request.eq(request.o),
            done.i.eq(detect.done),
            lane.detect_done.eq(done.o),
            gt.pcie_det_en.eq(detect.det_en),
            gt.pcie_ct.eq(detect.ct),
            detect.dcu_done.eq(gt.pcie_done),
            detect.dcu_con.eq(gt.pcie_con),
        ]
        self.specials += MultiReg(detect.connected, lane.rx_detected, "pcie_pipe")
        # Detection counters for bring-up ("sys", sampled as they change: debug precision).
        self._detect_status = CSRStatus(fields=[
            CSRField("requests",  size=8, offset=0,  description="Receiver detections requested by the LTSSM."),
            CSRField("done",      size=8, offset=8,  description="Detections completed by the DCU handshake."),
            CSRField("timeouts",  size=8, offset=16, description="Detections aborted by the timeout."),
            CSRField("connected", size=1, offset=24, description="Result of the last detection (1: receiver present)."),
        ])
        self.specials += [
            MultiReg(detect.n_requests, self._detect_status.fields.requests),
            MultiReg(detect.n_done,     self._detect_status.fields.done),
            MultiReg(detect.n_timeouts, self._detect_status.fields.timeouts),
            MultiReg(detect.connected,  self._detect_status.fields.connected),
        ]

        # 2.5 GT/s only.
        self.comb += self.rate_done.eq(1)

    def add_timing_constraints(self, sys_clk):
        platform = self.platform
        if not hasattr(self, "clocking"):
            return
        gt       = self.gt
        platform.add_period_constraint(gt.txoutclk, 1e9/self.dcu_clk_freq) # DCU clocks (gearbox side).
        platform.add_period_constraint(gt.rxoutclk, 1e9/self.dcu_clk_freq)
        platform.add_false_path_constraints(sys_clk, self.clocking.cd_pcie_link.clk, gt.cd_tx.clk, gt.cd_rx.clk)
