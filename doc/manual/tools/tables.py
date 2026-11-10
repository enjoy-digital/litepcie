#
# This file is part of the LiteX manual kit.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Pipe tables to grid tables.
#
# The sources of the manual use pipe tables, which are easy to write and to filter per board.
# Pandoc decides whether the cells of a pipe table wrap from the length of the source lines
# (pandoc 3) or of the longest cell (pandoc 2.9), and prints the table at its natural width
# otherwise, so the same source renders differently on the two versions and a table can run off
# the page. Grid tables always take their column widths from the separator row, on every pandoc
# version, and that model is the one doc/manual/check.py verifies. build.py therefore converts
# every pipe table of the filtered sources into a grid table before pandoc runs, keeping the
# proportions of the dash counts; check.py does the same conversion in memory before measuring.

import re
import textwrap

SEP_RE = re.compile(r"^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$")


def _cells(line):
    """Cells of a pipe-table row; `\\|` is a literal pipe."""
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", line.strip().strip("|"))]


def _wrap(cell, width):
    """Wrap a cell on `width` characters without breaking words (a code span keeps its words)."""
    if not cell:
        return [""]
    return textwrap.wrap(cell, width, break_long_words=False, break_on_hyphens=False) or [""]


def _pad_rows(header, rows):
    ncols = len(header)
    return [r + [""]*(ncols - len(r)) if len(r) < ncols else r[:ncols] for r in rows]


def grid_widths(header, dashes, rows):
    """Column widths in characters of the grid table built from a pipe table: the dash counts,
    widened where a word would not fit (a word longer than its column would break the grid)."""
    rows = _pad_rows(header, rows)
    widths = list(dashes)
    for c in range(len(header)):
        longest = max(len(w) for r in rows + [header] for w in (r[c].split() or [""]))
        widths[c] = max(widths[c], longest, 3)
    return widths


def pipe_to_grid(header, dashes, rows):
    """Render one table as a pandoc grid table; `dashes` are the separator dash counts."""
    rows   = _pad_rows(header, rows)
    if not rows:
        return []   # a header without rows is not a table for pandoc; drop it.
    widths = grid_widths(header, dashes, rows)
    sep  = "+" + "+".join("-"*(w + 2) for w in widths) + "+"
    hsep = "+" + "+".join("="*(w + 2) for w in widths) + "+"
    out  = [sep]

    def emit(cells):
        rendered = [_wrap(c, w) for c, w in zip(cells, widths)]
        for k in range(max(len(r) for r in rendered)):
            out.append("| " + " | ".join((r[k] if k < len(r) else "").ljust(w) for r, w in zip(rendered, widths)) + " |")
    emit(header)
    out.append(hsep)
    for r in rows:
        emit(r)
        out.append(sep)
    return out


def convert_markdown(text):
    """Return `text` with every pipe table replaced by the equivalent grid table."""
    lines = text.split("\n")
    out, i, in_code = [], 0, False
    while i < len(lines):
        line = lines[i]
        if line.startswith("```") or line.startswith("~~~"):
            in_code = not in_code
            out.append(line)
            i += 1
            continue
        if (not in_code and line.lstrip().startswith("|") and i + 1 < len(lines)
                and SEP_RE.match(lines[i + 1]) and "|" in lines[i + 1]):
            header = _cells(line)
            dashes = [max(1, len(x.strip().strip(":"))) for x in _cells(lines[i + 1])]
            j = i + 2
            rows = []
            while j < len(lines) and lines[j].lstrip().startswith("|"):
                rows.append(_cells(lines[j]))
                j += 1
            if len(dashes) == len(header):
                out.extend(pipe_to_grid(header, dashes, rows))
                i = j
                continue
        out.append(line)
        i += 1
    return "\n".join(out)
