#
# This file is part of LitePCIe project.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Debug taps: what the host tools and the registers of each block tell about the link, the DMA and
# the interrupts.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 300)
    dp = d.add(Container(20, 20, 720, 110, title="Datapath", title_pos="br"))
    host = d.add(Box(40, 45, 150, 46, label="Host\n(root port)", fill=COLOR_HARDWARE))
    phy  = d.add(Box(215, 45, 150, 46, label="PHY\n(hard IP or soft)"))
    dma  = d.add(Box(390, 45, 150, 46, label="DMA"))
    msi  = d.add(Box(565, 45, 150, 46, label="MSI or MSI-X"))
    d.add(Arrow((host, "r"), (phy, "l"), kind="data", heads="both"))
    d.add(Arrow((phy, "r"), (dma, "l"), kind="data", heads="both"))
    d.add(Arrow((dma, "r"), (msi, "l"), kind="control"))
    dbg = d.add(Container(20, 160, 720, 120, title="Debug views", title_pos="br"))
    tools = d.add(Box(40, 185, 150, 46, label="lspci, dmesg", fill=COLOR_ACCENT_LIGHT))
    preg  = d.add(Box(215, 185, 150, 46, label="Link status,\nLTSSM tracer", fill=COLOR_ACCENT))
    dreg  = d.add(Box(390, 185, 150, 46, label="Table level,\nloop status", fill=COLOR_ACCENT))
    mreg  = d.add(Box(565, 185, 150, 46, label="Enable, vector", fill=COLOR_ACCENT))
    for a, b in ((host, tools), (phy, preg), (dma, dreg), (msi, mreg)):
        d.add(Arrow((a, "b"), (b, "t"), kind="feedback"))
    return d
