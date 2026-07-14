#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import math
import unittest

from litex.gen import *

from litepcie.tlp.depacketizer import LitePCIeTLPDepacketizer

from test.model.tlp import CPL, CPLD


def _swap32(dword):
    return int.from_bytes(dword.to_bytes(4, "little"), "big")


def _dwords2packet(data_width, dwords):
    ratio  = data_width//32
    length = math.ceil(len(dwords)/ratio)
    dat    = [0]*length
    be     = [0]*length
    for n in range(length):
        for i in reversed(range(ratio)):
            dat[n] = dat[n] << 32
            be[n]  = be[n] << 4
            try:
                dat[n] |= dwords[ratio*n + i]
                be[n]  |= 0xF
            except IndexError:
                pass
    return dat, be


def _completion_dwords(*, with_data, length, byte_count, tag, status=0, data=[]):
    cpl               = CPLD() if with_data else CPL()
    cpl.fmt           = 0b10 if with_data else 0b00
    cpl.type          = 0b01010
    cpl.length        = length
    cpl.byte_count    = byte_count
    cpl.status        = status
    cpl.requester_id  = 0x1234
    cpl.completer_id  = 0x5678
    cpl.tag           = tag
    # Payload dwords are byte-swapped on the wire with endianness="big" (the header encode
    # compensates internally); pre-swap so the decoded payload matches `data`.
    return cpl.encode_dwords([_swap32(d) for d in data])


class TestTLPDepacketizer(unittest.TestCase):
    def _run_completion(self, data_width, dwords):
        dut = LitePCIeTLPDepacketizer(
            data_width   = data_width,
            endianness   = "big",
            capabilities = ["REQUEST", "COMPLETION"],
        )
        dat, be  = _dwords2packet(data_width, dwords)
        observed = []

        @passive
        def monitor():
            source = dut.cmp_source
            while True:
                yield source.ready.eq(1)
                if (yield source.valid) and (yield source.ready):
                    observed.append({
                        "first": (yield source.first),
                        "last":  (yield source.last),
                        "end":   (yield source.end),
                        "err":   (yield source.err),
                        "tag":   (yield source.tag),
                        "len":   (yield source.len),
                        "dat":   (yield source.dat),
                    })
                yield

        def stim():
            yield
            for beat_index, (d, b) in enumerate(zip(dat, be)):
                while True:
                    yield dut.sink.valid.eq(1)
                    yield dut.sink.first.eq(beat_index == 0)
                    yield dut.sink.last.eq(beat_index == (len(dat) - 1))
                    yield dut.sink.dat.eq(d)
                    yield dut.sink.be.eq(b)
                    yield
                    if (yield dut.sink.ready):
                        break
            yield dut.sink.valid.eq(0)
            yield dut.sink.first.eq(0)
            yield dut.sink.last.eq(0)
            for _ in range(32):
                yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        return observed

    def test_dataless_cpl_asserts_end(self):
        # A completion without data (e.g. the completion of a Configuration Write) is always
        # terminal: end must assert even though Length (reserved in data-less completions)
        # cannot be compared against Byte Count.
        for data_width in [64, 128]:
            with self.subTest(data_width=data_width):
                dwords   = _completion_dwords(with_data=False, length=0, byte_count=4, tag=0x42)
                observed = self._run_completion(data_width, dwords)
                self.assertEqual(len(observed), 1)
                self.assertEqual(observed[0]["first"], 1)
                self.assertEqual(observed[0]["last"],  1)
                self.assertEqual(observed[0]["end"],   1)
                self.assertEqual(observed[0]["err"],   0)
                self.assertEqual(observed[0]["tag"],   0x42)

    def test_dataless_cpl_error_asserts_end_and_err(self):
        # Unsupported Request: data-less completion with a non-zero status.
        for data_width in [64, 128]:
            with self.subTest(data_width=data_width):
                dwords   = _completion_dwords(with_data=False, length=0, byte_count=4, tag=0x07,
                                              status=1)
                observed = self._run_completion(data_width, dwords)
                self.assertEqual(len(observed), 1)
                self.assertEqual(observed[0]["end"], 1)
                self.assertEqual(observed[0]["err"], 1)

    def test_single_cpld_asserts_end(self):
        for data_width in [64, 128]:
            with self.subTest(data_width=data_width):
                dwords   = _completion_dwords(with_data=True, length=1, byte_count=4, tag=0x11,
                                              data=[0xDEADBEEF])
                observed = self._run_completion(data_width, dwords)
                self.assertEqual(len(observed), 1)
                self.assertEqual(observed[0]["end"], 1)
                self.assertEqual(observed[0]["err"], 0)
                self.assertEqual(observed[0]["len"], 1)
                self.assertEqual(observed[0]["dat"] & 0xFFFFFFFF, 0xDEADBEEF)

    def test_split_cpld_asserts_end_on_last_packet_only(self):
        # A 256-byte read split into 64-byte completions: Byte Count counts down and only the
        # packet whose Length covers the remaining Byte Count is terminal. `end` is a per-packet
        # header property, asserted on every beat of the terminal packet (consumers gate on
        # last & end).
        for data_width in [64, 128]:
            with self.subTest(data_width=data_width):
                intermediate = _completion_dwords(with_data=True, length=16, byte_count=256,
                                                  tag=0x21, data=list(range(16)))
                final        = _completion_dwords(with_data=True, length=16, byte_count=64,
                                                  tag=0x21, data=list(range(16)))
                observed_intermediate = self._run_completion(data_width, intermediate)
                observed_final        = self._run_completion(data_width, final)
                self.assertGreater(len(observed_intermediate), 0)
                self.assertGreater(len(observed_final), 0)
                self.assertEqual([b["end"] for b in observed_intermediate],
                                 [0]*len(observed_intermediate))
                self.assertEqual([b["end"] for b in observed_final],
                                 [1]*len(observed_final))
                self.assertEqual(observed_final[-1]["last"], 1)


if __name__ == "__main__":
    unittest.main()
