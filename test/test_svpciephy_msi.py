#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 blurbdust <blurbdust@gmail.com>
# SPDX-License-Identifier: BSD-2-Clause

"""Unit tests for the Stratix V PHY's MSI request.

The hard IP sends one MSI per rising edge of app_msi_req and acknowledges it with a single cycle of
app_msi_ack (Intel's chaining DMA example, altpcierd_cdma_ast_msi.v, applies the same rule). The
model below does the same, and the tests check that every MSI queued in front of the PHY is sent,
however close together they are queued and however late the acknowledge comes.
"""

import unittest

from migen import *

from litex.gen import *
from litex.soc.interconnect import stream

from litepcie.common import msi_layout
from litepcie.phy.svpciephy import _MSIRequest

# Test Bench ---------------------------------------------------------------------------------------

class _MSIRequestTB(LiteXModule):
    """The PHY's MSI path: a FIFO in front of the request, as the clock domain crossing is."""
    def __init__(self, direct=False):
        self.fifo = fifo = stream.SyncFIFO(msi_layout(), 4)
        self.sink = fifo.sink
        if direct:
            # The request driven straight from the FIFO, as it was before _MSIRequest.
            self.req = Signal()
            self.ack = Signal()
            self.comb += [
                self.req.eq(fifo.source.valid),
                fifo.source.ready.eq(self.ack),
            ]
        else:
            self.msi_req = msi_req = _MSIRequest()
            self.comb += fifo.source.connect(msi_req.sink)
            self.req = msi_req.req
            self.ack = msi_req.ack

def run(n, ack_delay, gap=0, direct=False, cycles=400):
    """Queue n MSIs, `gap` idle cycles apart, into a hard IP model that acknowledges each rising edge
    of the request `ack_delay` cycles later. Returns the number of MSIs the model sent, the number
    left queued, and whether the request ever dropped before its acknowledge."""
    dut     = _MSIRequestTB(direct=direct)
    results = {"sent": 0, "early_drop": False}

    def source():
        for i in range(n):
            yield dut.sink.valid.eq(1)
            yield dut.sink.dat.eq(i)
            yield
            while not (yield dut.sink.ready):
                yield
            yield dut.sink.valid.eq(0)
            for _ in range(gap):
                yield

    def hard_ip():
        prev = 0
        for _ in range(cycles):
            req = (yield dut.req)
            if req and not prev:
                for _ in range(ack_delay):
                    yield
                    if not (yield dut.req):
                        results["early_drop"] = True
                yield dut.ack.eq(1)
                yield
                yield dut.ack.eq(0)
                results["sent"] += 1
                prev = 1
                continue
            prev = req
            yield

    def queued():
        for _ in range(cycles + 1):
            yield
        results["left"] = (yield dut.fifo.level)

    run_simulation(dut, [source(), hard_ip(), queued()])
    return results["sent"], results["left"], results["early_drop"]

# Tests --------------------------------------------------------------------------------------------

class TestSVPCIEPHYMSI(unittest.TestCase):
    def test_back_to_back_msis_are_all_sent(self):
        for ack_delay in [1, 2, 3, 5]:
            for n in [1, 2, 3, 4, 8]:
                sent, left, early_drop = run(n, ack_delay)
                self.assertEqual(sent, n, f"{n} queued, ack after {ack_delay} cycles")
                self.assertEqual(left, 0, f"{n} queued, ack after {ack_delay} cycles")
                self.assertFalse(early_drop)

    def test_spaced_msis_are_all_sent(self):
        for gap in [0, 1, 2, 7]:
            sent, left, early_drop = run(6, 2, gap=gap)
            self.assertEqual(sent, 6, f"gap {gap}")
            self.assertEqual(left, 0, f"gap {gap}")
            self.assertFalse(early_drop)

    def test_model_catches_a_request_held_across_msis(self):
        # Driving the request from the FIFO's valid sends the first of two back-to-back MSIs and
        # leaves the second queued for good. If this ever passes, the model above no longer checks
        # the rule the other tests depend on.
        sent, left, _ = run(2, 2, direct=True)
        self.assertEqual(sent, 1)
        self.assertEqual(left, 1)


if __name__ == "__main__":
    unittest.main()
