#!/usr/bin/env python3
#
# This file is part of the LiteX manual kit.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Check the manual sources: every referenced image exists, every internal "#anchor" link
# resolves, every table fits the page, and (with --forbid) no listed word appears in the sources
# or in the figure texts. Usage: python3 doc/manual/check.py [defaults-pdf.yaml] (exit 1 on error)
#
# Anchors are taken from pandoc's own AST (pandoc -t json), so auto-generated header identifiers
# are exactly the ones the PDF/HTML build uses. LaTeX only warns on an undefined hyperlink target,
# so this check is what keeps cross-references honest.

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


def load_defaults(path):
    """Minimal reader for the input-files and resource-path lists (no PyYAML dependency)."""
    files, respath, key = [], ["."], None
    for line in Path(path).read_text().splitlines():
        if line.startswith("input-files:"):
            key = "files"
            continue
        if line.startswith("resource-path:"):
            key = None
            m = re.search(r"\[(.*)\]", line)
            if m:
                respath = [p.strip().strip('"\'') for p in m.group(1).split(",") if p.strip()]
            continue
        if key == "files":
            if line.startswith("  - "):
                files.append(line[4:].strip())
            elif line.strip() and not line.startswith(" "):
                key = None
    return files, respath


def walk(node, images, links, ids):
    if isinstance(node, dict):
        t, c = node.get("t"), node.get("c")
        if t == "Image":
            images.append(c[2][0])
            attr = c[0]
        elif t == "Link":
            links.append(c[2][0])
            attr = c[0]
        elif t == "Header":
            attr = c[1]
        elif t in ("Div", "Span", "CodeBlock", "Table"):
            attr = c[0]
        else:
            attr = None
        if isinstance(attr, list) and attr and isinstance(attr[0], str) and attr[0]:
            ids.add(attr[0])
        if isinstance(c, list):
            for x in c:
                walk(x, images, links, ids)
    elif isinstance(node, list):
        for x in node:
            walk(x, images, links, ids)


# Pipe-table width check --------------------------------------------------------------------------
# pandoc gives a pipe table wider than 72 characters column widths proportional to the dash counts
# of its separator row. A code identifier or a word cannot wrap, so it overflows into the next
# column when it is wider than its column. The estimate below (text width, font advances) is
# deliberately simple; it flags the tables a reader sees broken in the PDF.
# Column width model (pandoc 2.9 + eisvogel, A4 with 2.5 cm margins). Pandoc turns the
# separator widths into fractions of the text width, then its LaTeX writer shrinks every column
# by 0.97 per column of the table; a cell also loses its padding. A grid-table column counts its
# separator segment plus one, a pipe-table column its dashes; the denominator is the total, or
# 72 when the table is narrower than that.
TEXT_WIDTH_PT = 455.0
MONO_PT       = 6.6   # per character, code font (measured 6.55 in the PDF)
PROP_PT       = 5.0   # per character, text font (measured 4.7 average, more with capitals)
CELL_PAD_PT   = 8.0
COL_SHRINK    = 0.97  # per column


def column_width_pt(chars, total, ncols):
    """Usable width of a column of `chars` units out of `total`, in a table of `ncols` columns."""
    return chars/max(total, 72)*(COL_SHRINK**ncols)*TEXT_WIDTH_PT - CELL_PAD_PT


def _cells(line):
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", line.strip().strip("|"))]


def _tokens(cell):
    toks = [(m.group(1), MONO_PT) for m in re.finditer(r"`([^`]+)`", cell)]
    toks += [(w, PROP_PT) for w in re.sub(r"`[^`]+`", " ", cell).split()]
    return toks


def _check_columns(f, lineno, header, rows, widths, total, problems):
    """Report the first token of each column that is wider than the column (widths in chars)."""
    for col, d in enumerate(widths):
        width = column_width_pt(d, total, len(widths))
        for r in rows + [header]:
            if col < len(r):
                for tok, k in _tokens(r[col]):
                    if len(tok)*k > width:
                        name = header[col] if col < len(header) else str(col)
                        problems.append(f"{f}:{lineno}: column {name!r}: {tok!r} needs "
                                        f"{len(tok)*k:.0f} pt, column has {width:.0f} pt")
                        break
                else:
                    continue
                break


sys.path.insert(0, str(Path(__file__).resolve().parent/"tools"))
from tables import grid_widths   # noqa: E402


def _stringify(cell):
    """The text pandoc measures: code spans without backticks, links as their text."""
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", cell)
    text = re.sub(r"\[([^\]]*)\]\{[^}]*\}", r"\1", text)
    return text.replace("`", "").strip()


def _cell_width_pt(cell):
    """Rendered width of a whole cell on one line (no wrapping)."""
    width = 0.0
    for tok, k in _tokens(cell):
        width += len(tok)*k + 3.0   # word plus a space
    return width


