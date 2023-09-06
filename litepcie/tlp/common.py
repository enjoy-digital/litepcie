#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2023 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litepcie.common import *

# Constants ----------------------------------------------------------------------------------------

# Maximum payload size and request size (in bytes).
max_payload_size = 512
max_request_size = 512

# Format (fmt) field of different types of TLPs.
fmt_dict = {
    "mem_rd32" : 0b00, # Memory Read Request  (32-bit).
    "mem_rd64" : 0b01, # Memory Read Request  (64-bit).
    "mem_wr32" : 0b10, # Memory Write Request (32-bit).
    "mem_wr64" : 0b11, # Memory Write Request (64-bit).
    "cpld"     : 0b10, # Completion with Data.
    "cpl"      : 0b00, # Completion without Data.
    "cfg_rd0"  : 0b00, # Configuration Read Request (Type 0).
    "cfg_wr0"  : 0b10, # Configuration Write Request (Type 0).
    "ptm_req"  : 0b01, # PTM Request.
    "ptm_res"  : 0b11, # PTM Response.
}

# Type (type) field of different types of TLPs.
type_dict = {
    "mem_rd32" : 0b00000, # Memory Read Request  (32-bit).
    "mem_rd64" : 0b00000, # Memory Read Request  (64-bit).
    "mem_wr32" : 0b00000, # Memory Write Request (32-bit).
    "mem_wr64" : 0b00000, # Memory Write Request (64-bit).
    "cpld"     : 0b01010, # Completion with Data.
    "cpl"      : 0b01010, # Completion without Data.
    "cfg_rd0"  : 0b00100, # Configuration Read Request (Type 0).
    "cfg_wr0"  : 0b00100, # Configuration Write Request (Type 0).
    "ptm_req"  : 0b10100, # PTM Request.
    "ptm_res"  : 0b10100, # PTM Response.
}

# Format and Type fields for different types of TLPs.
fmt_type_dict = {
    "mem_rd32" : 0b00_00000, # Memory Read Request  (32-bit).
    "mem_rd64" : 0b01_00000, # Memory Read Request  (64-bit).
    "mem_wr32" : 0b10_00000, # Memory Write Request (32-bit).
    "mem_wr64" : 0b11_00000, # Memory Write Request (64-bit).
    "cpld"     : 0b10_01010, # Completion with Data.
    "cpl"      : 0b00_01010, # Completion without Data.
    "cfg_rd0"  : 0b00_00100, # Configuration Read Request (Type 0).
    "cfg_wr0"  : 0b10_00100, # Configuration Write Request (Type 0).
    "ptm_req"  : 0b01_10100, # PTM Request.
    "ptm_res"  : 0b11_10100, # PTM Response.
}

# Completion Status (cpl) field of Completion TLPs.
cpl_dict = {
    "sc"  : 0b000, # Successful Completion.
    "ur"  : 0b001, # Unsupported Request.
    "crs" : 0b010, # Configuration Request Retry Status.
    "ca"  : 0b011, # Completer Abort.
}

# Headers ------------------------------------------------------------------------------------------

# Length of the TLP common header (in bytes).
tlp_common_header_length = 16
# Define TLP common header fields.
tlp_common_header_fields = {
    "fmt"  : HeaderField(byte=0*4, offset=29, width=2), # Format.
    "type" : HeaderField(byte=0*4, offset=24, width=5), # Type.
}
# Define TLP common header
tlp_common_header = Header(
    fields           = tlp_common_header_fields,
    length           = tlp_common_header_length,
    swap_field_bytes = False # No byte swapping required.
)

# Length of the TLP configuration header (in bytes).
tlp_configuration_header_length = 16
# Define TLP request header fields.
tlp_configuration_header_fields = {
    "fmt"          : HeaderField(byte=0*4, offset=29, width= 2), # Format.
    "type"         : HeaderField(byte=0*4, offset=24, width= 5), # Type.
    "td"           : HeaderField(byte=0*4, offset=15, width= 1), # TLP Digest.
    "ep"           : HeaderField(byte=0*4, offset=14, width= 1), # Poisoned TLP.

    "requester_id" : HeaderField(byte=1*4, offset=16, width=16), # Requester ID.
    "tag"          : HeaderField(byte=1*4, offset= 8, width= 8), # Tag.
    "first_be"     : HeaderField(byte=1*4, offset= 0, width= 4), # First Byte Enable.

    "bus_number"   : HeaderField(byte=2*4, offset=24, width= 8), # Bus number.
    "device_no"    : HeaderField(byte=2*4, offset=19, width= 5), # Device number.
    "func"         : HeaderField(byte=2*4, offset=16, width= 3), # Function number.
    "ext_reg"      : HeaderField(byte=2*4, offset= 8, width= 3), # Extended Register.
    "register_no"  : HeaderField(byte=2*4, offset= 2, width= 6), # Register number.
}
# Define TLP configuration header.
tlp_configuration_header = Header(
    fields           = tlp_configuration_header_fields,
    length           = tlp_configuration_header_length,
    swap_field_bytes = False # No byte swapping required.
)

