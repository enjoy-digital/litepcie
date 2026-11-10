#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# FPGA accesses to host memory: Wishbone or AXI slave, crossbar master ports, PHY, host memory.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 200)
    soc  = d.add(Box(20, 30, 130, 140, label="SoC master\nCPU or\nuser logic"))
    wbs  = d.add(Box(200, 30, 130, 55, label="Wishbone slave", fill=COLOR_ACCENT))
    axi  = d.add(Box(200, 115, 130, 55, label="AXI slave", fill=COLOR_ACCENT))
    xbar = d.add(Box(380, 30, 110, 140, label="Crossbar\nmaster ports"))
    phy  = d.add(Box(540, 30, 80, 140, label="PHY", fill=COLOR_HARDWARE))
    mem  = d.add(Box(650, 30, 90, 140, label="Host\nmemory", fill=COLOR_HARDWARE))
    for b in (wbs, axi):
        d.add(Arrow((soc.x + soc.w, b.cy), (b, "l"), kind="data", heads="both"))
        d.add(Arrow((b, "r"), (xbar.x, b.cy), kind="accent", heads="both"))
    d.add(Arrow((xbar.x + xbar.w, xbar.cy), (phy.x, xbar.cy), kind="data", heads="both"))
    d.add(Arrow((phy.x + phy.w, phy.cy), (mem.x, phy.cy), kind="data", heads="both"))
    return d
