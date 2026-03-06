#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import sys
import unittest
import random

from migen import *
from migen.sim import run_simulation, passive

from litex.gen import *
from litex.soc.interconnect import stream

from litepcie.tlp.common import fmt_dict, tlp_raw_layout, phy_layout
from litepcie.tlp.packetizer import (
    LitePCIeTLPHeaderInserter64b,
    LitePCIeTLPHeaderInserter128b,
    LitePCIeTLPHeaderInserter256b,
    LitePCIeTLPHeaderInserter512b,
)

# Helpers ------------------------------------------------------------------------------------------

def _dws_per_beat(data_width):
    assert data_width % 32 == 0
    return data_width // 32

def _bytes_per_beat(data_width):
    return data_width // 8

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

def _mk_header_value(dw0, dw1, dw2, dw3):
    """Create sink.header value (4 DWs) where header[32*i:] maps to DWi."""
    return _pack_dwords_to_dat([dw0, dw1, dw2, dw3])

def _fmt_for_header_dws(header_dws):
    assert header_dws in (3, 4)
    # Any fmt that routes to the desired inserter is fine.
    if header_dws == 3:
        return fmt_dict["mem_wr32"]
    else:
        return fmt_dict["mem_wr64"]

def _model_insert_header(data_width, header_dws, header_4dws, payload_dws, payload_be_nibbles):
    """
    Software model of output beats after header insertion.

    header_dws: 3 or 4.
    header_4dws: list of 4 dwords [dw0..dw3] (dw3 ignored for 3DW).
    payload_dws: list of dwords (dw0..)
    payload_be_nibbles: list of nibbles per payload dw (same length as payload_dws)

    Returns list of beats:
        [{
          "first": 0/1,
          "last":  0/1,
          "dws":   [dw0..dw(beat_dws-1)],
          "be":    [ben0..ben(beat_dws-1)]  (nibbles)
        }, ...]
    """
    beat_dws = _dws_per_beat(data_width)

    # Build output DW stream.
    hdr_stream = header_4dws[:header_dws]
    hdr_be     = [0xF] * header_dws

    out_dws = list(hdr_stream) + list(payload_dws)
    out_be  = list(hdr_be)     + list(payload_be_nibbles)

    # If no payload, the HW expects "be==0" on input and will terminate with last.
    # For the model, we simply pack just the header stream and set last on the final beat.
    n_out_dws = len(out_dws)
    n_beats   = (n_out_dws + beat_dws - 1) // beat_dws
    beats = []
    for bi in range(n_beats):
        base = bi * beat_dws
        chunk_dws = out_dws[base:base+beat_dws]
        chunk_be  = out_be[ base:base+beat_dws]

        # Pad to full beat with zeros (and BE=0).
        if len(chunk_dws) < beat_dws:
            pad = beat_dws - len(chunk_dws)
            chunk_dws = chunk_dws + [0x00000000]*pad
            chunk_be  = chunk_be  + [0x0]*pad

        beats.append({
            "first" : 1 if (bi == 0) else 0,
            "last"  : 1 if (bi == n_beats-1) else 0,
            "dws"   : chunk_dws,
            "be"    : chunk_be,
        })
    return beats

def _build_tlp_raw_input_beats(data_width, payload_dws, payload_be_nibbles):
    """
    Build input beats for tlp_raw sink (no header in dat path, only payload).
    Returns beats list with:
        {"first","last","dws","be"}
    """
    beat_dws = _dws_per_beat(data_width)
    n = len(payload_dws)
    n_beats = (n + beat_dws - 1) // beat_dws if n else 1

    beats = []
    for bi in range(n_beats):
        base = bi * beat_dws
        chunk_dws = payload_dws[base:base+beat_dws]
        chunk_be  = payload_be_nibbles[base:base+beat_dws]

        if len(chunk_dws) < beat_dws:
            pad = beat_dws - len(chunk_dws)
            chunk_dws = chunk_dws + [0x00000000]*pad
            chunk_be  = chunk_be  + [0x0]*pad

        beats.append({
            "first" : 1 if (bi == 0) else 0,
            "last"  : 1 if (bi == n_beats-1) else 0,
            "dws"   : chunk_dws,
            "be"    : chunk_be,
        })

    # Special case: no payload => single beat with be==0 and last asserted.
    if n == 0:
        beats = [{
            "first" : 1,
            "last"  : 1,
            "dws"   : [0x00000000]*beat_dws,
            "be"    : [0x0]*beat_dws,
        }]
    return beats

def _rand_payload_dws_and_be(max_dws, allow_empty=False):
    n = random.randint(0 if allow_empty else 1, max_dws)
    dws = [random.getrandbits(32) for _ in range(n)]
    be  = [0xF] * n
    if n:
        # Optionally make last DW partial.
        last_nibble = random.choice([0xF, 0x7, 0x3, 0x1])
        be[-1] = last_nibble
    return dws, be

# DUT Wrapper --------------------------------------------------------------------------------------

class _HeaderInserterDUT(LiteXModule):
    def __init__(self, data_width):
        self.sink   = stream.Endpoint(tlp_raw_layout(data_width))
        self.source = stream.Endpoint(phy_layout(data_width))

        fmt_sig = Signal(len(self.sink.fmt))
        self.comb += fmt_sig.eq(self.sink.fmt)

        cls = {
             64 : LitePCIeTLPHeaderInserter64b,
            128 : LitePCIeTLPHeaderInserter128b,
            256 : LitePCIeTLPHeaderInserter256b,
            512 : LitePCIeTLPHeaderInserter512b,
        }[data_width]

        self.submodules.ins = cls(fmt=fmt_sig)
        self.comb += [
            self.sink.connect(self.ins.sink),
            self.ins.source.connect(self.source),
        ]

