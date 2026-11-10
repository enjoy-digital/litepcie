#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Host accesses to BAR0: masked to an offset, then Wishbone cycles from the CSR base address.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 190)
    host = d.add(Box(20, 40, 115, 70, label="Host CPU", fill=COLOR_HARDWARE))
    phy  = d.add(Box(170, 40, 115, 70, label="PHY", fill=COLOR_HARDWARE))
    dep  = d.add(Box(320, 40, 120, 70, label="Depacketizer\nBAR0 mask", fill=COLOR_ACCENT_LIGHT))
    wbm  = d.add(Box(475, 40, 120, 70, label="Wishbone\nmaster", fill=COLOR_ACCENT))
    bus  = d.add(Box(630, 40, 110, 70, label="SoC bus\nregisters"))
    for a, b in [(host, phy), (phy, dep), (dep, wbm), (wbm, bus)]:
        d.add(Arrow((a, "r"), (b, "l"), kind="accent" if a is dep else "data", heads="both"))
    d.add(Text(host.cx, 135, "MemRd, MemWr", size=13))
    d.add(Text(dep.cx, 135, "BAR0 offset", size=13))
    d.add(Text(wbm.cx, 135, "base + offset", size=13))
    d.add(Text(bus.cx, 135, "CSR bus", size=13))
    d.add(Text(wbm.cx, 160, "one CplD per DW", size=13))
    return d
