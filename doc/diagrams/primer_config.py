#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Type 0 configuration header (the first 64 bytes of the configuration space of an endpoint).

from primer_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 395)
    x0, w, h = 150, 120, 22
    A, L, S, F = COLOR_ACCENT, COLOR_ACCENT_LIGHT, COLOR_SHADE, COLOR_FILL
    rows = [
        (0x00, [(2, "Device ID", L), (2, "Vendor ID", L)], None),
        (0x04, [(2, "Status", F), (2, "Command", A)], "enables"),
        (0x08, [(3, "Class Code", F), (1, "Revision ID", F)], None),
        (0x0c, [(1, "BIST", F), (1, "Header Type", F), (1, "Latency Timer", F), (1, "Cache Line Size", F)], None),
        (0x10, [(4, "BAR0", A)], "first BAR"),
        (0x14, [(4, "BAR1", F)], None),
        (0x18, [(4, "BAR2", F)], None),
        (0x1c, [(4, "BAR3", F)], None),
        (0x20, [(4, "BAR4", F)], None),
        (0x24, [(4, "BAR5", F)], None),
        (0x28, [(4, "Cardbus CIS Pointer", S)], None),
        (0x2c, [(2, "Subsystem ID", F), (2, "Subsystem Vendor ID", F)], None),
        (0x30, [(4, "Expansion ROM Base Address", F)], None),
        (0x34, [(3, "Reserved", S), (1, "Cap. Pointer", A)], "capability list"),
        (0x38, [(4, "Reserved", S)], None),
        (0x3c, [(1, "Max_Lat", S), (1, "Min_Gnt", S), (1, "Interrupt Pin", F), (1, "Interrupt Line", F)], None),
    ]
    d.add(Text(x0, 12, "byte 3", size=12, anchor="start"))
    d.add(Text(x0 + 4*w, 12, "byte 0", size=12, anchor="end"))
    y = 28
    for offset, cells, note in rows:
        d.add(Text(x0 - 12, y + h/2, f"0x{offset:02x}", size=12, anchor="end"))
        bitfield(d, x0, y, [(n*w, label, fill) for n, label, fill in cells], h=h, size=12)
        if note:
            d.add(Text(x0 + 4*w + 14, y + h/2, note, size=12, anchor="start", color="#444444"))
        y += h
    return d
