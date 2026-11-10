#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# DMA plug-ins: buffering, synchronizer and loopback between user logic and the Writer/Reader.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 270)
    user = d.add(Box(20, 30, 100, 180, label="User logic"))
    buf  = d.add(Box(165, 30, 120, 180, label="Buffering", fill=COLOR_ACCENT))
    syn  = d.add(Box(330, 30, 120, 180, label="Synchronizer", fill=COLOR_ACCENT))
    loop = d.add(Box(495, 30, 100, 180, label="Loopback", fill=COLOR_ACCENT))
    wr   = d.add(Box(640, 30, 100, 70, label="DMA writer", fill=COLOR_ACCENT_LIGHT))
    rd   = d.add(Box(640, 140, 100, 70, label="DMA reader", fill=COLOR_ACCENT_LIGHT))
    chain = [user, buf, syn, loop]
    for a, b in zip(chain, chain[1:]):
        d.add(Arrow((a.x + a.w, wr.cy), (b.x, wr.cy), kind="data"))
        d.add(Arrow((b.x, rd.cy), (a.x + a.w, rd.cy), kind="data"))
    d.add(Arrow((loop.x + loop.w, wr.cy), (wr, "l"), kind="data"))
    d.add(Arrow((rd, "l"), (loop.x + loop.w, rd.cy), kind="data"))
    d.add(Arrow((syn.cx, 255), (syn.cx, syn.y + syn.h), kind="control", label="pps",
        label_pos=(syn.cx + 22, 240)))
    return d
