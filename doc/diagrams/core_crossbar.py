#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Crossbar master path: read-only, read-write and write-only ports, TLP controller, final arbiter.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 300)
    rd   = d.add(Box(20, 30, 130, 50, label="Read-only\nports"))
    rw   = d.add(Box(20, 110, 130, 50, label="Read-write\nports"))
    wr   = d.add(Box(20, 220, 130, 50, label="Write-only\nports"))
    arb0 = d.add(Box(195, 30, 100, 130, label="Arbiter and\ndispatcher", fill=COLOR_ACCENT_LIGHT))
    ctrl = d.add(Box(335, 65, 105, 60, label="TLP\ncontroller", fill=COLOR_ACCENT))
    arb1 = d.add(Box(195, 220, 100, 50, label="Arbiter and\ndispatcher", fill=COLOR_ACCENT_LIGHT))
    arb2 = d.add(Box(480, 30, 100, 240, label="Arbiter and\ndispatcher", fill=COLOR_ACCENT_LIGHT))
    pkt  = d.add(Box(620, 125, 120, 50, label="Packetizer\ndepacketizer", fill=COLOR_HARDWARE))
    d.add(Arrow((rd, "r"), (arb0.x, rd.cy), kind="accent", heads="both"))
    d.add(Arrow((rw, "r"), (arb0.x, rw.cy), kind="accent", heads="both"))
    d.add(Arrow((arb0.x + arb0.w, ctrl.cy), (ctrl, "l"), kind="accent", heads="both"))
    d.add(Arrow((ctrl, "r"), (arb2.x, ctrl.cy), kind="accent", heads="both"))
    d.add(Arrow((wr, "r"), (arb1, "l"), kind="data", heads="both"))
    d.add(Arrow((arb1, "r"), (arb2.x, arb1.cy), kind="data", heads="both"))
    d.add(Arrow((arb2.x + arb2.w, pkt.cy), (pkt, "l"), kind="data", heads="both"))
    return d
