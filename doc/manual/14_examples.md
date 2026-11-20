# Example designs and targets {#examples}

This chapter describes the example designs shipped with the project: the bench targets of the
hard-IP PHYs, the standalone core configurations of the generator, the soft PHY targets and the host
scripts that go with them. Use them to check a board, to compare two PHYs on the same board, or as a
starting point for a design.

## At a glance {#ex-glance}

Each target of `bench/` builds a complete SoC around the core. Run without `--build`, a target only
elaborates the design: it writes the Verilog sources and the `csr.csv` without calling the FPGA
toolchain, which is how the tests check them.

| Target | Board | PHY | Link | Bridge |
|-----------------------------|-----------------------|---------------------------|---------------|---------------|
| `kc705` | KC705 | `S7PCIEPHY` | Gen2 x1, x4, x8 | UARTBone |
| `kcu105` | KCU105 | `USPCIEPHY` | Gen3 x4, x8 | UARTBone |
| `xcu1525` | SQRL XCU1525 | `USPPCIEPHY` | Gen3 x4, x8, x16 | UARTBone |
| `fk33` | SQRL FK33 | `USPHBMPCIEPHY` | Gen3 x4, x8, x16 | JTAGBone |
| `acorn` | Acorn CLE-215+ | generated core | Gen2 x4 | none |
| `soft/acorn` | Acorn CLE-215+ | soft PHY, GTP | Gen1 x1 | UART or JTAG |
| `soft/ypcb` | YPCB-00338-1P1 | soft PHY, GTX | Gen1 to Gen3, x1 to x8 | JTAGBone |
| `soft/ku3p` | Alibaba XCKU3P | soft PHY, GTY | Gen1, Gen2 x1; Gen3 x1, x4, x8 | JTAGBone |
| `soft/versa` | Lattice ECP5 Versa | soft PHY, ECP5 DCU | Gen1 x1 | UARTBone |
| `soft/ypcb_gen3` | YPCB-00338-1P1 | GTX lane test | 8.0 GT/s loopback | JTAGBone |

