# This file is Copyright (c) 2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

import unittest
import os

root_dir    = os.path.join(os.path.abspath(os.path.dirname(__file__)), "..")
make_script = os.path.join(root_dir, "examples", "make.py")

class TestExamples(unittest.TestCase):
    def example_test(self, t, s):
        os.system("rm -rf {}/build".format(root_dir))
        cmd = "python3 " + make_script + " "
        cmd += "-t {} ".format(t)
        cmd += "-s {} ".format(s)
        cmd += "-p kc705 "
        cmd += "-Ob run False "
        cmd += "build-bitstream"
        os.system(cmd)
        self.assertEqual(os.path.isfile("{}/build/{}_kc705.v".format(root_dir, s.lower())), True)
        self.assertEqual(os.path.isfile("{}/build/csr.h".format(root_dir, s.lower())), True)
        self.assertEqual(os.path.isfile("{}/build/soc.h".format(root_dir, s.lower())), True)

    def test_dma_example(self):
        self.example_test("dma", "PCIeDMASoC")

    def gen_test(self, name):
        os.system("rm -rf examples/build")
        os.system("cd examples && python3 ../litepcie/gen.py gen/{}.yml".format(name))
        errors = not os.path.isfile("examples/build/gateware/litepcie_core.v")
        os.system("rm -rf examples/build")
        return errors

    def test_gen_ac701(self):
        errors = self.gen_test("ac701")
        self.assertEqual(errors, 0)
