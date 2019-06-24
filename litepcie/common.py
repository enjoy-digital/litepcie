# This file is Copyright (c) 2015-2018 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream
from litex.soc.interconnect.stream import *
from litex.soc.interconnect.stream_packet import *

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

def phy_layout(data_width):
    layout = [
        ("dat", data_width),
        ("be",  data_width//8)
    ]
    return EndpointDescription(layout)

def request_layout(data_width):
    layout = [
            ("we",               1),
            ("adr",             32),
            ("len",             10),
            ("req_id",          16),
            ("tag",              8),
            ("dat",     data_width),
            ("channel",          8),  # for routing
            ("user_id",          8)   # for packet identification
    ]
    return EndpointDescription(layout)

def completion_layout(data_width):
    layout = [
            ("adr",             32),
            ("len",             10),
            ("end",              1),
            ("req_id",          16),
            ("cmp_id",          16),
            ("err",              1),
            ("tag",              8),
            ("dat",     data_width),
            ("channel",          8),  # for routing
            ("user_id",          8)   # for packet identification
    ]
    return EndpointDescription(layout)

def msi_layout():
    return [("dat", 8)]


def dma_layout(data_width):
    layout = [("data", data_width)]
    return EndpointDescription(layout)
