# Integration {#integration}

This chapter explains how to add LitePCIe to your own design. It starts with a LiteX SoC, the
native way, then covers the choices of PHY, lanes and widths, the clocks and constraints, the DMA
stream interface and the interrupt map. It ends with root port designs, the standalone Verilog
core for designs built without LiteX, and a checklist to port a design to a new board.

## At a glance {#integ-glance}

| Item | Value |
|---------------------------|------------------------------------------------------------------|
| Language | Python (Migen, LiteX); Verilog through `litepcie_gen` |
| PHY classes | `S7PCIEPHY`, `USPCIEPHY`, `USPPCIEPHY`, `C5PCIEPHY`, `SVPCIEPHY`, `GW5APCIEPHY`, `LFCPNXPCIEPHY`, `SoftPCIEPHY` |
| Core classes | `LitePCIeEndpoint`, `LitePCIeRootPort` |
| Frontends | `LitePCIeDMA`, `LitePCIeWishboneBridge`, `LitePCIeAXISlave`, MSI and MSI-X |
| LiteX helper | `add_pcie` of the LiteX SoC class |
| User interface | DMA streams, 64 to 512-bit words; memory-mapped buses |
| Reference designs | `bench/kc705.py` and the other targets of `bench/` |

## Integration in a LiteX SoC {#integ-litex}

A design is a chain of parts, shown in the figure below. The PHY drives the link and exchanges
TLPs with the endpoint. The endpoint builds and parses the TLPs and routes them through its
crossbar to the frontends: a Wishbone bridge from BAR0 to the register bus, the DMA channels, and
the MSI controller that signals their interrupts to the host.

![LitePCIe in a LiteX SoC. The cyan arrow is the link to the host; user logic only sees the
streams of the DMA channels. Host accesses to BAR0 reach the register bus through the Wishbone
bridge.](integ_soc.svg)

The `add_pcie` method of the LiteX SoC class builds this chain from a PHY. The example below is a
complete Gen2 x1 endpoint on a 7-Series device, with one DMA channel looped back in user logic.
The pad name `pcie_x1` and the clock generator stand for those of your platform.

```python
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder  import Builder

from litepcie.phy.s7pciephy import S7PCIEPHY
from litepcie.software      import generate_litepcie_software

class PCIeSoC(SoCMini):
    def __init__(self, platform, sys_clk_freq=125e6):
        SoCMini.__init__(self, platform, sys_clk_freq, ident="My PCIe design")
        self.crg = _CRG(platform, sys_clk_freq) # Your clock generator, provides cd_sys.

        # PHY: hard IP, Gen2 x1, 64-bit datapath, 128 KiB BAR0.
        self.pcie_phy = S7PCIEPHY(platform, platform.request("pcie_x1"),
            data_width = 64,
            bar0_size  = 0x20000)

        # Endpoint, BAR0 bridge, MSI and one DMA channel.
        self.add_pcie(phy=self.pcie_phy, ndmas=1)

        # User logic: host to FPGA stream looped back to the FPGA to host stream.
        self.comb += self.pcie_dma0.source.connect(self.pcie_dma0.sink)
```

Then build the SoC and write the driver and tools for it, as the targets do with `--driver`:

```python
builder = Builder(soc, output_dir="build/pcie_soc", csr_csv="build/pcie_soc/csr.csv")
builder.build(run=True)
generate_litepcie_software(soc, "build/pcie_soc/driver")
```

`add_pcie` needs a register bus of 32-bit words and a CSR region in the memory map, which every
LiteX SoC has by default. It names the parts `pcie_endpoint`, `pcie_mmap`, `pcie_msi` and
`pcie_dma0` to `pcie_dmaN`; the driver expects these names. Its main parameters are below.

