```{=latex}
\frontmatter
```

# About this document {.unnumbered}

This manual is the reference of the LitePCIe project: a PCI Express core for FPGAs, its PHYs on
the vendors' hard IPs and on the transceivers, its frontends and its Linux driver. It is written
for FPGA engineers who want to add PCI Express to a design, and it teaches PCI Express along the
way.

No prior knowledge of PCI Express is assumed. Part I explains how PCI Express works, from the
lanes up to the interrupts a host receives, and points at the module that implements each
mechanism. Part II then describes the core and its frontends; Part III describes the PHYs.

Part IV is the user guide: the supported FPGAs and boards, the first build, the integration in a
design, the Linux driver and tools, the examples, the simulation and the debugging. The appendices
hold the register reference, the build options, the glossary, the performance figures and the
maintenance notes of this manual.

| If you want to | Read |
|------------------------------------------|----------------------------------------------|
| Know what the project does and does not | [Introduction](#introduction) |
| Learn how PCI Express works | [PCI Express in a nutshell](#pcie-primer) |
| Check that your FPGA or board is supported | [Supported FPGAs and boards](#boards) |
| Get a device enumerated by a host | [Getting started](#getting-started) |
| Add PCI Express to your own design | [Integration](#integration) |
| Move data between the FPGA and the host | [Scatter-gather DMA](#dma) |
| Understand a link that does not come up | [Debugging](#debugging) |

The manual follows the repository: every name, number and default is taken from the source code,
and the manual is generated from it on the date printed on the title page. When the code and the
manual disagree, the code is right and the manual has a bug.

## Conventions {.unnumbered}

- Numbers: `0x` prefix for hexadecimal, `0b` for binary.
- Rates: link rates in GT/s per lane (2.5 GT/s for Gen1, 5.0 for Gen2, 8.0 for Gen3, 16.0 for
  Gen4). DMA throughputs in Gb/s, as the tools of the project print them. Sizes in bytes, KiB and
  MiB.
- PCI Express names follow the PCI Express Base Specification 4.0, whose sections are cited as
  "PCIe section 4.2.6".
  Packets and fields are written in capitals (TLP, MemRd, CplD); LTSSM states are written with
  their dotted names, such as *Polling.Active*.
- *The core* is the TLP layer, the crossbar, the controller and the frontends; *the PHY* is a
  hard-IP wrapper or the soft PHY; *the project* is LitePCIe as a whole, with the Linux driver and
  the tools.
- *The host* is the computer the FPGA is plugged into, with its root complex and its Linux kernel;
  *the device* is the FPGA design when it is an endpoint; *the root port* is the FPGA design when
  it drives a link to a downstream device; *the link partner* is the port at the other end of the
  link.
- `<target>` stands for the name of a target script of `bench/` without its extension, such as
  `kc705` or `xcu1525`.
- `<config>` stands for a YAML configuration file of the standalone generator `litepcie_gen`, such
  as `examples/acorn.yml`.
- Paths are relative to the repository root. Shell commands are given for a Linux host.
- When the text names a source file, it is the file to open to check or extend the fact.
