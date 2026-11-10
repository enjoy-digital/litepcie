#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import re
import unittest
from pathlib import Path

from litepcie.software.rescan import DEFAULT_DEVICES

SOFTWARE = Path(__file__).parents[1] / "litepcie" / "software"

# Xilinx wrappers write `<base> + nlanes` as a decimal number in the IP Tcl, Vivado reads its digits
# as hex (ex: 9020 + 16 = 9036 -> 0x9036).
XILINX_DEVICE_IDS = {
    "S7_GEN2"  : (7020, [1, 2, 4, 8]),
    "US_GEN2"  : (8020, [1, 2, 4, 8]),
    "US_GEN3"  : (8030, [1, 2, 4, 8]),
    "USP_GEN2" : (9020, [1, 2, 4, 8, 16]),
    "USP_GEN3" : (9030, [1, 2, 4, 8, 16]),
    "USP_GEN4" : (9040, [1, 2, 4, 8, 16]),
}


class TestDriverDeviceIDs(unittest.TestCase):
    def test_xilinx_device_ids(self):
        config  = (SOFTWARE / "kernel" / "config.h").read_text()
        main    = (SOFTWARE / "kernel" / "main.c").read_text()
        defines = re.findall(r"#define\s+(PCIE_\w+_DEVICE_ID_\w+)\s+(0x[0-9a-fA-F]+)", config)
        names   = [name for name, _ in defines]
        self.assertEqual(len(names), len(set(names)), "duplicate device ID defines")
        defines = {name: int(value, 16) for name, value in defines}
        for family, (base, nlanes) in XILINX_DEVICE_IDS.items():
            for n in nlanes:
                name      = f"PCIE_XILINX_DEVICE_ID_{family}_X{n}"
                device_id = int(str(base + n), 16)
                with self.subTest(name=name):
                    self.assertEqual(defines.get(name), device_id)
                    self.assertIn(f"PCI_DEVICE(PCIE_XILINX_VENDOR_ID, {name})", main)
                    self.assertIn(("10ee", f"{device_id:04x}"), DEFAULT_DEVICES)

    def test_rescan_covers_driver_ids(self):
        config  = (SOFTWARE / "kernel" / "config.h").read_text()
        vendors = dict(re.findall(r"#define\s+PCIE_(\w+)_VENDOR_ID\s+0x([0-9a-fA-F]+)", config))
        for vendor, name in re.findall(r"PCI_DEVICE\(PCIE_(\w+)_VENDOR_ID,\s*(\w+)\)",
            (SOFTWARE / "kernel" / "main.c").read_text()):
            device = re.search(rf"#define\s+{name}\s+0x([0-9a-fA-F]+)", config).group(1)
            with self.subTest(name=name):
                self.assertIn((vendors[vendor].lower(), device.lower()), DEFAULT_DEVICES)
