#
# This file is part of LitePCIe project.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Register appendix of the manual: which designs tools/csr_doc.py elaborates and which register banks
# it documents (the engine is generic, part of the manual kit).

import importlib.util
import json
import os
import sys
import tempfile

# Configurations: script (path from the repository root) and command line. The KC705 target covers
# the hard-IP PHY, the LTSSM tracer, MSI and the DMA with buffering and loopback; the generator
# configuration adds MSI-X, PTM and the DMA synchronizer and monitor; the soft PHY targets add the
# bring-up registers of the soft PHY, at x1 (Acorn) and at 8.0 GT/s x4 (YPCB-00338-1P1).
CONFIGS = {
    "kc705"          : ("bench/kc705.py",      []),
    "gen_msix_ptm"   : ("litepcie/gen.py",     ["doc/manual/registers_gen.yml"]),
    "soft_acorn"     : ("bench/soft/acorn.py", ["--with-endpoint", "--with-debug", "--with-ltssm-tracer"]),
    "soft_ypcb_gen3" : ("bench/soft/ypcb.py",  ["--with-endpoint", "--speed", "gen3", "--nlanes", "4"]),
}

# Banks documented in the appendix (prefix match on the bank name), in order, with their title and
# the Python class that defines them. The longest matching prefix owns a bank.
BANKS = [
    ("pcie_phy",              "PHY status",    "the PHY wrappers", "litepcie/phy"),
    ("pcie_phy_ltssm_tracer", "LTSSM tracer",  "LTSSMTracer",      "litepcie/phy/common.py"),
    ("pcie_phy_debug",        "Soft PHY debug", "SoftPHYDebug",    "litepcie/phy/soft/debug.py"),
    ("pcie_phy_serdes",       "Soft PHY transceiver controls", "K7PCIeSerDes", "litepcie/phy/soft/serdes/gtx_7series.py"),
    ("pcie_msi",              "MSI",           "LitePCIeMSI",      "litepcie/core/msi.py"),
    ("pcie_msix",             "MSI-X",         "LitePCIeMSIX",     "litepcie/core/msi.py"),
    ("pcie_dma",              "DMA",           "LitePCIeDMA",      "litepcie/frontend/dma.py"),
    ("ptm",                   "PTM",           "PTMRequester",     "litepcie/frontend/ptm/core.py"),
]

# Notes printed after the title of a bank family: what the register descriptions do not say.
NOTES = {
    "pcie_phy": [
        "Every PHY has a `pcie_phy` bank. The table shows the 7-Series PHY of the KC705 target; the",
        "other Xilinx PHYs and the soft PHY have the same registers, the Gowin GW5A PHY adds",
        "transaction layer status registers and the Cyclone V PHY has none. The `ltssm` field",
        "uses the state codes of the hard IP: [Link status and LTSSM tracer](#debug-ltssm)",
        "decodes them.",
    ],
    "pcie_phy_ltssm_tracer": [
        "Added by `add_ltssm_tracer()`. Its register is in the `pcie_phy` bank, after the PHY",
        "registers, so its full name is `pcie_phy_ltssm_tracer_history`. Each read pops one",
        "transition from a 128-entry history; `valid` clear means the history is empty.",
    ],
    "pcie_phy_debug": [
        "Added to the soft PHY by `add_debug()`; the registers are in the `pcie_phy` bank, after",
        "the PHY registers (full names `pcie_phy_debug_<register>`). The table shows the",
        "YPCB-00338-1P1 design at 8.0 GT/s x4: `lanes` and `lane_disable` exist above x1, the",
        "`g3_` registers at 8.0 GT/s only. [Soft PHY debug](#debug-soft) reads them with",
        "`bench/soft/status.py`.",
    ],
    "pcie_phy_serdes": [
        "Added by the GTX adapter of the soft PHY in 8.0 GT/s designs, in the `pcie_phy` bank",
        "(full names `pcie_phy_serdes_<register>`): the 8.0 GT/s clock recovery setting and",
        "direct access to the transceiver DRP, used for the eye scans of",
        "[Soft PHY debug](#debug-soft).",
    ],
    "pcie_msi": [
        "Bank of the single-vector MSI controller of the KC705 target. The multi-vector",
        "controller (`LitePCIeMSIMultiVector`) has only `enable`.",
    ],
    "pcie_msix": [
        "In a design built with MSI-X, these registers are in the `pcie_msi` bank; they are listed",
        "under `pcie_msix` here only to keep them apart from the MSI ones. The vector table is the",
        "`pcie_msi_table` memory, four 32-bit words per vector. The driver uses MSI-X when the",
        "`pba` register exists. With 64 vectors and the big register ordering, the controller",
        "swaps the two halves of `pba`: the word at offset `0x0008` holds vectors 0 to 31, as the",
        "host reads the Pending Bit Array.",
    ],
    "pcie_dma": [
        "One bank per DMA channel, `pcie_dma0` to `pcie_dmaN`, all with the layout below. The",
        "`loopback`, `synchronizer`, `buffering` and `monitor` registers exist only when the",
        "plug-in is built; the status plug-in (`with_status`) adds `status_` registers not shown",
        "here. [Scatter-gather DMA](#dma) describes the descriptor format.",
    ],
    "ptm": [
        "Present when the design has PTM (`ptm: true` in a generator configuration).",
        "[Precision Time Measurement](#ptm) describes the exchange and the delays.",
    ],
}

