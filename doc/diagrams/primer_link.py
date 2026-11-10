#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# A PCI Express link: one differential pair per direction and per lane, AC coupled, a shared
# 100 MHz reference clock and the PERST# reset of the slot.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 300)
    d.add(Container(20, 15, 220, 205, title="Root port", title_pos="bl"))
    d.add(Container(520, 15, 220, 205, title="Endpoint", title_pos="br"))
    rtx = d.add(Box(50, 40, 150, 40, label="TX", stack=2, fill=COLOR_HARDWARE))
    rrx = d.add(Box(50, 105, 150, 40, label="RX", stack=2, fill=COLOR_HARDWARE))
    erx = d.add(Box(550, 40, 150, 40, label="RX", stack=2, fill=COLOR_ACCENT))
    etx = d.add(Box(550, 105, 150, 40, label="TX", stack=2, fill=COLOR_ACCENT))
    d.add(Box(318, 52, 24, 16, label="", fill="#ffffff", shadow=False))
    d.add(Box(418, 117, 24, 16, label="", fill="#ffffff", shadow=False))
    d.add(Arrow((rtx, "r"), (erx, "l"), kind="data", label="lanes 0 to N-1"))
    d.add(Arrow((etx, "l"), (rrx, "r"), kind="data", label="lanes 0 to N-1"))
    d.add(Text(330, 85, "AC coupling", size=12, color="#444444"))
    d.add(Text(430, 150, "AC coupling", size=12, color="#444444"))
    d.add(Arrow((240, 185), (520, 185), kind="control", label="PERST#"))
    clk = d.add(Box(305, 245, 150, 40, label="100 MHz refclk", fill=COLOR_HARDWARE))
    d.add(Arrow((clk, "l"), (130, 220), kind="control"))
    d.add(Arrow((clk, "r"), (630, 220), kind="control"))
    return d
