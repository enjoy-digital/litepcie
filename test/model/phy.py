#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2024 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import math

from litex.gen import *

from litepcie.common import *
from litepcie.phy.common import PHYRX128BMarkerDecoder, PHYRXDatapath
from litepcie.tlp.common import *

# Helpers ------------------------------------------------------------------------------------------

def print_phy(s):
    print("[PHY] {}".format(s))

# PHY Packet model ---------------------------------------------------------------------------------

class PHYPacket:
    def __init__(self, dat=[], be=[]):
        self.dat   = dat
        self.be    = be
        self.start = 1
        self.done  = 0

class PHYDwordsPacket:
    def __init__(self, dwords):
        self.dwords = list(dwords)
        self.done   = 0

# PHY Source model ---------------------------------------------------------------------------------

class PHYSource(LiteXModule):
    def __init__(self, data_width):
        self.source = stream.Endpoint(phy_layout(data_width))

        # # #

        self.packets = []
        self.packet  = PHYPacket()
        self.packet.done = 1

    def send(self, packet):
        self.packets.append(packet)

    def send_blocking(self, packet):
        self.send(packet)
        while packet.done == 0:
            yield

    @passive
    def generator(self):
        while True:
            if len(self.packets) and self.packet.done:
                self.packet = self.packets.pop(0)
            if self.packet.start and not self.packet.done:
                yield self.source.valid.eq(1)
                yield self.source.last.eq(len(self.packet.dat) == 1)
                yield self.source.dat.eq(self.packet.dat.pop(0))
                yield self.source.be.eq(self.packet.be.pop(0))
                self.packet.start = 0
            elif ((yield self.source.valid) == 1 and
                  (yield self.source.ready) == 1):
                yield self.source.last.eq(len(self.packet.dat) == 1)
                if len(self.packet.dat) > 0:
                    yield self.source.valid.eq(1)
                    yield self.source.dat.eq(self.packet.dat.pop(0))
                    yield self.source.be.eq(self.packet.be.pop(0))
                else:
                    self.packet.done = 1
                    yield self.source.valid.eq(0)
            yield

# PHY Source model, 7-series 128-bit receive interface ---------------------------------------------

class PHYSourceS7128b(LiteXModule):
    """Present packets like the 128-bit receive interface of the 7-series hard IP.

    Every beat carries 4 DWs with all-ones byte enables; packet boundaries are only given by the
    is_sof/is_eof markers (bit 4: present, bits 3:0: byte offset). A packet starts at DW0 of a new
    beat, or at DW2 of the beat where the previous packet ended in DW0/DW1 when another packet is
    already queued (straddling), as the hard IP does.
    """
    def __init__(self, straddle=True):
        self.source   = stream.Endpoint(phy_layout(128))
        self.is_sof   = Signal(5)
        self.is_eof   = Signal(5)
        self.straddle = straddle

        # # #

        self.packets = []

    def send(self, packet):
        self.packets.append(packet)

    def send_blocking(self, packet):
        self.send(packet)
        while packet.done == 0:
            yield

    @passive
    def generator(self):
        current   = None
        remaining = []
        in_flight = []
        yield self.source.valid.eq(0)
        while True:
            # Hold the beat until it is accepted.
            if (yield self.source.valid) and not (yield self.source.ready):
                yield
                continue
            for packet in in_flight:
                packet.done = 1
            in_flight = []
            if (current is None) and (len(self.packets) == 0):
                yield self.source.valid.eq(0)
                yield
                continue
            dws    = [0, 0, 0, 0]
            is_sof = 0
            is_eof = 0
            pos    = 0
            if current is None:
                current   = self.packets.pop(0)
                remaining = list(current.dwords)
                is_sof    = 0b10000
            while (pos < 4) and (current is not None):
                dws[pos] = remaining.pop(0)
                pos += 1
                if len(remaining) == 0:
                    is_eof = 0b10000 | (4*(pos - 1) + 3)
                    in_flight.append(current)
                    current = None
                    if self.straddle and (pos <= 2) and len(self.packets):
                        current   = self.packets.pop(0)
                        remaining = list(current.dwords)
                        pos       = 2
                        is_sof    = 0b11000
            dat = 0
            for i, dw in enumerate(dws):
                dat |= (dw & 0xffffffff) << (32*i)
            yield self.source.dat.eq(dat)
            yield self.source.be.eq(0xffff)
            yield self.is_sof.eq(is_sof)
            yield self.is_eof.eq(is_eof)
            yield self.source.valid.eq(1)
            yield

# PHY Sink model -----------------------------------------------------------------------------------

