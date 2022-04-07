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
        # Request Parameters.
        ("req_id",          16), # Requester ID.
        ("we",               1), # Request type; 0 : Read / 1 : Write.
        ("adr",  address_width), # Request address (In Bytes).
        ("len",             10), # Request length (In Dwords).
        ("tag",              8), # Request tag.

        # Data Stream.
        ("dat", data_width),

        # Internal LitePCIe Routing/Identification.
        ("channel", 8), # Crossbar's channel (Used for internal routing).
        ("user_id", 8), # Packet identification (Used for packet delimitation).
    ]
    return EndpointDescription(layout)

def completion_layout(data_width, address_width=32):
    layout = [
        # Completion Parameters.
        ("req_id",          16), # Requester ID.
        ("cmp_id",          16), # Completion ID.
        ("adr",  address_width), # Completion address (In Bytes).
        ("len",             10), # Completion length (In Dwords).
        ("end",              1), # Completion end (Current packet is the last).
        ("err",              1), # Completion error.
        ("tag",              8), # Completion tag.

        # Data Stream.
        ("dat",     data_width),

        # Internal LitePCIe Routing/Identification.
        ("channel", 8), # Crossbar's channel (Used for internal routing).
        ("user_id", 8)  # Packet identification (Used for packet delimitation).
    ]
    return EndpointDescription(layout)

def msi_layout():
    return [("dat", 8)]

def dma_layout(data_width):
    layout = [("data", data_width)]
    return EndpointDescription(layout)
