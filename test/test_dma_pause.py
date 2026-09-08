from types import SimpleNamespace

import pytest
from migen import *
from litex.gen import LiteXModule
from litepcie.core.common import LitePCIeMasterInternalPort, LitePCIeMasterPort
from litepcie.frontend.dma import LitePCIeDMAReader, LitePCIeDMAWriter


@pytest.mark.parametrize("writer", [False, True])
def test_pause_finishes_presented_request_and_blocks_next(writer):
    dut = LiteXModule()
    phy = SimpleNamespace(data_width=512, id=0x1234,
        max_request_size=Signal(16, reset=512), max_payload_size=Signal(16, reset=512))
    endpoint = SimpleNamespace(phy=phy, max_pending_requests=16)
    port = LitePCIeMasterPort(LitePCIeMasterInternalPort(512, 64, channel=0))
    cls = LitePCIeDMAWriter if writer else LitePCIeDMAReader
    dut.dma = dma = cls(endpoint, port, with_table=False, address_width=64, data_width=256)

    def run():
        yield dma.desc_sink.address.eq(0x123450000)
        yield dma.desc_sink.length.eq(1024)
        yield dma.desc_sink.last_disable.eq(1)
        yield dma.desc_sink.valid.eq(1)
        if writer:
            yield dma.sink.valid.eq(1)
            yield dma.sink.data.eq(0x55)
        for _ in range(200):
            yield
            if (yield port.source.valid):
                break
        else:
            assert False, "request was never presented"
        yield dma.request_enable.eq(0)
        held = (yield port.source.raw_bits())
        for _ in range(5):
            yield
            assert (yield port.source.valid)
            assert (yield port.source.raw_bits()) == held
        yield port.source.ready.eq(1)
        for _ in range(20):
            yield
            if (yield port.source.valid) and (yield port.source.last):
                break
        else:
            assert False, "paused in-flight request failed to finish"
        yield
        for _ in range(20):
            yield
            assert not (yield port.source.valid)
        yield dma.request_enable.eq(1)
        for _ in range(200):
            yield
            if (yield port.source.valid):
                break
        else:
            assert False, "resume failed"
    run_simulation(dut, run())
