#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *

from litepcie.phy.soft.ltssm import PCIeLTSSM, LTSSM_STATES

STATE_NAMES = {v: k for k, v in LTSSM_STATES.items()}

class LTSSMPair(Module):
    """Upstream and downstream LTSSMs connected at the PIPE interface level by a behavioral link:
    a Training Sequence is delivered to the partner `latency` cycles after being transmitted (one
    transmitted every `ts_period` cycles while enabled), the Logical Idle handshake completes when
    both sides are in it, receiver detection always succeeds, Electrical Idle is the partner's."""
    def __init__(self, timer_scale=1000, ts1_min=16, ts_period=8, latency=4):
        self.submodules.up = up = PCIeLTSSM(125e6, upstream=True,  timer_scale=timer_scale, ts1_min=ts1_min)
        self.submodules.dn = dn = PCIeLTSSM(125e6, upstream=False, timer_scale=timer_scale, ts1_min=ts1_min)
        self.comb += dn.link_number.eq(0x12)
        for a, b in [(up, dn), (dn, up)]:
            # Training Sequences a -> b.
            count = Signal(max=ts_period)
            done  = Signal()
            self.sync += [
                done.eq(0),
                If(a.tx_ts_enable,
                    If(count == ts_period - 1,
                        count.eq(0),
                        done.eq(1),
                    ).Else(
                        count.eq(count + 1)
                    )
                ).Else(
                    count.eq(0)
                )
            ]
            self.comb += a.tx_ts_done.eq(done)
            # Delivered to b with the fields latched at transmission.
            fields = ["ts2", "link", "link_pad", "lane", "lane_pad", "n_fts", "rate", "ctrl"]
            pipe = [done] + [getattr(a, "tx_ts2" if f == "ts2" else "tx_ts_" + f) for f in fields]
            for _ in range(latency):
                stage = [Signal(len(s)) for s in pipe]
                self.sync += [n.eq(o) for n, o in zip(stage, pipe)]
                pipe = stage
            self.comb += b.rx_ts.eq(pipe[0] & ~a.tx_elecidle)
            for f, s in zip(fields, pipe[1:]):
                self.comb += getattr(b, "rx_ts_" + f).eq(s)
            # Electrical Idle, receiver detection.
            self.comb += b.rx_elecidle.eq(a.tx_elecidle)
            self.sync += [b.detect_done.eq(b.tx_detect_rx), b.rx_detected.eq(1)]
        # Logical Idle handshake: completes a few cycles after both are in it.
        both   = Signal()
        hs_cnt = Signal(4)
        self.comb += both.eq(up.idle_hs & dn.idle_hs)
        self.sync += If(~both, hs_cnt.eq(0)).Elif(hs_cnt != 15, hs_cnt.eq(hs_cnt + 1))
        self.comb += [up.idle_hs_done.eq(hs_cnt >= 8), dn.idle_hs_done.eq(hs_cnt >= 8)]

def run_pair(dut, steps, budget=20000):
    """Run until each step's condition is met in order; returns the state trace and the cycles."""
    trace  = []
    cycles = []
    def generator():
        last = [None, None]
        step = 0
        for cycle in range(budget):
            for i, ltssm in enumerate([dut.up, dut.dn]):
                state = (yield ltssm.state)
                if state != last[i]:
                    trace.append((cycle, "ud"[i], STATE_NAMES.get(state, hex(state))))
                    last[i] = state
            if step < len(steps):
                cond, action = steps[step]
                if (yield from cond(dut)):
                    cycles.append(cycle)
                    if action is not None:
                        yield from action(dut)
                    step += 1
                    if step == len(steps):
                        return
            yield
    run_simulation(dut, generator())
    return trace, cycles

def both_l0(dut):
    return ((yield dut.up.l0) and (yield dut.dn.l0))

def both_not_l0(dut):
    return not ((yield dut.up.l0) or (yield dut.dn.l0))

