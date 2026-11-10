#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Root port: the FPGA drives the link; user logic issues configuration and memory requests.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 230)
    user = d.add(Box(20, 30, 125, 60, label="User logic\nor CPU"))
    mem  = d.add(Box(20, 140, 125, 60, label="SoC memory"))
    core = d.add(Box(215, 30, 150, 170, label="LitePCIe\nroot port", fill=COLOR_ACCENT))
    hard = d.add(Box(420, 30, 130, 170, label="Hard IP\nRootPort mode", fill=COLOR_ACCENT_LIGHT))
    dev  = d.add(Box(610, 30, 130, 170, label="Downstream\ndevice", fill=COLOR_HARDWARE))
    d.add(Arrow((user, "r"), (core.x, user.cy), kind="accent", heads="both", label="requests",
        label_pos=(180, user.cy - 12)))
    d.add(Arrow((core.x, mem.cy), (mem, "r"), kind="data", heads="both", label="device DMA",
        label_pos=(180, mem.cy - 12)))
    d.add(Arrow((core.x + core.w, core.cy), (hard.x, core.cy), kind="data", heads="both"))
    d.add(Arrow((hard.x + hard.w, hard.cy), (dev.x, hard.cy), kind="data", heads="both",
        label="link", label_pos=(580, hard.cy - 12)))
    return d
