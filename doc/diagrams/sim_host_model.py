#
# This file is part of LitePCIe project.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Migen unit tests: the Python host model (host memory, chipset, PHY model) exchanges TLPs with the
# endpoint and DMA under test, without any PHY or transceiver.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 330)
    host = d.add(Container(20, 20, 330, 290, title="Host model", title_pos="bl"))
    dut  = d.add(Container(410, 20, 330, 290, title="Design under test", title_pos="br"))
    mem  = d.add(Box(60, 55, 250, 50, label="Host\n(memory, requests)", fill=COLOR_ACCENT_LIGHT))
    chip = d.add(Box(60, 135, 250, 50, label="Chipset\n(completions, splits)", fill=COLOR_ACCENT_LIGHT))
    phy  = d.add(Box(60, 215, 250, 50, label="PHY model\n(TLP packets)", fill=COLOR_ACCENT_LIGHT))
    gen  = d.add(Box(450, 55, 250, 50, label="Test generators\n(streams, checks)"))
    dma  = d.add(Box(450, 135, 250, 50, label="LitePCIeDMA", fill=COLOR_ACCENT))
    ep   = d.add(Box(450, 215, 250, 50, label="LitePCIeEndpoint", fill=COLOR_ACCENT))
    d.add(Arrow((mem, "b"), (chip, "t"), kind="data", heads="both"))
    d.add(Arrow((chip, "b"), (phy, "t"), kind="data", heads="both"))
    d.add(Arrow((gen, "b"), (dma, "t"), kind="data", heads="both"))
    d.add(Arrow((dma, "b"), (ep, "t"), kind="data", heads="both"))
    d.add(Arrow((phy, "r"), (ep, "l"), kind="accent", heads="both", label="TLPs", label_side="above"))
    return d
