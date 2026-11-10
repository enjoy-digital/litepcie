#!/usr/bin/env python3
#
# This file is part of the LiteX manual kit.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Regenerate every manual figure: python3 doc/diagrams/build.py [--check] [name ...]
#
# Each figure is a module of this directory exposing build() -> svgdiag.Diagram; a module without
# build() is a shared helper. Outputs go to svg/<name>.svg
# (committed, referenced by the manual) and png/<name>.png (preview, ignored by git).
# --check regenerates in memory and fails when a committed SVG differs from its source (CI guard)
# or when Diagram.check() reports a layout warning (canvas width, label size, overlaps, arrows
# through boxes, see svgdiag.py). A plain run prints the warnings and fails on them too.

import importlib
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def figures(names):
    for src in sorted(HERE.glob("*.py")):
        if src.name in ("build.py", "svgdiag.py"):
            continue
        if names and src.stem not in names:
            continue
        yield src.stem


def main(argv):
    check_only = "--check" in argv
    names      = [a for a in argv if not a.startswith("--")]
    os.chdir(HERE)
    sys.path.insert(0, str(HERE))
    rc = 0
    for name in figures(names):
        module = importlib.import_module(name)
        if not hasattr(module, "build"):
            continue # Shared helper, not a figure.
        diagram  = module.build()
        svg, png = HERE/"svg"/f"{name}.svg", HERE/"png"/f"{name}.png"
        warnings = diagram.check()
        for warning in warnings:
            print(f"{name}.py: warning: {warning}")
        if warnings:
            rc = 1
        if check_only:
            if not svg.exists() or svg.read_text() != diagram.render():
                print(f"STALE: doc/diagrams/svg/{name}.svg differs from {name}.py (run python3 doc/diagrams/build.py)")
                rc = 1
            continue
        diagram.save(svg, png)
        print(f"generated svg/{name}.svg png/{name}.png")
    if check_only and rc == 0:
        print("all figures up to date, no warning")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
