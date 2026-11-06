#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest

from migen import *

from litepcie.phy.soft.common      import LOGICAL_IDLE
from litepcie.phy.soft.dll.dllp    import DLLPEncoder, DLLPDecoder
from litepcie.phy.soft.dll.dllp    import DLLP_ACK, DLLP_NAK, DLLP_INITFC1_P, DLLP_INITFC2_CPL, DLLP_UPDATEFC_NP
from litepcie.phy.soft.dll.framing import RXFramer, TXFramer

from test.model.soft.common import symbols_to_words
from test.model.soft.crc    import lcrc_bytes
from test.model.soft.dll    import tlp_frame, dllp_frame, dllp_value

def random_tlp(rng, ndws):
    return bytes(rng.getrandbits(8) for _ in range(4*ndws))

def dws(data):
    """Bytes to DW words (byte 0 on bits 7:0)."""
    return [int.from_bytes(data[i:i+4], "little") for i in range(0, len(data), 4)]

class TestSoftDLLFraming(unittest.TestCase):
    def test_dllp_encoder_decoder(self):
        rng = random.Random(0)
        cases = []
        for _ in range(32):
            cases.append((rng.choice([DLLP_ACK, DLLP_NAK]), dict(seq=rng.getrandbits(12))))
            cases.append((rng.choice([DLLP_INITFC1_P, DLLP_INITFC2_CPL, DLLP_UPDATEFC_NP]),
                dict(hdr_fc=rng.getrandbits(8), data_fc=rng.getrandbits(12), vc=0)))
        class DUT(Module):
            def __init__(self):
                self.submodules.enc  = DLLPEncoder()
                self.submodules.dec  = DLLPDecoder()
                self.submodules.dec2 = DLLPDecoder() # Driven by the test.
                self.comb += self.dec.dllp.eq(self.enc.dllp)
        dut = DUT()
        def generator():
            for type, fields in cases:
                yield dut.enc.type.eq(type)
                yield dut.enc.seq.eq(fields.get("seq", 0))
                yield dut.enc.hdr_fc.eq(fields.get("hdr_fc", 0))
                yield dut.enc.data_fc.eq(fields.get("data_fc", 0))
                yield dut.enc.vc.eq(fields.get("vc", 0))
                yield
                self.assertEqual((yield dut.enc.dllp), dllp_value(type, **fields))
                self.assertEqual((yield dut.dec.crc_ok), 1)
                self.assertEqual((yield dut.dec.type), type)
                if type in [DLLP_ACK, DLLP_NAK]:
                    self.assertEqual((yield dut.dec.seq), fields["seq"])
                    self.assertEqual((yield dut.dec.ack), int(type == DLLP_ACK))
                    self.assertEqual((yield dut.dec.nak), int(type == DLLP_NAK))
                else:
                    self.assertEqual((yield dut.dec.hdr_fc), fields["hdr_fc"])
                    self.assertEqual((yield dut.dec.data_fc), fields["data_fc"])
                    self.assertEqual((yield dut.dec.fc), 1)
                    self.assertEqual((yield dut.dec.fc_type), (type >> 4) & 0x3)
                    self.assertEqual(((yield dut.dec.init1), (yield dut.dec.init2), (yield dut.dec.update)),
                        (int(type == DLLP_INITFC1_P), int(type == DLLP_INITFC2_CPL), int(type == DLLP_UPDATEFC_NP)))
            # Corrupted CRC.
            yield dut.dec2.dllp.eq(dllp_value(DLLP_ACK, seq=5) ^ (1 << 40))
            yield
            self.assertEqual((yield dut.dec2.crc_ok), 0)
            self.assertEqual((yield dut.dec2.ack), 0)
        run_simulation(dut, generator())

    def run_rx(self, symbols):
        dut   = RXFramer()
        tlps  = []
        dllps = []
        errors = []
        current = []
        def generator():
            yield dut.tlp.ready.eq(1)
            for data, ctrl in symbols_to_words(symbols) + [(0, 0)]*4:
                yield dut.sink.data.eq(data)
                yield dut.sink.ctrl.eq(ctrl)
                yield dut.sink.valid.eq(1)
                yield
                while not (yield dut.sink.ready):
                    yield
                if (yield dut.tlp.valid):
                    if (yield dut.tlp.first):
                        current.append({"seq": (yield dut.tlp.seq), "data": []})
                    current[-1]["data"].append((yield dut.tlp.data))
                    if (yield dut.tlp.last):
                        current[-1]["edb"] = (yield dut.tlp.edb)
                        tlps.append(current.pop())
                if (yield dut.dllp_valid):
                    dllps.append((yield dut.dllp))
                if (yield dut.error):
                    errors.append(True)
        run_simulation(dut, generator())
        return tlps, dllps, errors

    def test_rx_framer(self):
        # TLPs and DLLPs, back-to-back or separated by Logical Idle, at every word phase.
        rng = random.Random(1)
        for shift in range(4):
            symbols  = [(LOGICAL_IDLE, 0)]*shift
            expected_tlps  = []
            expected_dllps = []
            for _ in range(6):
                seq = rng.getrandbits(12)
                tlp = random_tlp(rng, rng.randrange(3, 8))
                nullified = rng.random() < 0.2
                symbols += tlp_frame(seq, tlp, nullified)
                crc = lcrc_bytes(seq.to_bytes(2, "big") + tlp)
                if nullified:
                    crc = bytes(b ^ 0xff for b in crc)
                expected_tlps.append({"seq": seq, "data": dws(tlp + crc), "edb": int(nullified)})
                if rng.random() < 0.5:
                    type = rng.choice([DLLP_ACK, DLLP_UPDATEFC_NP])
                    fields = dict(seq=rng.getrandbits(12)) if type == DLLP_ACK else dict(hdr_fc=3, data_fc=0x123)
                    symbols += dllp_frame(type, **fields)
                    expected_dllps.append(dllp_value(type, **fields))
                symbols += [(LOGICAL_IDLE, 0)]*rng.randrange(0, 5)
            symbols += [(LOGICAL_IDLE, 0)]*((-len(symbols)) % 4)
            tlps, dllps, errors = self.run_rx(symbols)
            self.assertEqual(errors, [], f"shift {shift}")
            self.assertEqual(tlps, expected_tlps, f"shift {shift}")
            self.assertEqual(dllps, expected_dllps, f"shift {shift}")

    def test_rx_framer_errors(self):
        # A K Symbol inside a TLP drops it (abort), the following packet is received.
        rng = random.Random(2)
        tlp = random_tlp(rng, 4)
        bad = tlp_frame(1, tlp)
        bad[8] = (0x1c, 1) # SKP-like K Symbol in the payload.
        good_tlp = random_tlp(rng, 3)
        symbols = bad + tlp_frame(2, good_tlp) + [(LOGICAL_IDLE, 0)]*4
        symbols += [(LOGICAL_IDLE, 0)]*((-len(symbols)) % 4)
        tlps, dllps, errors = self.run_rx(symbols)
        self.assertEqual(len(errors), 1)
        self.assertEqual(len(tlps), 1)
        self.assertEqual(tlps[0]["seq"], 2)
        self.assertEqual(tlps[0]["data"], dws(good_tlp + lcrc_bytes((2).to_bytes(2, "big") + good_tlp)))

    def test_tx_rx_roundtrip(self):
        # TXFramer -> RXFramer: TLPs (DW stream with LCRC) and DLLPs (priority between TLPs).
        rng = random.Random(3)
        class DUT(Module):
            def __init__(self):
                self.submodules.tx = TXFramer()
                self.submodules.rx = RXFramer()
                # Logical Idle fills the gaps (continuous lane stream, RX lookahead).
                self.comb += [
                    self.rx.sink.valid.eq(1),
                    self.tx.source.ready.eq(self.rx.sink.ready),
                    If(self.tx.source.valid,
                        self.rx.sink.data.eq(self.tx.source.data),
                        self.rx.sink.ctrl.eq(self.tx.source.ctrl),
                    )
                ]
        dut = DUT()
        packets = []
        for i in range(8):
            tlp = random_tlp(rng, rng.randrange(3, 6))
            seq = i
            crc = lcrc_bytes(seq.to_bytes(2, "big") + tlp)
            packets.append(("tlp", seq, dws(tlp + crc)))
            if i % 3 == 0:
                packets.append(("dllp", dllp_value(DLLP_ACK, seq=i)))
        rx_tlps, rx_dllps, current = [], [], []
        done = []
        def tx_gen():
            for packet in packets:
                if packet[0] == "tlp":
                    _, seq, words = packet
                    for j, word in enumerate(words):
                        yield dut.tx.tlp.data.eq(word)
                        yield dut.tx.tlp.seq.eq(seq)
                        yield dut.tx.tlp.first.eq(j == 0)
                        yield dut.tx.tlp.last.eq(j == len(words) - 1)
                        yield dut.tx.tlp.edb.eq(0)
                        yield dut.tx.tlp.valid.eq(1)
                        yield
                        while not (yield dut.tx.tlp.ready):
                            yield
                    yield dut.tx.tlp.valid.eq(0)
                else:
                    yield dut.tx.dllp.eq(packet[1])
                    yield dut.tx.dllp_valid.eq(1)
                    yield
                    while not (yield dut.tx.dllp_ready):
                        yield
                    yield dut.tx.dllp_valid.eq(0)
                for _ in range(rng.randrange(0, 3)):
                    yield
            for _ in range(16):
                yield
            done.append(True)
        def rx_mon():
            yield dut.rx.tlp.ready.eq(1)
            while not done:
                if (yield dut.rx.tlp.valid):
                    if (yield dut.rx.tlp.first):
                        current.append({"seq": (yield dut.rx.tlp.seq), "data": []})
                    current[-1]["data"].append((yield dut.rx.tlp.data))
                    if (yield dut.rx.tlp.last):
                        rx_tlps.append(current.pop())
                if (yield dut.rx.dllp_valid):
                    rx_dllps.append((yield dut.rx.dllp))
                yield
        run_simulation(dut, [tx_gen(), rx_mon()])
        self.assertEqual(rx_tlps, [{"seq": p[1], "data": p[2]} for p in packets if p[0] == "tlp"])
        self.assertEqual(rx_dllps, [p[1] for p in packets if p[0] == "dllp"])
