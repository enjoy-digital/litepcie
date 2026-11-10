#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Descriptor table: Prog mode (filled by software) and Loop mode (each descriptor refilled).

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 200)
    regs  = d.add(Box(20, 40, 120, 60, label="Registers\nvalue, we"))
    mode  = d.add(Box(185, 40, 100, 60, label="Mode\nloop_prog_n", fill=COLOR_ACCENT_LIGHT))
    table = d.add(Box(330, 40, 130, 60, label="Table FIFO\n256 entries", fill=COLOR_ACCENT, stack=2))
    split = d.add(Box(510, 40, 95, 60, label="Splitter"))
    fsm   = d.add(Box(645, 40, 95, 60, label="Write or\nread FSM"))
    d.add(Arrow((regs, "r"), (mode, "l"), kind="data", label="Prog", label_pos=(162, 58)))
    d.add(Arrow((mode, "r"), (table.x, mode.cy), kind="data"))
    d.add(Arrow((table.x + table.w + 8, table.cy), (split, "l"), kind="accent"))
    d.add(Arrow((split, "r"), (fsm, "l"), kind="data"))
    d.add(Arrow((488, table.cy), (mode.cx, mode.y + mode.h), via=[(488, 150), (mode.cx, 150)],
        kind="feedback", label="refill in Loop mode", label_pos=(395, 162)))
    return d
