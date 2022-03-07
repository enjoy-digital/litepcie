#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2022 Sylvain Munaut <tnt@246tNt.com>
# SPDX-License-Identifier: BSD-2-Clause

import os
import argparse
import socket

from litex import RemoteClient

# PCIe LTSSM Dictionary ----------------------------------------------------------------------------

PCIE_LTSSM = {
    0x00: "Detect.Quiet",
    0x01: "Detect.Active",
    0x02: "Polling.Active",
    0x03: "Polling.Compliance",
    0x04: "Polling.Configuration",
    0x05: "Configuration.Linkwidth.Start",
    0x06: "Configuration.Linkwidth.Accept",
    0x07: "Configuration.Lanenum.Accept",
    0x08: "Configuration.Lanenum.Wait",
    0x09: "Configuration.Complete",
    0x0A: "Configuration.Idle",
    0x0B: "Recovery.RcvrLock",
    0x0C: "Recovery.Speed",
    0x0D: "Recovery.RcvrCfg",
    0x0E: "Recovery.Idle",
    0x10: "L0",
    0x17: "L1.Entry",
    0x18: "L1.Idle",
    0x20: "Disabled",
    0x21: "Loopback_Entry_Master",
    0x22: "Loopback_Active_Master",
    0x23: "Loopback_Exit_Master",
    0x24: "Loopback_Entry_Slave",
    0x25: "Loopback_Active_Slave",
    0x26: "Loopback_Exit_Slave",
    0x27: "Hot_Reset",
    0x28: "Recovery_Equalization_Phase0",
    0x29: "Recovery_Equalization_Phase1",
    0x2a: "Recovery_Equalization_Phase2",
    0x2b: "Recovery_Equalization_Phase3",
}

# PCIe LTSSM Tracer --------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LitePCIe LTSSM tracer.")
    parser.add_argument("--csr-csv", default="csr.csv", help="CSR configuration file")
    parser.add_argument("--port",    default="1234",    help="Host bind port.")
    args = parser.parse_args()

    wb = RemoteClient(
        csr_csv = args.csr_csv,
        port    = int(args.port, 0)
    )
    wb.open()

    # Read history
    while True:
        v = wb.regs.pcie_phy_ltssm_tracer_history.read()

        ltssm_new = (v >>  0) & 0x3f
        ltssm_old = (v >>  6) & 0x3f
        overflow  = (v >> 30) & 1
        valid     = (v >> 31) & 1

        if not valid:
            break

        print(f"[0x{ltssm_old:02x}] {PCIE_LTSSM.get(ltssm_old, 'reserved'):<32s} -> [0x{ltssm_new:02x}] {PCIE_LTSSM.get(ltssm_new, 'reserved'):<32s}{('[Overflow, possible unknown intermediate states]' if overflow else ''):s}")


if __name__ == "__main__":
    main()
