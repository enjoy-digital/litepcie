#
# This file is part of LitePCIe-PTM.
#
# Copyright (c) 2023 NetTimeLogic
# Copyright (c) 2019-2023 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.common     import phy_layout
from litepcie.tlp.common import fmt_type_dict

from litepcie.tlp.depacketizer import LitePCIeTLPDepacketizer

# Helpers ------------------------------------------------------------------------------------------

def K(x, y):
    """K code generator ex: K(28, 5) is COM Symbol"""
    return (y << 5) | x

def D(x, y):
    """D code generator"""
    return (y << 5) | x

# Symbols (6.3.5) ----------------------------------------------------------------------------------

class Symbol:
    """Symbol definition with name, 8-bit value and description"""
    def __init__(self, name, value, description=""):
        self.name        = name
        self.value       = value
        self.description = description

SKP =  Symbol("SKP", K(28, 1), "Skip")
SDP =  Symbol("SDP", K(28, 2), "Start Data Packet")
EDB =  Symbol("EDB", K(28, 3), "End Bad")
SUB =  Symbol("SUB", K(28, 4), "Decode Error Substitution")
COM =  Symbol("COM", K(28, 5), "Comma")
RSD =  Symbol("RSD", K(28, 6), "Reserved")
SHP =  Symbol("SHP", K(27, 7), "Start Header Packet")
END =  Symbol("END", K(29, 7), "End")
SLC =  Symbol("SLC", K(30, 7), "Start Link Command")
EPF =  Symbol("EPF", K(23, 7), "End Packet Framing")

symbols = [SKP, SDP, EDB, SUB, COM, RSD, SHP, END, SLC, EPF]

# Endianness Swap ----------------------------------------------------------------------------------

class EndiannessSwap(LiteXModule):
    """Swap the data bytes/ctrl bits of stream"""
    def __init__(self, sink, source):
        assert len(sink.data) == len(source.data)
        assert len(sink.ctrl) == len(source.ctrl)
        self.comb += sink.connect(source, omit={"data", "ctrl"})
        n = len(sink.ctrl)
        for i in range(n):
            self.comb += source.data[8*i:8*(i+1)].eq(sink.data[8*(n-1-i):8*(n-1-i+1)])
            self.comb += source.ctrl[i].eq(sink.ctrl[n-1-i])

# Scrambler Unit (Appendix B) ----------------------------------------------------------------------

