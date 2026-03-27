#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest
from unittest.mock import patch

from migen import *
from migen.sim import passive, run_simulation

from litex.gen import *
from litex.soc.interconnect import axi, stream

import litepcie.frontend.axi as axi_frontend

from litepcie.common import dma_layout
from litepcie.frontend.dma import descriptor_layout


class _FakePHY:
    def __init__(self, data_width):
        self.data_width = data_width
        self.id = Signal(16, reset=0x1234)


class _FakeCrossbar:
    def get_master_port(self, write_only=False, read_only=False):
        return object()


class _FakeEndpoint:
    def __init__(self, data_width):
        self.phy = _FakePHY(data_width)
        self.crossbar = _FakeCrossbar()


class _FakeDMAWriter(LiteXModule):
    def __init__(self, endpoint, port, with_table=False):
        self.desc_sink = stream.Endpoint(descriptor_layout())
        self.sink      = stream.Endpoint(dma_layout(endpoint.phy.data_width))
        self.desc_count   = Signal(8)
        self.data_count   = Signal(8)
        self.last_address = Signal(32)
        self.last_length  = Signal(24)
        self.last_data    = Signal(endpoint.phy.data_width)

        self.comb += [
            self.desc_sink.ready.eq(1),
            self.sink.ready.eq(1),
        ]
        self.sync += [
            If(self.desc_sink.valid & self.desc_sink.ready,
                self.desc_count.eq(self.desc_count + 1),
                self.last_address.eq(self.desc_sink.address),
                self.last_length.eq(self.desc_sink.length),
            ),
            If(self.sink.valid & self.sink.ready,
                self.data_count.eq(self.data_count + 1),
                self.last_data.eq(self.sink.data),
            ),
        ]


class _FakeDMAReader(LiteXModule):
    def __init__(self, endpoint, port, with_table=False):
        self.desc_sink = stream.Endpoint(descriptor_layout())
        self.source    = stream.Endpoint(dma_layout(endpoint.phy.data_width))
        self.desc_count   = Signal(8)
        self.last_address = Signal(32)
        self.last_length  = Signal(24)

        self.comb += self.desc_sink.ready.eq(1)
        self.sync += If(self.desc_sink.valid & self.desc_sink.ready,
            self.desc_count.eq(self.desc_count + 1),
            self.last_address.eq(self.desc_sink.address),
            self.last_length.eq(self.desc_sink.length),
        )


class _AXIDUT(LiteXModule):
    def __init__(self, data_width=32, id_width=4):
        endpoint = _FakeEndpoint(data_width)
        self.submodules.frontend = axi_frontend.LitePCIeAXISlave(
            endpoint  = endpoint,
            data_width= data_width,
            id_width  = id_width,
        )
        self.axi    = self.frontend.axi
        self.dma_wr = self.frontend.dma_wr
        self.dma_rd = self.frontend.dma_rd


