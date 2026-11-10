#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# DMA descriptor: the 64-bit value register and the we register (address MSB, write strobe).

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 190)
    x0 = 120
    cells = [(70, "Reserved", COLOR_SHADE), (70, "Last\ndisable", COLOR_ACCENT_LIGHT),
        (70, "IRQ\ndisable", COLOR_ACCENT_LIGHT), (190, "Length (bytes)", COLOR_ACCENT),
        (220, "Address LSB", COLOR_ACCENT)]
    d.add(Text(20, 68, "value", size=15, anchor="start"))
    fields(d, x0, 45, cells, h=46)
    marks = [(x0 + 4, "63", "start"), (x0 + 66, "58", "end"), (x0 + 105, "57", "middle"),
        (x0 + 175, "56", "middle"), (x0 + 214, "55", "start"), (x0 + 396, "32", "end"),
        (x0 + 404, "31", "start"), (x0 + 616, "0", "end")]
    for x, t, a in marks:
        d.add(Text(x, 33, t, size=12, anchor=a, color=COLOR_STROKE))
    d.add(Text(20, 148, "we", size=15, anchor="start"))
    fields(d, x0 + 400, 125, [(220, "Address MSB", COLOR_ACCENT_LIGHT)], h=46)
    d.add(Text(x0 + 404, 113, "31", size=12, anchor="start", color=COLOR_STROKE))
    d.add(Text(x0 + 616, 113, "0", size=12, anchor="end", color=COLOR_STROKE))
    d.add(Text(x0 + 390, 148, "a write pushes the descriptor", size=13, anchor="end"))
    return d
