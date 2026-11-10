#!/usr/bin/env python3
#
# This file is part of the LiteX manual kit.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Manual kit tool. The kit is the tooling of the manuals of the LiteX ecosystem cores (build and
# check scripts, theme, templates, figure helper, register appendix engine, CI workflow); every
# repository holds a copy, listed with its checksums in doc/manual/KIT.
#
#   kit.py status                       kit files of this repository modified since doc/manual/KIT?
#   kit.py update                       record the current kit files in doc/manual/KIT (after a change)
#   kit.py sync --to <repo> [--force]   copy the kit to another repository
#   kit.py init --to <repo> --project <name> --title <title> --name <output>
#                                       sync, then create a skeleton manual (project files)
#
# sync refuses to overwrite a kit file that was modified in the target (its checksum differs from
# the target KIT and from the new file) unless --force: improve the kit in one repository, update
# its KIT, then sync it to the others.

import argparse
import datetime
import hashlib
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
KIT  = Path("doc/manual/KIT")

# Kit files, relative to the repository root. Everything else in doc/manual and doc/diagrams belongs
# to the project (chapters, metadata.yaml, manual.yaml, VOCABULARY.md, SOURCES.md, registers.py,
# csr/, figures of the chapters).
FILES = [
    ".github/workflows/doc.yml",
    "doc/diagrams/.gitignore",
    "doc/diagrams/README.md",
    "doc/diagrams/build.py",
    "doc/diagrams/svgdiag.py",
    "doc/manual/E_maintenance.md",
    "doc/manual/README.md",
    "doc/manual/STYLE.md",
    "doc/manual/Z_appendix.md",
    "doc/manual/build.py",
    "doc/manual/check.py",
    "doc/manual/defaults-html.yaml",
    "doc/manual/defaults-pdf.yaml",
    "doc/manual/figures/enjoy_digital.png",
    "doc/manual/figures/enjoy_digital_gray.png",
    "doc/manual/figures/litex_logo_dark.png",
    "doc/manual/style.css",
    "doc/manual/template/LICENSE.eisvogel",
    "doc/manual/template/eisvogel.latex",
    "doc/manual/template/manual.html5",
    "doc/manual/theme.yaml",
    "doc/manual/tools/appendix.lua",
    "doc/manual/tools/breakcode.lua",
    "doc/manual/tools/cover.py",
    "doc/manual/tools/csr_doc.py",
    "doc/manual/tools/kit.py",
    "doc/manual/tools/svg2pdf.lua",
    "doc/manual/tools/tables.py",
]

# Helpers ------------------------------------------------------------------------------------------

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_kit(root):
    """(version, {path: sha256}) of the KIT file of a repository, or (None, {}) if absent."""
    path = root/KIT
    if not path.exists():
        return None, {}
    version, sums = None, {}
    for line in path.read_text().split("\n"):
        if line.startswith("version:"):
            version = line.split(":", 1)[1].strip()
        elif line and not line.startswith("#"):
            digest, name = line.split(None, 1)
            sums[name.strip()] = digest
    return version, sums


def write_kit(root, sums, version):
    lines = ["# Manual kit (doc/manual/tools/kit.py): version and checksums of the kit files. Do not",
             "# edit: run kit.py update after changing a kit file, kit.py sync to copy the kit.",
             f"version: {version}", ""]
    lines += [f"{sums[f]}  {f}" for f in FILES]
    (root/KIT).write_text("\n".join(lines) + "\n")


def current_sums(root):
    missing = [f for f in FILES if not (root/f).exists()]
    if missing:
        sys.exit("error: kit files missing in {}: {}".format(root, ", ".join(missing)))
    return {f: sha256(root/f) for f in FILES}


def modified(root):
    """Kit files of a repository that differ from its KIT (or all of them without a KIT)."""
    _, recorded = read_kit(root)
    return [f for f in FILES if (root/f).exists() and recorded.get(f) != sha256(root/f)]

# Commands -----------------------------------------------------------------------------------------

def cmd_status():
    version, _ = read_kit(ROOT)
    changed = modified(ROOT)
    print(f"kit version {version or '(no KIT file)'}")
    for f in changed:
        print(f"modified: {f}")
    if not changed:
        print("kit files up to date")
    return 1 if changed else 0


