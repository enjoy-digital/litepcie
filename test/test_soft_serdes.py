#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest

from migen import *
from migen.fhdl.specials import Instance

from litex.gen import *

from litex.build.xilinx import XilinxPlatform

from litepcie.phy.soft.common       import TS1, STP, END, LOGICAL_IDLE
from litepcie.phy.soft.serdes.model import PCIeSerDesModel

from test.model.soft.common import symbols_to_words, words_to_symbols

def random_packet(rng, ndws):
    return [(STP.value, 1)] + [(rng.getrandbits(8), 0) for _ in range(4*ndws + 2)] + [(END.value, 1)]

class Link(Module):
    """Two serdes models back-to-back: a ("a" lane clock) and b ("b" lane clock)."""
    def __init__(self, shift_a=0, shift_b=0, skp_interval=None):
        self.submodules.a = PCIeSerDesModel(tx_cd="a", rx_cd="b", rx_symbol_shift=shift_a, skp_interval=skp_interval)
        self.submodules.b = PCIeSerDesModel(tx_cd="b", rx_cd="a", rx_symbol_shift=shift_b, skp_interval=skp_interval)
        self.a.connect(self.b)

def transfer(link, words, bounds, clocks, polarity=False, idle=False):
    """Transmit words on a (lane 0), return the words received by b."""
    lane_a, lane_b = link.a.lanes[0], link.b.lanes[0]
    outs = []
    done = []
    def a_gen():
        yield lane_a.tx_polarity.eq(polarity)
        yield lane_b.rx_polarity.eq(polarity)
        yield lane_a.tx_elecidle.eq(idle)
        for _ in range(8):
            yield
        for (data, ctrl), (first, last) in zip(words, bounds):
            yield lane_a.sink.data.eq(data)
            yield lane_a.sink.ctrl.eq(ctrl)
            yield lane_a.sink.first.eq(first)
            yield lane_a.sink.last.eq(last)
            yield lane_a.sink.valid.eq(1)
            while True:
                yield
                if (yield lane_a.sink.ready):
                    break
        yield lane_a.sink.valid.eq(0)
        for _ in range(64):
            yield
        done.append(True)
    def b_mon():
        yield lane_b.source.ready.eq(1)
        while not done:
            if (yield lane_b.source.valid):
                outs.append(((yield lane_b.source.data), (yield lane_b.source.ctrl)))
            yield
    run_simulation(link, {"a": [a_gen()], "b": [b_mon()]}, clocks=clocks)
    return outs

def stimulus(seed=0):
    rng    = random.Random(seed)
    items  = [TS1.to_symbols()]*4
    for _ in range(12):
        items.append(random_packet(rng, rng.randrange(1, 5)))
        items.append([(LOGICAL_IDLE, 0)]*4*rng.randrange(0, 2))
    words, bounds = [], []
    for item in items:
        ws = symbols_to_words(item)
        for i, w in enumerate(ws):
            words.append(w)
            bounds.append((i == 0, i == len(ws) - 1))
    return words, bounds