@ResetInserter()
@CEInserter()
class ScramblerUnit(Module):
    """Scrambler Unit

    This module generates the scrambled datas for the USB3.0 link (X^16 + X^5 + X^4 + X^3 + 1 polynom).
    """
    def __init__(self, reset=0xffff):
        self.value = Signal(32)

        # # #

        new = Signal(16)
        cur = Signal(16, reset=reset)

        self.comb += [
            new[0].eq(cur[0]  ^ cur[6] ^ cur[8]  ^ cur[10]),
            new[1].eq(cur[1]  ^ cur[7] ^ cur[9]  ^ cur[11]),
            new[2].eq(cur[2]  ^ cur[8] ^ cur[10] ^ cur[12]),
            new[3].eq(cur[3]  ^ cur[6] ^ cur[8]  ^ cur[9]  ^ cur[10] ^ cur[11] ^ cur[13]),
            new[4].eq(cur[4]  ^ cur[6] ^ cur[7]  ^ cur[8]  ^ cur[9]  ^ cur[11] ^ cur[12] ^ cur[14]),
            new[5].eq(cur[5]  ^ cur[6] ^ cur[7]  ^ cur[9]  ^ cur[12] ^ cur[13] ^ cur[15]),
            new[6].eq(cur[0]  ^ cur[6] ^ cur[7]  ^ cur[8]  ^ cur[10] ^ cur[13] ^ cur[14]),
            new[7].eq(cur[1]  ^ cur[7] ^ cur[8]  ^ cur[9]  ^ cur[11] ^ cur[14] ^ cur[15]),
            new[8].eq(cur[0]  ^ cur[2] ^ cur[8]  ^ cur[9]  ^ cur[10] ^ cur[12] ^ cur[15]),
            new[9].eq(cur[1]  ^ cur[3] ^ cur[9]  ^ cur[10] ^ cur[11] ^ cur[13]),
            new[10].eq(cur[0] ^ cur[2] ^ cur[4]  ^ cur[10] ^ cur[11] ^ cur[12] ^ cur[14]),
            new[11].eq(cur[1] ^ cur[3] ^ cur[5]  ^ cur[11] ^ cur[12] ^ cur[13] ^ cur[15]),
            new[12].eq(cur[2] ^ cur[4] ^ cur[6]  ^ cur[12] ^ cur[13] ^ cur[14]),
            new[13].eq(cur[3] ^ cur[5] ^ cur[7]  ^ cur[13] ^ cur[14] ^ cur[15]),
            new[14].eq(cur[4] ^ cur[6] ^ cur[8]  ^ cur[14] ^ cur[15]),
            new[15].eq(cur[5] ^ cur[7] ^ cur[9]  ^ cur[15]),

            self.value[0].eq(cur[15]),
            self.value[1].eq(cur[14]),
            self.value[2].eq(cur[13]),
            self.value[3].eq(cur[12]),
            self.value[4].eq(cur[11]),
            self.value[5].eq(cur[10]),
            self.value[6].eq(cur[9]),
            self.value[7].eq(cur[8]),
            self.value[8].eq(cur[7]),
            self.value[9].eq(cur[6]),
            self.value[10].eq(cur[5]),
            self.value[11].eq(cur[4]  ^ cur[15]),
            self.value[12].eq(cur[3]  ^ cur[14] ^ cur[15]),
            self.value[13].eq(cur[2]  ^ cur[13] ^ cur[14] ^ cur[15]),
            self.value[14].eq(cur[1]  ^ cur[12] ^ cur[13] ^ cur[14]),
            self.value[15].eq(cur[0]  ^ cur[11] ^ cur[12] ^ cur[13]),
            self.value[16].eq(cur[10] ^ cur[11] ^ cur[12] ^ cur[15]),
            self.value[17].eq(cur[9]  ^ cur[10] ^ cur[11] ^ cur[14]),
            self.value[18].eq(cur[8]  ^ cur[9]  ^ cur[10] ^ cur[13]),
            self.value[19].eq(cur[7]  ^ cur[8]  ^ cur[9]  ^ cur[12]),
            self.value[20].eq(cur[6]  ^ cur[7]  ^ cur[8]  ^ cur[11]),
            self.value[21].eq(cur[5]  ^ cur[6]  ^ cur[7]  ^ cur[10]),
            self.value[22].eq(cur[4]  ^ cur[5]  ^ cur[6]  ^ cur[9]  ^ cur[15]),
            self.value[23].eq(cur[3]  ^ cur[4]  ^ cur[5]  ^ cur[8]  ^ cur[14]),
            self.value[24].eq(cur[2]  ^ cur[3]  ^ cur[4]  ^ cur[7]  ^ cur[13] ^ cur[15]),
            self.value[25].eq(cur[1]  ^ cur[2]  ^ cur[3]  ^ cur[6]  ^ cur[12] ^ cur[14]),
            self.value[26].eq(cur[0]  ^ cur[1]  ^ cur[2]  ^ cur[5]  ^ cur[11] ^ cur[13] ^ cur[15]),
            self.value[27].eq(cur[0]  ^ cur[1]  ^ cur[4]  ^ cur[10] ^ cur[12] ^ cur[14]),
            self.value[28].eq(cur[0]  ^ cur[3]  ^ cur[9]  ^ cur[11] ^ cur[13]),
            self.value[29].eq(cur[2]  ^ cur[8]  ^ cur[10] ^ cur[12]),
            self.value[30].eq(cur[1]  ^ cur[7]  ^ cur[9]  ^ cur[11]),
            self.value[31].eq(cur[0]  ^ cur[6]  ^ cur[8]  ^ cur[10]),
        ]
        self.sync += cur.eq(new)

