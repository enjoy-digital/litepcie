#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Common datapath of the hard-IP PHYs: clock domain crossing, width conversion, packet buffer and
# 128-bit receive aligner between the core and the hard IP.

from svgdiag import *
from phy_helpers import frac


def build():
    d = Diagram(CANVAS_WIDTH, 260)
    d.add(Container(270, 15, 355, 230, title="pcie clock domain", title_pos="tl"))
    core  = d.add(Box(15, 55, 105, 170, label="Core\ncd clock\ndomain", fill=COLOR_ACCENT_LIGHT))
    txcdc = d.add(Box(145, 60, 100, 55, label="CDC FIFO", fill=COLOR_ACCENT))
    rxcdc = d.add(Box(145, 160, 100, 55, label="CDC FIFO", fill=COLOR_ACCENT))
    txcnv = d.add(Box(290, 60, 140, 55, label="Width\nconverter", fill=COLOR_ACCENT))
    rxcnv = d.add(Box(290, 160, 140, 55, label="Width\nconverter", fill=COLOR_ACCENT))
    txbuf = d.add(Box(450, 60, 155, 55, label="Packet buffer\nUltraScale+ option"))
    rxaln = d.add(Box(450, 160, 155, 55, label="128-bit aligner\n7-Series"))
    hip   = d.add(Box(650, 55, 95, 170, label="Hard IP", fill=COLOR_HARDWARE))
    ytx, yrx = 87.5, 187.5
    d.add(Arrow((core, "r", frac(core, ytx)), (txcdc, "l"), kind="data"))
    d.add(Arrow((txcdc, "r"), (txcnv, "l"), kind="data"))
    d.add(Arrow((txcnv, "r"), (txbuf, "l"), kind="data"))
    d.add(Arrow((txbuf, "r"), (hip, "l", frac(hip, ytx)), kind="data"))
    d.add(Arrow((hip, "l", frac(hip, yrx)), (rxaln, "r"), kind="data"))
    d.add(Arrow((rxaln, "l"), (rxcnv, "r"), kind="data"))
    d.add(Arrow((rxcnv, "l"), (rxcdc, "r"), kind="data"))
    d.add(Arrow((rxcdc, "l"), (core, "r", frac(core, yrx)), kind="data"))
    return d
