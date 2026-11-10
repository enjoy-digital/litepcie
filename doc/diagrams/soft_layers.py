#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Layers of the soft PHY: what replaces the hard IP between the core and the transceivers.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 190)
    d.add(Container(108, 15, 529, 160, title="SoftPCIEPHY", title_pos="br"))
    core = d.add(Box(15, 50, 78, 70, label="Core", fill=COLOR_ACCENT_LIGHT))
    dp   = d.add(Box(122, 50, 105, 70, label="CDC, width\nadapters"))
    tl   = d.add(Box(252, 50, 105, 70, label="Transaction\nLayer glue", fill=COLOR_ACCENT))
    dll  = d.add(Box(382, 50, 100, 70, label="Data Link\nLayer", fill=COLOR_ACCENT))
    phy  = d.add(Box(507, 50, 115, 70, label="Physical\nLayer, LTSSM", fill=COLOR_ACCENT))
    gt   = d.add(Box(662, 50, 83, 70, label="FPGA\ntrans-\nceivers", fill=COLOR_HARDWARE))
    for a, b in [(core, dp), (dp, tl), (tl, dll), (dll, phy), (phy, gt)]:
        d.add(Arrow((a, "r"), (b, "l"), kind="data", heads="both"))
    return d
