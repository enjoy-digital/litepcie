#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY control and status over a litex_server.

python3 bench/soft/status.py --csr-csv csr.csv [status] [trace] [enable] [disable] [retrain] [speed] [disable=MASK] [loopback=N]
    [g3force=0|1]
"""

import sys
import argparse

from litex import RemoteClient

from litepcie.phy.soft.ltssm import LTSSM_STATES

STATE_NAMES = {code: name for name, code in LTSSM_STATES.items()}

def main():
    parser = argparse.ArgumentParser(description="Soft PCIe PHY control and status.")
    parser.add_argument("--csr-csv", default="csr.csv", help="CSR configuration file.")
    parser.add_argument("--host",    default="localhost", help="litex_server host.")
    parser.add_argument("--port",    default=1234, type=int, help="litex_server port.")
    parser.add_argument("commands",  nargs="*", default=["status"])
    args = parser.parse_args()

    bus = RemoteClient(csr_csv=args.csr_csv, host=args.host, port=args.port)
    bus.open()
    regs = bus.regs
    # CSR names: Physical Layer alone (pcie_phy_*), or full PHY with its debug (pcie_phy_debug_*).
    name = "pcie_phy_debug_" if hasattr(regs, "pcie_phy_debug_control") else "pcie_phy_"
    reg  = lambda n: getattr(regs, name + n)
    tracer = None
    for n in ["pcie_phy_ltssm_tracer_history", "pcie_phy_tracer_history"]:
        tracer = getattr(regs, n, tracer)

    for command in args.commands:
        if command == "status":
            status = reg("status").read()
            state  = status & 0x3f
            print(f"ltssm: {state:#04x} {STATE_NAMES.get(state, '?')}")
            for field, bit in [("l0", 8), ("link_up", 9), ("serdes_ready", 10), ("rx_elecidle", 11),
                               ("rx_polarity", 12), ("enabled", 13), ("perst", 14), ("rate", 15), ("gen3", 29)]:
                print(f"{field}: {(status >> bit) & 1}")
            print(f"link: {(status >> 16) & 0xff}, lane: {(status >> 24) & 0x1f}")
            lanes = name + "lanes"
            if hasattr(regs, lanes):
                value = getattr(regs, lanes).read()
                print(f"lanes ok: {value & 0xff:#04x}, deskew locked: {(value >> 8) & 1}, width: x{(value >> 9) & 0x1f}")
            if hasattr(regs, name + "g3_status"):
                g3 = reg("g3_status").read()
                print(f"8.0 GT/s: locked {g3 & 1}, aligned {(g3 >> 1) & 0xff:#04x}, rate_done {(g3 >> 9) & 1}, "
                      f"pll_lock {(g3 >> 10) & 1}, rate timeouts {(g3 >> 16) & 0xff}, force {reg('g3_control').read() & 1}")
            if hasattr(regs, "gt_status_status"):
                gt = regs.gt_status_status.read()
                print(f"gt: tx_ready {gt & 1}, rx_ready {(gt >> 1) & 1}, mmcm_locked {(gt >> 2) & 1}, cpll_locked {(gt >> 3) & 1}")
            for counter in ["rx_ts", "rx_ts_errors", "rx_errors", "rx_overflows", "rx_dllp", "rx_tlp", "rx_rate"]:
                print(f"{counter}: {reg(counter).read()}")
            if hasattr(regs, name + "dll_status"):
                dll = reg("dll_status").read()
                print(f"dll: state {dll & 3}, pending {(dll >> 2) & 1}, fc_ok {(dll >> 3) & 1}, tx_ready {(dll >> 4) & 1}, rx_valid {(dll >> 5) & 1}, rx_ready {(dll >> 6) & 1}")
                for counter in ["dll_replays", "dll_rx_errors", "dll_link_errors", "dll_tx_tlps", "dll_rx_tlps"]:
                    print(f"{counter}: {reg(counter).read()}")
            if hasattr(regs, "pcie_phy_link_status"):
                print(f"dl_active: {regs.pcie_phy_link_status.read() & 1}")
        elif command == "trace":
            while True:
                entry = tracer.read()
                if not (entry >> 31) & 1:
                    break
                new, old = entry & 0x3f, (entry >> 6) & 0x3f
                overflow = " (overflow)" if (entry >> 30) & 1 else ""
                print(f"{STATE_NAMES.get(old, hex(old))} -> {STATE_NAMES.get(new, hex(new))}{overflow}")
        elif command == "enable":
            reg("control").write(1)
        elif command == "disable":
            reg("control").write(0)
        elif command == "speed":
            reg("control").write(reg("control").read() | 4)
        elif command == "retrain":
            reg("control").write(reg("control").read() | 2)
        elif command.startswith("disable="):
            reg("lane_disable").write(int(command.split("=")[1], 0))
        elif command == "g3counts":
            c = reg("g3_counts").read()
            print(f"lane 0: blocks {c & 0xffff}, undefined {(c >> 16) & 0xffff}, eieos {(c >> 32) & 0xffff}, "
                  f"slips {(c >> 48) & 0xffff}, words {reg('g3_words').read()}")
        elif command == "g3raw":
            for _ in range(8):
                reg("g3_control").write((reg("g3_control").read() & 0b1010101) | 0b10)
                print(f"tx {reg('g3_raw_tx').read():010x} rx {reg('g3_raw_rx').read():010x}")
        elif command == "g3trace":
            reg("g3_control").write((reg("g3_control").read() & 0b1010101) | 0b1000)
        elif command == "g3dump":
            names = {v: k for k, v in LTSSM_STATES.items()}
            seq   = ["IDLE", "CLOCK", "PMA-HOLD", "DRP", "PMA-RELEASE", "GT", "RX-RESET", "RX-READY"]
            for i in range(reg("g3_trace_count").read()):
                reg("g3_trace_index").write(i)
                e = reg("g3_trace_data").read()
                print(f"{(e >> 26)*8.192:12.1f} us  {names.get(e & 0x3f, hex(e & 0x3f)):30s} rate {(e >> 6) & 3} "
                      f"pll_sel {(e >> 8) & 1} done {(e >> 9) & 1} seq {seq[(e >> 10) & 7]:11s} "
                      f"eidle gt {(e >> 13) & 1} ltssm {(e >> 14) & 1} locked {(e >> 15) & 1} "
                      f"ec {(e >> 20) & 3} x{(e >> 16) & 15} ts {(e >> 22) & 15}")
        elif command.startswith("g3capture="):
            # Arm the raw capture of Lane 0, delay in 200 MHz cycles after the trigger.
            reg("g3_capture_delay").write(int(command.split("=")[1], 0))
            reg("g3_control").write((reg("g3_control").read() & 0b1010101) | 0b100000)
        elif command == "g3words":
            print(f"done {reg('g3_capture_done').read()}")
            for i in range(1024):
                reg("g3_capture_index").write(i)
                print(f"{reg('g3_capture_data').read():010x}")
        elif command.startswith("g3eidle="):
            reg("g3_control").write((reg("g3_control").read() & 0b1010001) | (int(command.split("=")[1]) << 2))
        elif command.startswith("g3lpm="):
            reg("g3_control").write((reg("g3_control").read() & 0b1000101) | (int(command.split("=")[1]) << 4))
        elif command.startswith("g3xyden="):
            reg("g3_control").write((reg("g3_control").read() & 0b0010101) | (int(command.split("=")[1]) << 6))
        elif command.startswith("g3cdr="):
            [getattr(regs, n) for n in regs.__dict__ if n.endswith("gen3_rxcdr_cfg")][0].write(int(command.split("=")[1], 0))
        elif command == "g3cdr":
            print(f"gen3 RXCDR_CFG {[getattr(regs, n) for n in regs.__dict__ if n.endswith('gen3_rxcdr_cfg')][0].read():#020x}")
        elif command.startswith("g3force="):
            reg("g3_control").write(int(command.split("=")[1]))
        elif command.startswith("loopback="):
            reg("loopback").write(int(command.split("=")[1]))
        else:
            sys.exit(f"Unknown command: {command}")
    bus.close()

if __name__ == "__main__":
    main()
