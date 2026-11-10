#
# This file is part of LitePCIe project.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Soft PHY SoC simulation (bench/soft/sim_soc.py): a root built from the soft Physical and Data Link
# Layers with a host model, and the LitePCIe SoC on SoftPCIEPHY, linked by two transceiver models.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 400)
    root = d.add(Container(20, 20, 300, 360, title="Root side", title_pos="tl"))
    dev  = d.add(Container(440, 20, 300, 360, title="Device side", title_pos="tr"))
    host = d.add(Box(60, 65, 220, 46, label="Host model\n(driver sequence)", fill=COLOR_ACCENT_LIGHT))
    dll  = d.add(Box(60, 145, 220, 40, label="Data Link Layer"))
    phy  = d.add(Box(60, 220, 220, 46, label="Physical Layer\n(downstream)"))
    rser = d.add(Box(60, 300, 220, 40, label="Transceiver model", fill=COLOR_HARDWARE))
    soc  = d.add(Box(480, 65, 220, 46, label="LitePCIe SoC\n(DMA, MSI, BAR0)", fill=COLOR_ACCENT))
    soft = d.add(Box(480, 182, 220, 46, label="SoftPCIEPHY", fill=COLOR_ACCENT))
    dser = d.add(Box(480, 300, 220, 40, label="Transceiver model", fill=COLOR_HARDWARE))
    for a, b in ((host, dll), (dll, phy), (phy, rser), (soc, soft), (soft, dser)):
        d.add(Arrow((a, "b"), (b, "t"), kind="data", heads="both"))
    d.add(Arrow((rser, "r", 0.3), (dser, "l", 0.3), kind="accent", label="symbols", label_side="above"))
    d.add(Arrow((dser, "l", 0.7), (rser, "r", 0.7), kind="accent", label="shift, skew",
        label_side="below"))
    return d
