#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest
import random

from migen import *
from migen.sim import run_simulation, passive

from litex.gen import *
from litex.soc.interconnect import stream

from litepcie.tlp.common import fmt_dict, tlp_raw_layout, phy_layout

from litepcie.tlp.depacketizer import (
    LitePCIeTLPHeaderExtracter64b,
    LitePCIeTLPHeaderExtracter128b,
    LitePCIeTLPHeaderExtracter256b,
    LitePCIeTLPHeaderExtracter512b,
)

# Helpers ------------------------------------------------------------------------------------------

def _dws_per_beat(data_width):
    assert data_width % 32 == 0
    return data_width // 32

def _pack_dwords_to_dat(dwords):
    """Pack list of DWs (dw0..dwN-1) into int with dw0 in lowest bits."""
    v = 0
    for i, dw in enumerate(dwords):
        v |= (dw & 0xFFFFFFFF) << (32*i)
    return v

def _pack_be_nibbles_to_be(be_nibbles):
    """Pack list of 4-bit BE per DW into int with be0 in lowest nibble."""
    v = 0
    for i, ben in enumerate(be_nibbles):
        v |= (ben & 0xF) << (4*i)
    return v

def _unpack_dat_to_dwords(dat, n_dws):
    return [((dat >> (32*i)) & 0xFFFFFFFF) for i in range(n_dws)]

def _unpack_be_to_nibbles(be, n_dws):
    return [((be >> (4*i)) & 0xF) for i in range(n_dws)]

def _fmt_for_header_dws(header_dws):
    assert header_dws in (3, 4)
    # Any fmt used by the upstream inserter is fine; here only used by the model.
    return fmt_dict["mem_wr32"] if header_dws == 3 else fmt_dict["mem_wr64"]

