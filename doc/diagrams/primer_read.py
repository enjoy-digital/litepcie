#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Posted write and non-posted reads: completions split in pieces, tags interleaved.

from primer_helpers import *


def build():
    d = Diagram(CANVAS_WIDTH, 340)
    e = Exchange(d, "Device", "Root complex")
    e.msg("MemWr, 256 bytes", to="right", kind="accent", note="posted: no reply")
    e.msg("MemRd, tag 3, 256 bytes", to="right", note="non-posted")
    e.msg("MemRd, tag 4, 256 bytes", to="right")
    e.gap()
    e.msg("CplD, tag 3, 128 bytes", to="left", kind="accent", note="byte count 256")
    e.msg("CplD, tag 4, 128 bytes", to="left", kind="accent", note="byte count 256")
    e.msg("CplD, tag 3, 128 bytes", to="left", kind="accent", note="byte count 128")
    e.msg("CplD, tag 4, 128 bytes", to="left", kind="accent", note="byte count 128")
    return d