class TestAXIFrontend(unittest.TestCase):
    def test_valid_single_write_issues_descriptor_and_okay_response(self):
        with patch.object(axi_frontend, 'LitePCIeDMAWriter', _FakeDMAWriter),                  patch.object(axi_frontend, 'LitePCIeDMAReader', _FakeDMAReader):
            dut = _AXIDUT()
            observed = {}

            def stim():
                yield dut.axi.aw.valid.eq(1)
                yield dut.axi.aw.addr.eq(0x100)
                yield dut.axi.aw.id.eq(3)
                yield dut.axi.aw.len.eq(0)
                yield dut.axi.aw.size.eq(2)
                yield dut.axi.aw.burst.eq(axi.BURST_INCR)
                yield
                while not (yield dut.axi.aw.ready):
                    yield
                yield dut.axi.aw.valid.eq(0)

                yield dut.axi.w.valid.eq(1)
                yield dut.axi.w.data.eq(0xdeadbeef)
                yield dut.axi.w.strb.eq(0xf)
                yield dut.axi.w.last.eq(1)
                yield
                while not (yield dut.axi.w.ready):
                    yield
                yield dut.axi.w.valid.eq(0)

                yield dut.axi.b.ready.eq(1)
                while not (yield dut.axi.b.valid):
                    yield
                observed['resp']       = (yield dut.axi.b.resp)
                observed['id']         = (yield dut.axi.b.id)
                observed['desc_count'] = (yield dut.dma_wr.desc_count)
                observed['data_count'] = (yield dut.dma_wr.data_count)
                observed['address']    = (yield dut.dma_wr.last_address)
                observed['length']     = (yield dut.dma_wr.last_length)
                observed['data']       = (yield dut.dma_wr.last_data)
                yield

            run_simulation(dut, stim(), vcd_name=None)
            self.assertEqual(observed, {
                'resp': axi.RESP_OKAY,
                'id': 3,
                'desc_count': 1,
                'data_count': 1,
                'address': 0x100,
                'length': 4,
                'data': 0xdeadbeef,
            })

    def test_invalid_write_returns_slverr_without_descriptor(self):
        with patch.object(axi_frontend, 'LitePCIeDMAWriter', _FakeDMAWriter),                  patch.object(axi_frontend, 'LitePCIeDMAReader', _FakeDMAReader):
            dut = _AXIDUT()
            observed = {}

            def stim():
                yield dut.axi.aw.valid.eq(1)
                yield dut.axi.aw.addr.eq(0x80)
                yield dut.axi.aw.id.eq(7)
                yield dut.axi.aw.len.eq(1)
                yield dut.axi.aw.size.eq(1)
                yield dut.axi.aw.burst.eq(axi.BURST_WRAP)
                yield
                while not (yield dut.axi.aw.ready):
                    yield
                yield dut.axi.aw.valid.eq(0)

                for beat, last in [(0x11111111, 0), (0x22222222, 1)]:
                    yield dut.axi.w.valid.eq(1)
                    yield dut.axi.w.data.eq(beat)
                    yield dut.axi.w.strb.eq(0xf)
                    yield dut.axi.w.last.eq(last)
                    yield
                    while not (yield dut.axi.w.ready):
                        yield
                yield dut.axi.w.valid.eq(0)

                yield dut.axi.b.ready.eq(1)
                while not (yield dut.axi.b.valid):
                    yield
                observed['resp']       = (yield dut.axi.b.resp)
                observed['id']         = (yield dut.axi.b.id)
                observed['desc_count'] = (yield dut.dma_wr.desc_count)
                observed['data_count'] = (yield dut.dma_wr.data_count)
                yield

            run_simulation(dut, stim(), vcd_name=None)
            self.assertEqual(observed, {
                'resp': axi.RESP_SLVERR,
                'id': 7,
                'desc_count': 0,
                'data_count': 0,
            })

    def test_write_last_mismatch_returns_slverr(self):
        with patch.object(axi_frontend, 'LitePCIeDMAWriter', _FakeDMAWriter),                  patch.object(axi_frontend, 'LitePCIeDMAReader', _FakeDMAReader):
            dut = _AXIDUT()
            observed = {}

            def stim():
                yield dut.axi.aw.valid.eq(1)
                yield dut.axi.aw.addr.eq(0x180)
                yield dut.axi.aw.id.eq(2)
                yield dut.axi.aw.len.eq(1)
                yield dut.axi.aw.size.eq(2)
                yield dut.axi.aw.burst.eq(axi.BURST_INCR)
                yield
                while not (yield dut.axi.aw.ready):
                    yield
                yield dut.axi.aw.valid.eq(0)

                for beat, last in [(0x11111111, 1), (0x22222222, 0)]:
                    yield dut.axi.w.valid.eq(1)
                    yield dut.axi.w.data.eq(beat)
                    yield dut.axi.w.strb.eq(0xf)
                    yield dut.axi.w.last.eq(last)
                    yield
                    while not (yield dut.axi.w.ready):
                        yield
                yield dut.axi.w.valid.eq(0)

                yield dut.axi.b.ready.eq(1)
                while not (yield dut.axi.b.valid):
                    yield
                observed['resp']       = (yield dut.axi.b.resp)
                observed['desc_count'] = (yield dut.dma_wr.desc_count)
                observed['data_count'] = (yield dut.dma_wr.data_count)
                observed['length']     = (yield dut.dma_wr.last_length)
                observed['data']       = (yield dut.dma_wr.last_data)
                yield

            run_simulation(dut, stim(), vcd_name=None)
            self.assertEqual(observed, {
                'resp': axi.RESP_SLVERR,
                'desc_count': 1,
                'data_count': 2,
                'length': 8,
                'data': 0x22222222,
            })

    def test_partial_write_strobe_returns_slverr(self):
        with patch.object(axi_frontend, 'LitePCIeDMAWriter', _FakeDMAWriter),                  patch.object(axi_frontend, 'LitePCIeDMAReader', _FakeDMAReader):
            dut = _AXIDUT()
            observed = {}

            def stim():
                yield dut.axi.aw.valid.eq(1)
                yield dut.axi.aw.addr.eq(0x1c0)
                yield dut.axi.aw.id.eq(6)
                yield dut.axi.aw.len.eq(0)
                yield dut.axi.aw.size.eq(2)
                yield dut.axi.aw.burst.eq(axi.BURST_INCR)
                yield
                while not (yield dut.axi.aw.ready):
                    yield
                yield dut.axi.aw.valid.eq(0)

                yield dut.axi.w.valid.eq(1)
                yield dut.axi.w.data.eq(0x12345678)
                yield dut.axi.w.strb.eq(0x3)
                yield dut.axi.w.last.eq(1)
                yield
                while not (yield dut.axi.w.ready):
                    yield
                yield dut.axi.w.valid.eq(0)

                yield dut.axi.b.ready.eq(1)
                while not (yield dut.axi.b.valid):
                    yield
                observed['resp']       = (yield dut.axi.b.resp)
                observed['desc_count'] = (yield dut.dma_wr.desc_count)
                observed['data_count'] = (yield dut.dma_wr.data_count)
                yield

            run_simulation(dut, stim(), vcd_name=None)
            self.assertEqual(observed, {
                'resp': axi.RESP_SLVERR,
                'desc_count': 1,
                'data_count': 1,
            })

    def test_valid_two_beat_read_returns_okay_and_last(self):
        with patch.object(axi_frontend, 'LitePCIeDMAWriter', _FakeDMAWriter),                  patch.object(axi_frontend, 'LitePCIeDMAReader', _FakeDMAReader):
            dut = _AXIDUT()
            observed = {
                'beats': [],
            }

            @passive
            def monitor():
                while True:
                    yield dut.axi.r.ready.eq(1)
                    if (yield dut.axi.r.valid) and (yield dut.axi.r.ready):
                        observed['beats'].append({
                            'data': (yield dut.axi.r.data),
                            'resp': (yield dut.axi.r.resp),
                            'last': (yield dut.axi.r.last),
                            'id':   (yield dut.axi.r.id),
                        })
                    yield

            def stim():
                yield dut.axi.ar.valid.eq(1)
                yield dut.axi.ar.addr.eq(0x200)
                yield dut.axi.ar.id.eq(5)
                yield dut.axi.ar.len.eq(1)
                yield dut.axi.ar.size.eq(2)
                yield dut.axi.ar.burst.eq(axi.BURST_INCR)
                yield
                while not (yield dut.axi.ar.ready):
                    yield
                yield dut.axi.ar.valid.eq(0)

                while not (yield dut.dma_rd.desc_count):
                    yield
                observed['desc_count'] = (yield dut.dma_rd.desc_count)
                observed['address']    = (yield dut.dma_rd.last_address)
                observed['length']     = (yield dut.dma_rd.last_length)

                yield dut.dma_rd.source.valid.eq(1)
                yield dut.dma_rd.source.data.eq(0xaaaabbbb)
                yield
                while not (yield dut.dma_rd.source.ready):
                    yield
                yield dut.dma_rd.source.data.eq(0xccccdddd)
                yield
                while not (yield dut.dma_rd.source.ready):
                    yield
                yield dut.dma_rd.source.valid.eq(0)
                for _ in range(2):
                    yield

            run_simulation(dut, [stim(), monitor()], vcd_name=None)
            self.assertEqual(observed['desc_count'], 1)
            self.assertEqual(observed['address'], 0x200)
            self.assertEqual(observed['length'], 8)
            self.assertEqual([entry['data'] for entry in observed['beats']], [0xaaaabbbb, 0xccccdddd])
            self.assertEqual([entry['resp'] for entry in observed['beats']], [axi.RESP_OKAY, axi.RESP_OKAY])
            self.assertEqual([entry['last'] for entry in observed['beats']], [0, 1])
            self.assertEqual([entry['id'] for entry in observed['beats']], [5, 5])

    def test_invalid_read_returns_slverr_without_descriptor(self):
        with patch.object(axi_frontend, 'LitePCIeDMAWriter', _FakeDMAWriter),                  patch.object(axi_frontend, 'LitePCIeDMAReader', _FakeDMAReader):
            dut = _AXIDUT()
            observed = {
                'beats': [],
            }

            @passive
            def monitor():
                while True:
                    yield dut.axi.r.ready.eq(1)
                    if (yield dut.axi.r.valid) and (yield dut.axi.r.ready):
                        observed['beats'].append({
                            'data': (yield dut.axi.r.data),
                            'resp': (yield dut.axi.r.resp),
                            'last': (yield dut.axi.r.last),
                            'id':   (yield dut.axi.r.id),
                        })
                    yield

            def stim():
                yield dut.axi.ar.valid.eq(1)
                yield dut.axi.ar.addr.eq(0x40)
                yield dut.axi.ar.id.eq(9)
                yield dut.axi.ar.len.eq(1)
                yield dut.axi.ar.size.eq(0)
                yield dut.axi.ar.burst.eq(axi.BURST_FIXED)
                yield
                while not (yield dut.axi.ar.ready):
                    yield
                yield dut.axi.ar.valid.eq(0)
                for _ in range(4):
                    yield
                observed['desc_count'] = (yield dut.dma_rd.desc_count)

            run_simulation(dut, [stim(), monitor()], vcd_name=None)
            self.assertEqual(observed['desc_count'], 0)
            self.assertEqual([entry['data'] for entry in observed['beats']], [0, 0])
            self.assertEqual([entry['resp'] for entry in observed['beats']], [axi.RESP_SLVERR, axi.RESP_SLVERR])
            self.assertEqual([entry['last'] for entry in observed['beats']], [0, 1])
            self.assertEqual([entry['id'] for entry in observed['beats']], [9, 9])


if __name__ == '__main__':
    unittest.main()
