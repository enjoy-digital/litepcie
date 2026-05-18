#!/usr/bin/env python3

# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import argparse
import subprocess
import sys
from pathlib import Path


DEFAULT_DEVICES = (
    # Xilinx 7-Series.
    ("10ee", "7021"),
    ("10ee", "7022"),
    ("10ee", "7024"),
    ("10ee", "7028"),
    # Xilinx Ultrascale.
    ("10ee", "8021"),
    ("10ee", "8022"),
    ("10ee", "8024"),
    ("10ee", "8028"),
    ("10ee", "8031"),
    ("10ee", "8032"),
    ("10ee", "8034"),
    ("10ee", "8038"),
    # Xilinx Ultrascale+.
    ("10ee", "9021"),
    ("10ee", "9022"),
    ("10ee", "9024"),
    ("10ee", "9028"),
    ("10ee", "902f"),
    ("10ee", "9031"),
    ("10ee", "9032"),
    ("10ee", "9034"),
    ("10ee", "9038"),
    ("10ee", "903f"),
    ("10ee", "9041"),
    ("10ee", "9042"),
    ("10ee", "9044"),
    ("10ee", "9048"),
    # Lattice / Gowin.
    ("1204", "9c25"),
    ("22c2", "1100"),
)


def normalize_hex_id(value):
    try:
        return f"{int(value, 16):04x}"
    except ValueError as e:
        raise argparse.ArgumentTypeError(f"invalid hexadecimal id: {value}") from e


def parse_device(value):
    fields = value.split(":")
    if len(fields) != 2:
        raise argparse.ArgumentTypeError("expected vendor:device")
    return tuple(normalize_hex_id(field) for field in fields)


def sudo_write(path, value):
    subprocess.run(
        ["sudo", "tee", str(path)],
        input=f"{value}\n",
        text=True,
        stdout=subprocess.DEVNULL,
        check=True,
    )


def get_pcie_device_ids(vendor, device):
    try:
        output = subprocess.check_output(
            ["lspci", "-D", "-d", f"{vendor}:{device}"],
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except subprocess.CalledProcessError:
        return []
    return [line.split()[0] for line in output.splitlines() if line]


def remove_driver(module):
    print(f"Removing {module} driver...")
    subprocess.run(["sudo", "rmmod", module], check=False)


def remove_pcie_device(device_id):
    print(f"Removing PCIe device {device_id}...")
    sudo_write(Path("/sys/bus/pci/devices") / device_id / "remove", 1)


def rescan_pcie_bus():
    print("Rescanning PCIe bus...")
    sudo_write(Path("/sys/bus/pci/rescan"), 1)


def load_driver(module):
    print(f"Loading {module} driver...")
    subprocess.run(["sudo", "modprobe", module], check=True)


def main():
    parser = argparse.ArgumentParser(description="LitePCIe PCIe bus rescan helper.")
    parser.add_argument(
        "--module",
        default="litepcie",
        help="kernel module to remove/reload (default: litepcie)",
    )
    parser.add_argument(
        "--device",
        action="append",
        default=[],
        type=parse_device,
        metavar="VENDOR:DEVICE",
        help="PCI vendor/device ID to rescan; can be specified multiple times",
    )
    parser.add_argument(
        "--no-rmmod",
        action="store_true",
        help="do not unload the driver before removing devices",
    )
    parser.add_argument(
        "--no-modprobe",
        action="store_true",
        help="do not reload the driver after rescanning the bus",
    )
    args = parser.parse_args()

    devices = tuple(args.device) if args.device else DEFAULT_DEVICES
    device_ids = []
    for vendor, device in devices:
        device_ids.extend(get_pcie_device_ids(vendor, device))

    if not args.no_rmmod:
        remove_driver(args.module)

    for device_id in device_ids:
        remove_pcie_device(device_id)

    rescan_pcie_bus()

    if not args.no_modprobe:
        load_driver(args.module)

    return 0


if __name__ == "__main__":
    sys.exit(main())
