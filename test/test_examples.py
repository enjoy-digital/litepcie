#
# This file is part of LitePCIe.
#
# Copyright (c) 2019-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import sys
import tempfile
import unittest
import subprocess
from pathlib import Path

import pytest

# Test Examples ------------------------------------------------------------------------------------

@pytest.mark.examples
@pytest.mark.slow
class TestExamples(unittest.TestCase):
    def target_test(self, target):
        with tempfile.TemporaryDirectory(prefix=f"litepcie-{target}-") as tmpdir:
            build_dir = Path(tmpdir) / "build"
            csr_csv   = Path(tmpdir) / "csr.csv"
            cmd       = [
                sys.executable, f"bench/{target}.py",
                "--output-dir", str(build_dir),
                "--csr-csv", str(csr_csv),
            ]
            subprocess.run(cmd, check=True)
            self.assertEqual((build_dir / "gateware" / f"{target}.v").is_file(), True)
            self.assertEqual((build_dir / "software/include/generated/csr.h").is_file(), True)
            self.assertEqual((build_dir / "software/include/generated/soc.h").is_file(), True)
            self.assertEqual((build_dir / "software/include/generated/mem.h").is_file(), True)
            self.assertEqual(csr_csv.is_file(), True)

    def test_kc705_target(self):
        self.target_test("kc705")

    def test_kcu105_target(self):
        self.target_test("kcu105")

    def test_fk33_target(self):
        self.target_test("fk33")

    def test_xcu1525_target(self):
        self.target_test("xcu1525")

    def gen_test(self, name):
        with tempfile.TemporaryDirectory(prefix=f"litepcie-{name}-") as tmpdir:
            build_dir  = Path(tmpdir) / "build"
            header_dir = Path(tmpdir)
            cmd        = [
                sys.executable, "litepcie/gen.py", f"examples/{name}.yml",
                "--output-dir", str(build_dir),
                "--header-dir", str(header_dir),
            ]
            subprocess.run(cmd, check=True)
            return not all([
                (build_dir / "gateware/litepcie_core.v").is_file(),
                (header_dir / "csr.h").is_file(),
                (header_dir / "soc.h").is_file(),
                (header_dir / "mem.h").is_file(),
            ])

    def test_ac701_gen(self):
        errors = self.gen_test("ac701")
        self.assertEqual(errors, 0)

    def test_ac701_msix_gen(self):
        with tempfile.TemporaryDirectory(prefix="litepcie-ac701-msix-") as tmpdir:
            config = Path(tmpdir) / "ac701_msix.yml"
            config.write_text(Path("examples/ac701.yml").read_text().replace(
                '"msi_irqs"                : 16,', '"msi_irqs" : 16, "msi_x" : True,'))
            build_dir = Path(tmpdir) / "build"
            subprocess.run([sys.executable, "litepcie/gen.py", str(config),
                "--output-dir", str(build_dir),
                "--header-dir", str(tmpdir),
            ], check=True)
            # Hard IP configured for MSI-X (32 vectors), user IRQs on vectors 16-31.
            tcl = (build_dir / "gateware/litepcie_core.tcl").read_text()
            self.assertIn("CONFIG.MSIx_Enabled {True}", tcl)
            self.assertIn("CONFIG.MSIx_Table_Size {20}", tcl)
            verilog = (build_dir / "gateware/litepcie_core.v").read_text()
            self.assertIn("main_pcie_msi_irqs[31:16] = msi_irqs;", verilog)
            # Vectors 0-31 in the PBA word at 0x1808 (upper half of the 64-bit CSR with big ordering).
            self.assertIn("main_pcie_msi_pba_status = {main_pcie_msi_vector[31:0], main_pcie_msi_vector[63:32]};", verilog)
            self.assertIn("#define CSR_PCIE_MSI_PBA_ADDR (CSR_BASE + 0x1808L)", (Path(tmpdir) / "csr.h").read_text())
