#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# PTM dialog: the endpoint (requester) sends a PTM Request, the root port answers a PTM ResponseD.

from core_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 210)
    lanes = Lanes(d, "Root port\nPTM responder", "LitePCIe endpoint\nPTM requester", xl=240, xr=520,
        rows=2)
    lanes.msg("PTM Request", to_right=False, left_note="t2: received", right_note="t1: sent")
    lanes.msg("PTM ResponseD", to_right=True, kind="accent", left_note="t3: sent",
        right_note="t4: received")
    return d
