# Vocabulary of the LitePCIe manual

Project-specific writing rules, completing the generic `STYLE.md` of the manual kit.

## Names of the parts

- *the core* is the TLP layer, crossbar, controller and frontends (`litepcie/core`, `litepcie/tlp`,
  `litepcie/frontend`); *the PHY* is a hard-IP wrapper or the soft PHY; *the project* is LitePCIe as
  a whole, including the Linux driver and tools.
- *hard IP* is the PCIe block of the FPGA vendor; *soft PHY* is the PHY of LitePCIe built on the
  transceivers (`litepcie/phy/soft`).
- *the host* is the computer (root complex and its Linux kernel) the FPGA is plugged into; *the
  device* is the FPGA design when it is an endpoint; *the root port* is the FPGA design when it
  drives a link to a downstream device; *link partner* is the port at the other end of the link.
- *the driver* is the Linux kernel module `litepcie.ko`; *the library* is `liblitepcie`; *the tools*
  are `litepcie_util` and `litepcie_test`.
- *target* is a script of `bench/`; *the generator* is `litepcie_gen` (standalone Verilog core).

## Protocol names

- Generations as *Gen1* to *Gen4* (no space, as the PCIe specification and LitePCIe write them),
  rates in GT/s per lane (2.5, 5.0, 8.0, 16.0 GT/s), link widths as x1, x2, x4, x8, x16.
- Layers: *physical layer*, *data link layer*, *transaction layer* in lower case in prose.
- Packets and fields in capitals: TLP, DLLP, MemRd, MemWr, CplD, Cpl, UpdateFC, ACK, NAK, MSI,
  MSI-X, PTM, BAR, MPS, MRRS, RCB, BDF.
- LTSSM states dotted and capitalised without code font: *Detect.Quiet*, *Polling.Active*,
  *Configuration.Idle*, *Recovery.RcvrLock*, *L0*.
- Cite the specification as "PCI Express Base Specification section 4.2.6" (first use), then
  "PCIe section 4.2.6".

## Placeholders

- `<target>` is a target script name of `bench/` without `.py` (`kc705`, `acorn`); `<config>` is a
  generator YAML file. Both are defined once in the Conventions of the front matter.

## Hardware names

- Boards: KC705, KCU105, SQRL XCU1525, SQRL FK33, Acorn CLE-215+ (on the LiteX Acorn Baseboard),
  YPCB-00338-1P1, Alibaba XCKU3P, LiteX-M2SDR, SPEC-A7.
- FPGA families: Artix-7, Kintex-7, Virtex-7, Kintex UltraScale, Kintex/Virtex UltraScale+,
  Intel Cyclone V, Intel Stratix V, Gowin GW5A, Lattice CertusPro-NX.
