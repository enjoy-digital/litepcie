#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# One core on many PHYs: the vendor hard IPs and the soft PHY on the transceivers.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 225)
    core = d.add(Box(180, 15, 400, 44, label="LitePCIe core, frontends and driver", fill=COLOR_ACCENT))
    d.add(Container(5, 100, 590, 115, title="Hard-IP PHYs", title_pos="bl"))
    d.add(Container(605, 100, 150, 115, title="Soft PHY", title_pos="br"))
    phys = [
        (15,  "Xilinx\n7-Series, US, US+"),
        (160, "Intel\nCyclone V, Stratix V"),
        (305, "Gowin\nGW5A"),
        (450, "Lattice\nCertusPro-NX"),
        (615, "Transceivers\nGTP, GTX, GTY"),
    ]
    d.add(Bus([(380, 59), (380, 82)], kind="data"))
    d.add(Bus([(80, 82), (680, 82)], kind="data"))
    for x, label in phys:
        b = d.add(Box(x, 115, 130, 52, label=label, size=13, fill=COLOR_ACCENT_LIGHT if x > 600 else COLOR_FILL))
        d.add(Arrow((b.cx, 82), (b, "t"), kind="data"))
    return d
