#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# MSI-X: pending vector (PBA), table read, MemWr issued through a crossbar master port.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 240)
    src  = d.add(Box(20, 40, 110, 70, label="DMA and\nuser IRQs"))
    pba  = d.add(Box(170, 40, 120, 70, label="Pending\nvector (PBA)", fill=COLOR_ACCENT_LIGHT))
    fsm  = d.add(Box(330, 40, 120, 70, label="Table read\nMemWr issue", fill=COLOR_ACCENT))
    tab  = d.add(Box(330, 150, 120, 60, label="MSI-X table\n4 words/vector", fill=COLOR_ACCENT_LIGHT))
    xbar = d.add(Box(490, 40, 90, 70, label="Crossbar\nand PHY"))
    host = d.add(Box(650, 40, 90, 70, label="Host", fill=COLOR_HARDWARE))
    d.add(Arrow((src, "r"), (pba, "l"), kind="data"))
    d.add(Arrow((pba, "r"), (fsm, "l"), kind="data"))
    d.add(Arrow((tab, "t"), (fsm, "b"), kind="control"))
    d.add(Arrow((fsm, "r"), (xbar, "l"), kind="accent"))
    d.add(Arrow((xbar, "r"), (host, "l"), kind="accent", label="MemWr", label_pos=(615, 63)))
    d.add(Arrow((host.cx, host.y + host.h), (tab, "r"), via=[(host.cx, tab.cy)], kind="feedback",
        label="table writes (BAR0)", label_pos=(560, tab.cy - 12)))
    return d
