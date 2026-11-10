#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Board in a host: root port, slot signals (lanes, reference clock, PERST#), PHY, core, user logic.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 300)
    d.add(Container(20, 20, 210, 260, title="Host", title_pos="bl"))
    d.add(Container(350, 20, 390, 260, title="FPGA board", title_pos="br"))
    cpu  = d.add(Box(45, 50, 160, 55, label="CPU, memory", fill=COLOR_HARDWARE))
    rp   = d.add(Box(45, 150, 160, 90, label="Root port", fill=COLOR_HARDWARE))
    phy  = d.add(Box(380, 150, 130, 90, label="Hard IP\nor soft PHY", fill=COLOR_ACCENT))
    core = d.add(Box(550, 150, 165, 90, label="LitePCIe core", fill=COLOR_ACCENT_LIGHT))
    user = d.add(Box(550, 50, 165, 55, label="User logic"))
    d.add(Arrow((cpu, "b"), (rp, "t"), kind="data", heads="both"))
    d.add(Arrow((rp, "r", 0.2), (phy, "l", 0.2), kind="accent", heads="both", label="lanes"))
    d.add(Arrow((rp, "r", 0.55), (phy, "l", 0.55), kind="control", label="refclk"))
    d.add(Arrow((rp, "r", 0.85), (phy, "l", 0.85), kind="control", label="PERST#"))
    d.add(Arrow((phy, "r"), (core, "l"), kind="data", heads="both"))
    d.add(Arrow((core, "t"), (user, "b"), kind="data", heads="both", label="DMA, MMAP", label_side="right"))
    return d