# Opening paragraph of the appendix and the sentence that ends the access paragraph.
INTRO = ["This appendix lists the registers of the LitePCIe cores that the host reads and writes",
         "through BAR0. It is generated from the register definitions of the gateware, elaborated on",
         "four configurations without running an FPGA toolchain. Offsets are in bytes from the base",
         "of the bank; the base addresses depend on the SoC and are in the `csr.csv` of a build."]
USAGE = ["The driver and the tools use these names through", "the generated `csr.h`, so they rarely need the offsets."]
MAIN_BANK = "Registers of the top-level `main` bank of the SoC."


# The PHY bank also holds the registers of the PHY's submodules (LTSSM tracer, soft PHY debug and
# transceiver controls): they are documented as their own banks, named after the prefix of their
# registers, with their offsets kept from the base of the PHY bank.
SPLITS = {"pcie_phy": ["ltssm_tracer", "debug", "serdes"]}

# Banks documented under another name: the `pcie_msi` bank of an MSI-X design (the MSI design of
# the KC705 target has a `pcie_msi` bank too), and the DMA channels after the first one (same
# registers as `pcie_dma0`).
RENAMES = {"pcie_msi": "pcie_msix"}
DROPS   = ["pcie_dma1", "pcie_dma2", "pcie_dma3"]


def _split_banks(soc, csr_json):
    import copy
    for bank, subs in SPLITS.items():
        region = soc.csr.regions.get(bank)
        if region is None:
            continue
        keep = list(region.obj)
        for sub in subs:
            regs = []
            for csr in [c for c in keep if c.name.startswith(sub + "_")]:
                keep.remove(csr)
                c = copy.copy(csr)
                c.name = csr.name[len(sub) + 1:]
                regs.append(c)
            if regs:
                name = f"{bank}_{sub}"
                soc.csr.regions[name] = copy.copy(region)
                soc.csr.regions[name].obj = regs
                csr_json["csr_bases"][name] = csr_json["csr_bases"][bank]
        region.obj = keep
    for bank in DROPS:
        soc.csr.regions.pop(bank, None)
    if "pba" in [c.name for c in getattr(soc.csr.regions.get("pcie_msi"), "obj", [])]:
        for old, new in RENAMES.items():
            soc.csr.regions[new] = soc.csr.regions.pop(old)
            csr_json["csr_bases"][new] = csr_json["csr_bases"][old]
            for reg in list(csr_json["csr_registers"]):
                if reg.startswith(old + "_"):
                    csr_json["csr_registers"][new + reg[len(old):]] = csr_json["csr_registers"][reg]


def _load(repo_root, script):
    """Import a script of the repository under a unique module name."""
    name = "manual_" + script.replace("/", "_").replace(".py", "")
    spec = importlib.util.spec_from_file_location(name, os.path.join(repo_root, script))
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def elaborate(name, repo_root):
    """Run the main() of a target or of the generator with its Builder replaced by one that
    elaborates without the toolchain; return (soc, csr_json, module, argv)."""
    script, argv = CONFIGS[name]
    sys.path.insert(0, repo_root)
    from litex.soc.integration.builder import Builder
    captured = {}
    old_cwd  = os.getcwd()

    with tempfile.TemporaryDirectory() as tmp:
        class CaptureBuilder(Builder):
            def __init__(self, soc, *args, **kwargs):
                kwargs.update(output_dir=tmp, csr_csv=os.path.join(tmp, "csr.csv"),
                    csr_json=os.path.join(tmp, "csr.json"), compile_software=False,
                    compile_gateware=False)
                Builder.__init__(self, soc, **kwargs)
                captured["soc"] = soc

            def build(self, *args, **kwargs):
                kwargs["run"] = False
                return Builder.build(self, *args, **kwargs)

        os.chdir(repo_root)
        mod = _load(repo_root, script)
        mod.Builder = CaptureBuilder
        if hasattr(mod, "generate_litepcie_software_headers"):
            mod.generate_litepcie_software_headers = lambda soc, dst: None
        old_argv = sys.argv
        sys.argv = [script] + argv
        try:
            mod.main()
        finally:
            sys.argv = old_argv
            os.chdir(old_cwd)
        captured["json"] = json.load(open(os.path.join(tmp, "csr.json")))
    # Memories mapped on the CSR bus (the MSI-X vector table) have no register definitions.
    soc, csr_json = captured["soc"], captured["json"]
    for bank, region in list(soc.csr.regions.items()):
        if not isinstance(region.obj, list):
            del soc.csr.regions[bank]
    _split_banks(soc, csr_json)
    module = os.path.splitext(os.path.basename(script))[0]
    if script.startswith("bench/soft/"):
        module = "soft/" + module
    return soc, csr_json, module, argv
