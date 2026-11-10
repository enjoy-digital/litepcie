#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Core architecture: PHY, TLP packetizer/depacketizer, crossbar, TLP controller and frontends.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 330)
    d.add(Container(140, 15, 385, 300, title="LitePCIeEndpoint", title_pos="bl"))
    phy   = d.add(Box(20,  40, 100, 220, label="PHY\nhard IP or\nsoft PHY", fill=COLOR_HARDWARE))
    depkt = d.add(Box(165, 50, 130, 50, label="TLP\ndepacketizer", fill=COLOR_ACCENT_LIGHT))
    pkt   = d.add(Box(165, 200, 130, 50, label="TLP\npacketizer", fill=COLOR_ACCENT_LIGHT))
    xbar  = d.add(Box(325, 40, 85, 220, label="Crossbar", fill=COLOR_ACCENT))
    ctrl  = d.add(Box(430, 170, 85, 60, label="TLP\ncontroller", fill=COLOR_ACCENT))
    slv   = d.add(Box(615, 40, 135, 55, label="Wishbone master\nPTM capability"))
    wr    = d.add(Box(615, 115, 135, 50, label="DMA Writers\nDMA status"))
    rd    = d.add(Box(615, 185, 135, 100, label="DMA Readers\nbridges to host\nMSI-X"))
    d.add(Arrow((phy.x + phy.w, depkt.cy), (depkt, "l"), kind="data"))
    d.add(Arrow((pkt, "l"), (phy.x + phy.w, pkt.cy), kind="data"))
    d.add(Arrow((depkt, "r"), (xbar.x, depkt.cy), kind="data"))
    d.add(Arrow((xbar.x, pkt.cy), (pkt, "r"), kind="data"))
    d.add(Arrow((slv.x, slv.cy), (xbar.x + xbar.w, slv.cy), kind="data", heads="both",
        label="slave", label_pos=(570, slv.cy - 10)))
    d.add(Arrow((wr.x, wr.cy), (xbar.x + xbar.w, wr.cy), kind="accent",
        label="write-only", label_pos=(570, wr.cy - 10)))
    d.add(Arrow((rd.x, ctrl.cy + 20), (ctrl.x + ctrl.w, ctrl.cy + 20), kind="accent", heads="both",
        label="read-capable", label_pos=(570, ctrl.cy + 10)))
    d.add(Arrow((ctrl, "l"), (xbar.x + xbar.w, ctrl.cy), kind="accent", heads="both"))
    return d
