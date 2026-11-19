#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# TLP controller: completion buffers of all the tags in one memory (cmp_bufs_shared).

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 250)
    rptr = d.add(Box(150, 20, 130, 60, label="Read pointer\nper tag", fill=COLOR_ACCENT_LIGHT))
    wptr = d.add(Box(480, 20, 130, 60, label="Write pointer\nper tag", fill=COLOR_ACCENT_LIGHT))
    oreg = d.add(Box(150, 160, 110, 60, label="Output\nregister"))
    mem  = d.add(Box(315, 150, 130, 80, label="One memory\nan area per tag", fill=COLOR_ACCENT))
    # Completions, from right to left.
    d.add(Arrow((740, mem.cy), (mem, "r"), kind="data", label="completions",
        label_pos=(680, mem.cy - 12)))
    d.add(Arrow((mem, "l"), (oreg, "r"), kind="data"))
    d.add(Arrow((oreg, "l"), (20, oreg.cy), kind="accent", label="in order",
        label_pos=(80, oreg.cy - 12)))
    # Write address: tag of the completion and write pointer of this tag.
    d.add(Arrow((740, wptr.cy), (wptr, "r"), kind="control", label="completion tag",
        label_pos=(680, wptr.cy - 10)))
    d.add(Arrow((wptr.cx, wptr.y + wptr.h), (mem.x + 100, mem.y), via=[(wptr.cx, 115),
        (mem.x + 100, 115)], kind="control", label="write address", label_pos=(545, 133)))
    # Read address: tag of the oldest request and read pointer of this tag.
    d.add(Arrow((20, rptr.cy), (rptr, "l"), kind="control", label="oldest request tag",
        label_pos=(80, rptr.cy - 10)))
    d.add(Arrow((rptr.cx, rptr.y + rptr.h), (mem.x + 30, mem.y), via=[(rptr.cx, 115),
        (mem.x + 30, 115)], kind="control", label="read address", label_pos=(275, 133)))
    return d
