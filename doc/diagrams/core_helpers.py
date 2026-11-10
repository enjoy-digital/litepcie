#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Shared helpers of the core figures (core_*.py, dma_*.py, mmap_*.py, irq_*.py, ptm_*.py): bit and
# word fields, packet exchange lanes. Not a figure (no build()).

from svgdiag import *

# Fields -------------------------------------------------------------------------------------------

def fields(d, x, y, cells, h=40, size=FONT_SIZE):
    """Adjoining square cells: cells is a list of (width, label, fill); returns the boxes."""
    boxes = []
    for w, label, fill in cells:
        boxes.append(d.add(Box(x, y, w, h, label=label, radius=0, fill=fill, size=size)))
        x += w
    return boxes

# Packet exchange lanes ----------------------------------------------------------------------------

class Lanes:
    """Two vertical lanes (left/right) with a title box on top of each; messages are horizontal
    arrows between them, one per row, the label above the arrow and optional notes outside."""
    def __init__(self, d, left, right, xl=230, xr=530, top=20, row=60, rows=3, bw=170,
        left_fill=COLOR_HARDWARE, right_fill=COLOR_ACCENT):
        self.d, self.xl, self.xr, self.row = d, xl, xr, row
        self.y0 = top + 50 + row*0.6
        bottom  = top + 50 + row*(rows + 0.2)
        d.add(Box(xl - bw/2, top, bw, 46, label=left,  fill=left_fill))
        d.add(Box(xr - bw/2, top, bw, 46, label=right, fill=right_fill))
        d.add(Bus([(xl, top + 46), (xl, bottom)], dash="4,3"))
        d.add(Bus([(xr, top + 46), (xr, bottom)], dash="4,3"))
        self.n = 0

    def msg(self, label, to_right=True, kind="data", left_note=None, right_note=None):
        y = self.y0 + self.n*self.row
        a, b = ((self.xl, y), (self.xr, y)) if to_right else ((self.xr, y), (self.xl, y))
        self.d.add(Arrow(a, b, kind=kind, label=label, label_pos=((self.xl + self.xr)/2, y - 12),
            label_size=15))
        if left_note:
            self.d.add(Text(self.xl - 12, y, left_note, size=14, anchor="end"))
        if right_note:
            self.d.add(Text(self.xr + 12, y, right_note, size=14, anchor="start"))
        self.n += 1
        return y
