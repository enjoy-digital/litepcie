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
    def __init__(self, timer_scale=1000, ts1_min=16, ts_period=8, latency=4, gen2=(False, False), fail_5g=False,
        gen3=(False, False), fail_8g=False, eq_phases23=True):
        self.submodules.up = up = PCIeLTSSM(125e6, upstream=True,  timer_scale=timer_scale, ts1_min=ts1_min,
            gen2_capable=gen2[0], gen3_capable=gen3[0])
        self.submodules.dn = dn = PCIeLTSSM(125e6, upstream=False, timer_scale=timer_scale, ts1_min=ts1_min,
            gen2_capable=gen2[1], gen3_capable=gen3[1], eq_phases23=eq_phases23)
        self.comb += dn.link_number.eq(0x12)
        self.comb += [up.eq_eval_done.eq(1), dn.eq_eval_done.eq(1)]
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
            fields = ["ts2", "link", "link_pad", "lane", "lane_pad", "rate", "ctrl", "eq_info"]
            pipe = [done] + [getattr(a, "tx_ts2" if f == "ts2" else "tx_ts_" + f) for f in fields]
            for _ in range(latency):
                stage = [Signal(len(s)) for s in pipe]
                self.sync += [n.eq(o) for n, o in zip(stage, pipe)]
                pipe = stage
            # Nothing received at another rate, nor at 5.0 GT/s on the upstream with fail_5g, nor after Phase 1 at
            # 8.0 GT/s with fail_8g (equalization failing).
            fail = Signal()
            if fail_8g:
                self.sync += If(b.state == LTSSM_STATES["Recovery.Equalization.Phase2"], fail.eq(1)).Elif(b.rate != 2, fail.eq(0))
            self.comb += b.rx_ts.eq(pipe[0] & ~a.tx_elecidle & (a.rate == b.rate) & ~(fail_5g & (b is up) & (b.rate == 1)) & ~fail)
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

    def speed_trace(self, dut, budget=60000):
        def request(dut):
            yield dut.dn.speed_change.eq(1)
            yield
            yield dut.dn.speed_change.eq(0)
        def speed_entered(dut):
            return ((yield dut.up.state) == LTSSM_STATES["Recovery.Speed"]) | ((yield dut.dn.state) == LTSSM_STATES["Recovery.Speed"])
        results = {}
        def check(dut):
            results["rate"] = ((yield dut.up.rate), (yield dut.dn.rate))
            return True
        trace, cycles = run_pair(dut, [(both_l0, request), (speed_entered, None), (both_l0, None), (check, None)], budget=budget)
        trace_str = "\n".join(f"{c:6d} {s} {n}" for c, s, n in trace)
        self.assertEqual(len(cycles), 4, "Not back in L0:\n" + trace_str)
        return trace, results["rate"], trace_str

    def test_speed_change(self):
        # Directed by the downstream, followed by the upstream on its TS1: 5.0 GT/s after one Recovery.
        trace, rate, trace_str = self.speed_trace(LTSSMPair(gen2=(True, True)))
        self.assertEqual(rate, (1, 1), trace_str)
        for side in "ud":
            states = [n for c, s, n in trace if s == side]
            self.assertEqual(states[states.index("L0") + 1:], [
                "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Speed",
                "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Idle", "L0"], trace_str)

    def test_speed_change_failed(self):
        # The upstream can't lock at 5.0 GT/s: both back to 2.5 GT/s and to L0, without a new training.
        trace, rate, trace_str = self.speed_trace(LTSSMPair(gen2=(True, True), fail_5g=True))
        self.assertEqual(rate, (0, 0), trace_str)
        for side in "ud":
            states = [n for c, s, n in trace if s == side]
            self.assertEqual(states.count("Detect.Quiet"), 1, trace_str)
            self.assertEqual(states.count("Recovery.Speed"), 2, trace_str)

    def test_speed_change_gen1_partner(self):
        # The partner advertises 2.5 GT/s only: the request is ignored.
        dut = LTSSMPair(gen2=(True, False))
        results = {}
        def request(dut):
            yield dut.up.speed_change.eq(1)
            yield
            yield dut.up.speed_change.eq(0)
        def later(dut):
            yield from ()
            results["count"] = results.get("count", 0) + 1
            return results["count"] == 2000
        def check(dut):
            results["state"] = (yield dut.up.state)
            results["rate"]  = (yield dut.up.rate)
            return True
        run_pair(dut, [(both_l0, request), (later, None), (check, None)])
        self.assertEqual(results["state"], LTSSM_STATES["L0"])
        self.assertEqual(results["rate"], 0)

