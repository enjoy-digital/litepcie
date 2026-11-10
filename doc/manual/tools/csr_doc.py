#!/usr/bin/env python3
#
# This file is part of the LiteX manual kit.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Register documentation tool of the manual:
#
#   csr_doc.py dump [--check] [CONFIG ...]   elaborate the designs of registers.py (no toolchain) and
#                                            write the CSR snapshots doc/manual/csr/<config>.json
#                                            (--check: fail if a committed snapshot differs)
#   csr_doc.py generate [--check]            write doc/manual/A_registers.md from the snapshots
#                                            (--check: fail if the appendix is not up to date)
#
# The snapshots carry, per documented register bank (doc/manual/registers.py): the register name, its offset from the
# bank base, its width, access, reset value, description and fields, as the LiteX CSR definitions
# document them. Descriptions therefore live in the gateware sources (CSRStorage/CSRStatus/CSRField
# descriptions): edit them there, refresh the snapshots with `dump`, then regenerate the appendix.

import argparse
import json
import os
import sys

HERE         = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT    = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SNAPSHOT_DIR = os.path.join(REPO_ROOT, "doc", "manual", "csr")
APPENDIX     = os.path.join(REPO_ROOT, "doc", "manual", "A_registers.md")

# Project configuration (doc/manual/registers.py): CONFIGS (designs to elaborate), BANKS (prefix,
# title, origin, path), NOTES, INTRO, USAGE, MAIN_BANK and elaborate(name, repo_root).
sys.path.insert(0, os.path.join(REPO_ROOT, "doc", "manual"))
import registers as project  # noqa: E402
CONFIGS  = project.CONFIGS
BANKS    = project.BANKS
NOTES    = getattr(project, "NOTES", {})
PREFIXES = [b[0] for b in BANKS]

# Dump ---------------------------------------------------------------------------------------------

def _const(v):
    """Reset value as an int, or None when it is not a constant."""
    from migen.fhdl.structure import Constant
    if isinstance(v, Constant):
        return v.value
    if isinstance(v, int):
        return v
    return None


def _csr_entry(csr, csr_json, bank, base):
    from litex.soc.interconnect.csr import CSRStorage, CSRStatus
    full = f"{bank}_{csr.name}"
    reg  = csr_json["csr_registers"].get(full)
    if reg is None:
        return None
    if isinstance(csr, CSRStorage):
        access, reset = "rw", _const(csr.storage.reset)
    elif isinstance(csr, CSRStatus):
        access, reset = "ro", None
    else:
        access, reset = "wo", None
    fields = []
    for f in getattr(csr, "fields", None) and csr.fields.fields or []:
        fields.append({
            "name"        : f.name,
            "offset"      : f.offset,
            "size"        : f.size,
            "reset"       : f.reset_value if isinstance(f.reset_value, int) else None,
            "description" : (f.description or "").strip(),
            "values"      : [[str(v[0]), str(v[1])] for v in (f.values or [])],
        })
    return {
        "name"        : csr.name,
        "offset"      : reg["addr"] - base,
        "size"        : csr.size,
        "access"      : access,
        "reset"       : reset,
        "description" : " ".join((getattr(csr, "description", None) or "").split()),
        "fields"      : fields,
    }


def dump_config(name):
    """Elaborate a design of the project (no FPGA toolchain) and return its snapshot."""
    soc, csr_json, module_name, argv = project.elaborate(name, REPO_ROOT)
    banks = {}
    for bank, region in sorted(soc.csr.regions.items()):
        objs = region.obj
        if bank == "main":
            objs = [c for c in objs if c.name.startswith(tuple(PREFIXES))]
        elif not bank.startswith(tuple(PREFIXES)):
            continue
        base = csr_json["csr_bases"][bank]
        regs = [_csr_entry(c, csr_json, bank, base) for c in objs]
        banks[bank] = sorted([r for r in regs if r is not None], key=lambda r: r["offset"])
    return {"config": name, "target": module_name, "argv": argv, "banks": banks}


def snapshot_path(name):
    return os.path.join(SNAPSHOT_DIR, f"{name}.json")


def cmd_dump(names, check):
    rc = 0
    os.makedirs(SNAPSHOT_DIR, exist_ok=True)
    for name in names or list(CONFIGS):
        text = json.dumps(dump_config(name), indent=1, sort_keys=True) + "\n"
        path = snapshot_path(name)
        if check:
            if not os.path.exists(path) or open(path).read() != text:
                print(f"STALE: {os.path.relpath(path, REPO_ROOT)} (run csr_doc.py dump)")
                rc = 1
            continue
        open(path, "w").write(text)
        print(f"wrote {os.path.relpath(path, REPO_ROOT)}")
    return rc

# Generate -----------------------------------------------------------------------------------------

def _esc(s):
    return s.replace("|", "\\|").replace("<", "\\<").replace(">", "\\>")


def _wrap_name(name, limit=15):
    """Long register names: allow a break at an underscore (code spans cannot wrap)."""
    if len(name) <= limit:
        return f"`{name}`"
    parts, line, out = name.split("_"), "", []
    for p in parts:
        cand = f"{line}_{p}" if line else p
        if len(cand) + 1 > limit and line:
            out.append(line + "_")
            line = p
        else:
            line = cand
    out.append(line)
    return " ".join(f"`{o}`" for o in out)


def _reset(v):
    return "-" if v is None else f"`{v:#x}`"


