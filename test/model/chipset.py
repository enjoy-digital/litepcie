#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random

from litepcie.common import *
from litepcie.tlp.common import *

from test.model.tlp import *

# Helpers ------------------------------------------------------------------------------------------

def print_chipset(s):
    print("[CHIPSET] {}".format(s))


def find_cmp_tags(queue):
    tags = []
    for tag, dwords in queue:
        if tag not in tags:
            tags.append(tag)
    return tags


def find_first_cmp_msg(queue, msg_tag):
    for i, (tag, dwords) in enumerate(queue):
        if tag == msg_tag:
            return i

# Chipset model ------------------------------------------------------------------------------------

class Chipset(Module):
    def __init__(self, phy, root_id, debug=False, with_reordering=False):
        self.phy     = phy
        self.root_id = root_id
        self.debug   = debug
        self.with_reordering = with_reordering

        # # #

        self.rd_data   = []
        self.cmp_queue = []
        self.en = False

    def set_host_callback(self, callback):
        self.host_callback = callback

    def enable(self):
        self.en = True

    def disable(self):
        self.en = False

    def wr(self, wr_cls, adr, data):
        wr = wr_cls()
        wr.fmt          = 0b10 if isinstance(wr, WR32) else 0b11
        wr.type         = 0b00000
        wr.length       = len(data)
        wr.first_be     = 0xf
        wr.address      = (adr << 2)
        wr.requester_id = self.root_id
        dwords = wr.encode_dwords(data)
        if self.debug:
            print_chipset(">>>>>>>>")
            print_chipset(parse_dwords(dwords))
        yield from self.phy.send_blocking(dwords)

    def wr32(self, adr, data):
        return self.wr(wr_cls=WR32, adr=adr, data=data)

    def wr64(self, adr, data):
        return self.wr(wr_cls=WR64, adr=adr, data=data)

    def rd(self, rd_cls, adr, length=1):
        rd = rd_cls()
        rd.fmt          = 0b00 if isinstance(rd, RD32) else 0b01
        rd.type         = 0b00000
        rd.length       = length
        rd.first_be     = 0xf
        rd.address      = (adr << 2)
        rd.requester_id = self.root_id
        dwords = rd.encode_dwords()
        if self.debug:
            print_chipset(">>>>>>>>")
            print_chipset(parse_dwords(dwords))
        yield from self.phy.send_blocking(dwords)
        dwords = None
        while dwords is None:
            dwords = self.phy.receive()
            yield
        cpld = CPLD(dwords)
        self.rd_data = cpld.data
        if self.debug:
            print_chipset("<<<<<<<<")
            print_chipset(cpld)

    def rd32(self, adr, length=1):
        return self.rd(rd_cls=RD32, adr=adr, length=length)

    def rd64(self, adr, length=1):
        return self.rd(rd_cls=RD64, adr=adr, length=length)

    def cmp(self, req_id, data, byte_count=None, lower_address=0, tag=0, with_split=False):
        if with_split:
            d = random.choice([64, 128, 256])
            n = byte_count//d
            if n == 0:
                self.cmp(req_id, data, byte_count=byte_count, tag=tag)
            else:
                for i in range(n):
                    cmp_data = data[i*byte_count//(4*n):(i+1)*byte_count//(4*n)]
                    self.cmp(req_id, cmp_data,
                        byte_count=byte_count-i*byte_count//n, tag=tag)
        else:
            if len(data) == 0:
                fmt = 0b00
                cpl = CPL()
            else:
                fmt = 0b10
                cpl = CPLD()
            cpl.fmt           = fmt
            cpl.type          = 0b01010
            cpl.length        = len(data)
            cpl.lower_address = lower_address
            cpl.requester_id  = req_id
            cpl.completer_id  = self.root_id
            if byte_count is None:
                cpl.byte_count = len(data)*4
            else:
                cpl.byte_count = byte_count
            cpl.tag = tag
            if len(data) == 0:
                dwords = cpl.encode_dwords()
            else:
                dwords = cpl.encode_dwords(data)
            self.cmp_queue.append((tag, dwords))

    def cmp_callback(self):
        if len(self.cmp_queue):
            if self.with_reordering:
                tags = find_cmp_tags(self.cmp_queue)
                tag  = random.choice(tags)
                n    = find_first_cmp_msg(self.cmp_queue, tag)
                tag, dwords = self.cmp_queue.pop(n)
            else:
                tag, dwords = self.cmp_queue.pop(0)
            if self.debug:
                print_chipset(">>>>>>>>")
                print_chipset(parse_dwords(dwords))
            self.phy.send(dwords)

    @passive
    def generator(self):
        while True:
            if self.en:
                dwords = self.phy.receive()
                if dwords is not None:
                    msg = parse_dwords(dwords)
                    if self.debug:
                        print_chipset("<<<<<<<< (Callback)")
                        print_chipset(msg)
                    self.host_callback(msg)
                self.cmp_callback()
            yield