# Scrambler (Appendix B) ---------------------------------------------------------------------------

class Scrambler(Module):
    """Scrambler

    This module scrambles the TX data/ctrl stream. K codes shall not be scrambled.
    """
    def __init__(self, reset=0x7dbd):
        self.enable = Signal(reset=1)
        self.sink   =   sink = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        self.submodules.unit = unit = ScramblerUnit(reset=reset)
        self.comb += unit.ce.eq(sink.valid & sink.ready)
        self.comb += sink.connect(source)
        for i in range(4):
            self.comb += [
                If(~self.enable | sink.ctrl[i], # K codes shall not be scrambled.
                    source.data[8*i:8*(i+1)].eq(sink.data[8*i:8*(i+1)])
                ).Else(
                    source.data[8*i:8*(i+1)].eq(sink.data[8*i:8*(i+1)] ^ unit.value[8*i:8*(i+1)])
                )
            ]

# Raw Descrambler (Scrambler + Auto-Synchronization) (Appendix B) ----------------------------------

class RawDescrambler(Module):
    """Descrambler

    This module descrambles the RX data/ctrl stream. K codes shall not be scrambled. The descrambler
    automatically synchronizes itself to the incoming stream and resets the scrambler unit when COM
    characters are seen.
    """
    def __init__(self, reset=0xffff):
        self.enable = Signal(reset=1)
        self.sink   =   sink = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        scrambler = Scrambler(reset=reset)
        self.submodules += scrambler
        self.comb += scrambler.enable.eq(self.enable)

        # Synchronize on COM
        for i in range(4):
            self.comb += [
                If(sink.valid &
                   sink.ready &
                   (sink.data[8*i:8*(i+1)] == COM.value) &
                   sink.ctrl[i],
                   scrambler.unit.reset.eq(1)
                )
            ]

        # Descramble data
        self.comb += [
            sink.connect(scrambler.sink),
            scrambler.source.connect(source)
        ]

# Raw Word Aligner ---------------------------------------------------------------------------------

class RawWordAligner(LiteXModule):
    """Raw Word Aligner

    Align RX Words by analyzing the location of the COM/K-codes (configurable) in the RX stream.
    """
    def __init__(self):
        self.enable = Signal(reset=1)
        self.sink   = sink   = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        update      = Signal()
        alignment   = Signal(2)
        alignment_d = Signal(2)

        buf = stream.Buffer([("data", 32), ("ctrl", 4)])
        self.submodules += buf
        self.comb += [
            sink.connect(buf.sink),
            source.valid.eq(sink.valid & buf.source.valid),
            buf.source.ready.eq(sink.valid & source.ready),
        ]

        # Alignment detection
        for i in reversed(range(4)):
            self.comb += [
                If(sink.valid & sink.ready,
                    If(sink.ctrl[i] & (sink.data[8*i:8*(i+1)] == COM.value),
                        update.eq(1),
                        alignment.eq(i)
                    )
                )
            ]
        self.sync += [
            If(sink.valid & sink.ready,
                If(self.enable & update,
                    alignment_d.eq(alignment)
                )
            )
        ]

        # Data selection
        data = Cat(buf.source.data, sink.data)
        ctrl = Cat(buf.source.ctrl, sink.ctrl)
        cases = {}
        for i in range(4):
            cases[i] = [
                source.data.eq(data[8*i:]),
                source.ctrl.eq(ctrl[1*i:]),
            ]
        self.comb += Case(alignment_d, cases)

# Raw Datapath -------------------------------------------------------------------------------------

