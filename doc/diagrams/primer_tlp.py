#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# TLP headers: DW0 common to all TLPs, request DW1/DW2 (3DW), 64-bit address DW2/DW3 (4DW),
# completion DW1/DW2. One row per 32-bit DW, bit 31 on the left.

from primer_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 380)
    x0 = 90
    A, L, S = COLOR_ACCENT, COLOR_ACCENT_LIGHT, COLOR_SHADE
    d.add(Text(x0, 12, "bit 31", size=12, anchor="start"))
    d.add(Text(x0 + 640, 12, "bit 0", size=12, anchor="end"))
    groups = [
        ("Every TLP", [
            ("DW0", [(60, "Fmt", A), (100, "Type", A), (20, "", S), (60, "TC", L), (80, "flags", L),
                     (20, "TD", L), (20, "EP", L), (40, "Attr", L), (40, "AT", S), (200, "Length (DW)", A)]),
        ]),
        ("Request, 3DW: MemRd, MemWr below 4 GiB", [
            ("DW1", [(320, "Requester ID", L), (160, "Tag", A), (80, "Last BE", L), (80, "First BE", L)]),
            ("DW2", [(600, "Address [31:2]", A), (40, "", S)]),
        ]),
        ("Request, 4DW: address above 4 GiB", [
            ("DW2", [(640, "Address [63:32]", A)]),
            ("DW3", [(600, "Address [31:2]", A), (40, "", S)]),
        ]),
        ("Completion: Cpl, CplD", [
            ("DW1", [(320, "Completer ID", L), (60, "Status", A), (20, "", S), (240, "Byte Count", A)]),
            ("DW2", [(320, "Requester ID", L), (160, "Tag", A), (20, "", S), (140, "Lower Addr", L)]),
        ]),
    ]
    y = 28
    for title, rows in groups:
        d.add(Text(x0, y + 10, title, size=13, anchor="start", italic=True))
        y += 22
        for name, cells in rows:
            d.add(Text(x0 - 12, y + 15, name, size=13, anchor="end"))
            bitfield(d, x0, y, cells)
            y += 30
        y += 10
    return d