# Length of the TLP request header (in bytes).
tlp_request_header_length = 16
# Define TLP request header fields.
tlp_request_header_fields = {
    "fmt"          : HeaderField(byte=0*4, offset=29, width= 2), # Format.
    "type"         : HeaderField(byte=0*4, offset=24, width= 5), # Type.
    "tc"           : HeaderField(byte=0*4, offset=20, width= 3), # Traffic Class.
    "td"           : HeaderField(byte=0*4, offset=15, width= 1), # TLP Digest.
    "ep"           : HeaderField(byte=0*4, offset=14, width= 1), # Poisoned TLP.
    "attr"         : HeaderField(byte=0*4, offset=12, width= 2), # Attributes.
    "length"       : HeaderField(byte=0*4, offset= 0, width=10), # Length.

    "requester_id" : HeaderField(byte=1*4, offset=16, width=16), # Requester ID.
    "tag"          : HeaderField(byte=1*4, offset= 8, width= 8), # Tag.
    "last_be"      : HeaderField(byte=1*4, offset= 4, width= 4), # Last Byte Enable.
    "first_be"     : HeaderField(byte=1*4, offset= 0, width= 4), # First Byte Enable.

    "address"      : HeaderField(byte=2*4, offset= 0, width=64), # Address.
}
# Define TLP request header.
tlp_request_header = Header(
    fields           = tlp_request_header_fields,
    length           = tlp_request_header_length,
    swap_field_bytes = False # No byte swapping required.
)

# Length of the TLP completion header (in bytes).
tlp_completion_header_length = 16
# Define TLP completion header fields.
tlp_completion_header_fields = {
    "fmt"           : HeaderField(byte=0*4, offset=29, width= 2), # Format.
    "type"          : HeaderField(byte=0*4, offset=24, width= 5), # Type.
    "tc"            : HeaderField(byte=0*4, offset=20, width= 3), # Traffic Class.
    "td"            : HeaderField(byte=0*4, offset=15, width= 1), # TLP Digest.
    "ep"            : HeaderField(byte=0*4, offset=14, width= 1), # Poisoned TLP.
    "attr"          : HeaderField(byte=0*4, offset=12, width= 2), # Attributes.
    "length"        : HeaderField(byte=0*4, offset= 0, width=10), # Length.

    "completer_id"  : HeaderField(byte=1*4, offset=16, width=16), # Completer ID.
    "status"        : HeaderField(byte=1*4, offset=13, width= 3), # Completion Status.
    "bcm"           : HeaderField(byte=1*4, offset=12, width= 1), # Byte Count Mismatch.
    "byte_count"    : HeaderField(byte=1*4, offset= 0, width=12), # Byte Count.

    "requester_id"  : HeaderField(byte=2*4, offset=16, width=16), # Requester ID.
    "tag"           : HeaderField(byte=2*4, offset= 8, width= 8), # Tag.
    "lower_address" : HeaderField(byte=2*4, offset= 0, width= 7), # Lower Address.
}
# Define TLP completion header.
tlp_completion_header = Header(
    fields           = tlp_completion_header_fields,
    length           = tlp_completion_header_length,
    swap_field_bytes = False # No byte swapping required.
)

# Length of the TLP PTM header (in bytes).
tlp_ptm_header_length = 16
# Define TLP request header fields.
tlp_ptm_header_fields = {
    "fmt"          : HeaderField(byte=0*4, offset=29, width= 2), # Format.
    "type"         : HeaderField(byte=0*4, offset=24, width= 5), # Type.
    "tc"           : HeaderField(byte=0*4, offset=20, width= 3), # Traffic Class.
    "ln"           : HeaderField(byte=0*4, offset=17, width= 1), # ?.
    "th"           : HeaderField(byte=0*4, offset=16, width= 1), # ?.
    "td"           : HeaderField(byte=0*4, offset=15, width= 1), # TLP Digest.
    "ep"           : HeaderField(byte=0*4, offset=14, width= 1), # Poisoned TLP.
    "attr"         : HeaderField(byte=0*4, offset=12, width= 2), # Attributes.
    "length"       : HeaderField(byte=0*4, offset= 0, width=10), # Length.

    "requester_id" : HeaderField(byte=1*4, offset=16, width=16), # Requester ID.
    "message_code" : HeaderField(byte=1*4, offset=0,  width= 8), # Message Code.
    "master_time"  : HeaderField(byte=2*4, offset=0,  width=64), # Master Time.
}
# Define TLP PTM header.
tlp_ptm_header = Header(
    fields           = tlp_ptm_header_fields,
    length           = tlp_ptm_header_length,
    swap_field_bytes = False # No byte swapping required.
)

