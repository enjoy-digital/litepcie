# This file is Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from migen import *

from litepcie.common import *

# constants
fmt_type_dict = {
    "mem_rd32": 0b0000000,
    "mem_wr32": 0b1000000,
    "mem_rd64": 0b0100000,
    "mem_wr64": 0b1100000,

    "cpld":     0b1001010,
    "cpl":      0b0001010
}

cpl_dict = {
    "sc":  0b000,
    "ur":  0b001,
    "crs": 0b010,
    "ca":  0b011
}

max_payload_size = 512
max_request_size = 512

# headers
tlp_common_header_length = 16
tlp_common_header_fields = {
    "fmt":  HeaderField(0*4, 29, 2),
    "type": HeaderField(0*4, 24, 5),
}
tlp_common_header = Header(tlp_common_header_fields,
                           tlp_common_header_length,
                           swap_field_bytes=False)


tlp_request_header_length = 16
tlp_request_header_fields = {
    "fmt":          HeaderField(0*4, 29,  2),
    "type":         HeaderField(0*4, 24,  5),
    "tc":           HeaderField(0*4, 20,  3),
    "td":           HeaderField(0*4, 15,  1),
    "ep":           HeaderField(0*4, 14,  1),
    "attr":         HeaderField(0*4, 12,  2),
    "length":       HeaderField(0*4,  0, 10),

    "requester_id": HeaderField(1*4, 16, 16),
    "tag":          HeaderField(1*4,  8,  8),
    "last_be":      HeaderField(1*4,  4,  4),
    "first_be":     HeaderField(1*4,  0,  4),

    "address":      HeaderField(2*4,  2, 30),
}
tlp_request_header = Header(tlp_request_header_fields,
                            tlp_request_header_length,
                            swap_field_bytes=False)


tlp_completion_header_length = 16
tlp_completion_header_fields = {
    "fmt":           HeaderField(0*4, 29,  2),
    "type":          HeaderField(0*4, 24,  5),
    "tc":            HeaderField(0*4, 20,  3),
    "td":            HeaderField(0*4, 15,  1),
    "ep":            HeaderField(0*4, 14,  1),
    "attr":          HeaderField(0*4, 12,  2),
    "length":        HeaderField(0*4,  0, 10),

    "completer_id":  HeaderField(1*4, 16, 16),
    "status":        HeaderField(1*4, 13,  3),
    "bcm":           HeaderField(1*4, 12,  1),
    "byte_count":    HeaderField(1*4,  0, 12),

    "requester_id":  HeaderField(2*4, 16, 16),
    "tag":           HeaderField(2*4,  8,  8),
    "lower_address": HeaderField(2*4,  0,  7),
}
tlp_completion_header = Header(tlp_completion_header_fields,
                               tlp_completion_header_length,
                               swap_field_bytes=False)

# helpers
def convert_bytes(s, endianness="big"):
    return reverse_bytes(s) if endianness == "big" else s

def convert_bits(s, endianness="big"):
    return reverse_bits(s) if endianness == "big" else s

# layouts
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
