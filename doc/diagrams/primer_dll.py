#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Data link layer: flow control initialization, TLP sequence numbers, ACK/NAK and replay, UpdateFC.

from primer_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 400)
    e = Exchange(d, "Device", "Root complex")
    e.msg("InitFC1, InitFC2", to="right", note="credits offered", note_side="left")
    e.msg("InitFC1, InitFC2", to="left", note="DL_Active")
    e.gap()
    e.msg("TLP, seq 0", to="right", kind="accent", note="kept for replay", note_side="left")
    e.msg("TLP, seq 1", to="right", kind="accent")
    e.msg("ACK 0", to="left", note="seq 0 freed")
    e.msg("NAK 0", to="left", note="seq 1 bad LCRC", note_side="right")
    e.msg("TLP, seq 1 (replay)", to="right", kind="accent", note="sent again", note_side="left")
    e.msg("ACK 1", to="left")
    e.msg("UpdateFC", to="left", note="credits back")
    return d
