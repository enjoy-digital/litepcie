#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# PCI Express topology: root complex with its root ports, a switch and endpoints, with example BDFs.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 370)
    cpu = d.add(Box(200, 10, 140, 36, label="CPU", fill=COLOR_HARDWARE))
    mem = d.add(Box(420, 10, 140, 36, label="Memory", fill=COLOR_HARDWARE))
    d.add(Container(90, 85, 570, 95, title="Root complex", title_pos="tl"))
    rp1 = d.add(Box(110, 128, 140, 40, label="Root port", fill=COLOR_ACCENT_LIGHT))
    rp2 = d.add(Box(500, 128, 140, 40, label="Root port", fill=COLOR_ACCENT_LIGHT))
    sw  = d.add(Box(105, 220, 150, 44, label="Switch"))
    epa = d.add(Box(20,  305, 150, 48, label="Endpoint\n03:00.0"))
    epb = d.add(Box(190, 305, 150, 48, label="Endpoint\n04:00.0"))
    fpg = d.add(Box(480, 305, 180, 48, label="FPGA endpoint\n05:00.0", fill=COLOR_ACCENT))
    d.add(Arrow((cpu.cx, 46), (cpu.cx, 85), kind="data", heads="both"))
    d.add(Arrow((mem.cx, 46), (mem.cx, 85), kind="data", heads="both"))
    d.add(Arrow((rp1, "b"), (sw, "t", 0.5), kind="data", heads="both", label="link", label_side="right"))
    d.add(Arrow((sw, "b", 0.3), (epa, "t"), kind="data", heads="both"))
    d.add(Arrow((sw, "b", 0.7), (epb, "t"), kind="data", heads="both"))
    d.add(Arrow((rp2, "b"), (fpg, "t"), kind="accent", heads="both",
        label="link", label_side="right"))
    return d
