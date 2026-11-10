# Maintaining this manual {#maintenance}

The manual sources live in `doc/manual/` and the figure sources in `doc/diagrams/`. Two files
there are the references: `README.md` for the toolchain, the build commands and the mechanical
rules, and `STYLE.md` for the editorial rules (voice, paragraphs, figures, tables, chapter
template). This appendix summarizes what a maintainer needs.

The manual follows the default development branch of the repository. Every fact is traceable to
a file of the repository at that revision; `SOURCES.md` records the sources of each chapter and
is updated with the chapter.

## Toolchain {#maint-toolchain}

Rebuilding the manual needs pandoc, XeLaTeX and an SVG converter: `rsvg-convert` from librsvg, or
the `cairosvg` Python package when librsvg is not installed. The packages and the fonts are listed
in the README. The sources build with pandoc 2.9 and 3.x. The Gravur title font is downloaded at
build time; without network access the titles use a condensed fallback font.

## Build and checks {#maint-build}

```sh
# Figures, checks, PDF and HTML, in build/doc/.
python3 doc/manual/build.py
# The manual without regenerating the figures.
python3 doc/manual/build.py --check --pdf --html
# Regenerate the SVG figures, or fail if one is stale.
python3 doc/diagrams/build.py [--check]
# Links, anchors, figures and table widths only.
python3 doc/manual/build.py --check
```

The outputs are `build/doc/<name>.pdf` and `build/doc/<name>.html`, `<name>` being set in
`manual.yaml`. The HTML page is self-contained: figures, fonts and styles are embedded, so the
file can be copied or published alone.

## Continuous integration and publication {#maint-ci}

Every push and pull request runs the figure and source checks (`.github/workflows/doc.yml`, job
`check`), so a broken link or a stale figure fails the pull request. Every night, when `master` has
new commits, the job `nightly` builds the PDF and HTML and replaces the assets of the
`manual-nightly` pre-release of the repository. The manual is therefore never committed: the
release always holds the manual of the latest `master`, and its notes give the commit.

## Changing the manual {#maint-changes}

- Change a chapter together with the code it describes, in the same pull request, and update
  `SOURCES.md` when a fact comes from a new file.
- Change a figure in its Python source in `doc/diagrams/`, regenerate it and commit both the
  source and the SVG. Never edit an SVG by hand.
- Give a stable identifier to every heading a link points to; `check.py` fails on a link to a
  missing anchor.
- Keep the theme in one place: colours and fonts of the PDF in `metadata.yaml`, of the HTML page
  in `style.css`, of the figures in `svgdiag.py`.
