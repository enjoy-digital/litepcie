#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# LitePCIe at a glance: host, PHY, core (TLP layer and crossbar), frontends and user logic.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 260)
    d.add(Container(285, 20, 200, 225, title="Core", title_pos="bl"))
    d.add(Container(505, 20, 135, 225, title="Frontends", title_pos="bl"))
    host = d.add(Box(20,  95, 100, 60, label="Host\nLinux driver", fill=COLOR_HARDWARE))
    phy  = d.add(Box(150, 95, 110, 60, label="PHY\nhard IP or soft", size=13, fill=COLOR_ACCENT_LIGHT))
    tlp  = d.add(Box(295, 95, 70,  60, label="TLP\nlayer", fill=COLOR_ACCENT))
    xbar = d.add(Box(405, 95, 70,  60, label="Cross-\nbar", fill=COLOR_ACCENT))
    dma  = d.add(Box(520, 35,  105, 40, label="DMA", fill=COLOR_ACCENT))
    mmap = d.add(Box(520, 105, 105, 40, label="MMAP", fill=COLOR_ACCENT))
    msi  = d.add(Box(520, 165, 105, 40, label="MSI, MSI-X", fill=COLOR_ACCENT))
    user = d.add(Box(660, 35,  80, 170, label="User\nlogic"))
    d.add(Arrow((host, "r"), (phy, "l"), kind="data", heads="both"))
    d.add(Arrow((phy, "r"), (tlp, "l"), kind="data", heads="both"))
    d.add(Arrow((tlp, "r"), (xbar, "l"), kind="data", heads="both"))
    for f in (dma, mmap, msi):
        via = [] if f is mmap else [(490, 125), (490, f.cy)]
        d.add(Arrow((xbar, "r"), (f, "l"), via=via, kind="data", heads="both"))
    d.add(Arrow((dma, "r"), (660, dma.cy), kind="data", heads="both"))
    d.add(Arrow((mmap, "r"), (660, mmap.cy), kind="data", heads="both"))
    d.add(Arrow((660, msi.cy), (msi, "r"), kind="control"))
    return d