class TestSoftSerDes(unittest.TestCase):
    def check(self, outs, words):
        expected = words_to_symbols(words)
        received = words_to_symbols(outs)
        # Logical Idle fills the gaps before the first word: find the stream in the received Symbols.
        start = next(i for i in range(len(received)) if received[i:i + 8] == expected[:8])
        self.assertEqual(received[start:start + len(expected)], expected)

    def test_model_link(self):
        # Same clocks, every RX Symbol shift: TS and packets received at the partner.
        words, bounds = stimulus()
        for shift in range(4):
            outs = transfer(Link(shift_a=shift, shift_b=(shift + 1) % 4), words, bounds, clocks={"a": 10, "b": 10})
            self.check(outs, words)

    def test_model_link_ppm(self):
        # Partner clocks 2% apart (far beyond PCIe tolerances), dense SKP Ordered Sets: compensated.
        words, bounds = stimulus(1)
        outs = transfer(Link(skp_interval=4), words, bounds, clocks={"a": 98, "b": 100})
        self.check(outs, words)
        outs = transfer(Link(skp_interval=4), words, bounds, clocks={"a": 100, "b": 98})
        self.check(outs, words)

    def test_model_link_polarity(self):
        # Inverted TX polarity, corrected by the RX polarity control.
        words, bounds = stimulus(2)
        outs = transfer(Link(), words, bounds, clocks={"a": 10, "b": 10}, polarity=True)
        self.check(outs, words)

    def test_model_link_polarity_mismatch(self):
        # Inverted TX without RX correction: errors/garbage, no packet received.
        words, bounds = stimulus(3)
        link = Link()
        lane_a, lane_b = link.a.lanes[0], link.b.lanes[0]
        outs = []
        done = []
        def a_gen():
            yield lane_a.tx_polarity.eq(1)
            for (data, ctrl), (first, last) in zip(words, bounds):
                yield lane_a.sink.data.eq(data)
                yield lane_a.sink.ctrl.eq(ctrl)
                yield lane_a.sink.valid.eq(1)
                yield
            yield lane_a.sink.valid.eq(0)
            for _ in range(32):
                yield
            done.append(True)
        def b_mon():
            yield lane_b.source.ready.eq(1)
            while not done:
                if (yield lane_b.source.valid):
                    outs.append(((yield lane_b.source.data), (yield lane_b.source.ctrl)))
                yield
        run_simulation(link, {"a": [a_gen()], "b": [b_mon()]}, clocks={"a": 10, "b": 10})
        received = words_to_symbols(outs)
        self.assertNotIn(words_to_symbols(words)[:8], [received[i:i + 8] for i in range(len(received))])

    def test_model_electrical_idle(self):
        # Electrical Idle seen by the partner (filtered), receiver detection.
        link = Link()
        lane_a, lane_b = link.a.lanes[0], link.b.lanes[0]
        results = {}
        def a_gen():
            yield lane_a.tx_elecidle.eq(1)
            for _ in range(32):
                yield
            results["idle"] = (yield lane_b.rx_elecidle)
            yield lane_a.tx_elecidle.eq(0)
            yield lane_a.sink.valid.eq(1)
            for _ in range(32):
                yield
            results["active"] = (yield lane_b.rx_elecidle)
            yield lane_a.tx_detect_rx.eq(1)
            yield
            yield lane_a.tx_detect_rx.eq(0)
            yield
            results["detect"] = ((yield lane_a.detect_done), (yield lane_a.rx_detected))
        run_simulation(link, {"a": [a_gen()]}, clocks={"a": 10, "b": 10})
        self.assertEqual(results["idle"], 1)
        self.assertEqual(results["active"], 0)
        self.assertEqual(results["detect"], (1, 1))

class TestSoftSerDesGTP(unittest.TestCase):
    def elaborate(self, nlanes):
        import inspect
        from liteiclink.serdes.gtp_7series import GTP
        if "align_comma_word" not in inspect.signature(GTP.__init__).parameters:
            self.skipTest("Requires the LiteICLink serdes/gtp-pcie-ports GTP options.")
        from litepcie.phy.soft.serdes.gtp_7series import A7PCIeSerDes
        class Top(LiteXModule):
            def __init__(self, platform):
                self.cd_sys = ClockDomain()
                pads = Record([
                    ("rst_n", 1), ("clk_p", 1), ("clk_n", 1),
                    ("tx_p", nlanes), ("tx_n", nlanes), ("rx_p", nlanes), ("rx_n", nlanes),
                ])
                self.serdes = A7PCIeSerDes(platform, pads, sys_clk_freq=100e6)
                self.serdes.add_timing_constraints(self.cd_sys.clk)
        platform = XilinxPlatform("xc7a200t-fbg484-2", io=[])
        top      = Top(platform)
        fragment = top.get_fragment()
        verilog  = str(platform.get_verilog(fragment))
        return top, fragment, verilog

    def test_gtp_elaboration(self):
        for nlanes in [1, 2, 4]:
            with self.subTest(nlanes=nlanes):
                top, fragment, verilog = self.elaborate(nlanes)
                instances = [s for s in fragment.specials if isinstance(s, Instance)]
                count = lambda of: len([i for i in instances if i.of == of])
                self.assertEqual(count("GTPE2_COMMON"),  1)
                self.assertEqual(count("GTPE2_CHANNEL"), nlanes)
                self.assertEqual(count("IBUFDS_GTE2"),   1)
                self.assertEqual(count("MMCME2_ADV"),    1)
                self.assertEqual(count("BUFGCTRL"),      1)
                channel = [i for i in instances if i.of == "GTPE2_CHANNEL"][0]
                params  = {item.name: item.value for item in channel.items if isinstance(item, Instance.Parameter)}
                self.assertEqual(params["ALIGN_COMMA_WORD"].value, 1)
                self.assertEqual(params["TX_DRIVE_MODE"], "PIPE")
                self.assertEqual(params["RXBUF_RESET_ON_EIDLE"], "TRUE")
                self.assertEqual(params["RXCDR_CFG"].value, 0x000107FE406001041010)
                self.assertEqual(params["TX_DATA_WIDTH"].value, 40)
                self.assertIn("GTPE2_CHANNEL", verilog)
