# Manual diagrams

Each figure is a Python module whose `build()` function returns a `svgdiag.Diagram`. The manual
references the generated files in `svg/` (committed); `png/` holds local previews (ignored).

```sh
python3 doc/diagrams/build.py               # regenerate every figure
python3 doc/diagrams/build.py ltssm_main    # regenerate one figure
python3 doc/diagrams/build.py --check       # fail if a committed SVG is stale or a layout check fails
```

The figures follow the Enjoy-Digital block-diagram style: cut top-right and bottom-left corners,
grey panels, cyan-tinted principal blocks (the brand colour `#2eaadc`), medium-grey external
hardware, regular Carlito labels and italic container titles. Colours, type sizes, arrows and
shadows live in `svgdiag.py`; the full rules are in [the manual style guide](../manual/STYLE.md#figures).

Carlito (`fonts-crosextra-carlito`) is the preferred font, with Calibri and Liberation Sans
fallbacks. Shadows use translucent vector outlines instead of SVG filters, keeping PDF shapes
and text as vectors. Adjacent bit fields use `radius=0`, which disables chamfers and shadows.

All figures share a 760 px canvas width, so Markdown, HTML and PDF use the same assets at the same
printed scale. The build checks bounds, text sizes and fit, overlapping labels, arrow routing and
whether the generated SVGs match their sources.