class RawDatapath(LiteXModule):
    """Raw Datapath

    This module realizes the:
    - Data-width adaptation (from transceiver's data-width to 32-bit).
    - Clock domain crossing (from transceiver's RX clock to system clock).
    - Words alignment.

    """
    def __init__(self, clock_domain="sys", phy_dw=16):
        self.sink   = stream.Endpoint([("data", phy_dw), ("ctrl", phy_dw//8)])
        self.source = stream.Endpoint([("data",     32), ("ctrl",         4)])

        # # #

        # Data-width adaptation
        converter = stream.StrideConverter(
            [("data", phy_dw), ("ctrl", phy_dw//8)],
            [("data",     32), ("ctrl",         4)],
            reverse=False)
        converter = stream.BufferizeEndpoints({"sink":   stream.DIR_SINK})(converter)
        converter = ClockDomainsRenamer(clock_domain)(converter)
        self.converter = converter

        # Clock domain crossing
        cdc = stream.AsyncFIFO([("data", 32), ("ctrl", 4)], 8, buffered=True)
        cdc = ClockDomainsRenamer({"write": clock_domain, "read": "sys"})(cdc)
        self.cdc = cdc

        # Words alignment
        word_aligner = RawWordAligner()
        word_aligner = stream.BufferizeEndpoints({"source": stream.DIR_SOURCE})(word_aligner)
        self.word_aligner = word_aligner

        # Flow
        self.submodules += stream.Pipeline(
            self.sink,
            converter,
            cdc,
            word_aligner,
            self.source,
        )

# TLP Aligner --------------------------------------------------------------------------------------

class TLPAligner(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        first        = Signal()
        alignment    = Signal(2)
        sink_ctrl_d  = Signal(4)
        sink_ctrl_dd = Signal(4)
        sink_data_d  = Signal(32)
        sink_data_dd = Signal(32)

        self.comb += sink.ready.eq(1)
        self.sync += [
            If(sink.valid,
                sink_data_d.eq(sink.data),
                sink_data_dd.eq(sink_data_d),
                sink_ctrl_d.eq(sink.ctrl),
                sink_ctrl_dd.eq(sink_ctrl_d)
            )
        ]

        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(sink.valid,
                If(sink.ctrl[0] & (sink.data[0*8:1*8] == 0xfb),
                   NextValue(alignment, 0b00),
                   NextState("RECEIVE-0")
                ),
                If(sink.ctrl[1] & (sink.data[1*8:2*8] == 0xfb),
                   NextValue(alignment, 0b01),
                   NextState("RECEIVE-0")
                ),
                If(sink.ctrl[2] & (sink.data[2*8:3*8] == 0xfb),
                   NextValue(alignment, 0b10),
                   NextState("RECEIVE-0")
                ),
                If(sink.ctrl[3] & (sink.data[3*8:4*8] == 0xfb),
                   NextValue(alignment, 0b11),
                   NextState("RECEIVE-0")
                )
            ),
        )
        fsm.act("RECEIVE-0",
            If(sink.valid,
                NextValue(first, 1),
                NextState("RECEIVE-1")
            )
        )
        fsm.act("RECEIVE-1",
            If(sink.valid,
                source.valid.eq(1),
                NextValue(first, 0),
                Case(alignment, {
                    0b00 : [
                        source.data[8*0:8*1].eq(sink_data_dd[8*3:8*4]),
                        source.data[8*1:8*2].eq(sink_data_d [8*0:8*1]),
                        source.data[8*2:8*3].eq(sink_data_d [8*1:8*2]),
                        source.data[8*3:8*4].eq(sink_data_d [8*2:8*3]),
                        source.ctrl[0].eq(sink_ctrl_dd[3]),
                        source.ctrl[1].eq(sink_ctrl_d [0]),
                        source.ctrl[2].eq(sink_ctrl_d [1]),
                        source.ctrl[3].eq(sink_ctrl_d [2]),
                    ],
                    0b01 : [
                        source.data[8*0:8*1].eq(sink_data_d[8*0:8*1]),
                        source.data[8*1:8*2].eq(sink_data_d[8*1:8*2]),
                        source.data[8*2:8*3].eq(sink_data_d[8*2:8*3]),
                        source.data[8*3:8*4].eq(sink_data_d[8*3:8*4]),
                        source.ctrl[0].eq(sink_ctrl_d[0]),
                        source.ctrl[1].eq(sink_ctrl_d[1]),
                        source.ctrl[2].eq(sink_ctrl_d[2]),
                        source.ctrl[3].eq(sink_ctrl_d[3]),
                    ],
                    0b10 : [
                        source.data[8*0:8*1].eq(sink_data_d[8*1:8*2]),
                        source.data[8*1:8*2].eq(sink_data_d[8*2:8*3]),
                        source.data[8*2:8*3].eq(sink_data_d[8*3:8*4]),
                        source.data[8*3:8*4].eq(sink.data  [8*0:8*1]),
                        source.ctrl[0].eq(sink_ctrl_d[1]),
                        source.ctrl[1].eq(sink_ctrl_d[2]),
                        source.ctrl[2].eq(sink_ctrl_d[3]),
                        source.ctrl[3].eq(sink.ctrl  [0]),
                    ],
                    0b11 : [
                        source.data[8*0:8*1].eq(sink_data_d[8*2:8*3]),
                        source.data[8*1:8*2].eq(sink_data_d[8*3:8*4]),
                        source.data[8*2:8*3].eq(sink.data  [8*0:8*1]),
                        source.data[8*3:8*4].eq(sink.data  [8*1:8*2]),
                        source.ctrl[0].eq(sink_ctrl_d[2]),
                        source.ctrl[1].eq(sink_ctrl_d[3]),
                        source.ctrl[2].eq(sink.ctrl  [0]),
                        source.ctrl[3].eq(sink.ctrl  [1]),
                    ],
                }),
            ),
            If(sink.valid & ~first,
                If(sink_ctrl_dd[0] & (sink_data_dd[0*8:1*8] == 0xfd),
                   source.last.eq(1),
                   NextState("IDLE")
                ),
                If(sink_ctrl_dd[1] & (sink_data_dd[1*8:2*8] == 0xfd),
                   source.last.eq(1),
                   NextState("IDLE")
                ),
                If(sink_ctrl_dd[2] & (sink_data_dd[2*8:3*8] == 0xfd),
                   source.last.eq(1),
                   NextState("IDLE")
                ),
                If(sink_ctrl_dd[3] & (sink_data_dd[3*8:4*8] == 0xfd),
                   source.last.eq(1),
                   NextState("IDLE")
                )
            ),
        )


# TLP Endianness Swap ------------------------------------------------------------------------------

class TLPEndiannessSwap(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint([("data", 32), ("ctrl", 4)])

        # # #

        self.submodules += EndiannessSwap(sink, source)

# TLP Filter/Formater ------------------------------------------------------------------------------

class TLPFilterFormater(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint([("data", 32), ("ctrl", 4)])
        self.source = source = stream.Endpoint(phy_layout(64))

        # # #

        # Signals.
        count = Signal(32)

        # Always accept incoming data.
        self.comb += sink.ready.eq(1)

        # Data-FIFO (For eventual source unavailability absorbtion).
        self.fifo = fifo = stream.SyncFIFO(phy_layout(32), depth=4, buffered=True)

        # Data-Width Converter: 32-bit to 64-bit.
        self.conv = conv = stream.StrideConverter(
            description_from = phy_layout(32),
            description_to   = phy_layout(64),
            reverse          = False
        )
        self.comb += [
            fifo.sink.be.eq(0b1111),
            fifo.source.connect(conv.sink),
            conv.source.connect(self.source),
        ]

        # FSM.
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(sink.valid,
                # PTM Request.
                If(sink.data[24:32] == fmt_type_dict["ptm_req"],
                    fifo.sink.valid.eq(1),
                    fifo.sink.dat.eq(sink.data),
                    NextValue(count, 3 - 1), # 3DWs Header.
                    NextState("RECEIVE")
                # PTM Response.
                ).Elif(sink.data[24:32] == fmt_type_dict["ptm_res"],
                    fifo.sink.valid.eq(1),
                    fifo.sink.dat.eq(sink.data),
                    NextValue(count, 4 - 1), # 4DWs Header.
                    NextState("RECEIVE")
                ).Else(
                    NextState("END")
                )
            )
        )
        fsm.act("RECEIVE",
            If(sink.valid,
                fifo.sink.valid.eq(1),
                fifo.sink.dat.eq(sink.data),
                NextValue(count, count - 1),
                If(count == 0,
                    fifo.sink.last.eq(1),
                    NextState("END")
                ),
                If(sink.last,
                    fifo.sink.last.eq(1),
                    NextState("IDLE")
                )
            )
        )
        fsm.act("END",
            If(sink.valid & sink.last,
                NextState("IDLE")
            )
        )

# PCIe PTM Sniffer ---------------------------------------------------------------------------------

class PCIePTMSniffer(LiteXModule):
    def __init__(self, rx_rst_n, rx_clk, rx_data, rx_ctrl):
        self.source = source = stream.Endpoint([("message_code", 8), ("master_time", 64), ("link_delay", 32)])
        assert len(rx_data) == 16
        assert len(rx_ctrl) == 2

        # # #

        # Clocking.
        self.cd_sniffer = ClockDomain()
        self.comb += self.cd_sniffer.clk.eq(rx_clk)
        self.comb += self.cd_sniffer.rst.eq(~rx_rst_n)

        # Raw Sniffing.
        self.raw_datapath    = ClockDomainsRenamer("sniffer")(RawDatapath(phy_dw=16))
        self.raw_descrambler = ClockDomainsRenamer("sniffer")(RawDescrambler())
        self.comb += [
            self.raw_datapath.sink.valid.eq(1),
            self.raw_datapath.sink.data.eq(rx_data),
            self.raw_datapath.sink.ctrl.eq(rx_ctrl),
            self.raw_datapath.source.connect(self.raw_descrambler.sink),
        ]

        # TLP Sniffing.
        self.tlp_aligner         = ClockDomainsRenamer("sniffer")(TLPAligner())
        self.tlp_endianness_swap = ClockDomainsRenamer("sniffer")(TLPEndiannessSwap())
        self.tlp_filter_formater = ClockDomainsRenamer("sniffer")(TLPFilterFormater())

        self.submodules += stream.Pipeline(
            self.raw_descrambler,
            self.tlp_aligner,
            self.tlp_endianness_swap,
            self.tlp_filter_formater,
        )

        # TLP Depacketizer. FIXME: Direct inject TLPs in LitePCIe through an Arbiter.
        self.tlp_depacketizer = ClockDomainsRenamer("sniffer")(LitePCIeTLPDepacketizer(
            data_width   = 64,
            endianness   = "big",
            address_mask = 0,
            capabilities = ["PTM"],
        ))
        self.comb += self.tlp_filter_formater.source.connect(self.tlp_depacketizer.sink)

        # TLP CDC.
        self.cdc = cdc = stream.ClockDomainCrossing(
            layout  = self.source.description,
            cd_from = "sniffer",
            cd_to   = "sys",
        )
        self.comb += [
            self.tlp_depacketizer.ptm_source.connect(cdc.sink, keep={"valid", "ready", "master_time"}),
            cdc.sink.message_code.eq(self.tlp_depacketizer.ptm_source.message_code),
            cdc.sink.master_time[ 0:32].eq(self.tlp_depacketizer.ptm_source.master_time[32:64]),
            cdc.sink.master_time[32:64].eq(self.tlp_depacketizer.ptm_source.master_time[ 0:32]),
            cdc.sink.link_delay.eq(reverse_bytes(self.tlp_depacketizer.ptm_source.dat[32:64])),
            cdc.source.connect(self.source)
        ]

    def add_sources(self, platform):
        cdir = os.path.abspath(os.path.dirname(__file__))
        platform.add_source(os.path.join(cdir, "sniffer_tap.v"))
