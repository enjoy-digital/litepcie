#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Lane datapaths of the soft PHY: SKP insertion and scrambling on TX; descrambling, SKP removal and
# elastic buffer on RX; 8b/10b in the fabric, raw words to the transceiver.

from svgdiag import *
from phy_helpers import frac


def build():
    d = Diagram(CANVAS_WIDTH, 230)
    pl   = d.add(Box(15, 20, 90, 190, label="Physical\nLayer", fill=COLOR_ACCENT_LIGHT))
    skpi = d.add(Box(130, 30, 100, 60, label="SKP\ninsertion", fill=COLOR_ACCENT))
    scr  = d.add(Box(250, 30, 100, 60, label="Scrambler", fill=COLOR_ACCENT))
    eb   = d.add(Box(130, 140, 100, 60, label="Elastic\nbuffer", fill=COLOR_ACCENT))
    skpr = d.add(Box(250, 140, 100, 60, label="SKP\nremoval", fill=COLOR_ACCENT))
    dscr = d.add(Box(370, 140, 105, 60, label="Descrambler", fill=COLOR_ACCENT))
    code = d.add(Box(500, 20, 100, 190, label="8b/10b\nLiteICLink"))
    gt   = d.add(Box(645, 20, 100, 190, label="Transceiver", fill=COLOR_HARDWARE))
    ytx, yrx = 60, 170
    d.add(Arrow((pl, "r", frac(pl, ytx)), (skpi, "l"), kind="data"))
    d.add(Arrow((skpi, "r"), (scr, "l"), kind="data"))
    d.add(Arrow((scr, "r"), (code, "l", frac(code, ytx)), kind="data"))
    d.add(Arrow((code, "r", frac(code, ytx)), (gt, "l", frac(gt, ytx)), kind="data"))
    d.add(Arrow((gt, "l", frac(gt, yrx)), (code, "r", frac(code, yrx)), kind="data"))
    d.add(Arrow((code, "l", frac(code, yrx)), (dscr, "r"), kind="data"))
    d.add(Arrow((dscr, "l"), (skpr, "r"), kind="data"))
    d.add(Arrow((skpr, "l"), (eb, "r"), kind="data"))
    d.add(Arrow((eb, "l"), (pl, "r", frac(pl, yrx)), kind="data"))
    return d