| Parameter | Default | Use |
|----------------------------------|----------|------------------------------------------------|
| `phy` | required | The PHY instance |
| `ndmas` | 0 | Number of DMA channels |
| `address_width` | 32 | 32 or 64-bit addresses for the DMA and the host memory |
| `data_width` | PHY width | Width of the DMA streams |
| `max_pending_requests` | 8 | Read requests in flight on the link |
| `with_dma_buffering` | `True` | FIFOs on the DMA streams, `dma_buffering_depth` 1024 |
| `with_dma_loopback` | `True` | Loopback of each DMA channel, enabled by software |
| `with_dma_synchronizer` | `False` | Start the DMA streams on a PPS signal |
| `with_dma_monitor` | `False` | Overflow and underflow counters on the DMA streams |
| `with_dma_status` | `False` | Status block written to the host memory |
| `msi_type` | `"msi"` | `"msi"`, `"msi-multi-vector"` or `"msi-x"` |
| `msi_width` | 32 | Number of interrupt inputs |
| `msis` | none | Interrupts of user logic, by name |
| `with_ptm` | `False` | PTM support in the endpoint, see [PTM](#ptm) |

`add_pcie` lives in LiteX (`litex/soc/integration/soc.py`); the DMA options are those of
`LitePCIeDMA`, described in [Scatter-gather DMA](#dma). It also adds a false path between the
system clock and the clock of the PHY.

### The explicit chain {#integ-explicit}

The targets of `bench/` build the same chain without `add_pcie`, one class at a time. This form
gives full control over each part: two DMA channels with different options, another bridge, or
the endpoint shared with other frontends. The excerpt below is the PCIe part of `bench/kc705.py`.

```python
from litepcie.phy.s7pciephy     import S7PCIEPHY
from litepcie.core              import LitePCIeEndpoint, LitePCIeMSI
from litepcie.frontend.dma      import LitePCIeDMA
from litepcie.frontend.wishbone import LitePCIeWishboneBridge

# PHY, with the LTSSM history registers.
self.pcie_phy = S7PCIEPHY(platform, platform.request(f"pcie_x{nlanes}"),
    data_width = data_width,
    bar0_size  = 0x20000)
self.pcie_phy.add_ltssm_tracer()

# Endpoint: TLP layer, crossbar, completion reordering.
self.pcie_endpoint = LitePCIeEndpoint(self.pcie_phy,
    endianness           = "big",
    max_pending_requests = 8)

# BAR0 to the register bus.
self.pcie_bridge = LitePCIeWishboneBridge(self.pcie_endpoint,
    base_address = self.mem_map["csr"])
self.bus.add_master(master=self.pcie_bridge.wishbone)

# DMA channel 0 (channel 1 is identical).
self.pcie_dma0 = LitePCIeDMA(self.pcie_phy, self.pcie_endpoint,
    with_buffering = True, buffering_depth=1024,
    with_loopback  = True)
self.add_constant("DMA_CHANNELS", 2)
self.add_constant("DMA_ADDR_WIDTH", 32)

# MSI: one interrupt input per DMA Writer and Reader.
self.pcie_msi = LitePCIeMSI()
self.comb += self.pcie_msi.source.connect(self.pcie_phy.msi)
self.interrupts = {
    "PCIE_DMA0_WRITER": self.pcie_dma0.writer.irq,
    "PCIE_DMA0_READER": self.pcie_dma0.reader.irq,
    "PCIE_DMA1_WRITER": self.pcie_dma1.writer.irq,
    "PCIE_DMA1_READER": self.pcie_dma1.reader.irq,
}
for i, (k, v) in enumerate(sorted(self.interrupts.items())):
    self.comb += self.pcie_msi.irqs[i].eq(v)
    self.add_constant(k + "_INTERRUPT", i)
```

The constants are part of the contract with the driver: `DMA_CHANNELS` sets the number of device
files, `DMA_ADDR_WIDTH` the DMA mask, and each `_INTERRUPT` constant the interrupt number of a
DMA Writer or Reader. The endianness of the endpoint must be the one of the PHY; `add_pcie` takes it
from the `endianness` attribute of the PHY class.

The explicit chain does not add the false path between the system clock and the clock of the PHY;
add it as `bench/xcu1525.py` does, see [Clocks and constraints](#integ-clocks).

## Choosing the PHY, lanes and widths {#integ-choices}

The PHY follows the FPGA family, as [Supported FPGAs and boards](#boards) lists. The number of
lanes follows the board: the PHY takes it from the width of the `tx_p` pads it receives. The data
width of the core is a choice, set by `data_width`, together with the system clock.

The bench targets use the pairs below. The data width times the system clock bounds the rate at
which the core moves data, so wider links get wider datapaths and a faster clock.

| Rate and width | Data width | System clock | Targets |
|---------------------|--------------|----------------|----------------------------------|
| Gen2 x1 | 64 bits | 125 MHz | `kc705.py --nlanes 1` |
| Gen2 x4, x8 | 128 bits | 200 MHz | `kc705.py` |
| Gen3 x4 | 128 bits | 200 MHz | `kcu105.py`, `xcu1525.py`, `fk33.py` |
| Gen3 x8 | 256 bits | 200 MHz | `kcu105.py`, `xcu1525.py`, `fk33.py` |
| Gen3 x16 | 512 bits | 200 MHz | `xcu1525.py`, `fk33.py` |

The hard IP has its own user clock and datapath width, set by `pcie_data_width` (the data width by
default). The PHY converts between the two widths and crosses between the two clocks. On 7-Series,
the user clock of the hard IP follows the lanes and its datapath width:

| Lanes | Hard IP width | User clock |
|----------|----------------|--------------|
| x1, x2 | 64 or 128 bits | 125 MHz |
| x4 | 64 bits | 250 MHz |
| x4 | 128 bits | 125 MHz |
| x8 | 128 bits | 250 MHz |

On UltraScale and UltraScale+, the user clock of the hard IP is 125 MHz at Gen2 and 250 MHz at Gen3
and Gen4. The widths each PHY accepts, and the options of each hard IP, are in [Hard-IP
PHYs](#hard-phys); the soft PHY works on 32 bits per lane, see [Soft PHY](#soft-phy).

### Interrupt types {#integ-msi}

The MSI controller comes in three types. A single-vector MSI signals every interrupt on one
vector, and the driver reads a register to find the source. A multi-vector MSI and MSI-X give each
interrupt its own vector. The driver uses MSI-X when the SoC has an MSI-X controller, and MSI
otherwise.

| Type | Class | Notes |
|--------------------------|------------------------------------|--------------------------------|
| `msi` | `LitePCIeMSI` | Default; vector, enable and clear registers |
| `msi-multi-vector` | `LitePCIeMSIMultiVector` | One MSI vector per interrupt |
| `msi-x` | `LitePCIeMSIX` | MSI-X table and PBA in BAR0, sent as MemWr TLPs |

On 7-Series, the hard IP advertises the MSI-X capability only with `msi_type="msi-x"` on the PHY
as well. The 7-Series and CertusPro-NX hard IPs announce the MSI-X table at offset `0x2000` of
BAR0 and the PBA at `0x1808`. The generator reserves the register locations that put them there;
`add_pcie` does not, so a LiteX SoC with MSI-X reserves them in its `csr_map`:

```python
class PCIeSoC(SoCMini):
    # MSI-X registers at 0x1800 (PBA at 0x1808), MSI-X table at 0x2000.
    csr_map = {"pcie_msi": 3, "pcie_msi_table": 4}
```

With the default register paging of `0x800` bytes, locations 3 and 4 start at `0x1800` and
`0x2000`. Check the result in `csr.csv`: `pcie_msi_pba` at `0x1808` and `pcie_msi_table` at
`0x2000`.
Without the reservation, the registers land where the allocation puts them and the host writes
the MSI-X table at the wrong place.

The CertusPro-NX hard IP has no MSI request interface: use MSI-X there, since `add_pcie` with the
default type gets no interrupt. On GW5A, two MSIs requested back to back may stall, because the
request is pulsed on the rising edge of its valid signal. [Memory-mapped bridges and
interrupts](#mmap-irq) describes the controllers.

## Clocks and constraints {#integ-clocks}

The design has three kinds of clocks. The table lists them, the false path between the two
asynchronous ones, and who declares each constraint.

| Clock | Frequency | Constraint |
|---------------------|-------------------------------|------------------------------------------------|
| `sys` | 125 MHz to 200 MHz in the targets | Your clock generator, as for any LiteX clock |
| `pcie` | User clock of the hard IP | The PHY |
| Reference clock | 100 MHz from the slot | The PHY, on the `clk_p` pad |
| `sys` to `pcie` | Asynchronous | A false path: `add_pcie`, or your design |

The core runs in the clock domain given by the `cd` parameter of the PHY, `sys` by default. The
PHY creates the `pcie` clock domain from the user clock of the hard IP and moves the TLPs between
the two domains through asynchronous FIFOs. The explicit chain declares the false path itself:

```python
platform.add_false_path_constraints(self.crg.cd_sys.clk, self.pcie_phy.cd_pcie.clk)
```

The PHY also takes PERST# from the `rst_n` pad and holds the hard IP in reset while it is low.
Some 7-Series boards need the transceiver placement fixed: `add_gt_loc_constraints` gives the
location of each lane. The soft PHY declares its transceiver clocks with `add_timing_constraints`.

## DMA stream interface {#integ-streams}

User logic exchanges data with the host through the two streams of each DMA channel. The Writer
stores the stream of the FPGA in the host memory; the Reader streams the host memory to the FPGA.
Both are LiteX streams with `data`, `valid`, `ready`, `first` and `last`.

| Stream | Direction | Rules |
|--------------------------|--------------|----------------------------------------------------|
| `pcie_dmaN.sink` | FPGA to host | Accepted while the Writer runs; `last` ends a descriptor early unless the descriptor disables it |
| `pcie_dmaN.source` | Host to FPGA | Valid while the Reader runs; `first` and `last` follow the descriptors |

The width of `data` is the `data_width` of the DMA, the width of the PHY by default. A DMA width
different from the width of the core adds converters between them.

The driver programs its descriptors with `last` disabled: each channel is a continuous stream of
8 KiB buffers, and the `last` signal of the sink has no effect. A design with its own software
can use `last` to end a buffer early. [Scatter-gather DMA](#dma) describes the descriptors and
the plug-ins.

Back-pressure is allowed on both streams. Send data only while `writer.enable` is set: the
standalone core gates `tready` with it. With buffering, FIFOs of `buffering_depth` bytes sit
between the streams and the DMA engines, and they are reset while their channel is disabled.

### Interrupt map {#integ-irq-map}

Each DMA Writer and Reader raises an interrupt when it completes a descriptor that asks for one.
The interrupt inputs of the MSI controller are numbered in the alphabetical order of their names,
and the SoC exports each number as a constant. With a multi-vector MSI or MSI-X, the input number
is also the vector number. The table gives the map of `bench/kc705.py`.

| Input | Constant | Source |
|----------|-------------------------------|---------------------|
| 0 | `PCIE_DMA0_READER_INTERRUPT` | DMA 0 Reader |
| 1 | `PCIE_DMA0_WRITER_INTERRUPT` | DMA 0 Writer |
| 2 | `PCIE_DMA1_READER_INTERRUPT` | DMA 1 Reader |
| 3 | `PCIE_DMA1_WRITER_INTERRUPT` | DMA 1 Writer |

`add_pcie` builds the same map and adds the interrupts of `msis` to it, sorted by name with the
DMA ones: choose the names of user interrupts knowing that they shift the numbers. The driver
handles up to 8 DMA channels and 32 vectors. The standalone core places the DMA interrupts first,
and the `msi_irqs` inputs of user logic from input 16 with MSI, or 32 with MSI-X.

## Root port designs {#integ-rootport}

The 7-Series, UltraScale and UltraScale+ PHYs also run their hard IP as a root port: the FPGA then
drives the link to a downstream device, such as an NVMe SSD. The photo below shows such a setup,
an Alibaba XCKU3P card with an M.2 adapter and an NVMe SSD.

![An Alibaba XCKU3P card as a root port, driving an NVMe SSD on an M.2 adapter.](xcku3p_nvme_setup.jpg){width=75%}

A root port design changes three things against an endpoint. The table lists them; [Core
architecture](#core-architecture) describes the root port in the core.

| Item | Setting | Effect |
|--------------------|----------------------------------------|----------------------------------------|
| PHY | `mode="RootPort"` | Hard IP configured as a root port |
| Core | `LitePCIeRootPort` | Endpoint without the BAR0 address mask |
| Configuration | `with_configuration=True` | CfgRd0 and CfgWr0 requests to enumerate the device |
| Local configuration | `with_cfg_mgmt=True` | Access to the configuration space of the root port |

`LitePCIeRootPort` is in `litepcie/core/rootport.py`. With `with_configuration`, the requests of a
crossbar master port carry a configuration flag, and the bus, device, function and register
numbers of the target. User logic enumerates the device with them, then reads and writes its
memory through MemRd and MemWr requests.

The maximum payload size of the link stays at its reset value of 128 bytes until both ends are
programmed; `with_cfg_mgmt` (7-Series and UltraScale+) lets the design program the root port side.
The root port and the 256 and 512-bit datapaths are less used than the endpoint on 64 and 128
bits: test them explicitly. LiteNVMe, an NVMe host core, is built on this mode.

## Standalone Verilog core {#integ-standalone}

Designs built without LiteX use `litepcie_gen`, installed with the package. It reads a YAML
configuration and generates a Verilog core with the PHY wrapper, the endpoint, the DMA channels,
the MSI controller and AXI interfaces. The figure below shows the ports of the generated module.

![The standalone core. The PCIe pins, the clock and the interrupt inputs are on the left; the
AXI-Lite or AXI memory-mapped ports and the AXI-Stream DMA ports are on the right.](integ_standalone.svg)

```sh
litepcie_gen examples/acorn.yml --output-dir build/acorn --header-dir build/acorn
```

The generator writes `gateware/litepcie_core.v` in the output directory, and the `csr.h`, `soc.h`
and `mem.h` headers of the driver in the header directory, the current directory by default.
`--doc` also builds the register documentation of the core with Sphinx.

The generated Verilog instantiates the hard IP of the vendor but does not contain it. Generate the
IP in your project with matching settings: `bench/acorn.py` does it for the 7-Series hard IP with
a Tcl `create_ip` command, and adds the false paths between the clocks of the core and of the IP.

The repository has four configurations in `examples/`, described in [Generator
configurations](#ex-gen). The main keys of the YAML file choose the PHY (`phy`, `phy_device`,
`phy_lanes`, `phy_data_width`, `phy_bar0_size`), the user clock (`clk_freq`, `clk_external`), the
optional AXI ports (`ctrl`, `mmap`, `mmap_slave`), the DMA channels (`dma_channels` and the `dma_*`
keys) and the interrupts (`msi_irqs`, `msi_x`). [Configuration keys](#opt-gen-keys) lists every
key with its default.

The ports of the module depend on the configuration:

- **Always**: `clk` and `rst`; the `pcie` pins (`pcie_rst_n`, `pcie_clk_p/n`, `pcie_rx_p/n`,
  `pcie_tx_p/n`); `msi_irqs`, the interrupt inputs of user logic.
- **Per DMA channel**: `dmaN_writer_axi_*` and `dmaN_reader_axi_*`, AXI-Stream with `tvalid`,
  `tready`, `tlast`, `tdata` and `tuser` carrying the first flag; `dmaN_status_writer_enable` and
  `dmaN_status_reader_enable`.
- **Optional**: `ctrl_axi_lite_*`, `mmap_axi_lite_*`, `mmap_slave_axi_lite_*` or
  `mmap_slave_axi_*`, and the `ptm_*` time inputs.

**Clocking.** With `clk_external: False`, the core outputs the clock and reset of the hard IP on
`clk` and `rst`, and user logic runs on them. With `clk_external: True`, user logic provides `clk`
at `clk_freq`, and the core crosses between it and the hard IP. The Stratix V PHY requires
`clk_external: True` with a free-running clock of 100 MHz to 125 MHz.

A Verilog instantiation looks like the following, trimmed from `bench/acorn.py` to the PCIe pins
and the first DMA channel:

```verilog
litepcie_core pcie (
    .clk                    (clk),
    .rst                    (rst),
    .pcie_rst_n             (pcie_rst_n),
    .pcie_clk_p             (pcie_clk_p),
    .pcie_clk_n             (pcie_clk_n),
    .pcie_rx_p              (pcie_rx_p),
    .pcie_rx_n              (pcie_rx_n),
    .pcie_tx_p              (pcie_tx_p),
    .pcie_tx_n              (pcie_tx_n),
    .dma0_writer_axi_tvalid (wr_tvalid),
    .dma0_writer_axi_tready (wr_tready),
    .dma0_writer_axi_tlast  (wr_tlast),
    .dma0_writer_axi_tdata  (wr_tdata),
    .dma0_reader_axi_tvalid (rd_tvalid),
    .dma0_reader_axi_tready (rd_tready),
    .dma0_reader_axi_tlast  (rd_tlast),
    .dma0_reader_axi_tdata  (rd_tdata),
    .msi_irqs               (msi_irqs)
);
```

The generator accepts the 7-Series, UltraScale, UltraScale+, Stratix V, GW5A and soft PHYs. It does
not support Cyclone V and CertusPro-NX yet: use a LiteX SoC for them. The header files feed the
driver and the tools: copy them next to the driver sources, in `kernel/`, before building, as
[Linux driver and tools](#software) explains.

## Integration without LiteX {#integ-other}

The standalone core is the path for vendor projects and other HDLs. Its AXI-Stream ports carry the
DMA data, its AXI-Lite master forwards the BAR0 accesses above `mmap_base` to user registers, and
its AXI slave gives user logic access to the host memory. The driver works with it unchanged.

For a family the generator does not support, generate Verilog from a small LiteX SoC instead: the
LiteX build writes the Verilog and the constraints before calling the vendor tools, and stops
there without `--build`.

## Porting to a new board {#integ-porting}

A new board needs a target script. Start from the target of the closest board in `bench/` or in
LiteX-Boards and go through the steps below.

1. Check the hardware against [Host requirements](#boards-host): edge connector or M.2 wiring,
   reference clock from the slot, PERST# on an FPGA pin.
2. Declare the PCIe pads in the platform: `rst_n`, `clk_p`, `clk_n` and the `rx` and `tx` pairs of
   each lane, in lane order.
3. Write the clock generator: `sys` from an oscillator of the board, not from the PCIe clock, at
   the frequency of [Choosing the PHY, lanes and widths](#integ-choices).
4. Instantiate the PHY of the family with the data width and BAR0 size, then call `add_pcie` with
   one DMA channel, or build the explicit chain.
5. Add a UART or JTAG bridge and the LTSSM tracer (`add_ltssm_tracer`), to read the link status
   before the driver is loaded.
6. Build, check the timing, load, and check the enumeration and the link width with `lspci`, as in
   [Getting started](#gs-enumeration).
7. Qualify the design with `litepcie_util scratch_test` and a long `dma_test`.

Where to go next: [Linux driver and tools](#software) for the software side, [Example designs and
targets](#examples) for complete designs, [Debugging](#debugging) when the link does not come up.
