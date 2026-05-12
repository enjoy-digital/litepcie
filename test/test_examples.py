#
# This file is part of LitePCIe.
#
# Copyright (c) 2019-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest
import subprocess
import sys
import tempfile
from pathlib import Path
import pytest

# Test Examples ------------------------------------------------------------------------------------

@pytest.mark.examples
@pytest.mark.slow
class TestExamples(unittest.TestCase):
    def target_test(self, target):
        with tempfile.TemporaryDirectory(prefix=f"litepcie-{target}-") as tmpdir:
            build_dir = Path(tmpdir) / "build"
            subprocess.run(
                [sys.executable, f"bench/{target}.py", "--output-dir", str(build_dir)],
                check=True,
            )
            self.assertEqual((build_dir / "gateware" / f"{target}.v").is_file(), True)
            self.assertEqual((build_dir / "software/include/generated/csr.h").is_file(), True)
            self.assertEqual((build_dir / "software/include/generated/soc.h").is_file(), True)
            self.assertEqual((build_dir / "software/include/generated/mem.h").is_file(), True)

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
            build_dir = Path(tmpdir) / "build"
            subprocess.run(
                [sys.executable, "litepcie/gen.py", f"examples/{name}.yml", "--output-dir", str(build_dir)],
                check=True,
            )
            return not (build_dir / "gateware/litepcie_core.v").is_file()

    def test_ac701_gen(self):
        errors = self.gen_test("ac701")
        self.assertEqual(errors, 0)
