#!/usr/bin/env python3

import sys
import os
import argparse
import subprocess
import struct
import importlib

from migen.fhdl import verilog
from migen.fhdl.structure import _Fragment

from litex.build.tools import write_to_file
from litex.build.xilinx.common import *

from litex.soc.integration import export

litepcie_path = "../"
sys.path.append(litepcie_path) # XXX

from litepcie.common import *


def autotype(s):
    if s == "True":
        return True
    elif s == "False":
        return False
    try:
        return int(s, 0)
    except ValueError:
        pass
    return s


def _import(default, name):
    return importlib.import_module(default + "." + name)


def _get_args():
    parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter,
        description="""\
LitePCIe - based on Migen.

This program builds and/or loads LitePCIe components.
One or several actions can be specified:

clean            delete previous build(s).
build-rtl        build verilog rtl.
build-bitstream  build-bitstream build FPGA bitstream.
build-csr-header save CSR map into C header file.
build-soc-header save CSR map into C header file.

load-bitstream   load bitstream into volatile storage.

all              clean, build-csr-csv, build-bitstream, load-bitstream.
""")

    parser.add_argument("-t", "--target", default="dma", help="Core type to build")
    parser.add_argument("-s", "--sub-target", default="", help="variant of the Core type to build")
    parser.add_argument("-p", "--platform", default=None, help="platform to build for")
    parser.add_argument("-Ot", "--target-option", default=[], nargs=2, action="append", help="set target-specific option")
    parser.add_argument("-Op", "--platform-option", default=[], nargs=2, action="append", help="set platform-specific option")
    parser.add_argument("-Ob", "--build-option", default=[], nargs=2, action="append", help="set build option")
    parser.add_argument("--csr-header", default="../litepcie/software/kernel/csr.h", help="C header file to save the CSR map into")
    parser.add_argument("--soc-header", default="../litepcie/software/kernel/soc.h", help="C header file to save the SoC constants into")
    parser.add_argument("action", nargs="+", help="specify an action")

    return parser.parse_args()

if __name__ == "__main__":
    args = _get_args()

    # create top-level Core object
    target_module = _import("targets", args.target)
    if args.sub_target:
        top_class = getattr(target_module, args.sub_target)
    else:
        top_class = target_module.default_subtarget

    if args.platform is None:
        platform_name = top_class.default_platform
    else:
        platform_name = args.platform
    platform_module = _import("litex.boards.platforms", platform_name)
    platform_kwargs = dict((k, autotype(v)) for k, v in args.platform_option)
    platform = platform_module.Platform(**platform_kwargs)
    platform.litepcie_path = litepcie_path

    build_name = top_class.__name__.lower() + "_" + platform_name
    top_kwargs = dict((k, autotype(v)) for k, v in args.target_option)
    soc = top_class(platform, **top_kwargs)
    soc.finalize()

    # decode actions
    action_list = ["clean", "build-csr-header", "build-soc-header", "build-bitstream", "load-bitstream", "all"]
    actions = {k: False for k in action_list}
    for action in args.action:
        if action in actions:
            actions[action] = True
        else:
            print("Unknown action: "+action+". Valid actions are:")
            for a in action_list:
                print("  "+a)
            sys.exit(1)

    print("""
      __   _ __      ___  _________
     / /  (_) /____ / _ \/ ___/  _/__
    / /__/ / __/ -_) ___/ /___/ // -_)
   /____/_/\__/\__/_/   \___/___/\__/

  A small footprint and configurable PCIe
          core powered by Migen
====== Building options: ======
Platform:  {}
Target:    {}
Subtarget: {}
System Clk: {} MHz
===============================""".format(
    platform_name,
    args.target,
    top_class.__name__,
    soc.clk_freq/1000000
    )
)

    # dependencies
    if actions["all"]:
        actions["build-csr-csv"]    = True
        actions["build-csr-header"] = True
        actions["build-soc-header"] = True
        actions["build-bitstream"]  = True
        actions["load-bitstream"]   = True

    if actions["build-bitstream"]:
        actions["build-csr-header"] = True
        actions["build-soc-header"] = True

    if actions["clean"]:
        subprocess.call(["rm", "-rf", "build/*"])

    if actions["build-csr-header"]:
        csr_header = export.get_csr_header(soc.csr_regions, soc.constants, with_access_functions=False)
        write_to_file(args.csr_header, csr_header)

    if actions["build-soc-header"]:
        soc_header = export.get_soc_header(soc.constants, with_access_functions=False)
        write_to_file(args.soc_header, soc_header)

    if actions["build-bitstream"]:
        build_kwargs = dict((k, autotype(v)) for k, v in args.build_option)
        vns = platform.build(soc, build_name=build_name, **build_kwargs)
        if hasattr(soc, "do_exit") and vns is not None:
            if hasattr(soc.do_exit, '__call__'):
                soc.do_exit(vns)

    if actions["load-bitstream"]:
        prog = platform.create_programmer()
        prog.load_bitstream("build/" + build_name + platform.bitstream_ext)