def cmd_update():
    sums    = current_sums(ROOT)
    digest  = hashlib.sha256("".join(sums[f] for f in FILES).encode()).hexdigest()[:8]
    version = f"{datetime.date.today().isoformat()}-{digest}"
    write_kit(ROOT, sums, version)
    print(f"wrote {KIT} (version {version})")
    return 0


def cmd_sync(target, force):
    target = Path(target).resolve()
    if not (target/".git").exists():
        sys.exit(f"error: {target} is not a git repository")
    if modified(ROOT):
        sys.exit("error: kit files of this repository differ from its KIT: run kit.py update first")
    version, sums = read_kit(ROOT)
    _, recorded   = read_kit(target)
    conflicts = []
    for f in FILES:
        dst = target/f
        if dst.exists():
            digest = sha256(dst)
            if digest != sums[f] and recorded.get(f) not in (None, digest):
                conflicts.append(f) # Modified in the target since its last sync.
            elif digest != sums[f] and f not in recorded and (target/KIT).exists():
                conflicts.append(f)
    if conflicts and not force:
        print("error: kit files modified in the target (merge them first, or use --force):")
        for f in conflicts:
            print(f"  {f}")
        return 1
    for f in FILES:
        dst = target/f
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT/f, dst)
    write_kit(target, sums, version)
    print(f"synced kit {version} ({len(FILES)} files) to {target}")
    return 0

# Skeleton -----------------------------------------------------------------------------------------

def skeleton(project, title, name, subtitle, years, license_short):
    """Project files of a new manual: {path: content}. Chapters carry their final anchors."""
    files   = {}
    escaped = title.replace("&", "\\\\&") # LaTeX header: \\& in YAML, \& for LaTeX.
    files["doc/manual/manual.yaml"] = "\n".join([
        "# Manual of this project: output name and chapters, in order (read by build.py; the pandoc defaults",
        "# files and the theme are generic, from the manual kit).",
        f"name: {name}",
        "chapters:",
        *[f"  - {c}" for c, _ in CHAPTERS],
        ""])
    files["doc/manual/metadata.yaml"] = "\n".join([
        "---",
        "# Project metadata of the manual (title page, headers, document properties). The theme (colours,",
        "# fonts, LaTeX options) is in theme.yaml; build.py merges both and replaces @DATE@.",
        f'title: "{title}"',
        f'project: "{project}"',
        f'subtitle: "{subtitle}"',
        "author: [Enjoy-Digital]",
        'date: "@DATE@"',
        f'license: "Copyright © {years} Enjoy-Digital. Licensed under the {license_short} license."',
        f'license-short: "{license_short}"',
        'contact: "hello@enjoy-digital.fr"',
        'website: "enjoy-digital.fr"',
        f'subject: "{project}"',
        "lang: en-US",
        f'header-right: "{escaped} · {license_short} · '
        '\\\\href{mailto:hello@enjoy-digital.fr}{hello@enjoy-digital.fr}"',
        "---", ""])
    files["doc/manual/VOCABULARY.md"] = "\n".join([
        f"# Vocabulary of the {project} manual", "",
        "Project-specific writing rules, completing the generic `STYLE.md` of the manual kit.", "",
        "## Names of the parts", "", "## Protocol names", "", "## Placeholders", "", "## Hardware names", ""])
    files["doc/manual/SOURCES.md"] = "\n".join([
        "# Sources of the manual's facts", "",
        "Every number and name in the manual is taken from the repository at the documented revision. This",
        "file records where each chapter's facts come from, so that a reviewer can re-check them and a",
        "maintainer knows what to update when the code changes.", "",
        "| Chapter / section | Sources |", "|---|---|", ""])
    files["doc/manual/registers.py"] = "\n".join([
        "#", f"# This file is part of {project} project.", "#",
        "# Register appendix of the manual: which designs tools/csr_doc.py elaborates and which register",
        "# banks it documents (the engine is generic, part of the manual kit).", "",
        "# Configurations: name -> (module, argv). Banks: (prefix, title, origin, path).",
        "CONFIGS   = {}", "BANKS     = []", "NOTES     = {}",
        f'INTRO     = ["This appendix lists the registers of the {project} cores."]',
        'USAGE     = ["Software accesses them by name through the `csr.csv` of a build."]',
        'MAIN_BANK = "Registers of the top-level `main` bank of the SoC."', "", "",
        "def elaborate(name, repo_root):",
        '    """Elaborate a design without running a toolchain; return (soc, csr_json, module, argv)."""',
        "    raise NotImplementedError", ""])
    for chapter, heading in CHAPTERS:
        path = f"doc/manual/{chapter}"
        if chapter in ("E_maintenance.md", "Z_appendix.md"):
            continue # Kit files.
        files[path] = heading + "\n"
    return files


