#
# This file is part of the LiteX manual kit.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Title page background of the PDF manual: a light page (#f3f6f9, the tint of enjoy-digital.fr) for
# the title, and a dark band at the bottom (#010101, the website hero) holding the logo, with the
# faint cyan 32 px grid of the website bands fading in from the left and cyan rules. Written as an
# SVG (A4, 595 x 842 pt) and converted to PDF by build.py.

PAGE_W, PAGE_H = 595, 842
GRID           = 24      # pt, the 32 px grid of the website at the PDF scale.
BAND_H         = 200     # pt, dark band at the bottom of the page (holds the logo).
CYAN           = "#2eaadc"
PAPER          = "#f3f6f9"
HERO           = "#010101"


def cover_svg():
    band_y = PAGE_H - BAND_H
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{PAGE_W}" height="{PAGE_H}" '
           f'viewBox="0 0 {PAGE_W} {PAGE_H}">',
           f'<rect width="{PAGE_W}" height="{PAGE_H}" fill="{PAPER}"/>',
           f'<rect x="0" y="{band_y}" width="{PAGE_W}" height="{BAND_H}" fill="{HERO}"/>']
    # Grid: opacity grows from 0 at 35% of the width to its maximum at the right edge (the website
    # mask), lighter on the light part than on the dark band.
    def alpha(x, top):
        return max(0.0, min(1.0, (x/PAGE_W - 0.35)/0.65))*(0.20 if top else 0.32)
    for i in range(PAGE_W//GRID + 1):
        x = i*GRID
        for y0, y1, top in ((0, band_y, True), (band_y, PAGE_H, False)):
            a = alpha(x, top)
            if a > 0:
                out.append(f'<line x1="{x}" y1="{y0}" x2="{x}" y2="{y1}" stroke="{CYAN}" '
                           f'stroke-opacity="{a:.3f}" stroke-width="0.6"/>')
    for j in range(PAGE_H//GRID + 1):
        y = j*GRID
        for i in range(PAGE_W//GRID + 1):
            x0 = i*GRID
            a  = alpha(x0 + GRID/2, y < band_y)
            if a > 0:
                out.append(f'<line x1="{x0}" y1="{y}" x2="{x0 + GRID}" y2="{y}" stroke="{CYAN}" '
                           f'stroke-opacity="{a:.3f}" stroke-width="0.6"/>')
    # Cyan rules: top of the dark band and bottom of the page.
    out.append(f'<rect x="0" y="{band_y}" width="{PAGE_W}" height="3" fill="{CYAN}"/>')
    out.append(f'<rect x="0" y="{PAGE_H - 6}" width="{PAGE_W}" height="6" fill="{CYAN}"/>')
    out.append("</svg>")
    return "\n".join(out) + "\n"
