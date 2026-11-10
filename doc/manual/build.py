#!/usr/bin/env python3
#
# This file is part of the LiteX manual kit.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Build the manual (PDF and HTML) from the Markdown sources of this directory: the chapters and the
# output name are in manual.yaml, the project metadata in metadata.yaml, the theme in theme.yaml.
#
#   python3 doc/manual/build.py                 # diagrams + check + PDF + HTML
#   python3 doc/manual/build.py --pdf           # PDF only
#   python3 doc/manual/build.py --html --check  # HTML plus the link/figure/table check
#
# Outputs: build/doc/<name>.pdf and build/doc/<name>.html (repository root, <name> from manual.yaml).
# Requirements: pandoc (2.9 or 3.x), a TeX distribution with xelatex, and rsvg-convert
# (librsvg2-bin) or the cairosvg Python package for the SVG figures. See README.md.

import argparse
import datetime
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT  = ROOT/"build"/"doc"

sys.path.insert(0, str(HERE/"tools"))
sys.path.insert(0, str(HERE.parent/"diagrams"))

# Gravur, the display font of enjoy-digital.fr, is not part of the repository: it is downloaded at
# build time (cached in build/doc/fonts/). Without it, the titles fall back to TeX Gyre Heros Cn
# (PDF) and Arial Narrow (HTML).
FONT_URL   = os.environ.get("MANUAL_FONT_URL", "https://enjoy-digital.fr/assets/fonts")
FONT_FILES = ["gravuconbol-webfont.ttf", "gravuconlig-webfont.ttf",
              "gravuconbol-webfont.woff2", "gravuconlig-webfont.woff2"]

LIGHT_FONTS = ["-V", "mainfont=Liberation Sans", "-V", "sansfont=Liberation Sans", "-V", "monofont=DejaVu Sans Mono"]

# Helpers ------------------------------------------------------------------------------------------

def require(tool, hint):
    if shutil.which(tool) is None:
        sys.exit(f"error: {tool} not found in PATH ({hint})")


def run(cmd, env=None):
    print("+", " ".join(str(c) for c in cmd))
    subprocess.run([str(c) for c in cmd], check=True, env=env)


def load_manual():
    """Read manual.yaml (name and chapter list) without a YAML dependency."""
    name, chapters = None, []
    for line in (HERE/"manual.yaml").read_text().split("\n"):
        if line.startswith("name:"):
            name = line.split(":", 1)[1].strip()
        elif line.startswith("  - "):
            chapters.append(line[4:].strip())
    if not name or not chapters:
        sys.exit("error: manual.yaml needs a name and a chapters list")
    return name, chapters


def metadata_value(key):
    """A top-level string value of metadata.yaml (title, project...)."""
    for line in (HERE/"metadata.yaml").read_text().split("\n"):
        if line.startswith(f"{key}:"):
            return line.split(":", 1)[1].strip().strip('"')
    return ""


def yaml_body(path):
    """Content of a YAML metadata block, without its --- delimiters."""
    return "\n".join(l for l in Path(path).read_text().split("\n") if l.strip() != "---")


def generation_date():
    """Date the manual is generated (printed on the title page and in every page footer)."""
    return datetime.date.today().isoformat()

def fetch_fonts(out, url):
    """Download the Gravur fonts into out/fonts (once); return True when they are all present."""
    import urllib.request
    fonts = out/"fonts"
    fonts.mkdir(parents=True, exist_ok=True)
    for name in FONT_FILES:
        path = fonts/name
        if path.exists() and path.stat().st_size > 0:
            continue
        try:
            with urllib.request.urlopen(f"{url}/{name}", timeout=20) as r:
                path.write_bytes(r.read())
        except Exception as e:
            print(f"warning: cannot fetch {url}/{name} ({e}): titles use the fallback font")
            path.unlink(missing_ok=True)
            return False
    return True

# Preparation --------------------------------------------------------------------------------------

