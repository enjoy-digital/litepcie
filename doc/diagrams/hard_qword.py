#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Stratix V qword alignment: where the first payload DW sits on the 256-bit Avalon-ST interface,
# by header size and address bit 2 (padding DW inserted when their parities differ).

from svgdiag import *
from phy_helpers import strip

ROWS = [
    ("3DW header, A[2] = 0", ["H0", "H1", "H2", "PAD", "D0", "D1", "D2", "D3"]),
    ("3DW header, A[2] = 1", ["H0", "H1", "H2", "D0",  "D1", "D2", "D3", "D4"]),
    ("4DW header, A[2] = 0", ["H0", "H1", "H2", "H3",  "D0", "D1", "D2", "D3"]),
    ("4DW header, A[2] = 1", ["H0", "H1", "H2", "H3",  "PAD", "D0", "D1", "D2"]),
]


def fill(label):
    if label == "PAD":
        return COLOR_ACCENT
    return COLOR_ACCENT_LIGHT if label.startswith("H") else COLOR_FILL


def build():
    d = Diagram(CANVAS_WIDTH, 240)
    x0, w = 200, 68
    for i in range(8):
        d.add(Text(x0 + w*i + w/2, 25, f"DW{i}", size=12))
    for r, (title, cells) in enumerate(ROWS):
        y = 50 + r*46
        d.add(Text(15, y + 17, title, size=13, anchor="start"))
        strip(d, x0, y, [(c, fill(c)) for c in cells], w)
    return d
