#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY control and status over a litex_server.

python3 bench/soft/status.py --csr-csv csr.csv [status] [trace] [enable] [disable] [retrain] [speed] [disable=MASK] [loopback=N]
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
    # CSR names: Physical Layer alone (pcie_phy_*), or under the endpoint.
    name = "pcie_endpoint_phy_debug_" if hasattr(regs, "pcie_endpoint_phy_debug_control") else "pcie_phy_"
    reg  = lambda n: getattr(regs, name + n)
    tracer = None
    for n in ["pcie_endpoint_phy_ltssm_tracer_history", "pcie_phy_tracer_history"]:
        tracer = getattr(regs, n, tracer)

    for command in args.commands:
        if command == "status":
            status = reg("status").read()
            state  = status & 0x3f
            print(f"ltssm: {state:#04x} {STATE_NAMES.get(state, '?')}")
            for field, bit in [("l0", 8), ("link_up", 9), ("serdes_ready", 10), ("rx_elecidle", 11),
                               ("rx_polarity", 12), ("enabled", 13), ("perst", 14), ("rate", 15)]:
                print(f"{field}: {(status >> bit) & 1}")
            print(f"link: {(status >> 16) & 0xff}, lane: {(status >> 24) & 0x1f}")
            lanes = name + "lanes"
            if hasattr(regs, lanes):
                value = getattr(regs, lanes).read()
                print(f"lanes ok: {value & 0xff:#04x}, deskew locked: {(value >> 8) & 1}, width: x{(value >> 9) & 0x1f}")
            if hasattr(regs, "gt_status_status"):
                gt = regs.gt_status_status.read()
                print(f"gt: tx_ready {gt & 1}, rx_ready {(gt >> 1) & 1}, mmcm_locked {(gt >> 2) & 1}, cpll_locked {(gt >> 3) & 1}")
            for counter in ["rx_ts", "rx_ts_errors", "rx_errors", "rx_overflows", "rx_dllp", "rx_tlp", "rx_rate"]:
                print(f"{counter}: {reg(counter).read()}")
            if hasattr(regs, "pcie_endpoint_phy_link_status"):
                print(f"dl_active: {regs.pcie_endpoint_phy_link_status.read() & 1}")
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
        elif command.startswith("loopback="):
            reg("loopback").write(int(command.split("=")[1]))
        else:
            sys.exit(f"Unknown command: {command}")
    bus.close()

if __name__ == "__main__":
    main()
