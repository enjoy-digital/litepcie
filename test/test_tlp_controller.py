#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from litex.gen import *

from litepcie.tlp.common import max_request_size
from litepcie.tlp.controller import LitePCIeTLPController, get_completion_buffer_depth


def _request_word(index):
    return 0xA0000000 + index


def _completion_word(tag, beat):
    return (tag << 24) | beat


def _completion_beats_for(data_width, request_size=max_request_size):
    return request_size // (data_width // 8)


class TestTLPController(unittest.TestCase):
    def test_completion_buffer_depth_formula(self):
        self.assertEqual(get_completion_buffer_depth(64),  65)
        self.assertEqual(get_completion_buffer_depth(128), 33)
        self.assertEqual(get_completion_buffer_depth(256), 17)
        self.assertEqual(get_completion_buffer_depth(512), 9)
        self.assertEqual(get_completion_buffer_depth(128, max_request_size_bytes=124), 9)
        self.assertEqual(get_completion_buffer_depth(64,  buffered=True), 64)
        self.assertEqual(get_completion_buffer_depth(128, buffered=True), 32)
        self.assertEqual(get_completion_buffer_depth(256, buffered=True), 16)
        self.assertEqual(get_completion_buffer_depth(512, buffered=True), 8)
        self.assertEqual(get_completion_buffer_depth(
            128, max_request_size_bytes=124, buffered=True), 8)

    def _issue_read_request(self, controller, *, index, channel=0, user_id=0, length_dwords=8,
        address=None):
        sink = controller.master_in.sink
        if address is None:
            address = index * 64
        while True:
            yield sink.valid.eq(1)
            yield sink.first.eq(1)
            yield sink.last.eq(1)
            yield sink.we.eq(0)
            yield sink.req_id.eq(0x1234)
            yield sink.adr.eq(address)
            yield sink.len.eq(length_dwords)
            yield sink.dat.eq(_request_word(index))
            yield sink.channel.eq(channel)
            yield sink.user_id.eq(user_id)
            yield
            if (yield sink.ready):
                break
        yield sink.valid.eq(0)
        yield sink.first.eq(0)
        yield sink.last.eq(0)
        yield

    def _push_completion(self, controller, *, tag, channel, user_id, beats, accepted,
        timeout=64, end_on_last=True, length_dwords=None):
        sink = controller.master_out.source
        if length_dwords is None:
            length_dwords = beats * (controller.master_out.source.dat.nbits // 32)
        for beat_index in range(beats):
            waited = 0
            while True:
                yield sink.valid.eq(1)
                yield sink.first.eq(beat_index == 0)
                yield sink.last.eq(beat_index == (beats - 1))
                yield sink.len.eq(length_dwords)
                yield sink.end.eq(1 if (end_on_last and beat_index == (beats - 1)) else 0)
                yield sink.err.eq(0)
                yield sink.tag.eq(tag)
                yield sink.req_id.eq(0x1234)
                yield sink.cmp_id.eq(0x5678)
                yield sink.adr.eq(beat_index * (controller.master_out.source.dat.nbits // 8))
                yield sink.dat.eq(_completion_word(tag, beat_index))
                yield sink.channel.eq(channel)
                yield sink.user_id.eq(user_id)
                yield
                if (yield sink.ready):
                    accepted.append(beat_index)
                    break
                waited += 1
                if waited > timeout:
                    yield sink.valid.eq(0)
                    yield sink.first.eq(0)
                    yield sink.last.eq(0)
                    yield
                    return
        yield sink.valid.eq(0)
        yield sink.first.eq(0)
        yield sink.last.eq(0)
        yield

    def test_reordered_split_completions_follow_request_order(self):
        data_width = 128
        controller = LitePCIeTLPController(
            data_width           = data_width,
            address_width        = 32,
            max_pending_requests = 4,
            cmp_bufs_buffered    = True,
        )

        observed_requests = []
        observed_completions = []

        @passive
        def monitor_requests():
            source = controller.master_out.sink
            while len(observed_requests) < 2:
                yield source.ready.eq(1)
                if (yield source.valid) and (yield source.ready):
                    observed_requests.append({
                        "tag":     (yield source.tag),
                        "channel": (yield source.channel),
                        "user_id": (yield source.user_id),
                    })
                yield

        @passive
        def monitor_completions():
            source = controller.master_in.source
            while len(observed_completions) < 4:
                yield source.ready.eq(1)
                if (yield source.valid) and (yield source.ready):
                    observed_completions.append({
                        "tag":     (yield source.tag),
                        "channel": (yield source.channel),
                        "user_id": (yield source.user_id),
                        "dat":     (yield source.dat),
                        "first":   (yield source.first),
                        "last":    (yield source.last),
                        "end":     (yield source.end),
                    })
                yield

        def stim():
            yield
            yield from self._issue_read_request(controller, index=0, channel=1, user_id=0x11)
            yield from self._issue_read_request(controller, index=1, channel=2, user_id=0x22)

            while len(observed_requests) < 2:
                yield

            first_tag = observed_requests[0]["tag"]
            second_tag = observed_requests[1]["tag"]

            accepted = []
            yield from self._push_completion(
                controller,
                tag      = second_tag,
                channel  = 9,
                user_id  = 0x99,
                beats    = 2,
                accepted = accepted,
            )
            self.assertEqual(accepted, [0, 1])
            for _ in range(4):
                yield
            self.assertEqual(observed_completions, [])

            accepted = []
            yield from self._push_completion(
                controller,
                tag      = first_tag,
                channel  = 7,
                user_id  = 0x77,
                beats    = 2,
                accepted = accepted,
            )
            self.assertEqual(accepted, [0, 1])

            timeout = 0
            while len(observed_completions) < 4:
                timeout += 1
                if timeout > 32:
                    self.fail(f"Timed out waiting for reordered completions, got {observed_completions}")
                yield

        run_simulation(controller, [stim(), monitor_requests(), monitor_completions()], vcd_name=None)

        self.assertEqual([c["tag"] for c in observed_completions], [
            observed_requests[0]["tag"],
            observed_requests[0]["tag"],
            observed_requests[1]["tag"],
            observed_requests[1]["tag"],
        ])
        self.assertEqual([c["channel"] for c in observed_completions], [1, 1, 2, 2])
        self.assertEqual([c["user_id"] for c in observed_completions], [0x11, 0x11, 0x22, 0x22])
        self.assertEqual([c["first"] for c in observed_completions], [1, 0, 1, 0])
        self.assertEqual([c["last"] for c in observed_completions], [0, 1, 0, 1])
        self.assertEqual([c["end"] for c in observed_completions], [0, 1, 0, 1])

    def test_completion_buffer_depth_matches_request_footprint(self):
        data_width = 128
        request_beats = _completion_beats_for(data_width)
        buffer_depth  = get_completion_buffer_depth(data_width)

        def accepted_beats(cmp_buf_depth):
            controller = LitePCIeTLPController(
                data_width           = data_width,
                address_width        = 32,
                max_pending_requests = 2,
                cmp_bufs_buffered    = False,
                cmp_buf_depth        = cmp_buf_depth,
            )

            observed_requests = []
            accepted = []

            @passive
            def monitor_requests():
                source = controller.master_out.sink
                while len(observed_requests) < 2:
                    yield source.ready.eq(1)
                    if (yield source.valid) and (yield source.ready):
                        observed_requests.append((yield source.tag))
                    yield

            def stim():
                yield
                yield from self._issue_read_request(
                    controller, index=0, length_dwords=request_beats * (data_width // 32))
                yield from self._issue_read_request(
                    controller, index=1, length_dwords=request_beats * (data_width // 32))

                while len(observed_requests) < 2:
                    yield

                yield from self._push_completion(
                    controller,
                    tag      = observed_requests[1],
                    channel  = 0,
                    user_id  = 0,
                    beats    = request_beats,
                    accepted = accepted,
                    timeout  = request_beats + 8,
                )
                for _ in range(4):
                    yield

            run_simulation(controller, [stim(), monitor_requests()], vcd_name=None)
            return len(accepted)

        self.assertEqual(accepted_beats(buffer_depth),      request_beats)
        self.assertEqual(accepted_beats(request_beats - 1), request_beats - 1)

    def test_tag_is_not_reused_before_buffered_completion_retires(self):
        controller = LitePCIeTLPController(
            data_width           = 128,
            address_width        = 32,
            max_pending_requests = 2,
            cmp_bufs_buffered    = True,
            cmp_buf_depth        = 2,
        )

        observed_requests = []

        @passive
        def monitor_requests():
            source = controller.master_out.sink
            while True:
                yield source.ready.eq(1)
                if (yield source.valid) and (yield source.ready):
                    observed_requests.append((yield source.tag))
                yield

        def stim():
            yield controller.master_in.source.ready.eq(1)
            yield
            yield from self._issue_read_request(controller, index=0)
            yield from self._issue_read_request(controller, index=1)
            while len(observed_requests) < 2:
                yield

            # Fill the younger request's reorder buffer while the older request is pending.
            accepted = []
            yield from self._push_completion(
                controller,
                tag      = observed_requests[1],
                channel  = 0,
                user_id  = 0,
                beats    = 2,
                accepted = accepted,
            )
            self.assertEqual(accepted, [0, 1])

            # No tag is available yet: receiving a completion must not release its tag.
            sink = controller.master_in.sink
            for _ in range(8):
                yield sink.valid.eq(1)
                yield sink.first.eq(1)
                yield sink.last.eq(1)
                yield sink.we.eq(0)
                yield sink.len.eq(8)
                yield sink.adr.eq(0x1000)
                yield
                self.assertEqual(len(observed_requests), 2)
            yield sink.valid.eq(0)

            # Retiring the older request releases its tag and permits the third request.
            accepted = []
            yield from self._push_completion(
                controller,
                tag      = observed_requests[0],
                channel  = 0,
                user_id  = 0,
                beats    = 2,
                accepted = accepted,
            )
            yield from self._issue_read_request(controller, index=2)
            while len(observed_requests) < 3:
                yield
            self.assertEqual(observed_requests[2], observed_requests[0])

        run_simulation(controller, [stim(), monitor_requests()], vcd_name=None)

    def test_split_completion_packets_hold_request_order(self):
        controller = LitePCIeTLPController(
            data_width           = 128,
            address_width        = 32,
            max_pending_requests = 4,
            cmp_bufs_buffered    = True,
        )

        observed_requests = []
        observed_completions = []

        @passive
        def monitor_requests():
            source = controller.master_out.sink
            while len(observed_requests) < 2:
                yield source.ready.eq(1)
                if (yield source.valid) and (yield source.ready):
                    observed_requests.append((yield source.tag))
                yield

        @passive
        def monitor_completions():
            source = controller.master_in.source
            while len(observed_completions) < 3:
                yield source.ready.eq(1)
                if (yield source.valid) and (yield source.ready):
                    observed_completions.append({
                        "tag":   (yield source.tag),
                        "first": (yield source.first),
                        "last":  (yield source.last),
                        "end":   (yield source.end),
                    })
                yield

        def stim():
            yield
            yield from self._issue_read_request(controller, index=0)
            yield from self._issue_read_request(controller, index=1)

            while len(observed_requests) < 2:
                yield

            accepted = []
            yield from self._push_completion(
                controller,
                tag         = observed_requests[0],
                channel     = 0,
                user_id     = 0,
                beats       = 1,
                accepted    = accepted,
                end_on_last = False,
            )
            self.assertEqual(accepted, [0])

            accepted = []
            yield from self._push_completion(
                controller,
                tag         = observed_requests[1],
                channel     = 0,
                user_id     = 0,
                beats       = 1,
                accepted    = accepted,
                end_on_last = True,
            )
            self.assertEqual(accepted, [0])

            accepted = []
            yield from self._push_completion(
                controller,
                tag         = observed_requests[0],
                channel     = 0,
                user_id     = 0,
                beats       = 1,
                accepted    = accepted,
                end_on_last = True,
            )
            self.assertEqual(accepted, [0])

            timeout = 0
            while len(observed_completions) < 3:
                timeout += 1
                if timeout > 32:
                    self.fail(f"Timed out waiting for split completions, got {observed_completions}")
                yield

        run_simulation(controller, [stim(), monitor_requests(), monitor_completions()], vcd_name=None)

        self.assertEqual([c["tag"] for c in observed_completions], [
            observed_requests[0],
            observed_requests[0],
            observed_requests[1],
        ])
        self.assertEqual([c["end"] for c in observed_completions], [0, 1, 1])

    def test_request_footprint_depth_accepts_legal_younger_completions(self):
        data_width = 128
        request_beats = _completion_beats_for(data_width)
        buffer_depth  = get_completion_buffer_depth(data_width)
        controller = LitePCIeTLPController(
            data_width           = data_width,
            address_width        = 32,
            max_pending_requests = 4,
            cmp_bufs_buffered    = False,
            cmp_buf_depth        = buffer_depth,
        )

        observed_requests = []
        accepted = []

        @passive
        def monitor_requests():
            source = controller.master_out.sink
            while len(observed_requests) < 3:
                yield source.ready.eq(1)
                if (yield source.valid) and (yield source.ready):
                    observed_requests.append((yield source.tag))
                yield

        def stim():
            yield
            for index in range(3):
                yield from self._issue_read_request(
                    controller,
                    index         = index,
                    length_dwords = request_beats * (data_width // 32),
                )

            while len(observed_requests) < 3:
                yield

            # Fill two younger tags to their exact legal footprint while the oldest request
            # is still pending. This must not stall because each tag only needs one request's
            # worth of buffering.
            for tag in observed_requests[1:]:
                accepted_for_tag = []
                yield from self._push_completion(
                    controller,
                    tag      = tag,
                    channel  = 0,
                    user_id  = 0,
                    beats    = request_beats,
                    accepted = accepted_for_tag,
                    timeout  = request_beats + 8,
                )
                accepted.extend(accepted_for_tag)

            for _ in range(4):
                yield

        run_simulation(controller, [stim(), monitor_requests()], vcd_name=None)
        self.assertEqual(len(accepted), 2 * request_beats)

    def _check_completion_buffer_accounts_for_packet_boundary_rounding(self, cmp_bufs_buffered):
        data_width = 128
        controller = LitePCIeTLPController(
            data_width           = data_width,
            address_width        = 32,
            max_pending_requests = 2,
            cmp_bufs_buffered    = cmp_bufs_buffered,
        )

        observed_requests = []
        retired_tags = []

        @passive
        def monitor_requests():
            source = controller.master_out.sink
            while len(observed_requests) < 2:
                yield source.ready.eq(1)
                if (yield source.valid) and (yield source.ready):
                    observed_requests.append((yield source.tag))
                yield

        @passive
        def monitor_completions():
            source = controller.master_in.source
            while len(retired_tags) < 2:
                yield source.ready.eq(1)
                if ((yield source.valid) and (yield source.ready) and
                    (yield source.last) and (yield source.end)):
                    retired_tags.append((yield source.tag))
                yield

        def stim():
            yield
            yield from self._issue_read_request(
                controller,
                index         = 0,
                length_dwords = 128,
                address       = 0,
            )
            yield from self._issue_read_request(
                controller,
                index         = 1,
                length_dwords = 128,
                address       = 4,
            )
            while len(observed_requests) < 2:
                yield

            # A 512-byte request starting four bytes after a 128-byte completion boundary can be
            # returned as 124 + 128 + 128 + 128 + 4 bytes. The independently packed Completion
            # TLPs occupy 8 + 8 + 8 + 8 + 1 = 33 beats on a 128-bit datapath.
            completion_sizes = [124, 128, 128, 128, 4]
            accepted = []
            for packet_index, completion_size in enumerate(completion_sizes):
                packet_beats = (completion_size + data_width//8 - 1)//(data_width//8)
                packet_accepted = []
                yield from self._push_completion(
                    controller,
                    tag           = observed_requests[1],
                    channel       = 0,
                    user_id       = 0,
                    beats         = packet_beats,
                    accepted      = packet_accepted,
                    timeout       = 8,
                    end_on_last   = packet_index == (len(completion_sizes) - 1),
                    length_dwords = completion_size//4,
                )
                self.assertEqual(len(packet_accepted), packet_beats)
                accepted.extend(packet_accepted)
            self.assertEqual(len(accepted), get_completion_buffer_depth(data_width))

            # Once the older request completes, both requests must retire in issue order.
            accepted = []
            yield from self._push_completion(
                controller,
                tag      = observed_requests[0],
                channel  = 0,
                user_id  = 0,
                beats    = 1,
                accepted = accepted,
            )
            self.assertEqual(accepted, [0])

            timeout = 0
            while len(retired_tags) < 2:
                timeout += 1
                if timeout > 64:
                    self.fail(f"Timed out waiting for completions, retired {retired_tags}")
                yield

        run_simulation(
            controller,
            [stim(), monitor_requests(), monitor_completions()],
            vcd_name=None,
        )
        self.assertEqual(retired_tags, observed_requests)

    def test_unbuffered_completion_buffer_accounts_for_packet_boundary_rounding(self):
        self._check_completion_buffer_accounts_for_packet_boundary_rounding(
            cmp_bufs_buffered=False)

    def test_buffered_completion_buffer_accounts_for_packet_boundary_rounding(self):
        self._check_completion_buffer_accounts_for_packet_boundary_rounding(
            cmp_bufs_buffered=True)
