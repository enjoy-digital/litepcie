#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 blurbdust <blurbdust@gmail.com>
# SPDX-License-Identifier: BSD-2-Clause

"""Unit tests for the Stratix V PHY's qword aligners.

These check the one piece of real logic in litepcie/phy/svpciephy.py: the translation between
LitePCIe's packed TLP layout and Intel's address-aligned Avalon-ST layout, in which a padding dword
is inserted between header and payload when the parity of the first payload dword's lane would not
match address bit 2.

The reference layouts here are the ones in Intel doc 683093 Figure 31 ("Location of Headers and Data
for Avalon-ST 256-Bit Interface") and in Intel's own example-design RTL
(altpcierd_ast256_downstream.v).
"""

import random
import types
import unittest
from unittest import mock

from migen import Module, Signal
from migen.fhdl.specials import Instance
from migen.sim import passive, run_simulation

from litepcie.phy import svpciephy
from litepcie.phy.svpciephy import _TXQwordAligner, _RXQwordDealigner

# Helpers ------------------------------------------------------------------------------------------

def make_header(fmt_4dw, has_data, addr_bit2):
    """Return the header dwords of a TLP with the requested shape."""
    dw0 = (has_data << 30) | (fmt_4dw << 29) | 0x10
    if fmt_4dw:
        # 4DW: address low dword is header dword 3.
        return [dw0, 0x11111111, 0x22222222, 0x33333330 | (addr_bit2 << 2)]
    else:
        # 3DW: address (or completion Lower Address) is header dword 2.
        return [dw0, 0x11111111, 0x22222220 | (addr_bit2 << 2)]

def dwords_to_beats(dwords, dws_per_beat):
    """Chunk a dword list into (dat, be, first, last) beats."""
    beats = []
    for i in range(0, len(dwords), dws_per_beat):
        chunk = dwords[i:i+dws_per_beat]
        dat   = 0
        be    = 0
        for j, d in enumerate(chunk):
            dat |= (d & 0xffffffff) << (32*j)
            be  |= 0xf << (4*j)
        beats.append((dat, be, i == 0, i + dws_per_beat >= len(dwords)))
    return beats

def beats_to_dwords(beats, dws_per_beat):
    """Inverse of dwords_to_beats, using the byte enables to find the end."""
    dwords = []
    for (dat, be, first, last) in beats:
        for j in range(dws_per_beat):
            if (be >> (4*j)) & 0xf:
                dwords.append((dat >> (32*j)) & 0xffffffff)
    return dwords

def stream_packets(dut, packets, dws_per_beat, gaps=False):
    """Drive dut.sink with the given packets, collect dut.source into `out`."""
    out = []

    def source_gen():
        for pkt in packets:
            for (dat, be, first, last) in dwords_to_beats(pkt, dws_per_beat):
                yield dut.sink.valid.eq(1)
                yield dut.sink.dat.eq(dat)
                yield dut.sink.be.eq(be)
                yield dut.sink.first.eq(first)
                yield dut.sink.last.eq(last)
                yield
                while not (yield dut.sink.ready):
                    yield
                if gaps and random.random() < 0.3:
                    yield dut.sink.valid.eq(0)
                    for _ in range(random.randrange(1, 4)):
                        yield
        yield dut.sink.valid.eq(0)
        for _ in range(32):
            yield

    def sink_gen():
        # Sample before advancing the cycle, then change ready: a beat transferred at an edge where
        # ready was still asserted must not be dropped by the testbench itself.
        yield dut.source.ready.eq(1)
        yield
        for _ in range(20000):
            if (yield dut.source.valid) and (yield dut.source.ready):
                out.append((
                    (yield dut.source.dat),
                    (yield dut.source.be),
                    (yield dut.source.first),
                    (yield dut.source.last),
                ))
            if gaps:
                yield dut.source.ready.eq(0 if random.random() < 0.2 else 1)
            yield

    run_simulation(dut, [source_gen(), sink_gen()])
    return out

def split_packets(beats):
    """Split a beat list into packets on the `last` flag."""
    packets = []
    current = []
    for b in beats:
        current.append(b)
        if b[3]:
            packets.append(current)
            current = []
    return packets

