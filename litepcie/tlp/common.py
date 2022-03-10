#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litepcie.common import *

# Constants ----------------------------------------------------------------------------------------

max_payload_size = 512
max_request_size = 512

fmt_type_dict = {
    "mem_rd32": 0b0000000,
    "mem_wr32": 0b1000000,
    "mem_rd64": 0b0100000,
    "mem_wr64": 0b1100000,

    "cpld":     0b1001010,
    "cpl":      0b0001010,
}

cpl_dict = {
    "sc":  0b000,
    "ur":  0b001,
    "crs": 0b010,
    "ca":  0b011,
}

# Headers ------------------------------------------------------------------------------------------

tlp_common_header_length = 16
tlp_common_header_fields = {
    "fmt":  HeaderField(byte=0*4, offset=29, width=2),
    "type": HeaderField(byte=0*4, offset=24, width=5),
}
tlp_common_header = Header(
    fields           = tlp_common_header_fields,
    length           = tlp_common_header_length,
    swap_field_bytes = False
)

tlp_request_header_length = 16
tlp_request_header_fields = {
    "fmt":          HeaderField(byte=0*4, offset=29, width= 2),
    "type":         HeaderField(byte=0*4, offset=24, width= 5),
    "tc":           HeaderField(byte=0*4, offset=20, width= 3),
    "td":           HeaderField(byte=0*4, offset=15, width= 1),
    "ep":           HeaderField(byte=0*4, offset=14, width= 1),
    "attr":         HeaderField(byte=0*4, offset=12, width= 2),
    "length":       HeaderField(byte=0*4, offset= 0, width=10),

    "requester_id": HeaderField(byte=1*4, offset=16, width=16),
    "tag":          HeaderField(byte=1*4, offset= 8, width= 8),
    "last_be":      HeaderField(byte=1*4, offset= 4, width= 4),
    "first_be":     HeaderField(byte=1*4, offset= 0, width= 4),

    "address":      HeaderField(byte=2*4, offset= 0, width=64),
}
tlp_request_header = Header(
    fields           = tlp_request_header_fields,
    length           = tlp_request_header_length,
    swap_field_bytes = False
)

tlp_completion_header_length = 16
tlp_completion_header_fields = {
    "fmt":           HeaderField(byte=0*4, offset=29, width= 2),
    "type":          HeaderField(byte=0*4, offset=24, width= 5),
    "tc":            HeaderField(byte=0*4, offset=20, width= 3),
    "td":            HeaderField(byte=0*4, offset=15, width= 1),
    "ep":            HeaderField(byte=0*4, offset=14, width= 1),
    "attr":          HeaderField(byte=0*4, offset=12, width= 2),
    "length":        HeaderField(byte=0*4, offset= 0, width=10),

    "completer_id":  HeaderField(byte=1*4, offset=16, width=16),
    "status":        HeaderField(byte=1*4, offset=13, width= 3),
    "bcm":           HeaderField(byte=1*4, offset=12, width= 1),
    "byte_count":    HeaderField(byte=1*4, offset= 0, width=12),

    "requester_id":  HeaderField(byte=2*4, offset=16, width=16),
    "tag":           HeaderField(byte=2*4, offset= 8, width= 8),
    "lower_address": HeaderField(byte=2*4, offset= 0, width= 7),
}
tlp_completion_header = Header(
    fields           = tlp_completion_header_fields,
    length           = tlp_completion_header_length,
    swap_field_bytes = False
)

# Helpers ------------------------------------------------------------------------------------------

def dword_endianness_swap(src, dst, data_width, endianness, mode="dat", ndwords=None):
    assert len(src) == len(dst)
    assert data_width%32 == 0
    assert mode in ["dat", "be"]
    r = []
    nbits       = {"dat":            32, "be":            4}[mode]
    ndwords     = data_width//32 if ndwords is None else ndwords
    reverse_cls = {"dat": reverse_bytes, "be": reverse_bits}[mode]
    for n in range(ndwords):
        low  = (n + 0)*nbits
        high = (n + 1)*nbits
        r += {
            "little" : [dst[low:high].eq(            src[low:high])],
            "big"    : [dst[low:high].eq(reverse_cls(src[low:high]))],
        }[endianness]
    return r

# Layouts ------------------------------------------------------------------------------------------

def tlp_raw_layout(data_width):
    layout = [
        ("header", 4*32),
        ("dat",    data_width),
        ("be",     data_width//8)
    ]
    return EndpointDescription(layout)


def tlp_common_layout(data_width):
    layout = tlp_common_header.get_layout() + [
        ("dat", data_width),
        ("be",  data_width//8)
    ]
    return EndpointDescription(layout)


def tlp_request_layout(data_width):
    layout = tlp_request_header.get_layout() + [
        ("dat", data_width),
        ("be",  data_width//8)
    ]
    return EndpointDescription(layout)


def tlp_completion_layout(data_width):
    layout = tlp_completion_header.get_layout() + [
        ("dat", data_width),
        ("be",  data_width//8)
    ]
    return EndpointDescription(layout)
