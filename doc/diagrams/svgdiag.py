#!/usr/bin/env python3
#
# This file is part of the LiteX manual kit.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# SVG block-diagram helper for the manual figures.
#
# House style (Enjoy-Digital block diagrams): diagonally cut top-right / bottom-left corners,
# pale grey panels, cyan-tinted principal blocks (the Enjoy-Digital brand colour), fine grey
# outlines and restrained offset shadows.
# Regular humanist sans labels, italic corner titles, grey arrows and dotted feedback / domains.
# Shadows use vector outlines, not SVG filters, so PDF export keeps text and geometry as vectors.
#
# A figure is a Python module in this directory exposing `build() -> Diagram`; build.py renders
# every figure to svg/<name>.svg (committed) and png/<name>.png (ignored, preview only).

import html
import shutil
import subprocess
from pathlib import Path

# Style constants ----------------------------------------------------------------------------------

FONT_FAMILY   = "Carlito, Calibri, 'Liberation Sans', Arial, sans-serif"
FONT_SIZE     = 15   # px, box labels (9 pt printed on the 760 px canvas).
FONT_SIZE_SM  = 12   # px, arrow labels (7.2 pt printed).
FONT_SIZE_TTL = 18   # px, container titles (10.8 pt printed).
FONT_SIZE_MIN = 10   # px, smallest size check() accepts for any label.
LINE_HEIGHT   = 1.2

# Every figure is drawn on a canvas of this width: the PDF prints the SVG at its natural size
# capped to the text width (455 pt), so one width means one printed scale for every label.
CANVAS_WIDTH  = 760

COLOR_STROKE  = "#5b5b5b"
COLOR_FILL    = "#fafafa"
COLOR_PANEL   = "#eeeeee"
COLOR_HARDWARE = "#b8b8b8" # External hardware (FPGA transceiver, host, cable).
COLOR_ACCENT  = "#bfe6f5" # Principal blocks of a figure (Enjoy-Digital cyan #2eaadc, tinted).
COLOR_ACCENT_LIGHT = "#e6f5fb" # Secondary blocks of the same family.
COLOR_CYAN    = "#2eaadc" # Brand cyan: highlighted arrows and markers.
COLOR_STREAM  = "#606060"
COLOR_TEXT    = "#000000"
COLOR_SHADE   = "#d0d0d0" # Reserved fields and secondary blocks.
COLOR_ERR     = "#d62828" # Error conditions only (overflow, underflow, fault).
COLOR_OK      = "#3f8f2a" # "Ok" markers only (full, locked, ready).

STROKE_BOX      = 0.9
STROKE_CONTROL  = 1.0
STROKE_STREAM   = 2.0
STROKE_FEEDBACK = 1.0
DASH_FEEDBACK   = "1,3"

RADIUS  = 0   # Straight edges, including corners that are not cut.
CHAMFER = 12  # Block cut-corner size; containers use a larger cut.
PAD_X   = 8   # Horizontal text padding of auto-sized boxes.
STACK_DX, STACK_DY = 5, -5 # Offset of the "stacked" copies drawn behind a box.

# Layers: containers are drawn first, then arrows, then boxes and texts, so arrows never cross
# the boxes they connect and containers never hide their content.
LAYER_CONTAINER, LAYER_ARROW, LAYER_BOX, LAYER_TEXT = 0, 1, 2, 3

# Approximate Helvetica/Arial advance widths (1/1000 em) for text-width estimation.
_W = {c: 556 for c in "abcdeghknopqsuvxyz0123456789"}
_W.update({c: 278 for c in " fijlt.,:;'!|/()[]"})
_W.update({c: 833 for c in "mw"})
_W.update({c: 667 for c in "ABEKPSVXYZ"})
_W.update({c: 722 for c in "CDHNRU"})
_W.update({c: 778 for c in "GOQ"})
_W.update({"M": 833, "W": 944, "I": 278, "J": 500, "L": 556, "T": 611, "F": 611, "r": 333,
           "-": 333, "_": 556, "&": 667, "<": 584, ">": 584, "=": 584, "+": 584, "*": 389})