def prepare(out, font_url=FONT_URL):
    """Write the build tree: chapters with grid tables, resolved metadata and defaults files,
    PDF figures and the title page background. Return the source directory."""
    import tables
    import cover
    import svgdiag
    src  = out/"src"
    figs = out/"figures"
    src.mkdir(parents=True, exist_ok=True)
    figs.mkdir(parents=True, exist_ok=True)

    # Chapters: pipe tables become grid tables (see tools/tables.py).
    name, files = load_manual()
    for f in files:
        (src/f).write_text(tables.convert_markdown((HERE/f).read_text()))

    # Display font: Gravur when it can be fetched, else TeX Gyre Heros Cn (PDF) / Arial Narrow (HTML).
    gravur = fetch_fonts(out, font_url)
    fonts  = out/"fonts"
    if gravur:
        font_bold  = f"[Path={fonts}/]{{gravuconbol-webfont.ttf}}"
        font_light = f"[Path={fonts}/]{{gravuconlig-webfont.ttf}}"
    else:
        font_bold  = "[Extension=.otf]{texgyreheroscn-bold}"
        font_light = "[Extension=.otf]{texgyreheroscn-regular}"
    css = (HERE/"style.css").read_text()
    if not gravur:
        css = "\n".join(l for l in css.split("\n") if not l.startswith("@font-face"))
    (out/"style.css").write_text(css) # Next to out/fonts, for the url("fonts/...") of @font-face.

    # Metadata: project metadata plus theme, absolute paths, display font and generation date.
    meta = "---\n" + yaml_body(HERE/"metadata.yaml") + "\n" + yaml_body(HERE/"theme.yaml") + "\n---\n"
    meta = meta.replace("@SHORTTITLE@", metadata_value("title").replace("&", "\\&"))
    meta = meta.replace("@GRAVUR_BOLD@", font_bold).replace("@GRAVUR_LIGHT@", font_light)
    meta = meta.replace("@MANUAL@", str(HERE)).replace("@BUILD@", str(out))
    meta = meta.replace("@DATE@", generation_date())
    (src/"metadata.yaml").write_text(meta)

    # Defaults files with absolute input, resource and output paths.
    respath = [str(src), str(HERE), str(HERE/"figures"), str(HERE.parent/"diagrams"/"svg"), str(ROOT/"doc"/"images"), str(ROOT/"doc")]
    for kind in ("pdf", "html"):
        lines = []
        for line in (HERE/f"defaults-{kind}.yaml").read_text().rstrip("\n").split("\n"):
            if line.startswith("resource-path:"):
                line = f"resource-path: [{', '.join(repr(r) for r in respath)}]"
            line = line.replace("@MANUAL@", str(HERE)).replace("@BUILD@", str(out))
            line = line.replace("metadata-file: metadata.yaml", f"metadata-file: {src/'metadata.yaml'}")
            lines.append(line)
        lines += ["input-files:"] + [f"  - {src/f}" for f in files]
        lines += [f"output-file: {out/name}.{kind}"]
        (src/f"defaults-{kind}.yaml").write_text("\n".join(lines) + "\n")

    # Figures (PDF for LaTeX, converted only when the SVG is newer) and title page background.
    for svg in sorted((HERE.parent/"diagrams"/"svg").glob("*.svg")):
        pdf = figs/f"{svg.stem}.pdf"
        if not pdf.exists() or pdf.stat().st_mtime < svg.stat().st_mtime:
            svgdiag.convert(svg, pdf)
    (out/"cover.svg").write_text(cover.cover_svg())
    svgdiag.convert(out/"cover.svg", out/"cover.pdf")
    return src

# Main ---------------------------------------------------------------------------------------------

def main(argv):
    parser = argparse.ArgumentParser(description="Build the manual (PDF and HTML).")
    parser.add_argument("--print",            choices=["name", "title", "project"], help="Print a manual property and exit (CI).")
    parser.add_argument("--pdf",              action="store_true", help="Build the PDF.")
    parser.add_argument("--html",             action="store_true", help="Build the standalone HTML.")
    parser.add_argument("--check",            action="store_true", help="Check images, cross-references and tables first.")
    parser.add_argument("--diagrams",         action="store_true", help="Regenerate the SVG figures first.")
    parser.add_argument("--light-fonts",      action="store_true", help="Use Liberation Sans / DejaVu Sans Mono (no texlive-fonts-extra).")
    parser.add_argument("--fail-if-warnings", action="store_true", help="Make pandoc warnings fatal.")
    parser.add_argument("--font-url",         default=FONT_URL, help="Base URL of the Gravur fonts (env MANUAL_FONT_URL).")
    parser.add_argument("--out",              default=str(OUT), help="Output directory (default: build/doc).")
    args = parser.parse_args(argv)
    if args.print:
        print(load_manual()[0] if args.print == "name" else metadata_value(args.print))
        return 0
    if not (args.pdf or args.html or args.check or args.diagrams):
        args.pdf = args.html = args.check = args.diagrams = True

    out = Path(args.out).resolve()
    os.chdir(HERE)
    out.mkdir(parents=True, exist_ok=True)
    require("pandoc", "apt install pandoc")
    if args.diagrams:
        run([sys.executable, HERE.parent/"diagrams"/"build.py"])
    if args.pdf:
        require("xelatex", "apt install texlive-xetex texlive-latex-extra texlive-fonts-recommended")
    src   = prepare(out, args.font_url)
    extra = ["--fail-if-warnings"] if args.fail_if_warnings else []
    if args.check:
        # Optional local list of words that must not appear (build/doc/forbidden.txt, not tracked).
        forbid = ["--forbid", out/"forbidden.txt"] if (out/"forbidden.txt").exists() else []
        run([sys.executable, HERE/"check.py", src/"defaults-pdf.yaml"] + forbid)
    if args.pdf:
        env = dict(os.environ, MANUAL_FIGURES=str(out/"figures"))
        cmd = ["pandoc", "-d", src/"defaults-pdf.yaml"] + extra
        if args.light_fonts:
            cmd += LIGHT_FONTS
        run(cmd, env=env)
    if args.html:
        run(["pandoc", "-d", src/"defaults-html.yaml"] + extra)
    if args.pdf or args.html:
        print(f"manual written to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
