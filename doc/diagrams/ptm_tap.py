#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# PTM paths: requests through the packetizer and hard IP, responses through a passive receive tap.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 250)
    rp   = d.add(Box(20, 30, 100, 190, label="Root port", fill=COLOR_HARDWARE))
    gt   = d.add(Box(160, 30, 110, 190, label="Transceivers\nPIPE", fill=COLOR_HARDWARE))
    hard = d.add(Box(320, 30, 120, 70, label="PCIe hard\nblock", fill=COLOR_HARDWARE))
    tap  = d.add(Box(320, 150, 120, 70, label="PTM receive\ntap", fill=COLOR_ACCENT))
    pkt  = d.add(Box(490, 30, 120, 70, label="TLP\npacketizer", fill=COLOR_ACCENT_LIGHT))
    req  = d.add(Box(490, 150, 120, 70, label="PTM\nrequester", fill=COLOR_ACCENT))
    d.add(Arrow((rp.x + rp.w, rp.cy), (gt.x, rp.cy), kind="data", heads="both", label="link",
        label_pos=(140, rp.cy - 12)))
    d.add(Arrow((gt.x + gt.w, hard.cy), (hard, "l"), kind="data", heads="both"))
    d.add(Arrow((gt.x + gt.w, tap.cy), (tap, "l"), kind="accent"))
    d.add(Arrow((tap, "r"), (req, "l"), kind="accent"))
    d.add(Arrow((req, "t"), (pkt, "b"), kind="control", label="request", label_pos=(570, 125)))
    d.add(Arrow((pkt, "l"), (hard, "r"), kind="data"))
    d.add(Arrow((740, req.cy), (req, "r"), kind="control", label="time", label_pos=(690, req.cy - 10)))
    return d