def text_width(s, size=FONT_SIZE, bold=False):
    """Estimated rendered width of s in px for the house font at size px (slightly conservative)."""
    w = sum(_W.get(c, 600) for c in s)/1000.0*size
    return w*(1.07 if bold else 1.0)


def _esc(s):
    return html.escape(s, quote=True)


def _fmt(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")

# Primitives ---------------------------------------------------------------------------------------

class Shape:
    layer = LAYER_BOX

    def render(self):
        raise NotImplementedError

    def port(self, side, frac=0.5):
        """Anchor on a side ("l", "r", "t", "b") at frac of its length, used by arrows."""
        x, y, w, h = self.x, self.y, self.w, self.h
        return {
            "l": (x,          y + h*frac),
            "r": (x + w,      y + h*frac),
            "t": (x + w*frac, y),
            "b": (x + w*frac, y + h),
        }[side]

    @property
    def cx(self):
        return self.x + self.w/2

    @property
    def cy(self):
        return self.y + self.h/2


class Text(Shape):
    """Text block centered vertically on (x, y); "\\n" separates lines; anchor start/middle/end."""
    layer = LAYER_TEXT

    def __init__(self, x, y, text, size=FONT_SIZE, bold=False, anchor="middle", italic=False, color=COLOR_TEXT,
        owner=None):
        self.x, self.y, self.text = x, y, text
        self.size, self.bold, self.anchor, self.italic, self.color = size, bold, anchor, italic, color
        self.owner = owner # Shape this text belongs to (its box, arrow or container), None if free.
        lines = text.split("\n")
        self.w = max(text_width(l, size, bold) for l in lines)
        self.h = len(lines)*size*LINE_HEIGHT
        # Left edge of the rendered text, for the canvas check (x is the anchor point).
        self.left = {"start": x, "middle": x - self.w/2, "end": x - self.w}[anchor]

    @property
    def bbox(self):
        """(x0, y0, x1, y1) of the rendered text block."""
        return (self.left, self.y - self.h/2, self.left + self.w, self.y + self.h/2)

    def render(self):
        lines = self.text.split("\n")
        lh    = self.size*LINE_HEIGHT
        y0    = self.y - (len(lines) - 1)*lh/2
        style = (f'font-family="{_esc(FONT_FAMILY)}" font-size="{self.size}" fill="{self.color}" '
                 f'text-anchor="{self.anchor}"')
        if self.bold:
            style += ' font-weight="bold"'
        if self.italic:
            style += ' font-style="italic"'
        out = [f'<text x="{_fmt(self.x)}" y="{_fmt(y0)}" {style} dominant-baseline="central">']
        for i, line in enumerate(lines):
            dy = 0 if i == 0 else lh
            out.append(f'<tspan x="{_fmt(self.x)}" dy="{_fmt(dy)}">{_esc(line)}</tspan>')
        out.append("</text>")
        return "".join(out)


class Box(Shape):
    """Cut-corner block with a centered label and a subtle vector shadow.

    chamfer: corners to cut instead of rounding, subset of {"tl", "tr", "bl", "br"}.
    stack:   number of offset copies drawn behind the box (a group of identical blocks).
    w/h:     None = auto-sized from the label.
    """
    layer = LAYER_BOX

    def __init__(self, x, y, w=None, h=None, label="", chamfer=None, bold=False, size=FONT_SIZE, stack=0,
        radius=None, fill=COLOR_FILL, shadow=None):
        lines = label.split("\n") if label else []
        if w is None:
            w = max(text_width(l, size, bold) for l in lines) + 2*PAD_X if lines else 40
            w = max(40, round(w/5)*5)
        if h is None:
            h = max(28, len(lines)*size*LINE_HEIGHT + 14)
        # Explicit radius=0 denotes adjoining cells in bit / memory maps: square, no shadow.
        cells = radius == 0 and chamfer is None
        if chamfer is None:
            chamfer = () if cells else ("tr", "bl")
        self.x, self.y, self.w, self.h = x, y, w, h
        self.label, self.chamfer, self.bold, self.size = label, set(chamfer), bold, size
        self.stack, self.radius, self.fill = stack, RADIUS if radius is None else radius, fill or COLOR_FILL
        self.shadow = not cells if shadow is None else shadow
        self.fits = all(text_width(l, size, bold) <= w - 2 for l in lines)

    def label_text(self):
        """The label as a Text (None when the box has no label)."""
        if not self.label:
            return None
        return Text(self.cx, self.cy, self.label, size=self.size, bold=self.bold, owner=self)

    @property
    def rect(self):
        return (self.x, self.y, self.x + self.w, self.y + self.h)

    def _outline(self, x, y):
        w, h, r = self.w, self.h, self.radius
        c = min(22 if isinstance(self, Container) else CHAMFER, w/5, h/4)
        if not self.chamfer:
            return f'<rect x="{_fmt(x)}" y="{_fmt(y)}" width="{_fmt(w)}" height="{_fmt(h)}" rx="{r}" ry="{r}"/>'
        cut = {k: (c if k in self.chamfer else r) for k in ("tl", "tr", "bl", "br")}

        def corner(name, a, b, p):
            # a: point before the corner, b: point after, p: the corner itself.
            if name in self.chamfer:
                return f"L{_fmt(a[0])},{_fmt(a[1])} L{_fmt(b[0])},{_fmt(b[1])} "
            return f"L{_fmt(a[0])},{_fmt(a[1])} Q{_fmt(p[0])},{_fmt(p[1])} {_fmt(b[0])},{_fmt(b[1])} "

        d  = f"M{_fmt(x + cut['tl'])},{_fmt(y)} "
        d += corner("tr", (x + w - cut["tr"], y),     (x + w, y + cut["tr"]),     (x + w, y))
        d += corner("br", (x + w, y + h - cut["br"]), (x + w - cut["br"], y + h), (x + w, y + h))
        d += corner("bl", (x + cut["bl"], y + h),     (x, y + h - cut["bl"]),     (x, y + h))
        d += corner("tl", (x, y + cut["tl"]),         (x + cut["tl"], y),         (x, y))
        return f'<path d="{d}Z"/>'

    def render(self):
        g = []
        if self.shadow:
            # Three translucent silhouettes approximate the reference's soft drop shadow without
            # rasterizing a whole SVG group when librsvg converts it to PDF.
            for dx, dy, width, opacity in ((1.2, 2.0, 3.0, 0.05), (1.2, 2.0, 1.5, 0.08), (1, 1.5, 0, 0.12)):
                g.append(f'<g fill="#000000" stroke="#000000" stroke-width="{width}" '
                         f'opacity="{opacity}" stroke-linejoin="round" aria-hidden="true">')
                g.append(self._outline(self.x + dx, self.y + dy))
                g.append("</g>")
        g.append(f'<g fill="{self.fill}" stroke="{COLOR_STROKE}" stroke-width="{STROKE_BOX}" stroke-linejoin="round">')
        for i in range(self.stack, 0, -1):
            g.append(self._outline(self.x + i*STACK_DX, self.y + i*STACK_DY))
        g.append(self._outline(self.x, self.y))
        g.append("</g>")
        if self.label:
            g.append(self.label_text().render())
        return "\n".join(g)


class Container(Box):
    """Large block grouping other shapes: chamfered corners, title in a corner, optional inner label."""
    layer = LAYER_CONTAINER

    def __init__(self, x, y, w, h, title="", chamfer=("tr", "bl"), title_pos="br", title_size=FONT_SIZE_TTL,
        label=None, label_pos=None, fill=COLOR_PANEL):
        super().__init__(x, y, w, h, label="", chamfer=chamfer, radius=RADIUS, fill=fill)
        self.title, self.title_pos, self.title_size = title, title_pos, title_size
        self.inner_label, self.inner_label_pos      = label, label_pos

    def title_text(self):
        """The title as a Text placed in its corner (None when the container has no title)."""
        if not self.title:
            return None
        lines = self.title.split("\n")
        th    = len(lines)*self.title_size*LINE_HEIGHT
        m     = 10
        # Keep italic titles clear of the diagonal corner, including their glyph overhang.
        mx = 24 if self.title_pos in self.chamfer else 12
        # Right-aligned titles in the right corners, left-aligned in the left corners.
        if self.title_pos == "br":
            tx, ty, anchor = self.x + self.w - mx, self.y + self.h - m - th/2, "end"
        elif self.title_pos == "bl":
            tx, ty, anchor = self.x + mx, self.y + self.h - m - th/2, "start"
        elif self.title_pos == "tr":
            tx, ty, anchor = self.x + self.w - mx, self.y + m + th/2, "end"
        else:
            tx, ty, anchor = self.x + mx, self.y + m + th/2, "start"
        return Text(tx, ty, self.title, size=self.title_size, italic=True, anchor=anchor, owner=self)

    def label_text(self):
        if not self.inner_label:
            return None
        lx, ly = self.inner_label_pos
        return Text(lx, ly, self.inner_label, size=FONT_SIZE, bold=True, owner=self)

    def texts(self):
        return [t for t in (self.title_text(), self.label_text()) if t is not None]

    def render(self):
        out = [super().render()]
        out += [t.render() for t in self.texts()]
        return "\n".join(out)


def _pt(p):
    """Accept an (x, y) tuple or a (shape, side[, frac]) anchor; return ((x, y), side or None)."""
    if isinstance(p[0], Shape):
        return p[0].port(*p[1:]), p[1]
    return tuple(p), None


def _auto_route(a, side_a, b, side_b):
    """Waypoints making the a -> b line axis-aligned (L bend, or Z bend through the middle).

    The first segment leaves a box port perpendicularly to its side: horizontally from a left or
    right port, vertically from a top or bottom port. Without side information the longer axis
    is used first. Returns [] when a and b are already aligned.
    """
    (x0, y0), (x1, y1) = a, b
    if abs(x0 - x1) < 0.5 or abs(y0 - y1) < 0.5:
        return []
    horizontal_first = {"l": True, "r": True, "t": False, "b": False}.get(side_a, abs(x1 - x0) >= abs(y1 - y0))
    arrive_horizontal = {"l": True, "r": True, "t": False, "b": False}.get(side_b, not horizontal_first)
    if horizontal_first and not arrive_horizontal:
        return [(x1, y0)]                       # L: along x, then down/up into a top/bottom port.
    if not horizontal_first and arrive_horizontal:
        return [(x0, y1)]                       # L: along y, then across into a left/right port.
    if horizontal_first:
        mx = (x0 + x1)/2
        return [(mx, y0), (mx, y1)]             # Z: across, vertical jog in the middle, across.
    my = (y0 + y1)/2
    return [(x0, my), (x1, my)]                 # Z: down, horizontal jog in the middle, down.


class Arrow(Shape):
    """Polyline from a to b through optional waypoints.

    kind:  "data" (thick grey stream), "control" (thin black), "feedback" (thin dotted),
           "bus" (thick grey, no heads), "accent" (thick brand cyan, the path a figure is about).
    heads: "end", "both", "start", "none".
    label: text placed at label_pos, or next to the middle of the line on label_side
           ("above", "below", "left", "right").
    """
    layer = LAYER_ARROW

    def __init__(self, a, b, kind="control", via=(), heads="end", label=None, label_pos=None,
        label_side="above", label_size=FONT_SIZE_SM, label_anchor="middle", label_color=COLOR_TEXT):
        (pa, side_a), (pb, side_b) = _pt(a), _pt(b)
        via = [tuple(v) for v in via]
        if not via:
            via = _auto_route(pa, side_a, pb, side_b)
        self.pts   = [pa] + via + [pb]
        self.kind, self.heads = kind, heads
        self.label, self.label_pos, self.label_side = label, label_pos, label_side
        self.label_size, self.label_anchor          = label_size, label_anchor
        self.label_color                            = label_color
        if kind == "bus":
            self.heads = "none"
        xs, ys = [p[0] for p in self.pts], [p[1] for p in self.pts]
        self.x, self.y, self.w, self.h = min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)

    @classmethod
    def ortho(cls, a, b, axis="h", **kwargs):
        """L-shaped route: first along axis ("h" or "v"), then to b."""
        (x0, y0), (x1, y1) = _pt(a)[0], _pt(b)[0]
        via = [(x1, y0)] if axis == "h" else [(x0, y1)]
        return cls((x0, y0), (x1, y1), via=via, **kwargs)

    @classmethod
    def zigzag(cls, a, b, at, axis="h", **kwargs):
        """Z-shaped route: along axis to coordinate `at`, across, then along axis again to b."""
        (x0, y0), (x1, y1) = _pt(a)[0], _pt(b)[0]
        via = [(at, y0), (at, y1)] if axis == "h" else [(x0, at), (x1, at)]
        return cls((x0, y0), (x1, y1), via=via, **kwargs)

    def _label_xy(self):
        if self.label_pos is not None:
            return self.label_pos
        (x0, y0), (x1, y1) = self.pts[0], self.pts[-1]
        mx, my = (x0 + x1)/2, (y0 + y1)/2
        off = 7 if self.kind in ("control", "feedback") else 10
        return {
            "above": (mx, my - off),
            "below": (mx, my + off),
            "left" : (mx - off, my),
            "right": (mx + off, my),
        }[self.label_side]

    def render(self):
        if self.kind in ("data", "bus"):
            stroke, width, dash, marker = COLOR_STREAM, STROKE_STREAM, None, "stream"
        elif self.kind == "accent":
            stroke, width, dash, marker = COLOR_CYAN, STROKE_STREAM, None, "accent"
        elif self.kind == "feedback":
            stroke, width, dash, marker = COLOR_STROKE, STROKE_FEEDBACK, DASH_FEEDBACK, "ctrl"
        else:
            stroke, width, dash, marker = COLOR_STROKE, STROKE_CONTROL, None, "ctrl"
        attrs = f'fill="none" stroke="{stroke}" stroke-width="{width}"'
        if dash:
            attrs += f' stroke-dasharray="{dash}"'
        if self.heads in ("end", "both"):
            attrs += f' marker-end="url(#arrow-{marker})"'
        if self.heads in ("start", "both"):
            attrs += f' marker-start="url(#arrow-{marker}-rev)"'
        d   = " ".join(f"{_fmt(x)},{_fmt(y)}" for x, y in self.pts)
        out = [f'<polyline points="{d}" {attrs}/>']
        if self.label:
            out.append(self.label_text().render())
        return "\n".join(out)

    def label_text(self):
        """The label as a Text (None when the arrow has no label)."""
        if not self.label:
            return None
        lx, ly = self._label_xy()
        anchor = self.label_anchor
        if self.label_pos is None and self.label_side in ("left", "right"):
            anchor = "end" if self.label_side == "left" else "start"
        return Text(lx, ly, self.label, size=self.label_size, anchor=anchor, color=self.label_color,
            owner=self)


