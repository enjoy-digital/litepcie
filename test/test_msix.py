#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest
from types import SimpleNamespace

from migen import *

from litex.gen import *
from litex.soc.interconnect import stream

from litepcie.common import request_layout, completion_layout
from litepcie.core.msi import LitePCIeMSIX

# MSI-X Test Bench ---------------------------------------------------------------------------------

class MSIXTB(LiteXModule):
    def __init__(self, address_width):
        self.port = port = SimpleNamespace(channel=0,
            source = stream.Endpoint(request_layout(64, address_width=address_width)),
            sink   = stream.Endpoint(completion_layout(64)),
        )
        endpoint = SimpleNamespace(
            phy      = SimpleNamespace(id=0x400),
            crossbar = SimpleNamespace(get_master_port=lambda: port),
        )
        self.msix = msix = LitePCIeMSIX(endpoint, width=2, default_enable=1)

        self.irqs       = Signal(2)
        self.table_adr  = Signal(1) # Vector.
        self.table_word = Signal(2) # Word within the entry.
        self.table_we   = Signal()
        self.table_dw   = Signal(32)
        table_wp = msix.table.get_port(write_capable=True)
        self.specials += table_wp
        self.comb += [
            msix.irqs.eq(self.irqs),
            table_wp.adr.eq(Cat(self.table_word, self.table_adr)),
            table_wp.we.eq(self.table_we),
            table_wp.dat_w.eq(self.table_dw),
            port.source.ready.eq(1),
        ]

# Test MSI-X ---------------------------------------------------------------------------------------

def entry(lower=0xfee01000, upper=0, data=0x45, mask=0):
    # Table entry as the host writes it: Lower Address, Upper Address, Data, Control.
    return [lower, upper, data, mask]

class TestMSIX(unittest.TestCase):
    def run_msix(self, address_width, actions):
        dut      = MSIXTB(address_width)
        requests = []
        pba      = []

        @passive
        def monitor():
            while True:
                if (yield dut.port.source.valid):
                    requests.append(((yield dut.port.source.adr), (yield dut.port.source.dat)))
                yield

        def stimulus():
            for action, *args in actions:
                if action == "table":
                    adr, words = args
                    for word, value in enumerate(words):
                        yield dut.table_adr.eq(adr)
                        yield dut.table_word.eq(word)
                        yield dut.table_dw.eq(value)
                        yield dut.table_we.eq(1)
                        yield
                    yield dut.table_we.eq(0)
                elif action == "irq":
                    yield dut.irqs.eq(args[0])
                    yield
                    yield dut.irqs.eq(0)
                elif action == "pba":
                    pba.append((yield dut.msix.pba.status))
                for _ in range(32):
                    yield

        run_simulation(dut, [stimulus(), monitor()])
        return requests, pba

    def test_msix_32b_address(self):
        for address_width in [32, 64]:
            requests, _ = self.run_msix(address_width, [("table", 0, entry()), ("irq", 0b01)])
            self.assertEqual(requests, [(0xfee01000, 0x45)])

    def test_msix_64b_address(self):
        requests, _ = self.run_msix(64, [("table", 0, entry(upper=0x1)), ("irq", 0b01)])
        self.assertEqual(requests, [(0x1_fee01000, 0x45)])

    def test_msix_64b_address_on_32b_endpoint_is_kept_pending(self):
        requests, pba = self.run_msix(32, [
            ("table", 0, entry(upper=0x1)),
            ("irq",   0b01),
            ("pba",),
            ("table", 0, entry(upper=0x0)),
        ])
        self.assertEqual(pba, [0b01])
        self.assertEqual(requests, [(0xfee01000, 0x45)])

    def test_msix_masked_is_kept_pending_and_generated_on_unmask(self):
        requests, pba = self.run_msix(64, [
            ("table", 0, entry(mask=1)),
            ("irq",   0b01),
            ("pba",),
            ("table", 0, entry(mask=0)),
            ("pba",),
        ])
        self.assertEqual(pba, [0b01, 0b00])
        self.assertEqual(requests, [(0xfee01000, 0x45)])

    def test_msix_masked_does_not_block_other_vectors(self):
        requests, pba = self.run_msix(64, [
            ("table", 0, entry(data=0x10, mask=1)),
            ("table", 1, entry(data=0x11, mask=0)),
            ("irq",   0b11),
            ("pba",),
        ])
        self.assertEqual(pba, [0b01])
        self.assertEqual(requests, [(0xfee01000, 0x11)])

if __name__ == "__main__":
    unittest.main()