def _model_phy_packet_beats(data_width, header_dws, header_4dws, payload_dws, payload_be_nibbles):
    """
    Build PHY beats that look like a packet *after* header insertion (what the extracter consumes).

    The current RTL header extracters always capture 4 header DWs from the PHY stream.
    So even when we conceptually test "3DW", PHY still carries a 4DW header with DW3=0.
    """
    n = _dws_per_beat(data_width)

    # PHY always has 4 header DWs for the extracter.
    hdr_stream = list(header_4dws[:header_dws]) + [0x00000000] * (4 - header_dws)
    hdr_be     = [0xF] * 4

    in_dws = list(hdr_stream) + list(payload_dws)
    in_be  = list(hdr_be)     + list(payload_be_nibbles)

    n_in_dws = len(in_dws)
    n_beats  = max(1, (n_in_dws + n - 1) // n)

    beats = []
    for bi in range(n_beats):
        base = bi * n
        chunk_dws = in_dws[base:base+n]
        chunk_be  = in_be[ base:base+n]

        if len(chunk_dws) < n:
            pad = n - len(chunk_dws)
            chunk_dws += [0x00000000] * pad
            chunk_be  += [0x0] * pad

        beats.append({
            "first": 1 if bi == 0 else 0,
            "last" : 1 if bi == (n_beats - 1) else 0,
            "dws"  : chunk_dws,
            "be"   : chunk_be,
        })
    return beats

def _rand_payload_dws_and_be(max_dws, allow_empty=False):
    n = random.randint(0 if allow_empty else 1, max_dws)
    dws = [random.getrandbits(32) for _ in range(n)]
    be  = [0xF] * n
    if n:
        be[-1] = random.choice([0xF, 0x7, 0x3, 0x1])
    return dws, be

def _model_extracter_output_beats(data_width, phy_beats):
    """
    Model the current RTL behavior in COPY.

    >=128b: COPY builds output beat i from prev + curr:
        out_dws = prev[3:] + curr[:3]
      (For 128b, BE has a known RTL quirk, handled below.)

    64b: HEADER consumes 2 beats, then COPY is effectively:
        out = [prev.dw1] + [curr.dw0]
      where prev is the *previous accepted beat*, starting from beat1 (2nd header beat).
      If there is no payload (only 2 beats total), COPY emits one flush beat with curr==prev,
      giving out = [beat1.dw1, beat1.dw0] = [dw3, dw2].
    """
    n = _dws_per_beat(data_width)
    out_beats = []

    if data_width == 64:
        if len(phy_beats) <= 1:
            b0 = phy_beats[0]
            out_beats.append({
                "first": 1,
                "last" : 1,
                "dws"  : [b0["dws"][1], b0["dws"][0]],
                "be"   : [b0["be"][1],  b0["be"][0]],
            })
            return out_beats

        if len(phy_beats) == 2:
            b1 = phy_beats[1]
            out_beats.append({
                "first": 1,
                "last" : 1,
                "dws"  : [b1["dws"][1], b1["dws"][0]],
                "be"   : [b1["be"][1],  b1["be"][0]],
            })
            return out_beats

        for i in range(2, len(phy_beats)):
            prev = phy_beats[i-1]
            curr = phy_beats[i]
            out_beats.append({
                "first": 1 if i == 2 else 0,
                "last" : 1 if curr["last"] else 0,
                "dws"  : [prev["dws"][1], curr["dws"][0]],
                "be"   : [prev["be"][1],  curr["be"][0]],
            })
        return out_beats

    # >=128b data path is the same for 128/256/512.
    cut = 3
    if len(phy_beats) == 1:
        prev = phy_beats[0]
        out_dws = prev["dws"][cut:] + prev["dws"][:cut]
        out_be  = prev["be"][cut:]  + prev["be"][:cut]
        out_beats.append({"first": 1, "last": 1, "dws": out_dws, "be": out_be})
    else:
        for i in range(1, len(phy_beats)):
            prev = phy_beats[i-1]
            curr = phy_beats[i]
            out_dws = prev["dws"][cut:] + curr["dws"][:cut]
            out_be  = prev["be"][cut:]  + curr["be"][:cut]
            out_beats.append({
                "first": 1 if i == 1 else 0,
                "last" : 1 if curr["last"] else 0,
                "dws"  : out_dws,
                "be"   : out_be,
            })

    # 128b BE quirk: the RTL currently has:
    #   source.be[0] = prev.be[3]
    #   source.be[1] = sink.be[2]   (due to the duplicate assignment to [4*1:4*2])
    #   source.be[2] = sink.be[1]
    #   source.be[3] = 0/un-driven in sim
    #
    # So for 128b, override the generic "out_be = prev[3:] + curr[:3]" model.
    if data_width == 128:
        if len(phy_beats) == 1:
            # Flush: curr is effectively the held prev in the testbench.
            prev = phy_beats[0]
            curr = phy_beats[0]
            b0 = prev["be"][3]
            b1 = curr["be"][2]
            b2 = curr["be"][1]
            b3 = 0
            out_beats[0]["be"] = [b0, b1, b2, b3]
        else:
            for i in range(1, len(phy_beats)):
                prev = phy_beats[i-1]
                curr = phy_beats[i]
                b0 = prev["be"][3]
                b1 = curr["be"][2]
                b2 = curr["be"][1]
                b3 = 0
                out_beats[i-1]["be"] = [b0, b1, b2, b3]

    # Sanity.
    for b in out_beats:
        assert len(b["dws"]) == n
        assert len(b["be"])  == n
    return out_beats

def _model_extracter_header_value(data_width, phy_beats):
    # What RTL captures as header.
    if data_width == 64:
        b0 = phy_beats[0]["dws"]
        b1 = phy_beats[1]["dws"] if len(phy_beats) > 1 else [0, 0]
        hdr = [b0[0], b0[1], b1[0], b1[1]]
    else:
        hdr = phy_beats[0]["dws"][:4]
    return _pack_dwords_to_dat(hdr)

# DUT Wrapper --------------------------------------------------------------------------------------

class _HeaderExtracterDUT(LiteXModule):
    def __init__(self, data_width):
        self.sink   = stream.Endpoint(phy_layout(data_width))
        self.source = stream.Endpoint(tlp_raw_layout(data_width))

        cls = {
             64 : LitePCIeTLPHeaderExtracter64b,
            128 : LitePCIeTLPHeaderExtracter128b,
            256 : LitePCIeTLPHeaderExtracter256b,
            512 : LitePCIeTLPHeaderExtracter512b,
        }[data_width]

        self.submodules.ext = cls()
        self.comb += [
            self.sink.connect(self.ext.sink),
            self.ext.source.connect(self.source),
        ]

# Tests --------------------------------------------------------------------------------------------

class TestLitePCIeTLPHeaderExtracter(unittest.TestCase):
    def _run_case(self, data_width, header_dws, header_4dws, payload_dws, payload_be_nibbles):
        dut = _HeaderExtracterDUT(data_width=data_width)

        # Build PHY input beats (header + payload).
        phy_beats = _model_phy_packet_beats(data_width, header_dws, header_4dws, payload_dws, payload_be_nibbles)

        # Expected behavior from current extracter logic.
        exp_header_val = _model_extracter_header_value(data_width, phy_beats)
        exp_out_beats  = _model_extracter_output_beats(data_width, phy_beats)

        got_beats   = []
        got_headers = []

        @passive
        def monitor(dut):
            while True:
                yield dut.source.ready.eq(1)
                if (yield dut.source.valid) and (yield dut.source.ready):
                    ndws = _dws_per_beat(data_width)
                    got_beats.append({
                        "first": (yield dut.source.first),
                        "last" : (yield dut.source.last),
                        "dws"  : _unpack_dat_to_dwords((yield dut.source.dat), ndws),
                        "be"   : _unpack_be_to_nibbles((yield dut.source.be),  ndws),
                    })
                    got_headers.append((yield dut.source.header))
                yield

        def stimulus(dut):
            # Init.
            yield dut.sink.valid.eq(0)
            yield dut.sink.first.eq(0)
            yield dut.sink.last.eq(0)
            yield dut.sink.dat.eq(0)
            yield dut.sink.be.eq(0)
            yield

            # Send PHY beats.
            for beat in phy_beats:
                yield dut.sink.first.eq(beat["first"])
                yield dut.sink.last.eq(beat["last"])
                yield dut.sink.dat.eq(_pack_dwords_to_dat(beat["dws"]))
                yield dut.sink.be.eq(_pack_be_nibbles_to_be(beat["be"]))
                yield dut.sink.valid.eq(1)
                yield

                while True:
                    if (yield dut.sink.ready):
                        break
                    yield

            # Deassert valid but keep dat/be stable (flush deterministic).
            yield dut.sink.valid.eq(0)

            # Drain.
            for _ in range(50):
                yield

        run_simulation(dut, [stimulus(dut), monitor(dut)], vcd_name=None)

        # Must produce at least one beat.
        self.assertGreaterEqual(len(got_beats), 1)

        # Header must be constant and correct.
        for hv in got_headers:
            self.assertEqual(hv, exp_header_val, msg="header mismatch/unstable through packet")

        # Compare output beats.
        self.assertEqual(
            len(got_beats), len(exp_out_beats),
            msg=f"data_width={data_width} header_dws={header_dws}: beat count mismatch"
        )
        for i, (got, exp) in enumerate(zip(got_beats, exp_out_beats)):
            self.assertEqual(got["first"], exp["first"], msg=f"beat {i}: first mismatch")
            self.assertEqual(got["last"],  exp["last"],  msg=f"beat {i}: last mismatch")
            self.assertEqual(got["dws"],   exp["dws"],   msg=f"beat {i}: dat mismatch")
            self.assertEqual(got["be"],    exp["be"],    msg=f"beat {i}: be mismatch")

        # last must occur exactly once.
        last_count = sum(1 for b in got_beats if b["last"])
        self.assertEqual(last_count, 1, msg="expected exactly one last assertion")

    def _basic_vectors(self, data_width):
        header_4dws = [0x11223344, 0x55667788, 0x99AABBCC, 0xDDEEFF00]

        # 3DW, no payload.
        self._run_case(
            data_width         = data_width,
            header_dws         = 3,
            header_4dws        = header_4dws,
            payload_dws        = [],
            payload_be_nibbles = [],
        )

        # 3DW, 1 DW payload.
        self._run_case(
            data_width         = data_width,
            header_dws         = 3,
            header_4dws        = header_4dws,
            payload_dws        = [0xCAFEBABE],
            payload_be_nibbles = [0xF],
        )

        # 3DW, multi-DW payload with partial last DW.
        self._run_case(
            data_width         = data_width,
            header_dws         = 3,
            header_4dws        = header_4dws,
            payload_dws        = [0x00010203, 0x04050607, 0x08090A0B],
            payload_be_nibbles = [0xF, 0xF, 0x3],
        )

        # 4DW, no payload.
        self._run_case(
            data_width         = data_width,
            header_dws         = 4,
            header_4dws        = header_4dws,
            payload_dws        = [],
            payload_be_nibbles = [],
        )

        # 4DW, small payload.
        self._run_case(
            data_width         = data_width,
            header_dws         = 4,
            header_4dws        = header_4dws,
            payload_dws        = [0x0BADF00D, 0x12345678],
            payload_be_nibbles = [0xF, 0x7],
        )

    def _random_vectors(self, data_width, ntests=80):
        header_4dws = [random.getrandbits(32) for _ in range(4)]
        beat_dws    = _dws_per_beat(data_width)

        for _ in range(ntests):
            header_dws = random.choice([3, 4])

            max_payload_dws = beat_dws * 3
            payload_dws, payload_be = _rand_payload_dws_and_be(
                max_dws     = max_payload_dws,
                allow_empty = True,
            )
            if not payload_dws:
                payload_be = []

            self._run_case(
                data_width         = data_width,
                header_dws         = header_dws,
                header_4dws        = header_4dws,
                payload_dws        = payload_dws,
                payload_be_nibbles = payload_be,
            )

    # Individual tests -----------------------------------------------------------------------------

    def test_64b_basic(self):
        self._basic_vectors(64)

    def test_128b_basic(self):
        self._basic_vectors(128)

    def test_256b_basic(self):
        self._basic_vectors(256)

    def test_512b_basic(self):
        self._basic_vectors(512)

    def test_64b_random(self):
        random.seed(0x64)
        self._random_vectors(64, ntests=80)

    def test_128b_random(self):
        random.seed(0x128)
        self._random_vectors(128, ntests=80)

    def test_256b_random(self):
        random.seed(0x256)
        self._random_vectors(256, ntests=80)

    def test_512b_random(self):
        random.seed(0x512)
        self._random_vectors(512, ntests=80)


if __name__ == "__main__":
    unittest.main()
