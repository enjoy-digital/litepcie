#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Clocking of a hard-IP PHY: reference clock, hard IP, 7-Series MMCM, user clock (pcie clock
# domain) and the crossing to the core clock domain.

from svgdiag import *
from phy_helpers import frac


def build():
    d = Diagram(CANVAS_WIDTH, 240)
    ref  = d.add(Box(15, 40, 120, 60, label="Reference\nclock", fill=COLOR_HARDWARE))
    mmcm = d.add(Box(15, 150, 120, 60, label="MMCM\n7-Series", fill=COLOR_ACCENT_LIGHT))
    hip  = d.add(Box(245, 40, 140, 170, label="Hard IP\ntransceivers\nPCIe block", fill=COLOR_HARDWARE))
    dp   = d.add(Box(450, 95, 135, 60, label="PHY datapath\npcie clock", fill=COLOR_ACCENT))
    core = d.add(Box(625, 95, 120, 60, label="Core\ncd clock", fill=COLOR_ACCENT_LIGHT))
    d.add(Arrow((ref, "r"), (hip, "l", frac(hip, 70)), kind="control"))
    d.add(Arrow((hip, "l", frac(hip, 165)), (mmcm, "r", frac(mmcm, 165)), kind="control",
        label="TX out clock"))
    d.add(Arrow((mmcm, "r", frac(mmcm, 195)), (hip, "l", frac(hip, 195)), kind="control",
        label="user clocks", label_side="below"))
    d.add(Arrow((hip, "r", frac(hip, 125)), (dp, "l"), kind="control", label="user clock"))
    d.add(Arrow((dp, "r"), (core, "l"), kind="feedback", heads="both", label="CDC"))
    return d