The bridge column gives the second access path to the registers, besides BAR0: it still answers
when the link is down. The boards are described in [Supported FPGAs and boards](#boards), and
[Build options](#build-options) lists every option of every target.

## Hard-IP bench targets {#ex-hard}

The four hard-IP targets share one design. A PLL makes the system clock and the PHY wraps the hard
IP of the FPGA, with its LTSSM tracer. A Wishbone bridge gives the host access to the SoC registers
through BAR0, and two DMA channels carry the streams.

| Block | Setting |
|-------------------------|------------------------------------------------------------------------------------|
| BAR0 | 128 KiB (`0x20000`) |
| Endpoint | 8 pending requests; big-endian on 7-Series, little-endian on UltraScale(+) |
| DMA | Two channels, 1024-byte buffering, loopback |
| Interrupts | Single-vector MSI, one interrupt input per DMA Writer and Reader |
| Debug | LTSSM tracer (`add_ltssm_tracer`) |

The system clock and the width of the core follow the number of lanes, as [Choosing the PHY, lanes
and widths](#integ-choices) lists. The default is x4 on every target. The commands below elaborate
the KC705 design at x8, then build it, generate its driver and load it. `--load` programs the FPGA
in volatile memory; it does not write the configuration flash.

```sh
# Elaborate only (Verilog, csr.csv)
python3 bench/kc705.py --nlanes 8
# Build the bitstream, generate the driver, load the FPGA
python3 bench/kc705.py --nlanes 8 --build --driver --load
```

The driver lands in `build/kc705/driver/`, with the generated `csr.h` of the design next to the
kernel module sources. [Getting started](#getting-started) goes on from there: building the
driver, loading it and running `litepcie_util`.

## Standalone core in a SoC {#ex-acorn}

The `acorn` target shows the other way to use the project: a Verilog core made by the generator,
instantiated in a SoC like any third-party IP. It runs the generator on `examples/acorn.yml`, adds
the generated `litepcie_core.v` and the 7-Series hard IP to the sources, and ties the interfaces of
the core to constants.

```sh
cd bench
python3 acorn.py --build --load
```

The target reads `../examples/acorn.yml` and writes the core in `build/gateware/`, so it runs from
the `bench/` directory. Its DMA streams and memory-mapped interfaces are left unconnected: it is a
template for the port list of a generated core, not a test design.

## Generator configurations {#ex-gen}

The generator `litepcie_gen` builds a standalone Verilog core from a YAML file.
[Integration](#integration) explains its flow and its ports; the files of `examples/` are ready-made
configurations.

| File | PHY | Link | DMA | Other features |
|------------------------------|-------------------------|----------|----------------|--------------------------|
| `ac701.yml` | `S7PCIEPHY` | x4, 128 bits | 4 channels | Synchronizer, monitor, AXI slave |
| `acorn.yml` | `S7PCIEPHY` | x4, 128 bits | 4 channels | External clock, AXI slave |
| `acorn_soft.yml` | `SoftPCIEPHY` | x1, 64 bits | 1 channel | External clock, monitor |
| `kcu105.yml` | `USPCIEPHY` | x4, 128 bits | 2 channels | 64-bit addresses, AXI-Lite slave |

All four have an AXI-Lite memory-mapped master at `0x20000` and 16 user interrupts. `kcu105.yml`
also shows the per-channel form of `dma_channels`, a dictionary with the settings of each channel.

```sh
litepcie_gen examples/ac701.yml --output-dir build/ac701
```

The command writes `build/ac701/gateware/litepcie_core.v`, and `csr.h`, `soc.h` and `mem.h` in the
header directory (`--header-dir`, the current directory by default). The driver and the tools are
built with these headers. [Generator configuration](#opt-gen) lists every key of the YAML file with
its default.

## Soft PHY targets {#ex-soft}

The soft PHY targets bring up the soft PHY, on boards that also have a hard IP and on the Versa, which has none. They are bring-up
designs: the soft PHY is in development, and [Soft PHY](#soft-phy) gives its status. Each target
builds one of three designs; the Versa target builds the full endpoint only.

| Design | Option | Content |
|-----------------------|------------------------------------|--------------------------------------------------|
| Physical layer alone | none | Lane and LTSSM, received packets dropped |
| Full endpoint | `--with-endpoint` | `SoftPCIEPHY` with `add_pcie`: MMAP, one DMA, MSI |
| Hard IP | `--hard-ip` | The same endpoint on `S7PCIEPHY`, for comparison |

The physical layer alone trains the link to L0 against the root port. The host then shows the link
up with the data link layer inactive, which proves the training without the upper layers. The full
endpoint enumerates like a hard-IP design and works with the same driver.

The YPCB-00338-1P1, Alibaba XCKU3P and Lattice ECP5 Versa targets always build the soft PHY debug registers and the
LTSSM tracer. The Acorn target adds them to the full endpoint only with `--with-debug` and
`--with-ltssm-tracer`.

Wherever the debug registers are built, the LTSSM stays disabled at reset and while PERST# is
asserted. A design that makes the host hang then cannot do it again at the next boot;
`--ltssm-autostart` enables the LTSSM at reset, for enumeration at boot.

```sh
# Full endpoint, x4 at 5.0 GT/s, with the driver
python3 bench/soft/ypcb.py --with-endpoint --speed gen2 --nlanes 4 --driver --build
# Same design on the hard IP
python3 bench/soft/ypcb.py --hard-ip --nlanes 4 --driver --build
```

The `soft/ypcb_gen3` target is a lane test without a host. It runs four GTX lanes at 8.0 GT/s in
near-end loopback and checks the 128b/130b block alignment and the scrambler. [Soft PHY
debug](#debug-soft) describes the bring-up steps of these targets.

## Host scripts {#ex-scripts}

Three scripts work on these designs from the host. The first two talk to a `litex_server` started
on the bridge of the target and find the registers by name in the `csr.csv` of the build.

| Script | Purpose |
|---------------------------------------------------------------|----------------------------------------------|
| `bench/test_ltssm_tracer.py` | Prints the LTSSM history of a PHY, decoded |
| `bench/soft/status.py` | Soft PHY control and status: enable, retrain, counters, traces |
| `litepcie/software/rescan.py` | Removes the device, rescans the PCIe bus and reloads the driver |

```sh
litex_server --uart --uart-port /dev/ttyUSBX &
python3 bench/test_ltssm_tracer.py --csr-csv csr.csv --family 7series
```

The rescan helper runs on the host and calls `sudo` for the writes to sysfs; [Tools](#sw-tools)
gives its options. [Debugging](#debugging) uses all three scripts.

## LiteX-Boards targets {#ex-litex-boards}

Most boards with a PCIe connector have a LiteX-Boards target, outside this repository. Their
`--with-pcie` option adds the PHY, the endpoint, the DMA and MSI through the `add_pcie` method of
the LiteX SoC. With `--build --no-compile` they write the sources and stop before the FPGA
toolchain, a quick check of a change of the core against many boards.

```sh
python3 -m litex_boards.targets.<board> --with-pcie --build --no-compile
```

Where to go next: [Getting started](#getting-started) for the first build and the driver,
[Integration](#integration) for a design of your own, and [Build options](#build-options) for every
option.
