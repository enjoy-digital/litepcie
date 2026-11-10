#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# The three layers of PCI Express on both sides of a link, and the units each pair exchanges.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 300)
    d.add(Container(20, 10, 230, 280, title="Root complex", title_pos="bl"))
    d.add(Container(510, 10, 230, 280, title="Device (FPGA)", title_pos="br"))
    rows = [("Transaction layer", "TLPs"),
            ("Data link layer",   "DLLPs, sequence, LCRC"),
            ("Physical layer",    "Symbols, ordered sets")]
    y = 30
    for name, what in rows:
        h = d.add(Box(45,  y, 180, 50, label=name, fill=COLOR_HARDWARE))
        v = d.add(Box(535, y, 180, 50, label=name, fill=COLOR_ACCENT))
        d.add(Arrow((h, "r"), (v, "l"), kind="feedback", heads="both", label=what, label_size=13))
        y += 75
    d.add(Text(380, 268, "link: 1 to 16 lanes", size=13))
    return d
