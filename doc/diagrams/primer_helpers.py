#
# This file is part of LitePCIe.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Shared helpers of the introduction and primer figures (no build(): not a figure).
#
# Exchange (sequence) diagrams: one vertical lane per side (a titled box on top and a dashed line
# below), horizontal arrows between the lanes for the packets, labels above the arrows.

from svgdiag import *


class Exchange:
    """Two-lane exchange diagram: left and right lanes at x_left/x_right."""
    def __init__(self, d, left, right, x_left=170, x_right=590, top=20, bottom=None, fill_left=COLOR_ACCENT,
        fill_right=COLOR_HARDWARE, width=140):
        self.d, self.xl, self.xr = d, x_left, x_right
        bottom = bottom or d.height - 10
        for x, name, fill in ((x_left, left, fill_left), (x_right, right, fill_right)):
            d.add(Box(x - width/2, top, width, 36, label=name, fill=fill))
            d.add(Bus([(x, top + 36), (x, bottom)], dash="4,3"))
        self.y = top + 36 + 26

    def msg(self, label, to="right", kind="control", step=36, note=None, note_side=None):
        """Arrow between the lanes at the current row, label above; returns the row y."""
        y = self.y
        a, b = ((self.xl, y), (self.xr, y)) if to == "right" else ((self.xr, y), (self.xl, y))
        self.d.add(Arrow(a, b, kind=kind, label=label, label_side="above", label_size=15))
        if note:
            note_side = note_side or ("right" if to == "right" else "left")
            if note_side == "right":
                self.d.add(Text(self.xr + 12, y, note, size=14, anchor="start", color="#444444"))
            else:
                self.d.add(Text(self.xl - 12, y, note, size=14, anchor="end", color="#444444"))
        self.y += step
        return y

    def gap(self, step=12):
        """Extra vertical space before the next row."""
        self.y += step


def bitfield(d, x, y, cells, h=30, size=13):
    """Row of adjoining square cells: cells is a list of (width, label, fill)."""
    out = []
    for w, label, fill in cells:
        out.append(d.add(Box(x, y, w, h, label=label, radius=0, fill=fill, size=size)))
        x += w
    return out
