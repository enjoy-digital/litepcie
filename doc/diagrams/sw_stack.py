#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Software stack: application, liblitepcie, driver and DMA buffers, FPGA registers and DMA channels.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 380)
    d.add(Container(20, 20, 450, 120, title="User space", title_pos="bl"))
    d.add(Container(230, 170, 240, 190, title="Kernel", title_pos="bl"))
    d.add(Container(520, 20, 220, 340, title="FPGA", title_pos="br"))
    app = d.add(Box(50, 45, 160, 55, label="Application,\ntools"))
    lib = d.add(Box(260, 45, 170, 55, label="liblitepcie"))
    drv = d.add(Box(260, 185, 170, 50, label="Driver"))
    buf = d.add(Box(260, 255, 170, 50, label="DMA buffers", fill=COLOR_ACCENT_LIGHT))
    reg = d.add(Box(550, 45, 160, 55, label="Registers\n(BAR0)"))
    eng = d.add(Box(550, 240, 160, 60, label="DMA\nchannels", fill=COLOR_ACCENT))
    d.add(Arrow((app, "r"), (lib, "l"), kind="control"))
    d.add(Arrow((lib, "b"), (drv, "t"), kind="control", label="ioctl, read, write",
        label_pos=(353, 155), label_anchor="start"))
    d.add(Arrow((430, 195), (550, 72), via=[(490, 195), (490, 72)], kind="control"))
    d.add(Arrow((550, 255), (430, 225), via=[(505, 255), (505, 225)], kind="control", label="MSI",
        label_pos=(450, 218)))
    d.add(Arrow((drv, "b"), (buf, "t"), kind="control"))
    d.add(Arrow((eng, "l", 0.75), (430, 285), kind="accent", heads="both", label="DMA"))
    return d