class PHYSink(Module):
    def __init__(self, data_width):
        self.sink = stream.Endpoint(phy_layout(data_width))

        # # #

        self.packet = PHYPacket()
        self.first  = True

    def receive(self):
        self.packet.done = 0
        while self.packet.done == 0:
            yield

    @passive
    def generator(self):
        while True:
            self.packet.done = 0
            yield self.sink.ready.eq(1)
            if (yield self.sink.valid) == 1 and self.first:
                self.packet.start = 1
                self.packet.dat = [(yield self.sink.dat)]
                self.packet.be = [(yield self.sink.be)]
                self.first = False
            elif (yield self.sink.valid):
                self.packet.start = 0
                self.packet.dat.append((yield self.sink.dat))
                self.packet.be.append((yield self.sink.be))
            if (yield self.sink.valid) == 1 and (yield self.sink.last) == 1:
                self.packet.done = 1
                self.first = True
            yield

# PHY Layer model ----------------------------------------------------------------------------------

class PHY(LiteXModule):
    """PHY model.

    ``rx_interface`` selects how host packets are presented to the core:
    - ``"exact"``: beats carry exact byte enables and first/last (ideal PHY).
    - ``"s7-128b"``: beats are shaped like the 7-series hard IP 128-bit receive interface (markers,
      all-ones tkeep, straddling) and go through the PHY's marker decoder, aligner and RX datapath.
    """
    def __init__(self, data_width, id, bar0_size, debug, rx_interface="exact"):
        self.data_width   = data_width
        self.rx_interface = rx_interface

        self.id = id

        self.bar0_size = bar0_size
        self.bar0_mask = get_bar_mask(bar0_size)

        self.max_request_size = Signal(10, reset=512)
        self.max_payload_size = Signal(8,  reset=128)

        if rx_interface == "exact":
            self.phy_source = PHYSource(data_width)
            self.source     = self.phy_source.source
        elif rx_interface == "s7-128b":
            assert data_width == 128
            self.phy_source  = PHYSourceS7128b()
            self.rx_markers  = PHYRX128BMarkerDecoder()
            # Single-clock form of the PHY RX datapath (aligner, no clock domain crossing), run in
            # the simulation's sys domain.
            self.rx_datapath = ClockDomainsRenamer({"pcie": "sys"})(
                PHYRXDatapath(data_width, data_width, "pcie", with_aligner=True))
            raw = self.phy_source.source
            self.comb += [
                self.rx_markers.is_sof.eq(self.phy_source.is_sof),
                self.rx_markers.is_eof.eq(self.phy_source.is_eof),
                raw.connect(self.rx_datapath.sink, omit={"first", "last", "be"}),
                self.rx_datapath.sink.first.eq(self.rx_markers.first),
                self.rx_datapath.sink.last.eq( self.rx_markers.last),
                self.rx_datapath.sink.be.eq(   self.rx_markers.be),
                self.rx_datapath.aligner.first_dword.eq(self.rx_markers.first_dword),
            ]
            self.source = self.rx_datapath.source
        else:
            raise ValueError(f"Unknown rx_interface {rx_interface}")
        self.phy_sink = PHYSink(data_width)
        self.sink     = self.phy_sink.sink

    def dwords2packet(self, dwords):
            ratio  = self.data_width//32
            length = math.ceil(len(dwords)/ratio)
            dat    = [0]*length
            be     = [0]*length
            for n in range(length):
                for i in reversed(range(ratio)):
                    dat[n] = dat[n] << 32
                    be[n]  = be[n] << 4
                    try:
                        dat[n] |= dwords[ratio*n+i]
                        be[n]  |= 0xF
                    except:
                        pass
            return dat, be

    def _packet(self, dwords):
        if self.rx_interface == "exact":
            dat, be = self.dwords2packet(dwords)
            return PHYPacket(dat, be)
        return PHYDwordsPacket(dwords)

    def send(self, dwords):
        self.phy_source.send(self._packet(dwords))

    def send_blocking(self, dwords):
        yield from self.phy_source.send_blocking(self._packet(dwords))

    def packet2dwords(self, p_dat, p_be):
            ratio  = self.data_width//32
            dwords = []
            for dat, be in zip(p_dat, p_be):
                for i in range(ratio):
                    dword_be  = (be >> (4*i)) & 0xf
                    dword_dat = (dat >> (32*i)) & 0xffffffff
                    if dword_be == 0xf:
                        dwords.append(dword_dat)
            return dwords

    def receive(self):
        if self.phy_sink.packet.done:
            self.phy_sink.packet.done = 0
            return self.packet2dwords(self.phy_sink.packet.dat, self.phy_sink.packet.be)
        else:
            return None