def expected_altera_dwords(header, payload):
    """The dword sequence Intel's hard IP expects on tx_st_data, from `header` + `payload`."""
    hdr_4dw   = bool((header[0] >> 29) & 1)
    has_data  = bool((header[0] >> 30) & 1)
    addr_bit2 = ((header[3] if hdr_4dw else header[2]) >> 2) & 1
    # Payload lane parity must match address bit 2: 3DW packs at lane 3 (odd), 4DW at lane 4 (even).
    pad = has_data and (addr_bit2 == (1 if hdr_4dw else 0))
    return header + ([0] if pad else []) + payload

# Tests --------------------------------------------------------------------------------------------

class TestSVPCIEPHYAlignment(unittest.TestCase):
    def _packets(self, dws_per_beat):
        """(header, payload) pairs covering both header sizes, both alignments, many lengths."""
        cases = []
        for hdr_4dw in [0, 1]:
            for addr_bit2 in [0, 1]:
                for npayload in [0, 1, 2, 3, 4, 5, 8, 9, 15, 16, 17, 32]:
                    has_data = 1 if npayload else 0
                    header   = make_header(hdr_4dw, has_data, addr_bit2)
                    payload  = [0xd0000000 + i for i in range(npayload)]
                    cases.append((header, payload))
        return cases

    def test_tx_aligner_matches_intel_layout(self):
        for data_width in [128, 256]:
            dws    = data_width//32
            cases  = self._packets(dws)
            packed = [h + p for (h, p) in cases]
            dut    = _TXQwordAligner(data_width)
            beats  = stream_packets(dut, packed, dws)
            got    = split_packets(beats)
            self.assertEqual(len(got), len(cases), f"packet count, {data_width}-bit")
            for (h, p), pkt in zip(cases, got):
                self.assertEqual(beats_to_dwords(pkt, dws), expected_altera_dwords(h, p),
                    f"{data_width}-bit, 4dw={bool((h[0]>>29)&1)}, "
                    f"addr2={(h[-1]>>2)&1 if (h[0]>>29)&1 else (h[2]>>2)&1}, len={len(p)}")

    def test_rx_dealigner_is_the_inverse(self):
        for data_width in [128, 256]:
            dws     = data_width//32
            cases   = self._packets(dws)
            altera  = [expected_altera_dwords(h, p) for (h, p) in cases]
            dut     = _RXQwordDealigner(data_width)
            beats   = stream_packets(dut, altera, dws)
            got     = split_packets(beats)
            self.assertEqual(len(got), len(cases), f"packet count, {data_width}-bit")
            for (h, p), pkt in zip(cases, got):
                self.assertEqual(beats_to_dwords(pkt, dws), h + p,
                    f"{data_width}-bit, len={len(p)}")

    def test_round_trip_with_backpressure(self):
        random.seed(42)
        for data_width in [128, 256]:
            dws    = data_width//32
            cases  = self._packets(dws)
            packed = [h + p for (h, p) in cases]

            class _RoundTrip(Module):
                def __init__(self):
                    self.submodules.tx = tx = _TXQwordAligner(data_width)
                    self.submodules.rx = rx = _RXQwordDealigner(data_width)
                    self.comb += tx.source.connect(rx.sink)
                    self.sink   = tx.sink
                    self.source = rx.source

            dut   = _RoundTrip()
            beats = stream_packets(dut, packed, dws, gaps=True)
            got   = split_packets(beats)
            self.assertEqual(len(got), len(cases), f"packet count, {data_width}-bit")
            for pkt_in, pkt_out in zip(packed, got):
                self.assertEqual(beats_to_dwords(pkt_out, dws), pkt_in)


# Hard IP RX Avalon-ST Interface -------------------------------------------------------------------

class _NoInstance:
    # The hard IP and its reconfiguration logic are vendor Instances; the test plays the hard IP.
    @staticmethod
    def lower(dr):
        return Module()


class _FakePlatform:
    device = "5SGSMD5K2F40C2"

    def __init__(self):
        self.toolchain = types.SimpleNamespace(additional_sdc_commands=[])

    def add_ip(self, *args, **kwargs):
        pass

    def add_source(self, *args, **kwargs):
        pass

    def add_period_constraint(self, *args, **kwargs):
        pass


