#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Standalone Verilog core (litepcie_gen): port groups of the generated litepcie_core module.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 340)
    d.add(Container(250, 20, 270, 300, title="litepcie_core", title_pos="bl"))
    phy  = d.add(Box(285, 45, 190, 80, label="PHY", fill=COLOR_ACCENT))
    core = d.add(Box(285, 150, 190, 130, label="Endpoint, DMA,\nMSI, MMAP", fill=COLOR_ACCENT_LIGHT))
    pins = d.add(Box(30, 67, 160, 36, label="pcie pins", fill=COLOR_HARDWARE))
    clk  = d.add(Box(30, 170, 160, 36, label="clk, rst"))
    irq  = d.add(Box(30, 235, 160, 36, label="msi_irqs"))
    mmap = d.add(Box(570, 160, 170, 36, label="mmap AXI ports"))
    wr   = d.add(Box(570, 205, 170, 36, label="dmaN_writer_axi"))
    rd   = d.add(Box(570, 250, 170, 36, label="dmaN_reader_axi"))
    d.add(Arrow((pins, "r"), (285, 85), kind="data", heads="both"))
    d.add(Arrow((clk, "r"), (285, 188), kind="control", heads="both"))
    d.add(Arrow((irq, "r"), (285, 253), kind="control"))
    d.add(Arrow((phy, "b"), (core, "t"), kind="accent", heads="both"))
    d.add(Arrow((mmap, "l"), (475, 178), kind="data", heads="both"))
    d.add(Arrow((wr, "l"), (475, 223), kind="data"))
    d.add(Arrow((475, 268), (rd, "l"), kind="data"))
    return d
