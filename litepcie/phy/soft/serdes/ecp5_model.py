#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Dirk Eibach
# SPDX-License-Identifier: BSD-2-Clause

"""Behavioral model of one ECP5 DCU channel (raw 10BSER, PCIE_MODE) for LiteICLink's SerDesECP5, simulation only.

Replaces the DCUA instance and the CLKDIVF dividers (the testbench provides the "tx_full", "rx_full", "tx" and
"rx" clocks, or ``dcu_clk``/``lane_clk``: the DCU clock and the /2 clock). The serial line is a loopback by default:
what the channel transmits is what it receives, after ``bit_offset`` bits (the raw 10BSER bus has no comma
alignment: the symbols arrive at any bit offset) and with the SCI polarity bits applied. ``line_out``/``ei_out`` and
``line_in``/``ei_in`` connect two models. It models only what the adapter relies on (assumptions of the model, not
measured behavior):

- TX PLL lock (PLOL) some cycles after FFC_TRST is released, RX lock (RLOL) after FFC_RRST is released with signal.
- Loss of signal (RLOS): while the transmitter is in Electrical Idle (FFC_EI_EN), or ``force_los``.
- SCI: 64x8 registers, polarity bits (CH register 0x01: bit 0 RX, bit 1 TX).
- PCIe receiver detection (TN1261): FFS_PCIE_DONE goes low a few cycles after FFC_PCIE_CT (with FFC_PCIE_DET_EN
  and the TX in Electrical Idle), high again after ``detect_cycles``, FFS_PCIE_CON = ``present``.
"""

from migen import *

from liteiclink.serdes.serdes_ecp5 import SerDesECP5