def build_svpciephy(data_width=128):
    """Elaborate the real SVPCIEPHY without Quartus, with its datapath in the pcie domain."""
    pads = types.SimpleNamespace(
        clk_p   = Signal(),
        perst_n = Signal(reset=1),
        rx_p    = Signal(8),
        tx_p    = Signal(8),
    )
    ip = "/nonexistent/svpcie_xcvr_reconfig/synthesis/svpcie_xcvr_reconfig"
    widths = {"to": 700, "from": 460}
    with mock.patch.object(svpciephy, "add_hip_sources"), \
         mock.patch.object(svpciephy, "generate_xcvr_reconfig", return_value=(ip + ".qip", ip + ".v")), \
         mock.patch.object(svpciephy, "probe_reconfig_widths", return_value=widths):
        return svpciephy.SVPCIEPHY(_FakePlatform(), pads,
            data_width = data_width,
            cd         = "pcie",
            speed      = "gen1",
            nlanes     = 8,
        )


class TestSVPCIEPHYRXReadyLatency(unittest.TestCase):
    """rx_st is an Avalon-ST source with readyLatency 3 (pcie_sv_port.tcl: `rx_st readyLatency 3`):
    the hard IP may assert rx_st_valid in cycle k whenever rx_st_ready was asserted in cycle k-3, so
    up to 3 beats arrive after rx_st_ready deasserts. None of them may be lost."""

    def run_rx(self, tlps, ready_pattern, ready_latency=3, data_width=128):
        dws   = data_width//32
        phy   = build_svpciephy(data_width)
        p     = phy.hip_params
        beats = []
        for (header, payload) in tlps:
            dwords = expected_altera_dwords(header, payload)
            for i in range(0, len(dwords), dws):
                chunk = dwords[i:i+dws]
                data  = sum((d & 0xffffffff) << (32*j) for j, d in enumerate(chunk))
                last  = i + dws >= len(dwords)
                empty = (dws//2 - (len(chunk) + 1)//2) if last else 0
                beats.append((data, i == 0, last, empty))
        out = []

        @passive
        def hard_ip():
            # Greedy source: a beat on every ready cycle while data is pending.
            ready = {}
            k = 0
            while True:
                if beats and ready.get(k - ready_latency, 0):
                    data, sop, eop, empty = beats.pop(0)
                    yield p["o_rx_st_valid"].eq(1)
                    yield p["o_rx_st_data"].eq(data)
                    yield p["o_rx_st_sop"].eq(sop)
                    yield p["o_rx_st_eop"].eq(eop)
                    yield p["o_rx_st_empty"].eq(empty)
                else:
                    yield p["o_rx_st_valid"].eq(0)
                yield
                ready[k] = (yield p["i_rx_st_ready"])
                k += 1

        def litepcie():
            for r in ready_pattern:
                yield phy.source.ready.eq(r)
                yield
                if (yield phy.source.valid) and (yield phy.source.ready):
                    out.append((
                        (yield phy.source.dat),
                        (yield phy.source.be),
                        (yield phy.source.first),
                        (yield phy.source.last),
                    ))

        run_simulation(phy, {"pcie": [hard_ip(), litepcie()]}, clocks={"pcie": 10},
            special_overrides={Instance: _NoInstance})
        return out

    def test_rx_backpressure_with_ready_latency_3(self):
        # Completions with data, both alignments, back to back. LitePCIe stalls in bursts (what a
        # full pcie->sys CDC FIFO does) while the hard IP keeps sending its in-flight beats.
        rng  = random.Random(3)
        tlps = []
        for npayload in [24, 16, 32, 1, 8, 13, 20]:
            for addr_bit2 in [0, 1]:
                header  = make_header(0, 1, addr_bit2)
                payload = [rng.getrandbits(32) for _ in range(npayload)]
                tlps.append((header, payload))
        pattern = [0]*2 + ([1]*4 + [0]*6)*30 + [1]*100
        packets = split_packets(self.run_rx(tlps, pattern))
        self.assertEqual(len(packets), len(tlps))
        for (header, payload), pkt in zip(tlps, packets):
            self.assertEqual([beat[2] for beat in pkt], [1] + [0]*(len(pkt) - 1))
            # rx_st_empty is qword-granular: one trailing dword may be flagged but unused.
            got = beats_to_dwords(pkt, 4)
            self.assertEqual(got[:len(header) + len(payload)], header + payload)
            self.assertIn(len(got) - len(header) - len(payload), [0, 1])


if __name__ == "__main__":
    unittest.main()