# Chapters of a new manual and their first lines (part markers, title, anchor). The structure is the
# one of the USB3-PIPE manual; adapt it to the core at the outline stage.
def _part(title, num, mainmatter=False):
    pre = "\\mainmatter\n" if mainmatter else ""
    return (f"```{{=latex}}\n{pre}\\part{{{title}}}\n```\n\n"
            f"```{{=html}}\n<h1 class=\"part\">Part {num}. {title}</h1>\n```\n\n")

CHAPTERS = [
    ("00_front.md",           "```{=latex}\n\\frontmatter\n```\n\n# About this document {.unnumbered}\n\n## Conventions {.unnumbered}"),
    ("01_introduction.md",    _part("Understand", "I", mainmatter=True) + "# Introduction {#introduction}"),
    ("02_primer.md",          "# In a nutshell {#primer}"),
    ("03_architecture.md",    _part("The core", "II") + "# Architecture {#architecture}"),
    ("09_boards.md",          _part("Use it", "III") + "# Supported FPGAs and boards {#boards}"),
    ("10_getting_started.md", "# Getting started {#getting-started}"),
    ("11_integration.md",     "# Integration {#integration}"),
    ("12_examples.md",        "# Examples {#examples}"),
    ("13_simulation.md",      "# Simulation and verification {#simulation}"),
    ("14_debugging.md",       "# Debugging {#debugging}"),
    ("Z_appendix.md",         ""),
    ("A_registers.md",        "# Register reference {#registers}"),
    ("B_build_options.md",    "# Build options {#build-options}"),
    ("C_glossary.md",         "# Glossary {#glossary}"),
    ("D_performance.md",      "# Performance and resources {#performance}"),
    ("E_maintenance.md",      ""),
]


def cmd_init(target, project, title, name, subtitle, years, license_short, force):
    rc = cmd_sync(target, force)
    if rc:
        return rc
    target = Path(target).resolve()
    for path, content in skeleton(project, title, name, subtitle, years, license_short).items():
        dst = target/path
        if dst.exists():
            print(f"kept {path} (exists)")
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(content)
        print(f"created {path}")
    (target/"doc/diagrams/svg").mkdir(parents=True, exist_ok=True)
    return 0

# Main ---------------------------------------------------------------------------------------------

def main(argv):
    parser = argparse.ArgumentParser(description="Manual kit tool (status, update, sync, init).")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status", help="Kit files modified since doc/manual/KIT.")
    sub.add_parser("update", help="Record the current kit files in doc/manual/KIT.")
    p = sub.add_parser("sync", help="Copy the kit to another repository.")
    p.add_argument("--to",    required=True, help="Target repository.")
    p.add_argument("--force", action="store_true", help="Overwrite kit files modified in the target.")
    p = sub.add_parser("init", help="Sync the kit and create a skeleton manual in another repository.")
    p.add_argument("--to",       required=True, help="Target repository.")
    p.add_argument("--project",  required=True, help="Project name (LitePCIe).")
    p.add_argument("--title",    required=True, help="Manual title (PCIe Core).")
    p.add_argument("--name",     required=True, help="Output name (litepcie_manual).")
    p.add_argument("--subtitle", default="Design, Integration and Reference Manual", help="Subtitle.")
    p.add_argument("--years",    default=f"2015-{datetime.date.today().year}", help="Copyright years.")
    p.add_argument("--license",  default="BSD-2-Clause", help="License (SPDX identifier).")
    p.add_argument("--force",    action="store_true", help="Overwrite kit files modified in the target.")
    args = parser.parse_args(argv)
    if args.cmd == "status":
        return cmd_status()
    if args.cmd == "update":
        return cmd_update()
    if args.cmd == "sync":
        return cmd_sync(args.to, args.force)
    return cmd_init(args.to, args.project, args.title, args.name, args.subtitle, args.years, args.license,
        args.force)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
