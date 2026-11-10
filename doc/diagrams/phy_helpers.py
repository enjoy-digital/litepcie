#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Shared helpers of the PHY figures (hard_*, soft_*); no build(): not a figure.

from svgdiag import *

HEADER = "phy_helpers"


def strip(d, x, y, cells, w, h=34, size=13):
    """Row of adjoining square cells of width w: cells = [(label, fill)]; returns the boxes."""
    boxes = []
    for label, fill in cells:
        boxes.append(d.add(Box(x, y, w, h, label=label, radius=0, size=size, fill=fill)))
        x += w
    return boxes


def frac(box, y):
    """Fraction of the height of box at which an horizontal arrow at ordinate y meets its side."""
    return (y - box.y)/box.h
