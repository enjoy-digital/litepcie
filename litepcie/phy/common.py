#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *
from migen.genlib.cdc import MultiReg

from litex.soc.interconnect.packet import PacketFIFO

from litepcie.common import *
from litepcie.tlp.common import max_payload_size

# Helpers ------------------------------------------------------------------------------------------

def get_bar_size_config(size):
    """Return the exact Xilinx PCIe IP scale/size pair for a 32-bit BAR."""
    if (size < 128) or (size > 2*GB) or (size & (size - 1)):
        raise ValueError("32-bit PCIe BAR size must be a power of two between 128 bytes and 2 GiB")

    values = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512]
    for scale, unit in [
        ("Gigabytes", GB),
        ("Megabytes", MB),
        ("Kilobytes", KB),
        ("Bytes",       1),
    ]:
        if (size % unit) == 0 and (size // unit) in values:
            return scale, size // unit

    raise ValueError(f"PCIe BAR size 0x{size:x} cannot be represented by the Xilinx PCIe IP")

def rx_128b_byte_enable_from_eof(be, is_eof):
    """Rebuild the byte enables of a 128-bit RX beat from an EOF marker.

    Some hard IPs do not report tkeep/tlast on their 128-bit receive interface and signal the
    end of a TLP and the DW position of its last byte through a side-band marker instead
    (``is_eof[4]``: EOF present, ``is_eof[3:0]``: byte offset of the last byte, 3/7/11/15).
    The core relies on the byte enables of the last beat to tell valid DWs from padding, so
    they have to be rebuilt from that marker: all bytes are valid on a beat without EOF, and
    the bytes up to the marked position on a beat with EOF.
    """
    return [
        be.eq(0xffff),
        If(is_eof[4],
            Case(is_eof[2:4], {
                0 : be.eq(0x000f),
                1 : be.eq(0x00ff),
                2 : be.eq(0x0fff),
                3 : be.eq(0xffff),
            })
        )
    ]

# RX 128-bit Marker Decoder ------------------------------------------------------------------------

class PHYRX128BMarkerDecoder(Module):
    """Decode the is_sof/is_eof markers of a 128-bit hard IP receive interface.

    The 7-series hard IP reports packet boundaries on its 128-bit interface only through the markers
    of ``m_axis_rx_tuser`` (``is_sof[4]``/``is_eof[4]``: a TLP starts/ends in the beat, ``is_sof[3:0]``/
    ``is_eof[3:0]``: byte offset of its first/last byte); ``tlast`` is 0 and ``tkeep`` all-ones on
    every beat. Turn the markers into the ``first``/``last``/``be`` of the PHY stream and report a TLP
    starting on DW2 to the 128-bit aligner.
    """
    def __init__(self):
        self.is_sof      = Signal(5)
        self.is_eof      = Signal(5)
        self.first       = Signal()
        self.last        = Signal()
        self.be          = Signal(16)
        self.first_dword = Signal(2)

        # # #

        self.comb += [
            self.first.eq(self.is_sof[4]),
            self.last.eq(self.is_eof[4]),
            If(self.is_sof == 0b11000, self.first_dword.eq(2)),
        ]
        self.comb += rx_128b_byte_enable_from_eof(self.be, self.is_eof)

# TX Datapath --------------------------------------------------------------------------------------

class PHYTXDatapath(Module):
    def __init__(self, core_data_width, pcie_data_width, clock_domain, with_packet_buffer=False):
        self.sink   = sink   = stream.Endpoint(phy_layout(core_data_width))
        self.source = source = stream.Endpoint(phy_layout(pcie_data_width))

        # # #

        if with_packet_buffer:
            # Continuous input packets can acquire bubbles crossing independent
            # clocks. Do not expose a TLP to the hard IP until its last beat has
            # arrived in the PCIe domain (PG213 requester TVALID requirement).
            packet_words = (max_payload_size + 16 + pcie_data_width//8 - 1)//(pcie_data_width//8)
            self.submodules.packet_buffer = ClockDomainsRenamer("pcie")(PacketFIFO(
                phy_layout(pcie_data_width), payload_depth=2*packet_words,
                param_depth=4, buffered=True))
            self.comb += self.packet_buffer.source.connect(source)
            source = self.packet_buffer.sink

        if (clock_domain == "pcie") and (core_data_width == pcie_data_width):
            self.comb += sink.connect(source)
        else:
            pipe_valid = stream.PipeValid(phy_layout(core_data_width))
            pipe_valid = ClockDomainsRenamer(clock_domain)(pipe_valid)
            cdc        = stream.ClockDomainCrossing(
                layout          = phy_layout(core_data_width),
                cd_from         = clock_domain,
                cd_to           = "pcie",
                with_common_rst = True,
                depth           = 16,
            )
            converter  = stream.StrideConverter(phy_layout(core_data_width), phy_layout(pcie_data_width))
            converter  = ClockDomainsRenamer("pcie")(converter)
            pipe_ready = stream.PipeReady(phy_layout(pcie_data_width))
            pipe_ready = ClockDomainsRenamer("pcie")(pipe_ready)
            self.submodules += pipe_valid, cdc, converter, pipe_ready
            self.comb += [
                sink.connect(pipe_valid.sink),
                pipe_valid.source.connect(cdc.sink),
                cdc.source.connect(converter.sink),
                converter.source.connect(pipe_ready.sink),
                pipe_ready.source.connect(source),
            ]

# PHYRX128BAligner ---------------------------------------------------------------------------------

class PHYRX128BAligner(Module):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(phy_layout(128))
        self.source = source = stream.Endpoint(phy_layout(128))
        self.first_dword = Signal(2)

        # # #

        dat_last = Signal(64, reset_less=True)
        be_last  = Signal(8,  reset_less=True)
        self.sync += [
            If(sink.valid & sink.ready,
                dat_last.eq(sink.dat[64:]),
                be_last.eq( sink.be[8:]),
            )
        ]

        self.submodules.fsm = fsm = FSM(reset_state="ALIGNED")
        fsm.act("ALIGNED",
            sink.connect(source, omit={"first"}),
            # If "first" on DWORD2 and "last" on the same cycle, switch to UNALIGNED.
            If(sink.valid & sink.last & sink.first & (self.first_dword == 2),
                source.be[8:].eq(0),
                If(source.ready,
                    NextState("UNALIGNED")
                )
            )
        )
        fsm.act("UNALIGNED",
            sink.connect(source, omit={"first", "dat", "be"}),
            source.dat.eq(Cat(dat_last, sink.dat)),
            # The byte enables follow the shift unchanged: the PHY provides exact byte enables on
            # the last beat, so the DWs of the lower half that belong to the packet stay valid.
            source.be.eq( Cat(be_last,  sink.be)),
            # If "last" and not "first" on the same cycle, switch to ALIGNED.
            If(sink.valid & sink.last & ~sink.first,
                If(source.ready,
                    NextState("ALIGNED")
                )
            )
        )

# RX Datapath --------------------------------------------------------------------------------------

class PHYRXDatapath(Module):
    def __init__(self, core_data_width, pcie_data_width, clock_domain, with_aligner=False):
        self.sink   = sink   = stream.Endpoint(phy_layout(pcie_data_width))
        self.source = source = stream.Endpoint(phy_layout(core_data_width))

        # # #

        if (pcie_data_width == 128) and with_aligner:
            aligner = PHYRX128BAligner()
            aligner = ClockDomainsRenamer("pcie")(aligner)
            self.submodules.aligner = aligner
            self.comb += sink.connect(aligner.sink)
            sink = aligner.source

        if (clock_domain == "pcie") and (core_data_width == pcie_data_width):
            self.comb += sink.connect(source)
        else:
            pipe_ready = stream.PipeReady(phy_layout(pcie_data_width))
            pipe_ready = ClockDomainsRenamer("pcie")(pipe_ready)
            converter  = stream.StrideConverter(phy_layout(pcie_data_width), phy_layout(core_data_width))
            converter  = ClockDomainsRenamer("pcie")(converter)
            cdc        = stream.ClockDomainCrossing(
                layout          = phy_layout(core_data_width),
                cd_from         = "pcie",
                cd_to           = clock_domain,
                with_common_rst = True,
                depth           = 16,
            )
            pipe_valid = stream.PipeValid(phy_layout(core_data_width))
            pipe_valid = ClockDomainsRenamer(clock_domain)(pipe_valid)
            self.submodules += pipe_ready, converter, cdc, pipe_valid
            converted = converter.source
            if core_data_width > pcie_data_width:
                # StrideConverter retains unused upper slices on a partial up-conversion.
                # Track the number of loaded slices so stale byte enables cannot revive them.
                ratio = core_data_width // pcie_data_width
                count = Signal(max=ratio)
                valid_slices = Signal(max=ratio + 1)
                self.sync.pcie += If(converter.sink.valid & converter.sink.ready,
                    If(converter.sink.last | (count == ratio - 1),
                        valid_slices.eq(count + 1),
                        count.eq(0),
                    ).Else(count.eq(count + 1))
                )
                converted = stream.Endpoint(phy_layout(core_data_width))
                self.comb += converter.source.connect(converted, omit={"be"})
                for i in range(ratio):
                    low, high = i * (pcie_data_width // 8), (i + 1) * (pcie_data_width // 8)
                    self.comb += converted.be[low:high].eq(
                        Mux(valid_slices > i, converter.source.be[low:high], 0))
            self.comb += [
                sink.connect(pipe_ready.sink),
                pipe_ready.source.connect(converter.sink),
                converted.connect(cdc.sink),
                cdc.source.connect(pipe_valid.sink),
                pipe_valid.source.connect(source),
            ]

# LTSSMTracer --------------------------------------------------------------------------------------

class LTSSMTracer(Module, AutoCSR):
    def __init__(self, ltssm):
        self._history = CSRStatus(description="History of LTSSM states",
            fields = [
                CSRField("new",   offset= 0, size=6, description="New LTSSM state"),
                CSRField("old",   offset= 6, size=6, description="Old LTSSM state"),
                CSRField("ovfl",  offset=30, size=1, description="Overflow"),
                CSRField("valid", offset=31, size=1, description="Is data valid"),
        ])

        # The ltssm state signal input is sampled in the sys domain just using a MultiReg. This means
        # on change we could have an invalid state during 1 cycle.
        #
        # We also don't use an AsyncFIFO because the pcie clock domain is held in reset most of the
        # LTSSM initial negotiation defeating the point of this module.

        fifo = stream.SyncFIFO([("new", 6), ("old", 6), ("ovfl", 1)], 128)
        self.submodules += fifo

        ltssm_cur = Signal(6)
        ltssm_d1  = Signal(6)
        ltssm_d2  = Signal(6)

        overflow  = Signal()
        change    = Signal()

        self.sync += [
            ltssm_d1.eq(ltssm_cur),
            If(fifo.sink.ready, ltssm_d2.eq(ltssm_d1)),
            change.eq((ltssm_cur != ltssm_d1) & ~change),
            overflow.eq((overflow | change) & ~fifo.sink.ready),
        ]

        self.comb += [
            ltssm_cur.eq(ltssm),
            fifo.sink.new.eq(ltssm_cur),
            fifo.sink.old.eq(ltssm_d2),
            fifo.sink.ovfl.eq(overflow),
            fifo.sink.valid.eq(overflow | change),
            self._history.fields.new.eq(fifo.source.new),
            self._history.fields.old.eq(fifo.source.old),
            self._history.fields.ovfl.eq(fifo.source.ovfl),
            self._history.fields.valid.eq(fifo.source.valid),
            fifo.source.ready.eq(self._history.rd_stb),
        ]
