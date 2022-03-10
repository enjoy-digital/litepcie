#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from litepcie.common import *
from litepcie.tlp.common import *


# Helpers/Definitions ------------------------------------------------------------------------------

def get_field_data(field, dwords):
    return (dwords[field.byte//4] >> field.offset) & (2**field.width-1)

tlp_headers_dict = {
    "RD32": tlp_request_header,
    "WR32": tlp_request_header,
    "RD64": tlp_request_header,
    "WR64": tlp_request_header,
    "CPLD": tlp_completion_header,
    "CPL":  tlp_completion_header
}

# TLP Layer model ----------------------------------------------------------------------------------

class TLP:
    def __init__(self, name, dwords, header_dwords=3):
        assert header_dwords in [3, 4]
        self.name   = name
        self.header = dwords[:header_dwords]
        self.data   = dwords[header_dwords:]
        self.dwords = self.header + self.data
        self.header_dwords = header_dwords
        self.decode_dwords()

    def decode_dwords(self):
        for k, v in tlp_headers_dict[self.name].fields.items():
            setattr(self, k, get_field_data(v, self.header))

    def encode_dwords(self, data=[]):
        self.header = [0]*self.header_dwords
        for k, v in tlp_headers_dict[self.name].fields.items():
            field = tlp_headers_dict[self.name].fields[k]
            self.header[field.byte//4] |= (getattr(self, k) << field.offset)
        self.data   = data
        self.dwords = self.header + self.data
        return self.dwords

    def __repr__(self):
        r = self.name + "\n"
        r += "--------\n"
        for k in sorted(tlp_headers_dict[self.name].fields.keys()):
            r += k + " : 0x{:x}".format(getattr(self, k)) + "\n"
        if len(self.data) != 0:
            r += "data:\n"
            for d in self.data:
                r += "{:08x}\n".format(d)
        return r

# RD32 ---------------------------------------------------------------------------------------------

class RD32(TLP):
    def __init__(self, dwords=[0, 0, 0]):
        TLP.__init__(self, "RD32", dwords)

# WR32 ---------------------------------------------------------------------------------------------

class WR32(TLP):
    def __init__(self, dwords=[0, 0, 0]):
        TLP.__init__(self, "WR32", dwords)

# RD64 ---------------------------------------------------------------------------------------------

class RD64(TLP):
    def __init__(self, dwords=[0, 0, 0, 0]):
        _dwords = [d for d in dwords]
        _dwords[2] = dwords[3] # FIXME: Swap Address LSB/MSB.
        _dwords[3] = dwords[2] # FIXME: Swap Address LSB/MSB.
        TLP.__init__(self, "RD64", _dwords, header_dwords=4)

# WR64 ---------------------------------------------------------------------------------------------

class WR64(TLP):
    def __init__(self, dwords=[0, 0, 0, 0]):
        _dwords = [d for d in dwords]
        _dwords[2] = dwords[3] # FIXME: Swap Address LSB/MSB.
        _dwords[3] = dwords[2] # FIXME: Swap Address LSB/MSB.
        TLP.__init__(self, "WR64", _dwords, header_dwords=4)

# CPLD ---------------------------------------------------------------------------------------------

class CPLD(TLP):
    def __init__(self, dwords=[0, 0, 0]):
        TLP.__init__(self, "CPLD", dwords)

# CPL ----------------------------------------------------------------------------------------------

class CPL(TLP):
    def __init__(self, dwords=[0, 0, 0]):
        TLP.__init__(self, "CPL", dwords)

# Unknown ------------------------------------------------------------------------------------------

class Unknown:
    def __repr__(self):
        r = "UNKNOWN\n"
        return r

# --------------------------------------------------------------------------------------------------

fmt_type_dict = {
    fmt_type_dict["mem_rd32"]: (RD32, 3),
    fmt_type_dict["mem_wr32"]: (WR32, 4),
    fmt_type_dict["mem_rd64"]: (RD64, 4),
    fmt_type_dict["mem_wr64"]: (WR64, 5),
    fmt_type_dict["cpld"]:     (CPLD, 4),
    fmt_type_dict["cpl"]:      ( CPL, 3),
}


def parse_dwords(dwords):
    f = get_field_data(tlp_common_header.fields["fmt"], dwords)
    t = get_field_data(tlp_common_header.fields["type"], dwords)
    fmt_type = (f << 5) | t
    try:
        tlp, min_len = fmt_type_dict[fmt_type]
        if len(dwords) >= min_len:
            return tlp(dwords)
        else:
            return Unknown()
    except:
        return Unknown()
