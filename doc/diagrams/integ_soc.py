#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# LitePCIe in a LiteX SoC: PHY, endpoint, Wishbone bridge to the CSR bus, DMA channels, MSI.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 320)
    d.add(Container(120, 20, 620, 280, title="LiteX SoC", title_pos="br"))
    host = d.add(Box(20, 190, 80, 70, label="Host", fill=COLOR_HARDWARE))
    phy  = d.add(Box(140, 190, 110, 70, label="PCIe PHY", fill=COLOR_ACCENT))
    ep   = d.add(Box(290, 190, 140, 70, label="Endpoint", fill=COLOR_ACCENT))
    dma  = d.add(Box(480, 190, 110, 70, label="DMA\nchannels", stack=1, fill=COLOR_ACCENT_LIGHT))
    user = d.add(Box(635, 190, 90, 70, label="User\nlogic"))
    msi  = d.add(Box(160, 50, 140, 60, label="MSI"))
    brg  = d.add(Box(430, 50, 130, 60, label="Wishbone\nbridge"))
    csr  = d.add(Box(610, 50, 115, 60, label="CSR bus"))
    d.add(Arrow((host, "r"), (phy, "l"), kind="accent", heads="both"))
    d.add(Arrow((phy, "r"), (ep, "l"), kind="data", heads="both"))
    d.add(Arrow((ep, "r"), (dma, "l"), kind="data", heads="both"))
    d.add(Arrow((dma, "r"), (user, "l"), kind="data", heads="both"))
    d.add(Arrow((402, 190), (430, 80), via=[(402, 80)], kind="data", heads="both", label="BAR0",
        label_pos=(380, 140)))
    d.add(Arrow((brg, "r"), (csr, "l"), kind="data", heads="end"))
    d.add(Arrow((535, 190), (270, 110), via=[(535, 150), (270, 150)], kind="control", label="IRQs",
        label_pos=(470, 140)))
    d.add(Arrow((195, 110), (195, 190), kind="control", label="MSI", label_side="left"))
    return d
