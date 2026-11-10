#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Clock domains of the soft PHY: recovered clocks, lane clock, link clock, pcie and the core.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 250)
    ref  = d.add(Box(15, 20, 120, 60, label="Reference\nclock", fill=COLOR_HARDWARE))
    mmcm = d.add(Box(245, 20, 120, 60, label="MMCM", fill=COLOR_ACCENT_LIGHT))
    gt   = d.add(Box(15, 150, 120, 75, label="Transceivers\nrecovered\nclocks", fill=COLOR_HARDWARE))
    lane = d.add(Box(170, 150, 135, 75, label="Lane datapaths\npcie_pipe", fill=COLOR_ACCENT))
    link = d.add(Box(335, 150, 125, 75, label="LTSSM, DLL\npcie_link", fill=COLOR_ACCENT))
    tl   = d.add(Box(490, 150, 125, 75, label="Transaction\nLayer glue\npcie", fill=COLOR_ACCENT))
    core = d.add(Box(645, 150, 100, 75, label="Core\ncd", fill=COLOR_ACCENT_LIGHT))
    d.add(Arrow((ref, "r"), (mmcm, "l"), kind="control"))
    d.add(Arrow((ref, "b"), (gt, "t"), kind="control", label="PLL", label_side="right"))
    d.add(Arrow((mmcm, "b", (275 - 245)/120), (lane, "t", (275 - 170)/135), kind="control"))
    d.add(Arrow((mmcm, "b", (350 - 245)/120), (link, "t", (350 - 335)/125), kind="control"))
    d.add(Arrow((gt, "r"), (lane, "l"), kind="feedback"))
    d.add(Arrow((lane, "r"), (link, "l"), kind="feedback", heads="both"))
    d.add(Arrow((link, "r"), (tl, "l"), kind="control", heads="both"))
    d.add(Arrow((tl, "r"), (core, "l"), kind="feedback", heads="both"))
    return d
