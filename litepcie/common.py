#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2018 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream
from litex.soc.interconnect.stream import *
from litex.soc.interconnect.packet import *

# Constants/Helpers --------------------------------------------------------------------------------

KB = 1024
MB = 1024*KB
GB = 1024*MB

def get_bar_mask(size):
    mask = 0
    found = 0
    for i in range(32):
        if size%2:
            found = 1
        if found:
            mask |= (1 << i)
        size = size >> 1
    return mask

# Layouts ------------------------------------------------------------------------------------------

def phy_layout(data_width):
    layout = [
        ("dat", data_width),
        ("be",  data_width//8)
    ]
    return EndpointDescription(layout)

def request_layout(data_width, address_width=32):
    layout = [
        ("we",               1),
        ("adr",  address_width),
        ("len",             10),
        ("req_id",          16),
        ("tag",              8),
        ("dat",     data_width),
        ("channel",          8), # For routing.
        ("user_id",          8)  # For packet identification.
    ]
    return EndpointDescription(layout)

def completion_layout(data_width, address_width=32):
    layout = [
        ("adr",  address_width),
        ("len",             10),
        ("end",              1),
        ("req_id",          16),
        ("cmp_id",          16),
        ("err",              1),
        ("tag",              8),
        ("dat",     data_width),
        ("channel",          8), # For routing.
        ("user_id",          8)  # For packet identification.
    ]
    return EndpointDescription(layout)

def msi_layout():
    return [("dat", 8)]

def dma_layout(data_width):
    layout = [("data", data_width)]
    return EndpointDescription(layout)
