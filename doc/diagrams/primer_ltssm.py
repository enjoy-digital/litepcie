#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Simplified PCI Express LTSSM: training to L0, Recovery, L1 and the failure path.

from svgdiag import *


def build():
    d = Diagram(CANVAS_WIDTH, 250)
    det = d.add(Box(15,  30,  110, 44, label="Detect"))
    pol = d.add(Box(205, 30,  120, 44, label="Polling", fill=COLOR_ACCENT_LIGHT))
    cfg = d.add(Box(395, 30,  150, 44, label="Configuration", fill=COLOR_ACCENT_LIGHT))
    l0  = d.add(Box(615, 30,  125, 44, label="L0", fill=COLOR_ACCENT))
    pm  = d.add(Box(395, 150, 150, 44, label="L1"))
    rec = d.add(Box(615, 150, 125, 44, label="Recovery", fill=COLOR_ACCENT_LIGHT))
    # Training: Detect -> Polling -> Configuration -> L0.
    d.add(Arrow((det, "r", 0.3), (pol, "l", 0.3), kind="data", label="found"))
    d.add(Arrow((pol, "l", 0.75), (det, "r", 0.75), kind="feedback", label="timeout", label_side="below"))
    d.add(Arrow((pol, "r"), (cfg, "l"), kind="data", label="TS1, TS2"))
    d.add(Arrow((cfg, "r"), (l0, "l"), kind="data", label="trained"))
    # Recovery: retraining, speed change and equalization.
    d.add(Arrow((l0, "b", 0.3), (rec, "t", 0.3), kind="control", label="errors, speed",
        label_pos=(645, 130), label_anchor="end"))
    d.add(Arrow((rec, "t", 0.7), (l0, "b", 0.7), kind="data", label="done", label_side="right"))
    # L1: entered from L0 when the link is idle, left through Recovery.
    d.add(Arrow((l0, "b", 0.1), (pm, "t"), via=[(627, 100), (470, 100)], kind="control",
        label="idle", label_pos=(545, 92)))
    d.add(Arrow((pm, "r"), (rec, "l"), kind="control", label="exit"))
    # Failure of Recovery: back to Detect.
    d.add(Arrow((rec, "b"), (det, "b"), via=[(677, 228), (70, 228)], kind="feedback",
        label="failure", label_pos=(280, 220)))
    return d
