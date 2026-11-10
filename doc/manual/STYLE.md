# Writing style of the manual

This guide is the editorial reference of the manual: one consistent way of writing, so that a
reader finds the same structure in every chapter and a contributor knows how to add to it. It
complements `README.md` (toolchain, build, checks). This file is part of the manual kit and is
the same in every project; the vocabulary of this project (names of its parts, protocol
conventions, boards, placeholders) is in `VOCABULARY.md`. The voice is short paragraphs, one idea each,
plain words, and a figure or a table wherever it replaces a paragraph.

The manual has two jobs. It is the reference of the project (what it does, how to integrate it,
how to debug it) and it teaches the protocol or technology along the way: a reader who knows
FPGAs but not the protocol must come out of Part I able to read the code. Every protocol concept is explained once, in plain
words, then linked to the module that implements it.

## Goals

1. A newcomer (FPGA engineer, no background in the protocol) can read a chapter top to bottom without
   stopping.
2. A user finds the fact they need in one place, and every other place points there.
3. A contributor changes one section without having to rewrite three others.

## Paragraphs and sentences

- One idea per paragraph, 2 to 4 sentences, 60 words at most. A paragraph that needs a colon and
  a list of items *is* a list.
- Sentences of about 20 words, active voice, one verb. No parentheses that carry a second
  sentence; make it a sentence.
- Explain before naming. The name of a module, signal or file comes *after* the plain-language
  statement of what it does: "The aligner finds the comma in the received bits and shifts the
  words so that each symbol starts on a byte boundary (`RXAligner`)". At most one code
  identifier per sentence in prose; several identifiers belong in a table or a list.
- Use the same word for the same thing throughout, as `VOCABULARY.md` defines it: the names of
  the parts of the project, of the hardware, of the protocol objects and of the placeholders.
  General terms: *board* (hardware), *target* (a target script), *example* (an example design),
  *bitstream* (the file), *register* (never "CSR" in prose, except for the bus name "CSR bus").
- Protocol names follow the specification, cited with the word *section* ("USB 3.2 section 7.5.4",
  "PCIe 3.0 section 4.2"), never by page.
- No dates, pull request numbers, branch names, "former", "still", "recently", "current",
  "TODO" or names of people in the text, except in the credits of the introduction.
- Numbers with units and a space (`5 Gbps`, `125 MHz`, `446 MB/s`, `64 KiB`); hexadecimal in code
  font (`0x1d50`); data rates as `Gbps` and `Mbps`, throughputs as `MB/s` (10^6 bytes per
  second, as the host tools print them), sizes in KiB and MiB, times as "µs", "ns", "ms".
- No em dashes, no arrows in prose, no "etc." and no "..." in prose; finish the list.

## Structure of a chapter

1. **Opening paragraph**: what the chapter covers and who needs it, 2 or 3 sentences.
2. **At a glance**: when the chapter describes a thing (a board, a module, a class), a short table
   of its key facts *before* the explanations.
3. **Sections in the order a reader meets them**: concept and figure, then datapath, then
   control, then parameters and registers, then usage.
4. **In the code**: a module section ends with the file and class names, in one sentence or a
   small table.
5. **Where to go next**: links to the related chapters, one line.

Part I (Understand) explains the protocol as the specification defines it, with the project's choices
noted where they matter. Parts II and III describe the implementation and link back to the
Part I section of each concept instead of explaining it again.

## Figures

- One idea per figure, 3 to 8 blocks. A datapath figure shows the datapath; the control and
  clocking of the same module is another figure. Split a figure that needs more than two rows of
  boxes.
