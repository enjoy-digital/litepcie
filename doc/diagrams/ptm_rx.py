#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Multi-lane Gen1/Gen2 PTM receiver: lane descrambling, SKP removal, deskew, parsing, CDC.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 130)
    names = [("Lane\ndescramblers", COLOR_ACCENT_LIGHT, 2), ("SKP removal\nlane buffers", COLOR_ACCENT_LIGHT, 2),
        ("Deskew and\nde-striping", COLOR_ACCENT, 0), ("Response\nparser", COLOR_ACCENT, 0),
        ("Clock domain\ncrossing", COLOR_FILL, 0), ("PTM\nrequester", COLOR_FILL, 0)]
    boxes, x, w, gap = [], 20, 104, 23
    for label, fill, stack in names:
        boxes.append(d.add(Box(x, 30, w, 70, label=label, fill=fill, stack=stack)))
        x += w + gap
    for a, b in zip(boxes, boxes[1:]):
        d.add(Arrow((a.x + a.w + (8 if a.stack else 0), a.cy), (b, "l"), kind="accent"))
    return d
