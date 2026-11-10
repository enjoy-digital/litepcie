#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# DMA channel: user streams, plug-ins, Writer (MemWr) and Reader (MemRd), crossbar, host memory.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 250)
    user = d.add(Box(20, 30, 100, 190, label="User logic"))
    plug = d.add(Box(160, 30, 110, 190, label="Plug-ins", fill=COLOR_ACCENT_LIGHT))
    wr   = d.add(Box(315, 30, 150, 70, label="DMA writer\ntable, splitter", fill=COLOR_ACCENT))
    rd   = d.add(Box(315, 150, 150, 70, label="DMA reader\ntable, splitter", fill=COLOR_ACCENT))
    xbar = d.add(Box(510, 30, 100, 190, label="Crossbar"))
    host = d.add(Box(650, 30, 90, 190, label="PHY and\nhost\nmemory", fill=COLOR_HARDWARE))
    d.add(Arrow((user.x + user.w, wr.cy), (plug.x, wr.cy), kind="accent", label="sink",
        label_pos=(140, wr.cy - 12)))
    d.add(Arrow((plug.x + plug.w, wr.cy), (wr, "l"), kind="accent"))
    d.add(Arrow((wr, "r"), (xbar.x, wr.cy), kind="data", label="MemWr", label_pos=(487, wr.cy - 12)))
    d.add(Arrow((rd.x + rd.w, rd.y + 20), (xbar.x, rd.y + 20), kind="data", label="MemRd",
        label_pos=(487, rd.y + 8)))
    d.add(Arrow((xbar.x, rd.y + 55), (rd.x + rd.w, rd.y + 55), kind="data", label="CplD",
        label_pos=(487, rd.y + 43)))
    d.add(Arrow((rd, "l"), (plug.x + plug.w, rd.cy), kind="accent"))
    d.add(Arrow((plug.x, rd.cy), (user.x + user.w, rd.cy), kind="accent", label="source",
        label_pos=(140, rd.cy - 12)))
    d.add(Arrow((xbar.x + xbar.w, xbar.cy), (host.x, xbar.cy), kind="data", heads="both"))
    return d