- House style (`doc/diagrams/svgdiag.py`): the Enjoy-Digital block-diagram style, with straight
  edges and diagonally cut top-right and bottom-left corners. Containers are light grey;
  functional blocks are near-white; the blocks the figure is about are tinted with the brand cyan
  (`COLOR_ACCENT`, lighter `COLOR_ACCENT_LIGHT` for their neighbours); external hardware (host,
  transceiver, cable) is medium grey (`COLOR_HARDWARE`). Use fine grey outlines, subtle offset
  shadows, regular Carlito / Calibri labels and italic container titles inset from the corners.
  Data arrows are 2 px grey lines; the path the figure is about may use `kind="accent"` (2 px
  cyan); control arrows are 1 px; feedback and clock boundaries are dotted. Bit fields keep
  adjoining square cells without shadows (`radius=0`). Red is reserved for error conditions
  (bad CRC, retry, fault), green for "ok" markers (locked, aligned, link up).
- Every figure is drawn on a 760 px wide canvas (`svgdiag.CANVAS_WIDTH`; the height is free).
  The PDF prints the SVG at its natural size capped to the text width, so one canvas width means
  one printed scale: a 15 px box label prints at 9 pt, a 12 px arrow label at 7.2 pt. Dense
  blocks use 13 px labels; container titles use 18 px. No label is smaller than 10 px
  (`FONT_SIZE_MIN`); when a label does not fit, make the box bigger or use fewer words, never a
  smaller font.
- No sentence in a figure. Box labels are two or three words, arrow labels one to three words;
  the explanation, the formulas and the numbers go in the text or in the caption.
- Every figure has a caption that states what to look at, and the text refers to it ("the figure
  below shows...") before the figure appears.
- `Diagram.check()` fails the build (`python3 doc/diagrams/build.py --check`) on: a canvas width
  other than 760 px; any label under 10 px; a box label wider or taller than its box; overlapping
  text labels; a shape or a text leaving the canvas; a text overlapping a box it does not belong
  to, crossing a container border or crossed by an arrow; a diagonal or zero-length arrow
  segment; an arrow segment passing through a box it neither starts nor ends on. Unlabelled boxes
  are frames and are exempt from the overlap tests.
- State machines (such as a link training state machine) are drawn as boxes and orthogonal arrows like any other figure; timing
  and packet exchanges are drawn as lanes (one horizontal or vertical line per side, `Bus` with
  a dash) with horizontal arrows between them.

## Tables

- Use a table for anything enumerated with more than two attributes (modules, options, boards,
  parameters, registers). Column headers are nouns; cells are short; no full sentences in a fact
  table.
- Pipe tables take their column widths from the dash counts of the separator row (`build.py`
  converts them to grid tables): give a column enough dashes for its longest code identifier or
  path. A token cannot wrap; `check.py` fails on a table whose token overflows its column, and the
  fix is a wider column, a plain word instead of the identifier, or the command moved to a code
  block. Descriptions that need several sentences go in a paragraph after the table.
- The width model of `check.py` is measured on the PDF: the code font is 6.6 pt per character,
  the text font about 5 pt, and the text block is 455 pt wide. A code identifier of 20 characters
  therefore needs about a third of a five-column table; keep identifiers under 20 characters in
  tables.
- A table row never repeats a fact given in the prose above it.

## Cross-references

- Every chapter and every referenced heading carries an explicit identifier
  (`## Clock domains {#clock-domains}`); link with the section title as text ("see
  [Clock domains](#clock-domains)"), never "see above" or "see section 4.8".
- Point to a source file only when the reader is expected to open it, at most once per paragraph.

## Code

- Commands in fenced blocks with a language (`sh`, `console`, `python`, `verilog`, `yaml`), one
  command per line, comments on their own line, lines under 90 characters.
- Inline code only for identifiers that exist verbatim in the repository (files, classes,
  signals, options, registers). Concepts are written in words.

## Checklist before a pull request

- `python3 doc/manual/build.py --diagrams --check --pdf --html --fail-if-warnings` passes.
- Every new fact is traceable (`SOURCES.md` updated).
- Read the changed chapter once as a newcomer: no sentence needs to be read twice, no paragraph
  over 60 words, no figure with more than eight blocks, no repeated fact.
