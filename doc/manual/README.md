# Manual sources

This directory holds the sources of the manual of the project, its single reference document. It
is written in Markdown and built with pandoc into a PDF (eisvogel template) and a self-contained
HTML page, both styled after enjoy-digital.fr. The figures are SVG generated from Python sources
in `doc/diagrams/`. The tooling is the *manual kit*, shared by the LiteX ecosystem cores: see
[Manual kit](#manual-kit) below.

## Building

Requirements: `pandoc` (2.9 or 3.x), a TeX distribution with `xelatex` (Ubuntu:
`texlive-xetex texlive-latex-extra texlive-fonts-recommended texlive-fonts-extra lmodern`), and
`librsvg2-bin` (`rsvg-convert`) or the `cairosvg` Python package for the SVG figures. Fonts:
`fonts-crosextra-carlito` for the figures. Without `texlive-fonts-extra` (Source Sans Pro / Source
Code Pro), use `--light-fonts`. The Gravur title font of enjoy-digital.fr is not in the repository:
`build.py` downloads it into `build/doc/fonts/` (`--font-url` or `MANUAL_FONT_URL` to change the
source) and falls back to TeX Gyre Heros Condensed (PDF) and Arial Narrow (HTML) when it cannot.

```sh
python3 doc/manual/build.py                       # figures, checks, PDF, HTML
python3 doc/manual/build.py --pdf                 # PDF only
python3 doc/manual/build.py --html --check        # HTML plus the link/figure/table check
python3 doc/diagrams/build.py                     # regenerate the SVG figures (and PNG previews)
python3 doc/diagrams/build.py --check             # fail if a committed SVG is stale
python3 doc/manual/tools/csr_doc.py dump          # refresh the register snapshots (needs LiteX)
python3 doc/manual/tools/csr_doc.py generate      # regenerate the register appendix
```

Outputs are written to `build/doc/<name>.pdf` and `build/doc/<name>.html`, `<name>` being set in
`manual.yaml`; they are never committed.

## Continuous integration and nightly manual

`.github/workflows/doc.yml` runs two jobs:

- `check`, on every push and pull request: `doc/diagrams/build.py --check` (figures up to date, no
  layout warning) and `doc/manual/build.py --check` (links, anchors, images, table widths).
- `nightly`, every night on `master` (and on demand with `gh workflow run doc.yml`): builds the PDF
  and HTML and publishes them on the rolling `manual-nightly` pre-release of the repository,
  whose notes record the commit. A night without a new commit on `master` is skipped.

## Layout

| Path | Content |
|---|---|
| `manual.yaml` | Output name and chapter list, in order |
| `metadata.yaml` | Title page and document properties (title, project, license, contact) |
| `NN_*.md`, `A_*.md` to `E_*.md` | One file per chapter or appendix |
| `VOCABULARY.md` | Project vocabulary (names, protocol conventions, boards, placeholders) |
| `SOURCES.md` | Where each chapter's facts come from (files to re-check when the code changes) |
| `registers.py`, `csr/` | Designs and register banks of the register appendix, and their snapshots |
| `figures/` | Raster assets (logos; `litex_logo_dark.png` is the LiteX logo with a light tagline for dark backgrounds) |
| `theme.yaml` | Theme of the PDF: colours, fonts, eisvogel options |
| `defaults-pdf.yaml`, `defaults-html.yaml` | pandoc defaults files; `build.py` adds the chapters, the output and absolute paths |
| `template/eisvogel.latex` | Vendored eisvogel template and its BSD license (title font and second logo hooks added) |
| `template/manual.html5` | HTML page template (top bar, title band, sticky table of contents) |
| `style.css` | Style of the HTML page |
| `tools/` | Table converter, cover generator, register appendix engine (`csr_doc.py`), pandoc Lua filters, kit tool (`kit.py`) |
| `build.py`, `check.py` | Build driver and source checker |
| `STYLE.md` | Editorial style guide |
| `../diagrams/` | Python sources of the SVG figures, `svgdiag.py` helper, `svg/` outputs |

## Writing rules

`STYLE.md` is the editorial style guide and `VOCABULARY.md` the project vocabulary; the rules
below are the mechanical ones.

- Every fact (class, parameter, width, rate, default) must be traceable to a file of the
  repository at the documented revision. Prefer quoting the source path in the text when a reader
  may need to check it.
- Give stable identifiers to headings that are cross-referenced (`## Clock domains {#clock-domains}`)
  and link with `[text](#clock-domains)`; `check.py` fails on unresolved anchors.
- Figures: reference the SVG directly (`![Caption](phy_architecture.svg)`), no PNG. Photos of
  `doc/` are referenced by file name.
- Code and commands go in fenced blocks with a language (`sh`, `console`, `python`, `verilog`).
- Do not hand-edit SVGs: `svgdiag.py` encodes the figure style.

## Manual kit {#manual-kit}

The tooling is the same in every LiteX ecosystem core that has a manual; each repository holds a
copy. `KIT` lists the kit files with their version and checksum. The project files (`manual.yaml`,
`metadata.yaml`, the chapters, `VOCABULARY.md`, `SOURCES.md`, `registers.py`, the figures) are not
part of the kit.

```sh
python3 doc/manual/tools/kit.py status                      # kit files modified locally?
python3 doc/manual/tools/kit.py sync --to ../litepcie       # copy the kit to another repository
python3 doc/manual/tools/kit.py init --to ../litepcie \
    --project LitePCIe --title "PCIe Core" --name litepcie_manual   # kit plus a skeleton manual
```

`sync` refuses to overwrite a kit file that was modified in the target repository (its checksum
differs from the one in its `KIT`); improve the kit in one repository, then sync it to the others.

## Theme

The theme follows enjoy-digital.fr and its blog: brand cyan `#2eaadc` (numbers, rules, table
heads, code block rule, figure accents), text blue `#136f9c` (links), dark headings, a light title
page with a dark band and the enjoy-digital.fr cyan grid, dark code blocks (`#0d1117`), and the
Gravur display font for titles. The values live in `theme.yaml` (PDF), `style.css` (HTML),
`tools/cover.py` (PDF title page) and `../diagrams/svgdiag.py` (figures).

## pandoc notes

The sources build with pandoc 2.9 and 3.x. `build.py` converts every pipe table into a grid table
(`tools/tables.py`) so that both versions give the same column widths, converts the SVG figures
to PDF for LaTeX (`tools/svg2pdf.lua`, no `rsvg-convert` needed at pandoc time) and lets long
inline code break (`tools/breakcode.lua`). `theme.yaml` sets `book: true` and
`classoption: [oneside, openany]`, and bounds the figures to the text block with `\maxwidth` and
`\maxheight` (pandoc 2.9 emits a bare `\includegraphics`).
