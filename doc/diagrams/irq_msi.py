#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# MSI: interrupt sources, vector register, MSI stream to the PHY, clear written by the driver.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 210)
    src  = d.add(Box(20, 40, 130, 70, label="DMA and\nuser IRQs"))
    msi  = d.add(Box(210, 40, 150, 70, label="LitePCIeMSI\nenable, vector", fill=COLOR_ACCENT))
    phy  = d.add(Box(430, 40, 130, 70, label="PHY\nMSI request", fill=COLOR_ACCENT_LIGHT))
    host = d.add(Box(620, 40, 120, 70, label="Host driver", fill=COLOR_HARDWARE))
    d.add(Arrow((src, "r"), (msi, "l"), kind="data", label="irqs", label_pos=(180, 63)))
    d.add(Arrow((msi, "r"), (phy, "l"), kind="accent", label="msi stream", label_pos=(395, 63)))
    d.add(Arrow((phy, "r"), (host, "l"), kind="data", label="MSI", label_pos=(590, 63)))
    d.add(Arrow((host.cx, host.y + host.h), (msi.cx, msi.y + msi.h), via=[(host.cx, 160),
        (msi.cx, 160)], kind="feedback", label="read vector, write clear (BAR0)",
        label_pos=(487, 175)))
    return d