# Helpers ------------------------------------------------------------------------------------------

def dword_endianness_swap(src, dst, data_width, endianness, mode="dat", ndwords=None):
    """
    Perform an endianness swap on Migen signals.

    Parameters:
        src (Signal)           : Source signal.
        dst (Signal)           : Destination signal.
        data_width (int)       : Width of the data (in bits).
        endianness (str)       : Endianness ("little" or "big").
        mode (str, optional)   : Mode of operation ("dat" for data or "be" for Byte Enable). Defaults to "dat".
        ndwords (int, optional): Number of DWORDs. Defaults to data_width//32.

    Returns:
        list: List of assignments after endianness swap.
    """
    # Validate inputs
    assert len(src) == len(dst)
    assert data_width%32 == 0
    assert mode in ["dat", "be"]
    r = []
    # Select number of bits to swap based on the mode.
    nbits       = {"dat":            32, "be":            4}[mode]
    # Default number of dwords to data_width//32 if not provided.
    ndwords     = data_width//32 if ndwords is None else ndwords
    # Select reversing function based on the mode.
    reverse_cls = {"dat": reverse_bytes, "be": reverse_bits}[mode]

    # Iterate through each dword.
    for n in range(ndwords):
        low  = (n + 0)*nbits
        high = (n + 1)*nbits
         # Add swapped dword to result list.
        r += {
            "little" : [dst[low:high].eq(            src[low:high])],  # If little-endian, no need for reversal.
            "big"    : [dst[low:high].eq(reverse_cls(src[low:high]))], # If big-endian, reverse the bytes/bits.
        }[endianness]
    return r

# Layouts ------------------------------------------------------------------------------------------

def tlp_raw_layout(data_width):
    """
    Generate a raw TLP endpoint description.

    Parameters:
        data_width (int): Width of the data (in bits).

    Returns:
        EndpointDescription: Raw TLP endpoint description.
    """
    layout = [
        ("fmt",    2),            # Format field.
        ("header", 4*32),         # Header field.
        ("dat",    data_width),   # Data field.
        ("be",     data_width//8) # Byte Enable field.
    ]
    return EndpointDescription(layout)


def tlp_common_layout(data_width):
    """
    Generate a common TLP endpoint description.

    Parameters:
        data_width (int): Width of the data (in bits).

    Returns:
        EndpointDescription: Common TLP endpoint description.
    """
    layout = tlp_common_header.get_layout() + [
        ("dat", data_width),   # Data field.
        ("be",  data_width//8) # Byte Enable field.
    ]
    return EndpointDescription(layout)


def tlp_configuration_layout(data_width):
    """
    Generate a configuration TLP endpoint description.

    Parameters:
        data_width (int): Width of the data (in bits).

    Returns:
        EndpointDescription: Configuration TLP endpoint description.
    """
    layout = tlp_configuration_header.get_layout() + [
        ("dat", data_width),   # Data field.
        ("be",  data_width//8) # Byte Enable field.
    ]
    return EndpointDescription(layout)


def tlp_request_layout(data_width):
    """
    Generate a request TLP endpoint description.

    Parameters:
        data_width (int): Width of the data (in bits).

    Returns:
        EndpointDescription: Request TLP endpoint description.
    """
    layout = tlp_request_header.get_layout() + [
        ("dat", data_width),   # Data field.
        ("be",  data_width//8) # Byte Enable field.
    ]
    return EndpointDescription(layout)


def tlp_completion_layout(data_width):
    """
    Generate a completion TLP endpoint description.

    Parameters:
        data_width (int): Width of the data (in bits).

    Returns:
        EndpointDescription: Completion TLP endpoint description.
    """
    layout = tlp_completion_header.get_layout() + [
        ("dat", data_width),   # Data field.
        ("be",  data_width//8) # Byte Enable field.
    ]
    return EndpointDescription(layout)

def tlp_ptm_layout(data_width):
    """
    Generate a PTM TLP endpoint description.

    Parameters:
        data_width (int): Width of the data (in bits).

    Returns:
        EndpointDescription: PTM TLP endpoint description.
    """
    layout = tlp_ptm_header.get_layout() + [
        ("dat", data_width),   # Data field.
        ("be",  data_width//8) # Byte Enable field.
    ]
    return EndpointDescription(layout)