# Tests --------------------------------------------------------------------------------------------

class TestLitePCIeTLPHeaderInserter(unittest.TestCase):
    def _run_case(self, data_width, header_dws, header_4dws, payload_dws, payload_be_nibbles):
        dut = _HeaderInserterDUT(data_width=data_width)

        in_beats  = _build_tlp_raw_input_beats(data_width, payload_dws, payload_be_nibbles)
        exp_beats = _model_insert_header(data_width, header_dws, header_4dws, payload_dws, payload_be_nibbles)

        got_beats = []

        @passive
        def monitor(dut):
            while True:
                yield dut.source.ready.eq(1)
                if (yield dut.source.valid) and (yield dut.source.ready):
                    dat   = (yield dut.source.dat)
                    be    = (yield dut.source.be)
                    first = (yield dut.source.first)
                    last  = (yield dut.source.last)

                    ndws = _dws_per_beat(data_width)
                    got_beats.append({
                        "first" : first,
                        "last"  : last,
                        "dws"   : _unpack_dat_to_dwords(dat, ndws),
                        "be"    : _unpack_be_to_nibbles(be, ndws),
                    })
                yield

        def stimulus(dut):
            # Init.
            yield dut.sink.valid.eq(0)
            yield dut.sink.first.eq(0)
            yield dut.sink.last.eq(0)
            yield dut.sink.dat.eq(0)
            yield dut.sink.be.eq(0)
            yield dut.sink.header.eq(0)
            yield dut.sink.fmt.eq(0)
            yield

            # Set header fields (stable for the whole packet).
            yield dut.sink.header.eq(_pack_dwords_to_dat(header_4dws))
            yield dut.sink.fmt.eq(_fmt_for_header_dws(header_dws))
            yield

            for beat in in_beats:
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

            yield dut.sink.valid.eq(0)

            # Drain.
            for _ in range(50):
                yield

        run_simulation(dut, [stimulus(dut), monitor(dut)], vcd_name=None)

        # 1) first must be asserted on the first output beat.
        self.assertTrue(len(got_beats) >= 1)
        self.assertEqual(got_beats[0]["first"], 1, msg="first not asserted on first beat")

        # 2) Collect output DW stream in order (beat/lanes).
        got_stream = []
        got_last_indices = []
        for bi, b in enumerate(got_beats):
            if b["last"]:
                got_last_indices.append(bi)
            got_stream += list(b["dws"])

        # Expected semantic DW stream: header + payload DWs (payload DW count is len(payload_dws)).
        exp_stream = header_4dws[:header_dws] + list(payload_dws)
        exp_len    = len(exp_stream)

        # Take the first exp_len DWs from the observed stream.
        # (The inserter may emit extra padded/flush DWs afterwards.)
        self.assertGreaterEqual(
            len(got_stream), exp_len,
            msg=f"data_width={data_width} header_dws={header_dws}: DUT produced too few DWs"
        )

        got_stream_trim = got_stream[:exp_len]
        self.assertEqual(
            got_stream_trim, exp_stream,
            msg=f"data_width={data_width} header_dws={header_dws}: DW stream mismatch"
        )

        # 3) last must occur exactly once.
        self.assertEqual(len(got_last_indices), 1, msg="expected exactly one last assertion")

        # And it must occur on or after the beat where the final expected DW appears.
        # Compute which beat contains the last expected DW (0-indexed).
        ndws_per_beat = _dws_per_beat(data_width)
        last_exp_dw_index = exp_len - 1
        beat_of_last_exp  = last_exp_dw_index // ndws_per_beat

        self.assertGreaterEqual(
            got_last_indices[0], beat_of_last_exp,
            msg="last asserted before the final expected DW could have been output"
        )

        # 4) last must occur exactly once, and only after all valid DWs have been emitted.
        self.assertEqual(len(got_last_indices), 1, msg="expected exactly one last assertion")
        last_beat = got_last_indices[0]

        # Compute how many valid DWs were seen by the time last beat completes.
        valid_dws_until_last = 0
        for bi in range(last_beat + 1):
            for _, ben in zip(got_beats[bi]["dws"], got_beats[bi]["be"]):
                if ben != 0:
                    valid_dws_until_last += 1

        # We don't rely on BE to define semantic length.
        self.assertGreaterEqual(
            (last_beat + 1) * _dws_per_beat(data_width), exp_len,
            msg="last asserted too early (before exp_len DWs could have been output)"
        )

    def _basic_vectors(self, data_width):
        # Fixed header pattern (4 DWs available).
        header_4dws = [0x11223344, 0x55667788, 0x99AABBCC, 0xDDEEFF00]

        # 3DW, no payload (be==0) => output is just header (3 DWs) padded, last asserted.
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

    def _random_vectors(self, data_width, ntests=50):
        header_4dws = [random.getrandbits(32) for _ in range(4)]
        beat_dws    = _dws_per_beat(data_width)

        for _ in range(ntests):
            header_dws = random.choice([3, 4])

            # Keep payload reasonably small but spanning a few beats.
            max_payload_dws = beat_dws * 3
            payload_dws, payload_be = _rand_payload_dws_and_be(
                max_dws     = max_payload_dws,
                allow_empty = True,
            )

            # If empty, payload_be must be empty.
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