def _bank_groups(snaps):
    """Banks of every configuration, each documented once from the configuration where it has the
    most registers (the offsets of a bank are those of one elaboration)."""
    merged = {}
    for snap in snaps:
        for bank, regs in snap["banks"].items():
            if bank not in merged or len(regs) > len(merged[bank][1]):
                merged[bank] = (snap["config"], regs)
    return merged


def generate():
    snaps = [json.load(open(snapshot_path(n))) for n in CONFIGS if os.path.exists(snapshot_path(n))]
    merged = _bank_groups(snaps)
    out = []
    out += ["<!-- Generated by doc/manual/tools/csr_doc.py generate: do not edit, edit the CSR",
            "     descriptions in the gateware sources and regenerate. -->", ""]
    out += ["# Register reference {#registers}", ""]
    out += project.INTRO + [""]
    out += ["| Configuration | Target and options |",
            "|------------------------|--------------------------------------------------------|"]
    for s in snaps:
        argv = " ".join(f"`{a}`" for a in s["argv"])
        out.append(f"| `{s['config']}` | `{s['target']}` {argv} |")
    out += ["",
            "Access is `rw` for a register written by software (`CSRStorage`), `ro` for a status",
            "(`CSRStatus`) and `wo` for a write-only strobe (`CSR`). The reset value of a `rw`",
            "register ends its description. A register wider than 32 bits takes several",
            "32-bit words of the bus, most significant word first. " + project.USAGE[0]] + project.USAGE[1:] + [""]
    def owner(name):
        """Longest documented prefix of a bank or register name."""
        hits = [p for p in PREFIXES if name.startswith(p)]
        return max(hits, key=len) if hits else None

    for prefix, title, origin, path in BANKS:
        groups = []
        for bank in sorted(merged):
            config, regs = merged[bank]
            if bank == "main":
                regs = [r for r in regs if owner(r["name"]) == prefix]
                if regs:
                    groups.append(("main", regs))
            elif owner(bank) == prefix:
                groups.append((bank, regs))
        if not groups:
            continue
        anchor = "reg-" + prefix.replace("_", "-")
        out += [f"## {title} {{#{anchor}}}", ""]
        where = f"`{path}`" if "/" in path else path
        what  = f"`{origin}`" if origin[0] != "t" else origin
        out += [f"Defined by {what} ({where}).", ""]
        if prefix in NOTES:
            out += NOTES[prefix] + [""]
        for bank, regs in groups:
            if bank == "main":
                out += [project.MAIN_BANK, ""]
            elif len(groups) > 1:
                out += [f"### `{bank}`", ""]
            else:
                out += [f"Bank `{bank}`.", ""]
            out += ["| Register | Offset | Bits | Access | Description |",
                    "|----------------------------|-------------|--------|---------|"
                    "----------------------------------------|"]
            notes = []
            for r in regs:
                desc = _esc(r["description"])
                if not desc and len(r["fields"]) > 1:
                    desc = "See the fields below."
                elif not desc and len(r["fields"]) == 1:
                    desc = _esc(" ".join(r["fields"][0]["description"].split()))
                elif not desc and r["access"] == "wo":
                    desc = "Write strobe."
                if r["reset"] is not None:
                    desc = f"{desc} Reset {_reset(r['reset'])}.".strip()
                desc = desc or "No description."
                out.append(f"| {_wrap_name(r['name'])} | `{r['offset']:#06x}` | {r['size']} | {r['access']} "
                           f"| {desc} |")
                if r["fields"] and len(r["fields"]) > 1:
                    notes.append(r)
            out.append("")
            for r in notes:
                out += [f"Fields of `{r['name']}`:", ""]
                out += ["| Field | Bits | Description |",
                        "|------------------------|---------|------------------------------------------------------|"]
                for f in r["fields"]:
                    hi = f["offset"] + f["size"] - 1
                    bits = f"{hi}:{f['offset']}" if f["size"] > 1 else f"{f['offset']}"
                    desc = _esc(" ".join(f["description"].split()))
                    out.append(f"| {_wrap_name(f['name'])} | {bits} | {desc} |")
                out.append("")
    return "\n".join(out).rstrip() + "\n"


def cmd_generate(check):
    text = generate()
    if check:
        if not os.path.exists(APPENDIX) or open(APPENDIX).read() != text:
            print("STALE: doc/manual/A_registers.md (run csr_doc.py generate)")
            return 1
        return 0
    open(APPENDIX, "w").write(text)
    print(f"wrote {os.path.relpath(APPENDIX, REPO_ROOT)}")
    return 0

# Main ---------------------------------------------------------------------------------------------

def main(argv):
    parser = argparse.ArgumentParser(description="Register documentation tool of the manual.")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("dump", help="Elaborate the bench targets and write the CSR snapshots.")
    p.add_argument("--check", action="store_true", help="Fail if a committed snapshot differs.")
    p.add_argument("configs", nargs="*", help=f"Configurations (default: all of {', '.join(CONFIGS)}).")
    p = sub.add_parser("generate", help="Write A_registers.md from the snapshots.")
    p.add_argument("--check", action="store_true", help="Fail if the appendix is not up to date.")
    args = parser.parse_args(argv)
    if args.cmd == "dump":
        for name in args.configs:
            if name not in CONFIGS:
                parser.error(f"unknown configuration {name!r}")
        return cmd_dump(args.configs, args.check)
    return cmd_generate(args.check)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