def _check_natural(f, lineno, header, rows, problems):
    """A table printed at natural width: the sum of the widest cells must fit the text width."""
    ncols = max(len(r) for r in rows + [header])
    widths = []
    for col in range(ncols):
        widths.append(max((_cell_width_pt(r[col]) for r in rows + [header] if col < len(r)), default=0))
    total = sum(widths) + 12.0*ncols   # \tabcolsep on both sides of every column
    if total > TEXT_WIDTH_PT:
        worst = max(range(ncols), key=lambda c: widths[c])
        name = header[worst] if worst < len(header) else str(worst)
        problems.append(f"{f}:{lineno}: natural-width table needs {total:.0f} pt, page has {TEXT_WIDTH_PT:.0f} pt "
                        f"(widest column {name!r}); make a cell 72 characters or longer so the cells wrap, "
                        f"or shorten the cells")


def check_tables(root, files):
    """Tables whose widest unbreakable token exceeds its column width (pipe and grid tables)."""
    problems = []
    for f in files:
        lines = open(root/f).read().split("\n")
        i = 0
        while i < len(lines):
            if re.match(r"^\+(-+\+)+$", lines[i]):
                # Grid table: column widths are the separator segments, rows are the "|" lines.
                widths = [len(seg) + 1 for seg in lines[i].strip("+").split("+")]
                total  = sum(widths)
                j = i + 1
                cells  = []
                while j < len(lines) and (lines[j].startswith("|") or lines[j].startswith("+")):
                    if lines[j].startswith("|"):
                        cells.append(_cells(lines[j]))
                    j += 1
                header, rows = (cells[0], cells[1:]) if cells else ([], [])
                _check_columns(f, i + 1, header, rows, widths, total, problems)
                i = j
                continue
            if lines[i].startswith("|") and i + 1 < len(lines) and re.match(r"^\|?[\s:|-]+\|?$", lines[i + 1]):
                header, seps = _cells(lines[i]), _cells(lines[i + 1])
                dashes = [max(1, len(x)) for x in seps]
                total  = sum(dashes)
                j = i + 2
                rows = []
                while j < len(lines) and lines[j].startswith("|"):
                    rows.append(_cells(lines[j]))
                    j += 1
                if len(header) != len(dashes):
                    problems.append(f"{f}:{i + 1}: header has {len(header)} cells, separator {len(dashes)}")
                for k, r in enumerate(rows):
                    if len(r) != len(header):
                        problems.append(f"{f}:{i + 2 + k + 1}: row has {len(r)} cells, header {len(header)}")
                # build.py converts every pipe table to a grid table before pandoc runs (see
                # tools/tables.py), so the widths to check are those of the grid table.
                widths = [w + 3 for w in grid_widths(header, dashes, rows)]
                _check_columns(f, i + 1, header, rows, widths, sum(widths), problems)
                i = j
            else:
                i += 1
    return problems


def scan_words(root, files, respath, images, words):
    """Words that must not appear (case-insensitive) in the sources or in the figure texts."""
    pattern = re.compile("|".join(re.escape(w) for w in sorted(words, key=len, reverse=True)), re.I)
    hits = []
    for f in files:
        for n, line in enumerate(open(root/f).read().split("\n"), 1):
            m = pattern.search(line)
            if m:
                hits.append(f"{f}:{n}: {m.group(0)!r} in {line.strip()[:90]!r}")
    for url in images:
        for pth in respath:
            svg = root/pth/url
            if svg.exists() and svg.suffix == ".svg":
                text = " ".join(re.findall(r">([^<>]+)<", open(svg).read()))
                m = pattern.search(text)
                if m:
                    hits.append(f"{url}: {m.group(0)!r} in figure text")
                break
    return hits


def main(argv):
    ap = argparse.ArgumentParser(description="Check the manual sources (images, anchors, tables, words).")
    ap.add_argument("defaults", nargs="?", default="defaults-pdf.yaml")
    ap.add_argument("--forbid", default=None, help="File of words (one per line) that must not appear.")
    ap.add_argument("--no-tables", action="store_true", help="Skip the pipe-table column width check.")
    args = ap.parse_args(argv)
    defaults = args.defaults
    root     = Path(defaults).resolve().parent
    files, respath = load_defaults(defaults)
    ast = json.loads(subprocess.run(
        ["pandoc", "-f", "markdown+link_attributes+implicit_figures", "-t", "json", *[str(root/f) for f in files]],
        check=True, capture_output=True, text=True).stdout)
    images, links, ids = [], [], set()
    walk(ast["blocks"], images, links, ids)
    errors = []
    for url in images:
        if url.startswith(("http://", "https://")):
            continue
        if not any((root/p/url).exists() for p in respath):
            errors.append(f"missing image: {url}")
    for target in links:
        if target.startswith("#") and target[1:] not in ids:
            errors.append(f"unresolved cross-reference: {target}")
    if args.forbid:
        words = [w.strip() for w in Path(args.forbid).read_text().split("\n") if w.strip()]
        errors += [f"forbidden word: {h}" for h in scan_words(root, files, respath, images, words)]
    if not args.no_tables:
        errors += [f"table overflow: {t}" for t in check_tables(root, files)]
    for e in errors:
        print("ERROR:", e)
    internal = sum(1 for l in links if l.startswith("#"))
    print(f"checked {len(files)} files, {len(images)} images, {internal} internal links, {len(ids)} anchors: "
          f"{len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