class Bus(Shape):
    """Register/control trunk: a thin line with tick-less fan-out points, e.g. an MMAP bus."""
    layer = LAYER_ARROW

    def __init__(self, points, kind="control", dash=None, color=None):
        self.pts  = [tuple(p) for p in points]
        self.kind = kind
        self.dash, self.color = dash, color # dash: SVG dasharray (lifelines, time axes), color: override.
        xs, ys = [p[0] for p in self.pts], [p[1] for p in self.pts]
        self.x, self.y, self.w, self.h = min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)

    def render(self):
        stroke, width = (COLOR_STREAM, STROKE_STREAM) if self.kind == "data" else (COLOR_STROKE, STROKE_CONTROL)
        stroke = self.color or stroke
        dash   = f' stroke-dasharray="{self.dash}"' if self.dash else ""
        d = " ".join(f"{_fmt(x)},{_fmt(y)}" for x, y in self.pts)
        return f'<polyline points="{d}" fill="none" stroke="{stroke}" stroke-width="{width}"{dash}/>'

class Mark(Shape):
    """Small filled disc used as a state marker: COLOR_OK for "ok" states, COLOR_ERR for faults."""
    layer = LAYER_TEXT

    def __init__(self, x, y, color=COLOR_OK, r=5):
        self.x, self.y, self.w, self.h = x - r, y - r, 2*r, 2*r
        self.color, self.r = color, r

    def render(self):
        return (f'<circle cx="{_fmt(self.x + self.r)}" cy="{_fmt(self.y + self.r)}" r="{self.r}" '
                f'fill="{self.color}" stroke="none"/>')