class TestSoftLTSSM(unittest.TestCase):
    def test_training(self):
        dut = LTSSMPair()
        trace, cycles = run_pair(dut, [(both_l0, None)])
        trace_str = "\n".join(f"{c:6d} {s} {n}" for c, s, n in trace)
        self.assertEqual(len(cycles), 1, "No L0:\n" + trace_str)
        for side in "ud":
            states = [n for c, s, n in trace if s == side]
            self.assertEqual(states, [
                "Detect.Quiet", "Detect.Active", "Polling.Active", "Polling.Configuration",
                "Configuration.Linkwidth.Start", "Configuration.Linkwidth.Accept",
                "Configuration.Lanenum.Wait", "Configuration.Lanenum.Accept",
                "Configuration.Complete", "Configuration.Idle", "L0"], trace_str)
        # Link Number from the downstream, Lane 0.
        results = {}
        def check(dut):
            results["link"] = ((yield dut.up.link), (yield dut.dn.link))
            results["lane"] = ((yield dut.up.lane), (yield dut.dn.lane))
            return True
        run_pair(LTSSMPair(), [(both_l0, None), (check, None)])
        self.assertEqual(results["link"], (0x12, 0x12))
        self.assertEqual(results["lane"], (0, 0))

    def test_recovery(self):
        # Link Retrain from the upstream: both through Recovery back to L0.
        dut = LTSSMPair()
        def retrain(dut):
            yield dut.up.retrain.eq(1)
            yield
            yield dut.up.retrain.eq(0)
        trace, cycles = run_pair(dut, [(both_l0, retrain), (both_not_l0, None), (both_l0, None)])
        trace_str = "\n".join(f"{c:6d} {s} {n}" for c, s, n in trace)
        self.assertEqual(len(cycles), 3, trace_str)
        for side in "ud":
            states = [n for c, s, n in trace if s == side]
            self.assertEqual(states[states.index("L0") + 1:], [
                "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Idle", "L0"], trace_str)

    def test_hot_reset(self):
        # Downstream directed Hot Reset: TS1 with the Hot Reset bit in Recovery.Idle, both reset.
        dut = LTSSMPair()
        def request(dut):
            yield dut.dn.hot_reset_req.eq(1)
        def up_hot_reset(dut):
            return (yield dut.up.hot_reset)
        def up_detect(dut):
            return (yield dut.up.state) == LTSSM_STATES["Detect.Quiet"]
        trace, cycles = run_pair(dut, [(both_l0, request), (up_hot_reset, None), (up_detect, None)])
        trace_str = "\n".join(f"{c:6d} {s} {n}" for c, s, n in trace)
        self.assertEqual(len(cycles), 3, trace_str)
        # Both through Recovery to Hot Reset then Detect (the downstream restarts as soon as it sees
        # the upstream's activity).
        for side in "ud":
            states = [n for c, s, n in trace if s == side]
            self.assertEqual(states[states.index("L0") + 1:][:5], [
                "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Idle", "Hot_Reset", "Detect.Quiet"], trace_str)

    def test_timeouts_back_to_detect(self):
        # Without partner Training Sequences, Polling.Active times out back to Detect.
        dut = LTSSMPair()
        dut.comb += dut.dn.enable.eq(0) # Downstream held in Detect.Quiet.
        def up_polling(dut):
            return (yield dut.up.state) == LTSSM_STATES["Polling.Active"]
        def up_back(dut):
            return (yield dut.up.state) == LTSSM_STATES["Detect.Quiet"]
        trace, cycles = run_pair(dut, [(up_polling, None), (up_back, None)], budget=30000)
        trace_str = "\n".join(f"{c:6d} {s} {n}" for c, s, n in trace)
        self.assertEqual(len(cycles), 2, trace_str)
        # 24 ms / 1000 at 125 MHz = 3000 cycles.
        self.assertGreater(cycles[1] - cycles[0], 2900)