class TestSoftLTSSMGen3(unittest.TestCase):
    def speed_trace(self, dut, budget=200000):
        return TestSoftLTSSM.speed_trace(self, dut, budget=budget)

    def test_speed_change_8g(self):
        # 8.0 GT/s from 2.5 GT/s in one speed change, equalization with its four phases, then L0.
        trace, rate, trace_str = self.speed_trace(LTSSMPair(gen3=(True, True)))
        self.assertEqual(rate, (2, 2), trace_str)
        up = [n for c, s, n in trace if s == "u"]
        dn = [n for c, s, n in trace if s == "d"]
        self.assertEqual(up[up.index("L0") + 1:], [
            "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Speed", "Recovery.RcvrLock",
            "Recovery.Equalization.Phase0", "Recovery.Equalization.Phase1", "Recovery.Equalization.Phase2",
            "Recovery.Equalization.Phase3", "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Idle", "L0"], trace_str)
        self.assertEqual(dn[dn.index("L0") + 1:], [
            "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Speed", "Recovery.RcvrLock",
            "Recovery.Equalization.Phase1", "Recovery.Equalization.Phase2", "Recovery.Equalization.Phase3",
            "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Idle", "L0"], trace_str)

    def test_speed_change_8g_phase1_only(self):
        # The downstream port skips Phases 2 and 3: the upstream goes back to Recovery.RcvrLock from Phase 1.
        trace, rate, trace_str = self.speed_trace(LTSSMPair(gen3=(True, True), eq_phases23=False))
        self.assertEqual(rate, (2, 2), trace_str)
        up = [n for c, s, n in trace if s == "u"]
        self.assertEqual(up[up.index("Recovery.Equalization.Phase0"):up.index("Recovery.Equalization.Phase0") + 3], [
            "Recovery.Equalization.Phase0", "Recovery.Equalization.Phase1", "Recovery.RcvrLock"], trace_str)

    def test_speed_change_8g_gen2_partner(self):
        # 5.0 GT/s partner: 5.0 GT/s, no EQ TS2, no equalization.
        trace, rate, trace_str = self.speed_trace(LTSSMPair(gen2=(False, True), gen3=(True, False)))
        self.assertEqual(rate, (1, 1), trace_str)
        self.assertFalse(any("Equalization" in n for c, s, n in trace), trace_str)

    def test_speed_change_8g_eq_failed(self):
        # Nothing received from Phase 2: timeouts, back to 2.5 GT/s through Recovery.Speed, then L0.
        dut = LTSSMPair(gen3=(True, True), fail_8g=True)
        def request(dut):
            yield dut.dn.speed_change.eq(1)
            yield
            yield dut.dn.speed_change.eq(0)
        def speed_entered(dut):
            return ((yield dut.dn.state) == LTSSM_STATES["Recovery.Speed"])
        def eq_entered(dut):
            return ((yield dut.dn.state) == LTSSM_STATES["Recovery.Equalization.Phase2"])
        results = {}
        def check(dut):
            results["rate"] = ((yield dut.up.rate), (yield dut.dn.rate))
            return True
        trace, cycles = run_pair(dut, [(both_l0, request), (speed_entered, None), (eq_entered, None), (both_l0, None),
            (check, None)], budget=400000)
        trace_str = "\n".join(f"{c:6d} {s} {n}" for c, s, n in trace)
        self.assertEqual(len(cycles), 5, "Not back in L0:\n" + trace_str)
        self.assertEqual(results["rate"], (0, 0), trace_str)