# Diagram ------------------------------------------------------------------------------------------

class Diagram:
    def __init__(self, width, height, background="#ffffff"):
        self.width, self.height, self.background = width, height, background
        self.shapes = []

    def add(self, *shapes):
        self.shapes.extend(shapes)
        return shapes[0] if len(shapes) == 1 else shapes

    def _defs(self):
        # markerUnits=userSpaceOnUse keeps arrowheads at a fixed size regardless of stroke width.
        return f"""<defs>
  <marker id="arrow-ctrl" markerUnits="userSpaceOnUse" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
    <path d="M0,0 L8,4 L0,8 Z" fill="{COLOR_STROKE}"/></marker>
  <marker id="arrow-ctrl-rev" markerUnits="userSpaceOnUse" markerWidth="8" markerHeight="8" refX="1" refY="4" orient="auto">
    <path d="M8,0 L0,4 L8,8 Z" fill="{COLOR_STROKE}"/></marker>
  <marker id="arrow-stream" markerUnits="userSpaceOnUse" markerWidth="9" markerHeight="9" refX="9" refY="4.5" orient="auto">
    <path d="M0,0 L9,4.5 L0,9 Z" fill="{COLOR_STREAM}"/></marker>
  <marker id="arrow-accent" markerUnits="userSpaceOnUse" markerWidth="9" markerHeight="9" refX="9" refY="4.5" orient="auto">
    <path d="M0,0 L9,4.5 L0,9 Z" fill="{COLOR_CYAN}"/></marker>
  <marker id="arrow-accent-rev" markerUnits="userSpaceOnUse" markerWidth="9" markerHeight="9" refX="0" refY="4.5" orient="auto">
    <path d="M9,0 L0,4.5 L9,9 Z" fill="{COLOR_CYAN}"/></marker>
  <marker id="arrow-stream-rev" markerUnits="userSpaceOnUse" markerWidth="9" markerHeight="9" refX="0" refY="4.5" orient="auto">
    <path d="M9,0 L0,4.5 L9,9 Z" fill="{COLOR_STREAM}"/></marker>
</defs>"""

    def render(self):
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" '
               f'viewBox="0 0 {self.width} {self.height}">', self._defs()]
        if self.background:
            out.append(f'<rect width="100%" height="100%" fill="{self.background}"/>')
        for s in sorted(self.shapes, key=lambda s: s.layer):
            out.append(s.render())
        out.append("</svg>")
        return "\n".join(out) + "\n"

    def _texts(self):
        """Every rendered text with its owner: free Texts, box labels, container titles, arrow labels."""
        out = []
        for s in self.shapes:
            if isinstance(s, Text):
                out.append(s)
            elif isinstance(s, Container):
                out += s.texts()
            elif isinstance(s, (Box, Arrow)):
                t = s.label_text()
                if t is not None:
                    out.append(t)
        return out

    @staticmethod
    def _crosses(bbox, rect):
        """True when bbox intersects rect without being fully inside it (it crosses an edge)."""
        ax0, ay0, ax1, ay1 = bbox
        bx0, by0, bx1, by1 = rect
        intersects = ax0 < bx1 and ax1 > bx0 and ay0 < by1 and ay1 > by0
        inside     = ax0 >= bx0 and ax1 <= bx1 and ay0 >= by0 and ay1 <= by1
        return intersects and not inside

    @staticmethod
    def _intersects(bbox, rect):
        ax0, ay0, ax1, ay1 = bbox
        bx0, by0, bx1, by1 = rect
        return ax0 < bx1 and ax1 > bx0 and ay0 < by1 and ay1 > by0

    @staticmethod
    def _segment_hits(p, q, rect):
        """True when the axis-aligned segment p-q passes through the rectangle interior."""
        (x0, y0), (x1, y1) = p, q
        rx0, ry0, rx1, ry1 = rect
        sx0, sx1 = min(x0, x1), max(x0, x1)
        sy0, sy1 = min(y0, y1), max(y0, y1)
        return sx0 < rx1 and sx1 > rx0 and sy0 < ry1 and sy1 > ry0

    def check(self):
        """Layout warnings, all of which fail the build:

        - canvas width other than CANVAS_WIDTH, any label under FONT_SIZE_MIN px;
        - a box label wider or taller than its box, overlapping labels, a shape or a text leaving
          the canvas;
        - a text crossing the edge of a box or container it does not belong to, or lying over a
          box (this also catches a container title hidden behind a box), or crossed by an arrow;
        - a diagonal or zero-length arrow segment (the latter renders a sideways arrowhead);
        - an arrow segment passing through a box it does not start or end on.
        """
        warns = []
        if self.width != CANVAS_WIDTH:
            warns.append(f"canvas width {self.width} px, every figure uses {CANVAS_WIDTH} px")
        # Unlabelled boxes are frames (the outline of a strip, a background); texts and arrows may
        # lie over them, so the overlap tests only consider labelled boxes.
        boxes      = [s for s in self.shapes if isinstance(s, Box) and not isinstance(s, Container) and s.label]
        containers = [s for s in self.shapes if isinstance(s, Container)]

        def name(s):
            return getattr(s, "label", "") or getattr(s, "title", "") or getattr(s, "text", "") or type(s).__name__

        for s in self.shapes:
            pts = getattr(s, "pts", None)
            if isinstance(s, (Arrow, Bus)) and pts:
                for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                    if abs(x0 - x1) > 0.5 and abs(y0 - y1) > 0.5:
                        warns.append(f"diagonal segment ({x0:.0f},{y0:.0f}) to ({x1:.0f},{y1:.0f}) in "
                                     f"{type(s).__name__} {getattr(s, 'label', '') or ''}".rstrip())
                    if abs(x0 - x1) <= 0.5 and abs(y0 - y1) <= 0.5:
                        warns.append(f"zero-length segment at ({x0:.0f},{y0:.0f}) in "
                                     f"{type(s).__name__} {getattr(s, 'label', '') or ''}".rstrip())
            if isinstance(s, Arrow):
                ends = (pts[0], pts[-1])
                for b in boxes:
                    x0, y0, x1, y1 = b.rect
                    if any(x0 - 1 <= px <= x1 + 1 and y0 - 1 <= py <= y1 + 1 for px, py in ends):
                        continue # The arrow starts or ends on this box.
                    shrunk = (x0 + 1, y0 + 1, x1 - 1, y1 - 1)
                    if any(self._segment_hits(p, q, shrunk) for p, q in zip(pts, pts[1:])):
                        warns.append(f"arrow {getattr(s, 'label', '') or ''!r} passes through box {b.label!r}")
                        break
            if isinstance(s, Box) and not getattr(s, "fits", True):
                warns.append(f"label {s.label!r} wider than its box ({s.w} px)")
            if isinstance(s, Box) and s.label and len(s.label.split("\n"))*s.size*LINE_HEIGHT > s.h - 4:
                warns.append(f"label {s.label!r} too tall for its box ({s.h} px, including padding)")
            if isinstance(s, Box) and s.label and s.size < FONT_SIZE_MIN:
                warns.append(f"label {s.label!r} at {s.size} px, minimum is {FONT_SIZE_MIN} px")
            if isinstance(s, Container) and s.title and s.title_size < FONT_SIZE_MIN:
                warns.append(f"title {s.title!r} at {s.title_size} px, minimum is {FONT_SIZE_MIN} px")
            if isinstance(s, Text) and s.size < FONT_SIZE_MIN:
                warns.append(f"text {s.text!r} at {s.size} px, minimum is {FONT_SIZE_MIN} px")
            if isinstance(s, Arrow) and s.label and s.label_size < FONT_SIZE_MIN:
                warns.append(f"arrow label {s.label!r} at {s.label_size} px, minimum is {FONT_SIZE_MIN} px")
            if not isinstance(s, Text):
                if s.x < 0 or s.y < 0 or s.x + s.w > self.width or s.y + s.h > self.height:
                    warns.append(f"{name(s)!r} outside the canvas")

        arrows = [s for s in self.shapes if isinstance(s, (Arrow, Bus))]
        texts = self._texts()
        for i, t in enumerate(texts):
            for other in texts[i + 1:]:
                if self._intersects(t.bbox, other.bbox):
                    warns.append(f"text {t.text!r} overlaps text {other.text!r}")
            x0, y0, x1, y1 = t.bbox
            if x0 < 0 or y0 < 0 or x1 > self.width or y1 > self.height:
                warns.append(f"text {t.text!r} outside the canvas")
            # A text needs 1 px of clearance from a box or an arrow; a container border may be
            # touched from the inside but not crossed.
            bbox  = (x0 - 1, y0 - 1, x1 + 1, y1 + 1)
            exact = (x0, y0, x1, y1)
            for a in arrows:
                if a is t.owner or isinstance(t.owner, Box) and not isinstance(t.owner, Container):
                    continue # A box label is protected by the box itself.
                if any(self._segment_hits(p, q, bbox) for p, q in zip(a.pts, a.pts[1:])):
                    warns.append(f"text {t.text!r} is crossed by an arrow")
                    break
            for b in boxes:
                if b is t.owner:
                    continue
                if self._intersects(bbox, b.rect):
                    warns.append(f"text {t.text!r} overlaps box {b.label!r}")
            for c in containers:
                if c is t.owner:
                    continue
                if self._crosses(exact, c.rect):
                    warns.append(f"text {t.text!r} crosses the border of container {c.title!r}")
        return warns

    def save(self, svg_path, png_path=None, zoom=2.0):
        """Write the SVG (and a PNG preview with rsvg-convert when available); return check() warnings."""
        svg_path = Path(svg_path)
        svg_path.parent.mkdir(parents=True, exist_ok=True)
        svg_path.write_text(self.render())
        if png_path:
            convert(svg_path, png_path, zoom=zoom)
        return self.check()


def convert(svg_path, out_path, zoom=1.0):
    """Convert an SVG to PDF or PNG (from the extension of out_path) with rsvg-convert, or with
    cairosvg when librsvg is not installed. Both keep the text and the shapes as vectors in PDF."""
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fmt  = out_path.suffix.lstrip(".")
    conv = shutil.which("rsvg-convert")
    if conv:
        subprocess.run([conv, "-z", str(zoom), "-f", fmt, "-o", str(out_path), str(svg_path)], check=True)
        return
    import cairosvg
    {"pdf": cairosvg.svg2pdf, "png": cairosvg.svg2png}[fmt](url=str(svg_path), write_to=str(out_path),
        scale=zoom)
