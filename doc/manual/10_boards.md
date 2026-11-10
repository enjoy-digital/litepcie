```{=latex}
\part{Use it}
```

```{=html}
<h1 class="part">Part IV. Use it</h1>
```

# Supported FPGAs and boards {#boards}

This chapter lists the FPGA families the project supports and the boards it is built and tested
on. It also explains how a board connects to its host and what the host computer needs. Read it
before choosing hardware or before plugging a first board into a PC.

## At a glance {#boards-glance}

The project runs on the PCIe hard IP of seven FPGA families, and on FPGA transceivers through the
soft PHY. The table below gives the PHY class, the rates and the widths of each family;
[Hard-IP PHYs](#hard-phys) and [Soft PHY](#soft-phy) describe them.

| FPGA family | PHY class | Rates | Widths | Status |
|------------------------|------------------------|--------------|--------------|----------------|
| Artix-7, Kintex-7, Virtex-7 | `S7PCIEPHY` | Gen2 | x1, x2, x4, x8 | Validated |
| Kintex UltraScale | `USPCIEPHY` | Gen2, Gen3 | x1 to x8 | Validated |
| Kintex/Virtex UltraScale+ | `USPPCIEPHY` | Gen2, Gen3, Gen4 | x1 to x16 | Validated |
| Intel Cyclone V | `C5PCIEPHY` | Gen2 | x1, x2, x4 | Validated |
| Intel Stratix V | `SVPCIEPHY` | Gen1, Gen2 | x1, x4, x8 | Validated |
| Gowin GW5A | `GW5APCIEPHY` | Gen2 | x1, x4 | Validated |
| Lattice CertusPro-NX | `LFCPNXPCIEPHY` | Gen3 | x4 | Validated |
| Kintex-7, UltraScale+ | `SoftPCIEPHY` | Gen1, Gen2 | x1 to x8 | In development |

"Validated" means that a design with this PHY runs on hardware against a Linux host. The
UltraScale+ HBM devices use `USPHBMPCIEPHY`, a variant of `USPPCIEPHY`. The soft PHY row is
detailed in [Soft PHY](#soft-phy): its status changes often, and its Artix-7 GTP path has not run
on hardware yet.

## Boards and targets {#boards-targets}

The boards below have a target script in `bench/`. Each target is a LiteX SoC without CPU: a PHY,
the endpoint, a bridge from BAR0 to the register bus, DMA channels and MSI. Its `--driver` option
writes the driver and the tools that match the build.

| Board | FPGA family | PHY | Target |
|----------------------|----------------------|--------------------|------------------------------|
| KC705 | Kintex-7 | Hard IP | `kc705.py` |
| KCU105 | Kintex UltraScale | Hard IP | `kcu105.py` |
| SQRL XCU1525 | Virtex UltraScale+ | Hard IP | `xcu1525.py` |
| SQRL FK33 | Virtex UltraScale+ HBM | Hard IP | `fk33.py` |
| Acorn CLE-215+ | Artix-7 | Hard IP, soft PHY | `acorn.py`, `soft/acorn.py` |
| YPCB-00338-1P1 | Kintex-7 | Hard IP, soft PHY | `soft/ypcb.py` |
| Alibaba XCKU3P | Kintex UltraScale+ | Soft PHY | `soft/ku3p.py` |

[Example designs and targets](#ex-glance) gives the link, the bridge and the design of each
target, and [Build options](#build-options) their options. `bench/acorn.py` is the odd one: it
instantiates a standalone Verilog core made by the generator, not the Python classes.

## How a board connects to the host {#boards-connection}

The figure below shows the signals a PCIe slot brings to the FPGA. The host root port drives one
differential pair per lane towards the device and receives another one. The slot also provides a
100 MHz reference clock and PERST#, which holds the device in reset until the host power and clock
are stable.

![A board in a PCIe slot. The cyan path is the link: one transmit and one receive pair per lane,
from the root port to the hard IP or the soft PHY. The reference clock and PERST# come from the
slot.](boards_host.svg)

The reference clock of the slot feeds the transceivers through a dedicated clock input of the
FPGA. The 7-Series PHY also accepts 125 MHz and 250 MHz reference clocks (`refclk_freq`) for
boards with their own oscillator. PERST# arrives on the `rst_n` pad of the PHY.

## KC705 {#boards-kc705}

The KC705 is the Kintex-7 evaluation board of AMD, with an x8 PCIe edge connector. It is the
board of [Getting started](#getting-started), and its target is the explicit integration example
of [Integration](#integ-explicit).

| Item | Value |
|-----------------|--------------------------------------------------------------|
| PHY | `S7PCIEPHY`, Gen2, BAR0 of 128 KiB |
| Link | x4 by default; x1 or x8 with `--nlanes` |
| System clock | From the 200 MHz oscillator of the board, through an MMCM |
| Bridge | UARTBone, on the USB-UART of the board |
| Device ID | `10ee:7024` at x4 (`10ee:7021` at x1, `10ee:7028` at x8) |

## Acorn CLE-215+ {#boards-acorn}

The SQRL Acorn CLE-215+ is an Artix-7 board on an M.2 form factor with a PCIe x4 interface. On
the LiteX Acorn Baseboard Mini, shown below, one of its lanes reaches the x1 edge connector of the
baseboard, so the board plugs into any PCIe slot of a PC.

![The SQRL Acorn CLE-215+ on the LiteX Acorn Baseboard Mini, with its PCIe x1 edge
connector.](acorn_baseboard_mini.jpg){width=65%}

| Item | Value |
|---------------------|----------------------------------------------------------------|
| PHY | `S7PCIEPHY` (Gen2), or `SoftPCIEPHY` on the GTP transceiver |
| Lane | Lane 3 of the x4 pins on the Baseboard Mini (`--lane`) |
| Soft PHY target | `bench/soft/acorn.py`; `--hard-ip` for the same SoC on the hard IP |
| Standalone example | `bench/acorn.py` with `examples/acorn.yml` (x4, 128-bit) |
| Variants | `--variant cle-101`, `cle-215` or `cle-215+` (default) |

`bench/soft/acorn.py` builds the soft physical layer alone by default; `--with-endpoint` builds
the full endpoint, and `--hard-ip` the same endpoint on the hard IP, a Gen2 x1 link. The design
drives the M.2 CLKREQ# signal low to request the reference clock from the host.

## YPCB-00338-1P1 {#boards-ypcb}

The YPCB-00338-1P1 is a Kintex-7 card with an x8 PCIe edge connector and GTX transceivers. It is
the main board of the soft PHY bring-up: `bench/soft/ypcb.py` builds the soft PHY at x1, x2, x4
or x8 (`--nlanes`) and up to Gen3 (`--speed`). The photo in [Prerequisites](#gs-install) shows
it in a PC slot.

The soft PHY runs Gen2 x8 with a host on this board; at 8.0 GT/s it trains no link with a host,
as [Hardware findings](#debug-soft-findings) explains. `--hard-ip` builds the same endpoint on the
hard IP, at Gen2 x1, x4 or x8. The results, soft against hard, are in [Performance and
resources](#performance).

## Alibaba XCKU3P {#boards-xcku3p}

The Alibaba Cloud XCKU3P card is a low cost Kintex UltraScale+ card with an x8 PCIe edge
connector and two SFP cages. It runs the hard IP at Gen3 x8 with the LiteX-Boards target of the
next section, and the soft PHY on its GTY transceivers at Gen1 and Gen2 x1 (`bench/soft/ku3p.py`).

![The Alibaba Cloud XCKU3P card, a Kintex UltraScale+ card with a PCIe x8
edge.](alibaba_xcku3p.jpg){width=70%}

The board has no UART: its targets reach the register bus through JTAGBone. The same board serves
as a root port in [Root port designs](#integ-rootport).

## Other boards {#boards-other}

Many targets of LiteX-Boards build a LiteX SoC with LitePCIe through their `--with-pcie` option,
among them the KC705, KCU105, XCU1525, FK33, Acorn, Acorn Baseboard Mini, YPCB-00338-1P1 and
XCKU3P targets. They call `add_pcie`, described in [Integration in a LiteX SoC](#integ-litex).

```sh
python3 -m litex_boards.targets.<board> --with-pcie --driver --build
```

Any other board with a PCIe edge connector and a supported FPGA needs only a target of this kind,
written as [Porting to a new board](#integ-porting) explains. The SPEC-A7 below, an Artix-7 card
with a PCIe edge connector, an SFP cage and SMA connectors, is such a board.

![The SPEC-A7, an Artix-7 card with a PCIe edge connector.](spec_a7.jpg){width=60%}

LitePCIe is also the PCIe interface of complete products. The LiteX-M2SDR, an M.2 software
defined radio board on an Artix-7 XC7A200T, uses it on a Gen2 x4 link.

![The LiteX-M2SDR, an M.2 board built on LitePCIe.](m2sdr_board.png){width=75%}

## Host requirements {#boards-host}

The host is a computer with a PCIe slot and a Linux kernel. The list below gives what it needs for
the driver and the tools of [Linux driver and tools](#software).

- **Slot**: a slot at least as wide as the edge connector of the board; an M.2 board needs an M.2
  slot wired for PCIe, or an adapter.
- **Configured FPGA at enumeration**: the host enumerates the bus at boot. A bitstream loaded
  over JTAG after the boot needs a warm reboot or a rescan of the bus, as [Getting
  started](#gs-enumeration) shows.
- **Kernel headers and compiler**: the driver builds against the running kernel
  (`/lib/modules/<version>/build`), with `make` and `gcc`.
- **Secure Boot**: an unsigned module cannot load with Secure Boot enabled, which `init.sh`
  reports. Disable Secure Boot in the BIOS or sign the module.
- **Root access**: loading the module and rescanning the bus need root rights; `init.sh` then
  opens the device files to all users.
- **JTAG access**: `--load` writes the bitstream into a board in a slot through its JTAG port,
  from the host itself or from another computer.

Some hosts hang when a device answers badly during the boot enumeration. The soft PHY debug
designs keep their LTSSM disabled at reset and by PERST# for that reason, as [Soft PHY
targets](#ex-soft) explains.

Where to go next: [Getting started](#getting-started) to build and load a first design,
[Integration](#integration) to add LitePCIe to your own SoC.