class DCUAModel(Module):
    """Behavior of one DCUA channel, driven by the ``params`` (the Instance parameters of SerDesECP5).

    line_out/ei_out and line_in/ei_in (20-bit chunks per DCU clock, Electrical Idle) connect two models, loopback
    when not given. ``corrupt`` flips a bit of the received chunk, ``dcu_clk`` drives the DCU's FF_TX/RX_PCLK."""
    def __init__(self, params, bit_offset=0, tx_lock_cycles=64, rx_lock_cycles=32, detect_cycles=30,
        present=None, force_los=None, line_out=None, line_in=None, ei_out=None, ei_in=None, corrupt=None,
        dcu_clk=None):
        self.present    = present   if present   is not None else Signal(reset=1) # i: receiver present for the detection.
        self.force_los  = force_los if force_los is not None else Signal()        # i: force the loss of signal.
        self.detections = Signal(8)                                               # o: receiver detections started.

        # # #

        p   = lambda name: params[name]
        tx_chunk = Cat(*[p("i_CHX_FF_TX_D_%d" % n) for n in list(range(10)) + list(range(12, 22))])
        ei       = params["i_CHX_FFC_EI_EN"]

        # SCI ------------------------------------------------------------------------------------------
        sci_addr  = Cat(*[p("i_D_SCIADDR%d"  % n) for n in range(6)])
        sci_wdata = Cat(*[p("i_D_SCIWDATA%d" % n) for n in range(8)])
        regs      = Array(Signal(8) for _ in range(64))
        self.regs = regs
        self.sync += If(~p("i_D_SCIWSTN") & p("i_CHX_SCISEL"), regs[sci_addr].eq(sci_wdata))
        for n in range(8):
            self.comb += p("o_D_SCIRDATA%d" % n).eq(regs[sci_addr][n])
        rx_pol = regs[0x01][0]
        tx_pol = regs[0x01][1]

        # Line: TX chunk (20 bits per DCU clock) -> RX chunk, at bit_offset ---------------------------------
        line   = Signal(20)
        self.line = line # Line chunk (20 bits per DCU clock), for testbenches.
        self.sync.tx_full += line.eq(Mux(ei, 0, Mux(tx_pol, ~tx_chunk, tx_chunk)))
        ei_tx  = Signal()
        self.sync.tx_full += ei_tx.eq(ei)
        if line_out is not None:
            self.comb += [line_out.eq(line), ei_out.eq(ei_tx)]
        line_rx = line_in if line_in is not None else line # Loopback by default.
        ei_rx   = ei_in   if ei_in   is not None else ei_tx
        prev    = Signal(20)
        window  = Signal(40)
        self.sync.rx_full += prev.eq(line_rx)
        self.comb += window.eq(Cat(prev, line_rx))
        rx_chunk = Signal(20)
        rx_bits  = window[bit_offset:bit_offset + 20]
        rx_value = Mux(rx_pol, ~rx_bits, rx_bits)
        if corrupt is not None:
            rx_value = rx_value ^ (corrupt << 7)
        self.comb += rx_chunk.eq(rx_value)
        for i, n in enumerate(list(range(10)) + list(range(12, 22))):
            self.comb += p("o_CHX_FF_RX_D_%d" % n).eq(rx_chunk[i])
        for n in [10, 11, 22, 23]:
            self.comb += p("o_CHX_FF_RX_D_%d" % n).eq(0)

        # Loss of signal / lock ----------------------------------------------------------------------------
        los = Signal(reset=1)
        self.sync.rx_full += los.eq(ei_rx | self.force_los)
        self.comb += p("o_CHX_FFS_RLOS").eq(los)

        rx_count = Signal(max=rx_lock_cycles + 1)
        self.sync.rx_full += If(p("i_CHX_FFC_RRST") | los,
            rx_count.eq(0)
        ).Elif(rx_count != rx_lock_cycles,
            rx_count.eq(rx_count + 1)
        )
        self.comb += p("o_CHX_FFS_RLOL").eq(rx_count != rx_lock_cycles)

        tx_count = Signal(max=tx_lock_cycles + 1)
        self.sync.tx_full += If(p("i_D_FFC_TRST"),
            tx_count.eq(0)
        ).Elif(tx_count != tx_lock_cycles,
            tx_count.eq(tx_count + 1)
        )
        self.comb += p("o_D_FFS_PLOL").eq(tx_count != tx_lock_cycles)
        self.comb += p("o_CHX_FFS_LS_SYNC_STATUS").eq(1)

        # Receiver detection -----------------------------------------------------------------------------------
        done  = Signal(reset=1)
        con   = Signal()
        count = Signal(8)
        ct_d  = Signal()
        self.sync.tx_full += [
            ct_d.eq(p("i_CHX_FFC_PCIE_CT")),
            If(p("i_CHX_FFC_PCIE_CT") & ~ct_d & p("i_CHX_FFC_PCIE_DET_EN") & ei,
                done.eq(0),
                count.eq(detect_cycles),
                self.detections.eq(self.detections + 1),
            ).Elif(~done,
                If(count == 0,
                    con.eq(self.present),
                    done.eq(1),
                ).Else(
                    count.eq(count - 1)
                )
            )
        ]
        self.comb += [
            p("o_CHX_FFS_PCIE_DONE").eq(done),
            p("o_CHX_FFS_PCIE_CON").eq(con),
        ]
        if dcu_clk is not None:
            self.comb += [p("o_CHX_FF_TX_PCLK").eq(dcu_clk), p("o_CHX_FF_RX_PCLK").eq(dcu_clk)]
        # Outputs not modeled.
        for name in ["o_CHX_HDOUTP", "o_CHX_HDOUTN"]:
            if name in params:
                self.comb += params[name].eq(0)

class SerDesECP5Model(SerDesECP5):
    """SerDesECP5 with the DCU replaced by DCUAModel (``model_kwargs``: DCUAModel's arguments plus ``lane_clk``, the
    clock of the "tx"/"rx" domains, that the CLKDIVF dividers generate in the real DCU)."""
    def __init__(self, *args, model_kwargs=None, **kwargs):
        SerDesECP5.__init__(self, *args, **kwargs)
        self.model_kwargs = dict(model_kwargs or {})
        # The model replaces the real CLKDIVF dividers: remove them from the specials collected by SerDesECP5.
        specials = self._fragment.specials
        for special in list(specials):
            if getattr(special, "of", None) == "CLKDIVF":
                specials.discard(special)

    def do_finalize(self):
        kwargs   = dict(self.model_kwargs)
        lane_clk = kwargs.pop("lane_clk", None)
        if lane_clk is not None:
            self.comb += [self.cd_tx.clk.eq(lane_clk), self.cd_rx.clk.eq(lane_clk)]
        self.submodules.dcu_model = DCUAModel(self.serdes_params, **kwargs)
