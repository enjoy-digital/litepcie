#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# TLP header insertion: a 3DW or 4DW header followed by its payload on 64-bit and 128-bit beats.

from core_helpers import *

H, D, E = COLOR_ACCENT, COLOR_FILL, COLOR_SHADE


def row(d, y, title, beats, x0=230, cw=40, gap=14):
    d.add(Text(20, y + 18, title, size=14, anchor="start"))
    x = x0
    for beat in beats:
        cells = [(cw, name or "", {"H": H, "D": D}.get((name or " ")[0], E)) for name in beat]
        fields(d, x, y, cells, h=36, size=13)
        x += cw*len(beat) + gap


def build():
    d = Diagram(CANVAS_WIDTH, 230)
    row(d, 20, "64-bit, 3DW header",
        [["H0", "H1"], ["H2", "D0"], ["D1", "D2"], ["D3", "D4"], ["D5", None]], cw=40, gap=14)
    row(d, 80, "128-bit, 3DW header",
        [["H0", "H1", "H2", "D0"], ["D1", "D2", "D3", "D4"], ["D5", None, None, None]], cw=40, gap=14)
    row(d, 140, "128-bit, 4DW header",
        [["H0", "H1", "H2", "H3"], ["D0", "D1", "D2", "D3"], ["D4", "D5", None, None]], cw=40, gap=14)
    fields(d, 230, 194, [(40, "H", H)], h=26, size=13)
    d.add(Text(280, 207, "header DW", size=13, anchor="start"))
    fields(d, 380, 194, [(40, "D", D)], h=26, size=13)
    d.add(Text(430, 207, "payload DW", size=13, anchor="start"))
    fields(d, 530, 194, [(40, "", E)], h=26, size=13)
    d.add(Text(580, 207, "not valid (be at 0)", size=13, anchor="start"))
    return d
