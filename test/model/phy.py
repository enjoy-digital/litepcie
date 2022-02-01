#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import math

from litepcie.common import *
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

# PHY Source model ---------------------------------------------------------------------------------

class PHYSource(Module):
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

class PHY(Module):
    def __init__(self, data_width, id, bar0_size, debug):
        self.data_width = data_width

        self.id = id

        self.bar0_size = bar0_size
        self.bar0_mask = get_bar_mask(bar0_size)

        self.max_request_size = Signal(10, reset=512)
        self.max_payload_size = Signal(8,  reset=128)

        self.submodules.phy_source = PHYSource(data_width)
        self.submodules.phy_sink   = PHYSink(data_width)

        self.source = self.phy_source.source
        self.sink   = self.phy_sink.sink

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
                        dat[n] |= dwords[2*n+i]
                        be[n]  |= 0xF
                    except:
                        pass
            return dat, be

    def send(self, dwords):
        dat, be = self.dwords2packet(dwords)
        packet  = PHYPacket(dat, be)
        self.phy_source.send(packet)

    def send_blocking(self, dwords):
        dat, be = self.dwords2packet(dwords)
        packet  = PHYPacket(dat, be)
        yield from self.phy_source.send_blocking(packet)

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

