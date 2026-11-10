#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# UltraScale and UltraScale+ PHYs: the four AXI-Stream interfaces of the hard IP (RQ, CC, CQ, RC)
# and the adapters to the request and completion channels of the endpoint.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 300)
    ep  = d.add(Box(15, 15, 730, 50, label="Endpoint: request and completion channels",
        fill=COLOR_ACCENT_LIGHT))
    hip = d.add(Box(15, 235, 730, 50, label="UltraScale or UltraScale+ hard IP", fill=COLOR_HARDWARE))
    specs = [
        ("RQ adapter\ndevice requests",    "RQ", True),
        ("CC adapter\ndevice completions", "CC", True),
        ("CQ adapter\nhost requests",      "CQ", False),
        ("RC adapter\nhost completions",   "RC", False),
    ]
    for i, (label, name, tx) in enumerate(specs):
        x   = 15 + i*190
        box = d.add(Box(x, 120, 160, 60, label=label, fill=COLOR_ACCENT))
        f   = (x + 80 - 15)/730
        if tx:
            d.add(Arrow((ep, "b", f), (box, "t"), kind="data"))
            d.add(Arrow((box, "b"), (hip, "t", f), kind="data", label=name, label_side="right"))
        else:
            d.add(Arrow((hip, "t", f), (box, "b"), kind="data", label=name, label_side="right"))
            d.add(Arrow((box, "t"), (ep, "b", f), kind="data"))
    return d
