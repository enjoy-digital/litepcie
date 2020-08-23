#
# This file is part of LitePCIe.
#
# Copyright (c) 2019-2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest
import os

class TestExamples(unittest.TestCase):
    def target_test(self, target):
        os.system("rm -rf examples/build")
        os.system("cd examples && python3 {}.py".format(target))
        self.assertEqual(os.path.isfile("examples/build/{}/gateware/{}.v".format(target, target)), True)
        self.assertEqual(os.path.isfile("examples/build/{}/software/include/generated/csr.h".format(target)), True)
        self.assertEqual(os.path.isfile("examples/build/{}/software/include/generated/soc.h".format(target)), True)
        self.assertEqual(os.path.isfile("examples/build/{}/software/include/generated/mem.h".format(target)), True)

    def test_kc705_target(self):
        self.target_test("kc705")

    def gen_test(self, name):
        os.system("rm -rf examples/build")
        os.system("cd examples && python3 ../litepcie/gen.py {}.yml".format(name))
        errors = not os.path.isfile("examples/build/gateware/litepcie_core.v")
        os.system("rm -rf examples/build")
        return errors

    def test_ac701_gen(self):
        errors = self.gen_test("ac701")
        self.assertEqual(errors, 0)
