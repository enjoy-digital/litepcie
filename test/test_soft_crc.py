#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest
import zlib

from migen import *

from litepcie.phy.soft.dll.crc import LCRC, DLLPCRC, DLLP_CRC_POLYNOM, DLLP_CRC_INIT

from test.model.soft.crc import lcrc, lcrc_bytes, dllp_crc, dllp_crc_bytes

def crc16_reflected(data, polynom=DLLP_CRC_POLYNOM, init=DLLP_CRC_INIT):
    """Independent CRC-16 model: reflected (LSB-first) register algorithm."""
    polynom_reflected = int(f"{polynom:016b}"[::-1], 2)
    crc = init
    for value in data:
        crc ^= value
        for _ in range(8):
            crc = (crc >> 1) ^ (polynom_reflected if crc & 1 else 0)
    return crc ^ 0xffff

def tlp_bytes(rng, ndws):
    """Random TLP bytes (ndws DWs, header included) with a random Sequence Number prefix."""
    seq = rng.getrandbits(12)
    tlp = bytes(rng.getrandbits(8) for _ in range(4*ndws))
    return seq, tlp

class TestSoftCRC(unittest.TestCase):
    def test_lcrc_model_matches_zlib(self):
        # Same CRC-32 as the Ethernet FCS: LSB first, FFFFFFFFh seed, complemented, bit-reversed.
        rng = random.Random(0)
        for length in [1, 2, 3, 4, 5, 6, 18, 64, 257, 1024]:
            data = bytes(rng.getrandbits(8) for _ in range(length))
            self.assertEqual(lcrc(data), zlib.crc32(data))
            self.assertEqual(lcrc_bytes(data), zlib.crc32(data).to_bytes(4, "little"))

    def test_lcrc_regression_vector(self):
        # Memory Write (3DW header, 1 DW payload) with Sequence Number 6.
        data = bytes([0x00, 0x06]) + bytes.fromhex("40000001" "0100000f" "f0000000" "12345678")
        self.assertEqual(lcrc_bytes(data), zlib.crc32(data).to_bytes(4, "little"))
        self.assertEqual(lcrc(data), 0xe3fd114a)

    def test_dllp_crc_model(self):
        rng = random.Random(1)
        for _ in range(64):
            data = bytes(rng.getrandbits(8) for _ in range(4))
            self.assertEqual(dllp_crc(data), crc16_reflected(data))
            self.assertEqual(dllp_crc_bytes(data), crc16_reflected(data).to_bytes(2, "little"))

    def test_dllp_crc_regression_vectors(self):
        # Ack DLLP, Sequence Number 0 and UpdateFC-P (HdrFC 8, DataFC 128) with VC0.
        self.assertEqual(dllp_crc(bytes.fromhex("00000000")), crc16_reflected(bytes.fromhex("00000000")))
        self.assertEqual(dllp_crc(bytes.fromhex("00000000")), 0x62b3)
        self.assertEqual(dllp_crc(bytes.fromhex("80020080")), crc16_reflected(bytes.fromhex("80020080")))

    def test_dllp_crc_hdl(self):
        rng = random.Random(2)
        dut = DLLPCRC()
        def generator():
            for _ in range(64):
                data = bytes(rng.getrandbits(8) for _ in range(4))
                yield dut.data.eq(int.from_bytes(data, "little"))
                yield
                self.assertEqual((yield dut.value), dllp_crc(data))
        run_simulation(dut, generator())

    def lcrc_hdl(self, data_width):
        rng    = random.Random(data_width)
        nbytes = data_width//8
        dut    = LCRC(data_width=data_width)
        def generator():
            for ndws in [3, 4, 5, 7, 8, 16, 33, 128 + 4]:
                seq, tlp = tlp_bytes(rng, ndws)
                yield dut.clear.eq(1)
                yield dut.ce.eq(0)
                yield
                yield dut.clear.eq(0)
                # Sequence Number word (2 bytes, most significant first), then TLP words.
                words = [seq.to_bytes(2, "big")] + [tlp[i:i+nbytes] for i in range(0, len(tlp), nbytes)]
                for word in words:
                    yield dut.data.eq(int.from_bytes(word.ljust(nbytes, b"\0"), "little"))
                    yield dut.bytes.eq(len(word))
                    yield dut.ce.eq(1)
                    expected_next = lcrc(seq.to_bytes(2, "big") + tlp[:sum(len(w) for w in words[1:words.index(word)+1])]) if word is not words[0] else lcrc(seq.to_bytes(2, "big"))
                    yield
                    self.assertEqual((yield dut.next_value), expected_next)
                yield dut.ce.eq(0)
                yield
                self.assertEqual((yield dut.value), lcrc(seq.to_bytes(2, "big") + tlp), f"ndws {ndws}")
                self.assertEqual((yield dut.value).to_bytes(4, "little"), lcrc_bytes(seq.to_bytes(2, "big") + tlp))
        run_simulation(dut, generator())

    def test_lcrc_hdl_32(self):
        self.lcrc_hdl(32)

    def test_lcrc_hdl_64(self):
        self.lcrc_hdl(64)

    def test_lcrc_hdl_128(self):
        self.lcrc_hdl(128)

    def test_lcrc_hdl_unsupported_size_holds(self):
        # bytes values outside sizes (here 0 and 3) keep the state.
        dut = LCRC(data_width=32)
        def generator():
            yield dut.clear.eq(1)
            yield
            yield dut.clear.eq(0)
            yield dut.data.eq(0x12345678)
            yield dut.bytes.eq(4)
            yield dut.ce.eq(1)
            yield
            yield dut.bytes.eq(0)
            yield
            yield
            value = (yield dut.value)
            self.assertEqual(value, lcrc((0x12345678).to_bytes(4, "little")))
            for size in [0, 3]:
                yield dut.bytes.eq(size)
                yield
                yield
                self.assertEqual((yield dut.value), value)
        run_simulation(dut, generator())
