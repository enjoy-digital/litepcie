#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from litex.gen import *

from litepcie.tlp.common import cpl_dict, fmt_dict, type_dict
from litepcie.tlp.depacketizer import LitePCIeTLPDepacketizer

from test.model.tlp import CPL


def _pack_dwords(dwords):
    value = 0
    for n, dword in enumerate(dwords):
        value |= (dword & 0xffffffff) << (32*n)
    return value


class TestTLPDepacketizer(unittest.TestCase):
    def test_error_completion_is_terminal(self):
        dut = LitePCIeTLPDepacketizer(
            data_width   = 128,
            endianness   = "little",
            capabilities = ["COMPLETION"],
        )

        cpl = CPL()
        cpl.fmt           = fmt_dict["cpl"]
        cpl.type          = type_dict["cpl"]
        cpl.length        = 0
        cpl.completer_id  = 0x0100
        cpl.status        = cpl_dict["ca"]
        cpl.bcm           = 0
        cpl.byte_count    = 4
        cpl.requester_id  = 0x0400
        cpl.tag           = 0x5a
        cpl.lower_address = 0
        dwords = cpl.encode_dwords() + [0]

        observed = []

        @passive
        def monitor():
            source = dut.cmp_source
            while len(observed) < 1:
                yield source.ready.eq(1)
                if (yield source.valid) and (yield source.ready):
                    observed.append({
                        "err":    (yield source.err),
                        "status": (yield source.status),
                        "end":    (yield source.end),
                        "tag":    (yield source.tag),
                    })
                yield

        def stim():
            sink = dut.sink
            yield
            while True:
                yield sink.valid.eq(1)
                yield sink.first.eq(1)
                yield sink.last.eq(1)
                yield sink.dat.eq(_pack_dwords(dwords))
                yield sink.be.eq((1 << (128//8)) - 1)
                yield
                if (yield sink.ready):
                    break
            yield sink.valid.eq(0)
            yield sink.first.eq(0)
            yield sink.last.eq(0)
            for _ in range(16):
                yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)

        self.assertEqual(observed, [{
            "err":    1,
            "status": cpl_dict["ca"],
            "end":    1,
            "tag":    0x5a,
        }])
