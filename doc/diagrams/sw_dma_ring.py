#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Driver DMA ring: 256 buffers of 8 KiB per direction, hw_count and sw_count, one MSI every 32 buffers.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 270)
    labels = ["0", "1", "...", "31", "32", "...", "254", "255"]
    cells  = []
    for i, l in enumerate(labels):
        fill = COLOR_ACCENT if 1 <= i <= 3 else COLOR_FILL
        cells.append(d.add(Box(60 + 80*i, 110, 80, 44, label=l, radius=0, fill=fill)))
    d.add(Text(140, 50, "sw_count", size=FONT_SIZE_SM))
    d.add(Arrow((140, 60), (140, 110), kind="control"))
    d.add(Text(380, 50, "hw_count", size=FONT_SIZE_SM))
    d.add(Arrow((380, 60), (380, 110), kind="control"))
    d.add(Text(78, 175, "MSI", size=FONT_SIZE_SM))
    d.add(Text(420, 175, "MSI", size=FONT_SIZE_SM))
    d.add(Arrow((660, 154), (100, 154), via=[(660, 225), (100, 225)], kind="feedback",
        label="Loop mode: back to buffer 0", label_pos=(380, 240)))
    return d
