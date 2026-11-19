#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# Randomized stress of LitePCIeTLPController: random read requests, a Host model that splits the
# Completions at RCB boundaries and returns them in any legal order (or never), a user that stalls
# and flushes the controller with requests in flight. Checks that the data comes out in request
# order, that every request is terminated exactly once, that a tag is never reused while the Host
# still owns it and that nothing deadlocks.

import random
import unittest
import pytest

from types import SimpleNamespace

from migen import *

from litex.gen import *

from litepcie.tlp.controller import LitePCIeTLPController, get_completion_buffer_depth

# Stress -------------------------------------------------------------------------------------------

def split_request(rng, adr, nbytes, rcb, mps, merge_p):
    # Legal Completion boundaries: RCB-aligned addresses. Then merge neighbours up to MPS.
    pieces = []
    a, end = adr, adr + nbytes
    while a < end:
        b = min(end, (a//rcb + 1)*rcb)
        pieces.append(b - a)
        a = b
    pkts = [pieces[0]]
    for p in pieces[1:]:
        if rng.random() < merge_p and pkts[-1] + p <= mps:
            pkts[-1] += p
        else:
            pkts.append(p)
    return pkts

def run(args, seed):
    rng  = random.Random(seed)
    cls  = LitePCIeTLPController
    dw   = args.data_width
    bb   = dw//8
    kw   = dict(data_width=dw, address_width=32, max_pending_requests=args.pending)
    if args.depth is not None:
        kw["cmp_buf_depth"] = args.depth
    if args.cmp_timeout != 0:
        kw["cmp_timeout"] = args.cmp_timeout
    if args.shared:
        kw["cmp_bufs_shared"] = True
    dut  = cls(**kw)

    st = dict(issued=[], host=[], retired=0, progress=0, cycle=0, errors=[], maxout=0)
    outstanding = {}   # idx -> dict(idx, tag, pkts, pos)
    order       = []   # idx in issue order (host view), still having packets.
    st.update(exp=0, hold=False, stale=set(), lost=set(), late=0, resets=0, tagdup=0, terms=0, timeouts=0)

    @passive
    def req_gen():
        sink = dut.master_in.sink
        for _ in range(40): yield
        for i in range(args.requests):
            while st["hold"]:
                yield
            for _ in range(rng.choice([0, 0, 0, 1, 2, 5]) if rng.random() < args.req_gap_p else 0):
                yield
            ndw = 128 if rng.random() < 0.6 else rng.randint(1, 128)
            adr = 0x10000*(i + 1) + (0 if rng.random() < args.aligned_p else 4*rng.randint(0, 255))
            st["issued"].append((adr, ndw))
            st["busy"] = True
            yield sink.valid.eq(1); yield sink.first.eq(1); yield sink.last.eq(1)
            yield sink.we.eq(0); yield sink.adr.eq(adr); yield sink.len.eq(ndw)
            yield sink.channel.eq(0); yield sink.user_id.eq(i & 0xff)
            yield
            while not (yield sink.ready):
                yield
            st["progress"] = st["cycle"]
            yield sink.valid.eq(0)
            st["busy"] = False

    @passive
    def host_req():
        src = dut.master_out.sink
        k = 0
        while True:
            rdy = 1 if rng.random() > args.tx_stall_p else 0
            yield src.ready.eq(rdy)
            yield
            if (yield src.valid) and (yield src.ready) and (yield src.last) and not (yield src.we):
                tag = (yield src.tag); adr = (yield src.adr); ndw = (yield src.len)
                if (adr, ndw) != st["issued"][k]:
                    st["errors"].append(f"request {k} mismatch")
                if tag in [o["tag"] for o in outstanding.values()]:
                    st["tagdup"] += 1
                    if not args.late_p: st["errors"].append(f"cycle {st['cycle']}: tag {tag} reissued while outstanding at the Host")
                pkts = split_request(rng, adr, ndw*4, args.rcb, args.mps, args.merge_p)
                if rng.random() < args.lose_p:
                    st["lost"].add(k)     # The Host never completes it.
                else:
                    late = (k < args.requests//3) and (rng.random() < args.late_p)
                    st["late"] += late
                    outstanding[k] = dict(idx=k, tag=tag, pkts=pkts, pos=0, t=st["cycle"],
                        lat=args.late_delay if late else args.latency)
                    order.append(k)
                st["maxout"] = max(st["maxout"], len(order))
                k += 1

    def pick():
        if not order: return None
        lat = [t for t in order if st["cycle"] - outstanding[t]["t"] >= outstanding[t]["lat"]]
        if not lat: return None
        if args.policy == "inorder":
            return lat[0]
        if args.policy == "random":
            return rng.choice(lat)
        if args.policy == "youngest":
            return lat[-1]
        if args.policy == "oldest_last":
            # The oldest request is completed only when the controller can't issue anything more.
            others = [t for t in lat if t != order[0]]
            if others: return rng.choice(others)
            if st["cycle"] - st["progress"] > args.hold: return order[0]
            return None
        raise ValueError

    @passive
    def host_cmp():
        sink = dut.master_out.source
        while True:
            yield sink.valid.eq(0)
            if rng.random() < args.cmp_gap_p:
                yield; continue
            key = pick()
            if key is None:
                yield; continue
            o    = outstanding[key]
            tag  = o["tag"]
            nb   = o["pkts"][o["pos"]]
            last_pkt = (o["pos"] == len(o["pkts"]) - 1)
            beats = (nb + bb - 1)//bb
            for b in range(beats):
                yield sink.valid.eq(1)
                yield sink.first.eq(b == 0); yield sink.last.eq(b == beats - 1)
                yield sink.len.eq(nb//4); yield sink.tag.eq(tag)
                yield sink.end.eq(1 if last_pkt else 0); yield sink.err.eq(0)
                yield sink.dat.eq((o["idx"] << 32) | (o["pos"] << 16) | b)
                yield
                while not (yield sink.ready):
                    yield
                st["progress"] = st["cycle"]
            o["pos"] += 1
            if last_pkt:
                del outstanding[key]; order.remove(key)

    @passive
    def user():
        src = dut.master_in.source
        exp_pos, exp_b = 0, 0
        stall = 0
        while True:
            if stall == 0 and rng.random() < args.user_stall_p:
                stall = rng.choice([1, 2, 4, 16, args.user_stall_max])
            rdy = 0 if stall else 1
            if stall: stall -= 1
            yield src.ready.eq(rdy)
            yield
            if (yield src.valid) and (yield src.ready):
                st["progress"] = st["cycle"]
                strict = (not args.late_p) or (st["exp"] >= 2*args.requests//3)
                if (yield src.err):
                    # Error termination: one beat, in request order, for a flushed/lost request.
                    st["terms"] += 1
                    if not ((yield src.last) and (yield src.first)):
                        st["errors"].append(f"cycle {st['cycle']}: error beat without first/last")
                    if strict and st["exp"] not in st["stale"] and st["exp"] not in st["lost"] and len(st["errors"]) < 5:
                        st["errors"].append(f"cycle {st['cycle']}: request {st['exp']} terminated with an error")
                    st["exp"] += 1; exp_pos = 0; exp_b = 0
                    st["retired"] += 1
                    continue
                d = (yield src.dat)
                got = (d >> 32, (d >> 16) & 0xffff, d & 0xffff)
                exp_idx = st["exp"]
                if not strict:
                    # Late Completions may corrupt the requests reusing their tags: only count the
                    # terminations (one per request).
                    if (yield src.last) and (yield src.end):
                        st["exp"] += 1; exp_pos = 0; exp_b = 0
                        st["retired"] += 1
                    continue
                if got != (exp_idx, exp_pos, exp_b) and len(st["errors"]) < 5:
                    st["errors"].append(f"cycle {st['cycle']}: data {got}, expected {(exp_idx, exp_pos, exp_b)}")
                    st["exp"], exp_pos, exp_b = got
                exp_b += 1
                if (yield src.last):
                    exp_pos += 1; exp_b = 0
                    if (yield src.end):
                        st["exp"] += 1; exp_pos = 0
                        st["retired"] += 1

    @passive
    def resetter():
        while True:
            for _ in range(rng.randint(args.reset_every//2, args.reset_every*3//2) if args.reset_every else 10**9):
                yield
            st["hold"] = True
            while st.get("busy", False):
                yield
            yield; yield
            # Terminated with an error: the requests not fully delivered at this point.
            for i in range(st["exp"], len(st["issued"])):
                st["stale"].add(i)
            yield dut.ctrl_rst.eq(1)
            yield
            yield dut.ctrl_rst.eq(0)
            while st["exp"] < len(st["issued"]):
                yield
            for _ in range(args.pending + 8): yield
            st["resets"] += 1; st["progress"] = st["cycle"]
            st["hold"] = False

    def watchdog():
        while st["retired"] < args.requests:
            st["cycle"] += 1
            if st["cycle"] - st["progress"] > args.timeout:
                st["errors"].append(
                    f"DEADLOCK at cycle {st['cycle']}: retired {st['retired']}/{args.requests}, "
                    f"host outstanding (issue order) " +
                    str([(outstanding[t]['tag'], t, outstanding[t]['pos'], len(outstanding[t]['pkts'])) for t in order]))
                return
            yield

    run_simulation(dut, [req_gen(), host_req(), host_cmp(), user(), resetter(), watchdog()])
    return st


def stress_args(**kwargs):
    args = dict(
        data_width     = 64,     # Datapath width.
        pending        = 8,      # Max pending requests.
        depth          = None,   # Completion buffers depth (None: default).
        requests       = 200,    # Read requests.
        policy         = "random", # Host Completion order: inorder, random, youngest, oldest_last.
        rcb            = 64,     # Host Read Completion Boundary (bytes).
        mps            = 256,    # Host Max Payload Size (bytes).
        merge_p        = 0.5,    # Probability to merge two RCB pieces in one Completion.
        aligned_p      = 0.5,    # Probability of a RCB-aligned request.
        latency        = 0,      # Host latency (cycles).
        hold           = 50,     # oldest_last: cycles without progress before the oldest request.
        req_gap_p      = 0.2,
        cmp_gap_p      = 0.1,
        tx_stall_p     = 0.1,
        user_stall_p   = 0.02,
        user_stall_max = 200,
        timeout        = 3000,   # Cycles without progress reported as a deadlock.
        reset_every    = 0,      # ctrl_rst about every N cycles (0: never).
        lose_p         = 0,      # Probability that the Host never completes a request.
        late_p         = 0,      # Probability that the Host completes a request after late_delay
        late_delay     = 0,      # cycles (first third of the requests, last third checked).
        cmp_timeout    = 0,      # Controller's cmp_timeout (0: default).
        shared         = False,  # Completion buffers of all the tags in one memory.
    )
    args.update(kwargs)
    return SimpleNamespace(**args)

# Tests --------------------------------------------------------------------------------------------

class TestTLPControllerStress(unittest.TestCase):
    shared = False

    def stress_args(self, **kwargs):
        return stress_args(shared=self.shared, **kwargs)

    def stress(self, seeds=2, **kwargs):
        args = self.stress_args(**kwargs)
        for seed in range(seeds):
            with self.subTest(seed=seed, **kwargs):
                st = run(args, seed)
                self.assertEqual(st["errors"], [])
                self.assertEqual(st["retired"], args.requests)
                if not args.late_p:
                    self.assertEqual(st["tagdup"], 0)
        return st

    def test_completion_orders(self):
        # Any legal Completion order, buffers at their default depth.
        for data_width in [64, 128, 256, 512]:
            for policy in ["inorder", "random", "youngest", "oldest_last"]:
                self.stress(data_width=data_width, policy=policy, seeds=1)

    def test_max_pending_requests(self):
        for pending in [2, 4, 32]:
            self.stress(pending=pending, policy="oldest_last", seeds=1)

    def test_rcb_128(self):
        self.stress(rcb=128, mps=512, policy="youngest")

    def test_completion_buffer_depth_is_tight(self):
        # One beat less than the default depth deadlocks with unaligned requests whose oldest
        # Completion comes last: the default depth is the minimum.
        for data_width in [64, 512]:
            depth = get_completion_buffer_depth(data_width, buffered=True) - 1
            st = run(self.stress_args(data_width=data_width, depth=depth, policy="oldest_last",
                aligned_p=0, merge_p=0.3, requests=300), seed=0)
            self.assertTrue(any("DEADLOCK" in e for e in st["errors"]))

    def test_flush_with_requests_in_flight(self):
        for data_width, pending in [(64, 8), (256, 32)]:
            st = self.stress(data_width=data_width, pending=pending, latency=60, reset_every=2000,
                requests=300)
            self.assertGreater(st["resets"], 0)
            self.assertGreater(st["terms"], 0)

    def test_lost_completions(self):
        # Each lost request, and only these, is terminated with an error after the timeout.
        st = self.stress(lose_p=0.03, cmp_timeout=500, timeout=4000, user_stall_max=100,
            requests=300)
        self.assertGreater(len(st["lost"]), 0)
        self.assertEqual(st["terms"], len(st["lost"]))

    def test_lost_completions_without_timeout_deadlock(self):
        st = run(self.stress_args(lose_p=0.05, cmp_timeout=None, timeout=4000), seed=0)
        self.assertTrue(any("DEADLOCK" in e for e in st["errors"]))

    def test_late_completions(self):
        # Completions arriving after their request timed out, while no tag is reused: dropped,
        # the requests sent afterwards are delivered correctly.
        for data_width, policy in [(64, "random"), (256, "youngest"), (512, "oldest_last")]:
            st = self.stress(data_width=data_width, policy=policy, late_p=0.1, late_delay=600,
                cmp_timeout=400, timeout=4000, user_stall_max=100, hold=20, requests=450)
            self.assertGreater(st["late"], 0)

    def test_flush_and_lost_completions(self):
        self.stress(data_width=128, pending=16, policy="youngest", latency=60, reset_every=3000,
            lose_p=0.03, cmp_timeout=500, timeout=4000, user_stall_max=100, hold=20, requests=300)

@pytest.mark.slow
class TestTLPControllerStressSharedBuffers(TestTLPControllerStress):
    # Same tests with the Completion buffers of all the tags in one memory.
    shared = True

if __name__ == "__main__":
    unittest.main()
