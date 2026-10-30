#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2024 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random

from litex.gen import *

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

class Chipset(LiteXModule):
    def __init__(self, phy, root_id, debug=False, with_reordering=False, split_sizes=(64, 128, 256)):
        self.phy             = phy
        self.root_id         = root_id
        self.debug           = debug
        self.with_reordering = with_reordering
        self.split_sizes     = list(split_sizes)

        # # #

        self.rd_data        = []
        self.rd_completion  = None
        self.rd_completions = []
        self.cmp_queue      = [] # Completions to send for the Endpoint's reads.
        self.cpl_queue      = [] # Completions received for the Host's reads.
        self.en             = False

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
        wr.last_be      = 0xf if len(data) > 1 else 0x0
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

    def rd(self, rd_cls, adr, length=1, tc=0, first_be=0xf, last_be=None, attr=0, timeout=None):
        """Read from the Endpoint and wait for the completion(s).

        Works while the generator is running (DMA traffic in flight): completions for the Host's
        reads are dispatched to ``cpl_queue`` by the generator. ``timeout`` (cycles) raises when
        the read is left unanswered, as a hung host would be.
        """
        rd = rd_cls()
        rd.fmt          = 0b00 if isinstance(rd, RD32) else 0b01
        rd.type         = 0b00000
        rd.tc           = tc
        rd.attr         = attr
        rd.length       = length
        rd.first_be     = first_be
        rd.last_be      = (0 if length == 1 else 0xf) if last_be is None else last_be
        rd.address      = (adr << 2)
        rd.requester_id = self.root_id
        dwords = rd.encode_dwords()
        if self.debug:
            print_chipset(">>>>>>>>")
            print_chipset(parse_dwords(dwords))
        yield from self.phy.send_blocking(dwords)
        self.rd_data        = []
        self.rd_completions = []
        cycles = 0
        while True:
            cpld = None
            while cpld is None:
                if len(self.cpl_queue):
                    cpld = self.cpl_queue.pop(0)
                elif not self.en:
                    # Generator not running: receive directly.
                    dwords = self.phy.receive()
                    if dwords is not None:
                        msg = parse_dwords(dwords)
                        if isinstance(msg, (CPLD, CPL)):
                            cpld = msg
                        else:
                            self.host_callback(msg)
                if cpld is None:
                    if (timeout is not None) and (cycles >= timeout):
                        raise RuntimeError(f"Host read @0x{adr << 2:08x} not completed after {timeout} cycles")
                    cycles += 1
                    yield
            self.rd_data += cpld.data
            self.rd_completion = cpld
            self.rd_completions.append(cpld)
            if self.debug:
                print_chipset("<<<<<<<<")
                print_chipset(cpld)
            completion_capacity = 4*len(cpld.data) - (cpld.lower_address & 0x3)
            if cpld.byte_count <= completion_capacity:
                break

    def rd32(self, adr, length=1, tc=0, first_be=0xf, last_be=None, attr=0, timeout=None):
        return self.rd(rd_cls=RD32, adr=adr, length=length, tc=tc, attr=attr,
            first_be=first_be, last_be=last_be, timeout=timeout)

    def rd64(self, adr, length=1, tc=0, first_be=0xf, last_be=None, attr=0, timeout=None):
        return self.rd(rd_cls=RD64, adr=adr, length=length, tc=tc, attr=attr,
            first_be=first_be, last_be=last_be, timeout=timeout)

    def cmp(self, req_id, data, byte_count=None, lower_address=0, tag=0, with_split=False):
        if with_split:
            d = random.choice(self.split_sizes)
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
                    if isinstance(msg, (CPLD, CPL)):
                        # Answer to one of the Host's reads.
                        self.cpl_queue.append(msg)
                    else:
                        self.host_callback(msg)
                self.cmp_callback()
            yield
