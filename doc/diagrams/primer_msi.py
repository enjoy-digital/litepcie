#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# MSI and MSI-X: both are memory writes to an address given by the host; MSI-X keeps a table per
# vector in a BAR, with a mask and a pending bit array.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 320)
    d.add(Container(20, 15, 340, 205, title="MSI", title_pos="bl"))
    d.add(Container(400, 15, 340, 205, title="MSI-X", title_pos="bl"))
    cap  = d.add(Box(40, 40, 140, 54, label="Capability\naddress, data", size=13, fill=COLOR_ACCENT_LIGHT))
    mw1  = d.add(Box(210, 40, 130, 54, label="MemWr\ndata + vector", size=13, fill=COLOR_ACCENT))
    tab  = d.add(Box(420, 40, 150, 54, label="Table in a BAR\naddress, data, mask", size=13,
        fill=COLOR_ACCENT_LIGHT))
    pba  = d.add(Box(420, 120, 150, 54, label="PBA\npending bits", size=13, fill=COLOR_ACCENT_LIGHT))
    mw2  = d.add(Box(600, 40, 120, 54, label="MemWr\nper vector", size=13, fill=COLOR_ACCENT))
    host = d.add(Box(230, 255, 300, 44, label="Host interrupt controller", fill=COLOR_HARDWARE))
    d.add(Arrow((cap, "r"), (mw1, "l"), kind="control"))
    d.add(Arrow((tab, "r"), (mw2, "l"), kind="control"))
    d.add(Arrow((pba, "r"), (mw2, "b", 0.3), kind="feedback", label="on unmask", label_pos=(595, 138),
        label_anchor="start"))
    d.add(Arrow((mw1, "b"), (275, 255), kind="accent"))
    d.add(Arrow((mw2, "b", 0.7), (host, "r"), via=[(684, 277)], kind="accent"))
    return d
