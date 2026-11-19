#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Denis Bodor
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litepcie.common import *

# LitePCIeExpansionROM -----------------------------------------------------------------------------

class LitePCIeExpansionROM(LiteXModule):
    """PCIe Expansion ROM responder.

    Read-only BRAM: Memory Reads are completed one DWORD per Completion, Memory Writes are dropped.
    Connected before the Crossbar on the Requests' bar_hit (see LitePCIeEndpoint.add_expansion_rom).
    """
    def __init__(self, data_width, size, init=None):
        self.sink   = sink   = stream.Endpoint(request_layout(data_width))
        self.source = source = stream.Endpoint(completion_layout(data_width))

        self.id = Signal(16) # Completer ID.

        # # #

        depth = size//4
        if init is None:
            init = [0]*depth
        assert len(init) <= depth, "ROM content does not fit in the requested Expansion ROM size."

        mem  = Memory(32, depth, init=init)
        port = mem.get_port()
        self.specials += mem, port

        # Byte-accurate Completion accounting ------------------------------------------------------
        # Same Completion byte count/lower address rules as LitePCIeWishboneMaster.

        request_adr      = Signal(32)
        request_len      = Signal(10)
        request_first_be = Signal(4)
        request_last_be  = Signal(4)
        request_req_id   = Signal(16)
        request_tc       = Signal(3)
        request_attr     = Signal(2)
        request_tag      = Signal(8)
        dword_index      = Signal(10)
        byte_count       = Signal(12)
        read_dat         = Signal(32)

        first_byte_count   = Signal(3)
        last_byte_count    = Signal(3)
        request_byte_count = Signal(12)
        self.comb += [
            first_byte_count.eq(sum(sink.first_be[n] for n in range(4))),
            last_byte_count.eq(sum(sink.last_be[n] for n in range(4))),
            If(sink.len == 1,
                # PCIe encodes a zero-length Memory Read as a one-Dword request with all First
                # Byte Enables cleared. Its successful Completion still carries one Dword and a
                # Byte Count of one.
                request_byte_count.eq(Mux(first_byte_count == 0, 1, first_byte_count)),
            ).Else(
                request_byte_count.eq(first_byte_count + last_byte_count + 4*(sink.len - 2)),
            ),
        ]

        current_be = Signal(4)
        self.comb += If(request_len == 1,
            current_be.eq(request_first_be),
        ).Elif(dword_index == 0,
            current_be.eq(request_first_be),
        ).Elif(dword_index == (request_len - 1),
            current_be.eq(request_last_be),
        ).Else(
            current_be.eq(0xf),
        )

        current_byte_count   = Signal(3)
        current_lower_offset = Signal(2)
        self.comb += [
            current_byte_count.eq(sum(current_be[n] for n in range(4))),
            If(current_be == 0,
                current_lower_offset.eq(0),
            ).Elif(current_be[0],
                current_lower_offset.eq(0),
            ).Elif(current_be[1],
                current_lower_offset.eq(1),
            ).Elif(current_be[2],
                current_lower_offset.eq(2),
            ).Else(
                current_lower_offset.eq(3),
            ),
        ]

        # Responder FSM ----------------------------------------------------------------------------

        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(sink.valid & sink.first,
                If(sink.we,
                    NextState("DROP-WRITE")
                ).Else(
                    NextValue(request_adr,      sink.adr),
                    NextValue(request_len,      sink.len),
                    NextValue(request_first_be, sink.first_be),
                    NextValue(request_last_be,  sink.last_be),
                    NextValue(request_req_id,   sink.req_id),
                    NextValue(request_tc,       sink.tc),
                    NextValue(request_attr,     sink.attr),
                    NextValue(request_tag,      sink.tag),
                    NextValue(dword_index,      0),
                    NextValue(byte_count,       request_byte_count),
                    NextState("SETUP-READ")
                )
            ).Else(
                sink.ready.eq(1)
            )
        )
        fsm.act("DROP-WRITE",
            # Read-only: drop Memory Writes (posted, no Completion).
            sink.ready.eq(1),
            If(sink.valid & sink.last,
                NextState("IDLE")
            )
        )
        fsm.act("SETUP-READ",
            port.adr.eq(request_adr[2:] + dword_index),
            NextState("READ-DATA")
        )
        fsm.act("READ-DATA",
            NextValue(read_dat, port.dat_r),
            NextState("ISSUE-READ-COMPLETION")
        )
        self.comb += [
            source.first.eq(1),
            source.last.eq(1),
            source.len.eq(1),
            source.byte_count.eq(byte_count),
            source.err.eq(0),
            source.tag.eq(request_tag),
            source.adr.eq(request_adr + 4*dword_index + current_lower_offset),
            source.cmp_id.eq(self.id),
            source.req_id.eq(request_req_id),
            source.tc.eq(request_tc),
            source.attr.eq(request_attr),
            source.dat.eq(read_dat),
        ]
        fsm.act("ISSUE-READ-COMPLETION",
            source.valid.eq(1),
            If(source.ready,
                If(dword_index == (request_len - 1),
                    sink.ready.eq(1),
                    NextState("IDLE"),
                ).Else(
                    NextValue(dword_index, dword_index + 1),
                    NextValue(byte_count, byte_count - current_byte_count),
                    NextState("SETUP-READ"),
                )
            )
        )
