#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from litepcie.common import *
from litepcie.tlp.common import *

from test.model.phy import PHY
from test.model.tlp import *
from test.model.chipset import Chipset

# Helpers ------------------------------------------------------------------------------------------

def print_host(s):
    print("[HOST] {}".format(s))


# Host model ---------------------------------------------------------------------------------------

class Host(Module):
    def __init__(self, data_width, root_id, endpoint_id,
        bar0_size          = 1*MB,
        phy_debug          = False,
        chipset_debug      = False,
        chipset_split      = False,
        chipset_reordering = False,
        host_debug         = False):
        self.debug         = host_debug
        self.chipset_split = chipset_split

        # # #

        self.submodules.phy     = PHY(data_width, endpoint_id, bar0_size, phy_debug)
        self.submodules.chipset = Chipset(self.phy, root_id, chipset_debug, chipset_reordering)
        self.chipset.set_host_callback(self.callback)

        self.rd_queue = []

    def malloc(self, base, length):
        self.base   = base
        self.buffer = [0]*(length//4)

    def write_mem(self, adr, data):
        if self.debug:
            print_host("Writing {} bytes @0x{:08x}".format(len(data)*4, adr))
        current_adr = (adr-self.base)//4
        for i in range(len(data)):
            self.buffer[current_adr+i] = data[i]

    def read_mem(self, adr, length=1):
        if self.debug:
            print_host("Reading {} bytes @0x{:08x}".format(length, adr))
        current_adr = (adr-self.base)//4
        data        = []
        for i in range(length//4):
            data.append(self.buffer[current_adr+i])
        return data

    def callback(self, msg):
        if isinstance(msg, WR32):
            self.write_mem(msg.address, msg.data)
        elif isinstance(msg, RD32):
            self.rd_queue.append(msg)
        elif isinstance(msg, WR64):
            self.write_mem(msg.address, msg.data)
        elif isinstance(msg, RD64):
            self.rd_queue.append(msg)

    @passive
    def generator(self):
        while True:
            if len(self.rd_queue):
                msg     = self.rd_queue.pop(0)
                address = msg.address
                length  = msg.length*4
                data    = self.read_mem(address, length)
                self.chipset.cmp(msg.requester_id, data,
                    byte_count = length,
                    tag        = msg.tag,
                    with_split = self.chipset_split
                )
            yield
