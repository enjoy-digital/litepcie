#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# TLP controller: tag queue, request queue and per-tag completion buffers (reordering).

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 280)
    tags  = d.add(Box(200, 20, 110, 50, label="Tag queue", fill=COLOR_ACCENT_LIGHT))
    reqq  = d.add(Box(420, 20, 120, 50, label="Request queue", fill=COLOR_ACCENT_LIGHT))
    mux   = d.add(Box(220, 170, 110, 70, label="Mux in\nrequest order"))
    bufs  = d.add(Box(400, 170, 130, 70, label="Buffer\nper tag", fill=COLOR_ACCENT, stack=2))
    demux = d.add(Box(570, 170, 100, 70, label="Demux\nby tag"))
    d.add(Arrow((20, 100), (740, 100), kind="data", label="read requests, tagged",
        label_pos=(110, 88)))
    d.add(Arrow((tags.cx, tags.y + tags.h), (tags.cx, 100), kind="control"))
    d.add(Arrow((reqq.cx, 100), (reqq.cx, reqq.y + reqq.h), kind="control"))
    d.add(Arrow((740, 205), (demux, "r"), kind="data", label="completions", label_pos=(706, 193)))
    d.add(Arrow((demux, "l"), (bufs.x + bufs.w + 8, 205), kind="data"))
    d.add(Arrow((bufs, "l"), (mux, "r"), kind="data"))
    d.add(Arrow((mux, "l"), (20, 205), kind="accent", label="in order", label_pos=(70, 193)))
    d.add(Arrow((reqq.x + reqq.w, reqq.cy), (mux.x + 90, mux.y), via=[(570, reqq.cy), (570, 140),
        (mux.x + 90, 140)], kind="control"))
    d.add(Arrow((mux.x + 12, mux.y), (mux.x + 12, tags.y + tags.h), kind="feedback"))
    d.add(Text(mux.x + 4, 140, "tag freed", size=12, anchor="end"))
    return d
