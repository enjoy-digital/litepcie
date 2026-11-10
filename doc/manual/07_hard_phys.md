```{=latex}
\part{The PHYs}
```

```{=html}
<h1 class="part">Part III. The PHYs</h1>
```

# Hard-IP PHYs {#hard-phys}

Most FPGAs with PCIe have a hard block that implements the physical, data link and transaction
layers of the specification ([PCI Express in a nutshell](#pcie-primer)). The project wraps each of
them in a PHY with the same interface, so the core, the driver and the tools stay the same on every
vendor. This chapter describes the seven wrappers, what they share and how each one differs.

On an FPGA with a hard block, start with its hard-IP PHY: it is the validated path, and an x1
design on it takes about half the logic of the same design on the soft PHY. The
[Soft PHY](#soft-phy) is for the links that a hard block cannot give.

## At a glance {#hard-glance}

| Family | Class | Rates | Lanes | IP width |
|----------------|----------------------|------------|----------|---------|
| 7-Series | `S7PCIEPHY` | Gen2 | 1, 2, 4, 8 | 64, 128 |
| UltraScale | `USPCIEPHY` | Gen2, Gen3 | 1, 2, 4, 8 | 128, 256 |
| UltraScale+ | `USPPCIEPHY` | Gen2 to Gen4 | 1 to 16 | 128 to 512 |
| Cyclone V | `C5PCIEPHY` | Set by the IP | 1, 2, 4 | 64, 128 |
| Stratix V | `SVPCIEPHY` | Gen1, Gen2 | 4, 8 | 128, 256 |
| Gowin GW5A | `GW5APCIEPHY` | Gen2 | 1, 4 | 256 |
| CertusPro-NX | `LFCPNXPCIEPHY` | Gen3 | 4 | 128 |

All seven PHYs are validated on hardware. The first three rows are Xilinx families, then come
Intel, Gowin and Lattice. The IP width is the width in bits of the hard IP interface; the core
width may differ from it.

The rates of the two last rows come from the names of the driver's device IDs: the downloaded IP
configuration sets them, not the wrapper. The UltraScale+ devices with HBM use a subclass on the
`pcie4c_uscale_plus` IP (`USPHBMPCIEPHY`).

The repository records some results. On the YPCB-00338-1P1, the 7-Series hard IP runs the DMA
loopback test at 3.36 Gb/s at Gen2 x1, 13.33 Gb/s at x4 and 13.3 Gb/s at x8. Above about
13 Gb/s, the test software is the limit, not the link ([Measured results](#soft-results)). On the
Alibaba XCKU3P, the UltraScale+ hard IP runs the test at 9.45 Gb/s at Gen3 x8 (`doc/softphy.md`).

On Stratix V, the wrapper records that the device enumerates and that BAR0 accesses complete
against a Linux host; its DMA has not been exercised on hardware. The boards of each family are in
[Supported FPGAs and boards](#boards).

## The PHY contract {#hard-contract}

Every PHY presents the same signals to the endpoint, so a design changes its PHY class and nothing
else. The table below lists what the endpoint and the frontends read from a PHY.

| Attribute | Content |
|------------------------|--------------------------------------------------------------|
| `sink`, `source` | TLP streams of the core, one per direction (`phy_layout`) |
| `msi` | MSI requests from the interrupt controller, an 8-bit vector |
| `data_width` | Width of the core streams, in bits |
| `id` | Bus, device and function numbers given by the host |
| `bar0_mask` | Address mask of BAR0, from `bar0_size` |
| `max_payload_size` | MPS programmed by the host, in bytes |
| `max_request_size` | MRRS programmed by the host, in bytes |
| `endianness` | Byte order of the TLP DWs at the PHY |
| `qword_aligned` | Payload placed on a 64-bit boundary |

The UltraScale and UltraScale+ PHYs replace the two streams by separate request and completion
channels (`req_sink`, `req_source`, `cmp_sink`, `cmp_source`). The endpoint then builds one
packetizer and one depacketizer per channel ([Core architecture](#core-architecture)).

Each PHY takes a `cd` parameter: the clock domain of the core, `sys` by default. The CertusPro-NX
PHY is the exception, with `pcie` by default, so that its core runs on the clock of the hard IP.

Two attributes describe the data as the hard IP gives it. A big endian PHY, such as the
7-Series, Gowin, Lattice and soft PHYs, carries each DW with its bytes in the reverse order. The
endpoint swaps them back when it is built with `endianness="big"`.

The endpoint does not read the attribute itself, and its default is big endian. LiteX `add_pcie`
and the generator pass `phy.endianness`; a design that builds the endpoint by hand must do the
same, or the TLP fields of a little endian PHY come out byte swapped.

The second attribute, `qword_aligned`, is set on Cyclone V only. The Wishbone bridge then takes
the 32-bit data from the right half of a 64-bit beat, when the design passes it
`qword_aligned=phy.qword_aligned`.

## Common datapath {#hard-datapath}

Between the core and the hard IP, the Xilinx, Gowin and Lattice wrappers use the same two
datapaths. They cross from the core clock domain to the `pcie` clock domain of the hard IP and
convert the core width to the width of the hard IP. The figure below shows both directions.

![Common datapath of the hard-IP PHYs: a CDC FIFO and a width converter in each direction, with
the optional packet buffer on transmit and the 128-bit aligner on receive.](hard_datapath.svg)

The transmit datapath registers the stream in the core clock domain, crosses it with a 16-entry
clock domain crossing FIFO, then converts its width (`PHYTXDatapath`). The receive datapath does
the same in reverse (`PHYRXDatapath`). When the core runs in `pcie` at the width of the hard IP,
both reduce to wires.

**Width conversion.** The core can be narrower or wider than the hard IP, for instance a 64-bit
core on a 128-bit interface. On receive, an up-conversion tracks how many slices of the wide beat
were filled. It clears the byte enables of the unused slices, so a short last beat never carries
stale bytes.

**Packet buffer.** The UltraScale+ requester interface needs a TLP without gaps once it has
started. Beats can acquire gaps when they cross clock domains, so the `with_rq_buffer` option
holds each TLP in a packet FIFO until its last beat has arrived, then releases it at once.

**128-bit receive aligner.** At 128 bits, the 7-Series hard IP can start a TLP in the upper half
of a beat, on DW2. The aligner shifts such packets by two DWs so that each one starts on DW0
(`PHYRX128BAligner`). It adds one beat when a packet ends in the upper half.

At 128 bits, the 7-Series hard IP also leaves its last and byte-keep signals idle. It reports the
packet boundaries in markers of its user sideband instead. A decoder rebuilds the start, the end
and the byte enables of each beat from these markers (`PHYRX128BMarkerDecoder`).

### Clocking {#hard-clocking}

The hard IP takes the reference clock of the slot and provides the `pcie` clock, the user clock of
its application interface. The figure below shows the clocks around a hard-IP PHY.

![Clocking of a hard-IP PHY: the hard IP provides the user clock of the pcie clock domain; on
7-Series, an MMCM of the wrapper makes the PIPE and user clocks; the core runs in its own clock
domain behind the CDC FIFOs.](hard_clocks.svg)

| Family | Source of the `pcie` clock | Frequency |
|----------------|------------------------------------|---------------------------------------|
| 7-Series | MMCM of the wrapper | 250 MHz at x4 64-bit and x8, else 125 MHz |
| UltraScale(+) | Hard IP | 125 MHz at Gen2, 250 MHz at Gen3, Gen4 |
| Cyclone V | Core clock output of the hard IP | Set by the Platform Designer system |
| Stratix V | Core clock output of the hard IP | Set by rate, lanes and width |
| GW5A | `crg_pcie` domain of the design | Provided by the design |
| CertusPro-NX | User clock output of the hard IP | Set by the IP configuration |

On 7-Series, the wrapper builds the clocks that the vendor example design would build. An MMCM
locked on the transmit clock of the transceivers makes the 125 MHz and 250 MHz PIPE clocks and the
two user clocks. A clock multiplexer switches the PIPE clock when the link changes rate.

The 7-Series reference clock can be 100, 125 or 250 MHz (`refclk_freq`). The UltraScale and
Stratix V wrappers declare a 100 MHz reference clock.

### Status registers {#hard-registers}

Most PHYs add a small register bank, named `pcie_phy_*` in a SoC. It lets software on either side
read the link state and the settings of the host. The fields are listed in the
[register appendix](#registers).

| Register | Content | Read from the hard IP on |
|-----------------------------|-----------------------------|--------------------------------|
| `link_status` | Link up, rate, width, LTSSM state | All but Cyclone V |
| `msi_enable` | MSI enabled by the host | Xilinx, Stratix V |
| `msix_enable` | MSI-X enabled by the host | 7-Series |
| `bus_master_enable` | Bus mastering enabled | Xilinx, Stratix V |
| `max_request_size` | MRRS in bytes | Xilinx, Stratix V |
| `max_payload_size` | MPS in bytes | Xilinx, Stratix V |

Some PHYs declare a register without a source in the hard IP. On Gowin, `msi_enable` reads 1 and
`msix_enable` reads 0. On Stratix V, which has no MSI-X, `msix_enable` reads 0. On the
CertusPro-NX, both enables read 0 and only the link up bit of the link status is driven.

The UltraScale and UltraScale+ link status adds the PHY link state and the data link
initialization state. The Gowin PHY adds the bus and device numbers, the BAR decode, the receive
errors and the transmit credits of the hard IP.

## Xilinx 7-Series {#hard-s7}

The 7-Series PHY wraps the `pcie_7x` IP of the Artix-7, Kintex-7 and Virtex-7 devices
(`S7PCIEPHY`). It targets 5.0 GT/s on 1 to 8 lanes with a 64-bit or 128-bit interface. A Gen2 x8
link needs the 128-bit interface; the class rejects the combinations that the IP does not have.

| Parameter | Default | Role |
|------------------------------------|--------------|------------------------------------|
| `data_width` | 64 | Core width, 64 or 128 |
| `pcie_data_width` | `data_width` | Hard IP width, 64 or 128 |
| `refclk_freq` | 100 MHz | Reference clock, 100, 125 or 250 MHz |
| `bar0_size` | 1 MiB | BAR0 size, a power of two |
| `msi_type` | `msi` | `msi`, `msi-multi-vector` or `msi-x` |
| `mode` | `Endpoint` | `Endpoint` or `RootPort` |
| `with_ptm` | False | PTM extended capability |
| `with_cfg_mgmt` | False | Access to the local configuration space |
| `with_perst_refclk_gating` | False | Reference clock buffer off during PERST# |

With `msi-x`, the IP advertises a 32-entry MSI-X table at offset `0x2000` of BAR0 and its pending
bit array at `0x1808`. These offsets match the register map of the generator. With the two MSI
types, the IP advertises a single MSI vector.

The hard IP advertises a maximum payload of 512 bytes, 256 bytes at x8. In root port mode, the IP
declares the root port type and the host bridge class. The configuration management interface
lets the root port program its own Device Control register, such as its MPS.

**Placement.** The build resets the location constraints that the IP puts on its transceiver
common block and, below x8, on its buffer memories. `add_gt_loc_constraints` places the
transceiver channel of each lane when a board routes the lanes to other quads.

**QPLL sharing.** `use_external_qpll` makes the hard IP use a QPLL owned by the design, so that
another protocol can share the transceiver quad.

**PTM.** With `with_ptm`, the IP opens its extended configuration space to the PTM capability of
the core. `create_ptm_sniffer` adds the receiver that catches the PTM responses the hard IP
filters ([Precision Time Measurement](#ptm)).

## Xilinx UltraScale and UltraScale+ {#hard-us}

The UltraScale PHY wraps the `pcie3_ultrascale` IP (`USPCIEPHY`). The UltraScale+ PHY wraps the
`pcie4_uscale_plus` IP, or `pcie4c_uscale_plus` on HBM devices (`USPPCIEPHY`). Both hard IPs
split the traffic into four AXI-Stream interfaces instead of one TLP stream per direction.

| Interface | Direction | Content |
|-----------|----------------|--------------------------------------------|
| RQ | Device to host | Requests of the device (DMA) |
| RC | Host to device | Completions of these requests |
| CQ | Host to device | Requests of the host (BAR accesses) |
| CC | Device to host | Completions of the device |

These interfaces carry a descriptor instead of the TLP header. Four adapters convert between the
descriptors and the raw TLPs of the core, as the figure below shows. Each adapter sits behind its
own copy of the common datapath, so four datapaths cross the clock domains.

![UltraScale and UltraScale+ PHYs: four adapters convert the request and completion channels of
the endpoint to the RQ, CC, CQ and RC interfaces of the hard IP.](hard_axis.svg)

The adapters take 128, 256 and 512-bit interfaces. A 64-bit core runs on a wider hard IP through
the width converters of the datapath. The sideband bits of the hard IP are mapped to the raw form
by `xilinx_tuser.py`.

| Parameter | UltraScale | UltraScale+ |
|-------------------|-------------------------|-------------------------------|
| `speed` | `gen2`, `gen3` | `gen2`, `gen3`, `gen4` |
| Lanes | 1, 2, 4, 8 | 1, 2, 4, 8, 16 |
| `pcie_data_width` | 128, 256 | 128, 256, 512 |
| `mode` | Endpoint, root port | Endpoint, root port |
| Transceiver PLL | QPLL1 | QPLL1 at Gen2, QPLL0 above |
| Options | None | `with_cfg_mgmt`, `with_rq_buffer`, `with_ptm` |

PTM on UltraScale+ needs an endpoint at Gen2 x1 to x8, or at Gen3 and Gen4 x4 and x8, with a hard
IP width of 128 bits or more. Both PHYs drive the MSI inputs of the hard IP from the `msi` stream.

## Intel Cyclone V {#hard-c5}

The Cyclone V PHY drives the hard IP through its Avalon-ST application interface (`C5PCIEPHY`).
The wrapper does not configure the hard IP: it expects a Platform Designer system named
`pcie_phy`, which holds the hard IP and its transceiver reconfiguration controller.

The rate, the BAR and the identifiers are therefore set in that system. The wrapper takes 1, 2 or
4 lanes and a 64-bit or 128-bit width. The reconfiguration controller needs a free-running clock
(`reconfig_clk`), the core clock by default.

The Avalon-ST interface places each payload on a 64-bit boundary, so the PHY declares a qword
aligned payload. The wrapper reads the bus and device numbers and the Device Control register from
the configuration outputs of the hard IP. It has no status registers.

## Intel Stratix V {#hard-sv}

The Stratix V PHY drives the hard IP through its Avalon-ST interface (`SVPCIEPHY`). Quartus has no
Platform Designer component for this hard IP. The wrapper instantiates its top level directly and
adds its sources from the Quartus installation.

| Parameter | Default | Values |
|--------------------|------------|-------------------------------------------|
| `speed` | `gen2` | `gen1`, `gen2` |
| `nlanes` | 8 | 4, 8 |
| `data_width` | 256 | 128 or 256, by rate and lanes |
| `vendor_id` | `0x1172` | PCI vendor ID |
| `device_id` | `0xe001` | PCI device ID |
| `max_payload_size` | 256 | Advertised MPS, in bytes |
| `mgmt_clk` | Core clock | Clock of the reconfiguration controller |

The class accepts the rate, lane and width combinations of the Intel user guide, except the
64-bit width: its qword aligners work on 128-bit and 256-bit beats only. An x1 link needs the
64-bit width, so the PHY takes 4 or 8 lanes.

The reconfiguration controller needs a free-running clock of 100 to 125 MHz. The generator
therefore requires an external clock for this PHY (`clk_external`).

### Qword alignment {#hard-sv-qword}

The Avalon-ST interface does not pack the payload right after the header. It keeps each qword of
the payload in one 64-bit half of the beat: the first payload DW sits on an even DW lane when bit 2
of its address is 0, and on an odd lane when it is 1. When the packed position has the wrong
parity, a padding DW follows the header. The figure below shows the four cases on the 256-bit
interface.

![Stratix V qword alignment on the 256-bit interface: the first payload DW (D0) must sit on an
even DW lane when address bit 2 is 0 and on an odd one when it is 1; the PAD cells show the two
cases that need a padding DW.](hard_qword.svg)

The core uses the packed layout only. A transmit aligner inserts the padding DW and a receive
dealigner removes it at the PHY boundary (`_TXQwordAligner`, `_RXQwordDealigner`). The PHY then
declares no qword alignment to the rest of the core. TLPs without payload are never padded.

**Interrupts.** The hard IP sends one MSI per rising edge of its request input. The wrapper lowers
the request on each acknowledge, so that two queued MSIs give two edges (`_MSIRequest`).

## Gowin GW5A {#hard-gw5a}

The Gowin PHY drives the PCIe controller of the GW5A family (`GW5APCIEPHY`). It takes 1 or 4 lanes
and a 256-bit hard IP interface; the core can be 64, 128 or 256 bits wide. Its `pcie` clock comes
from a `crg_pcie` clock domain that the design provides.

The hard IP gives one valid bit per DW instead of byte enables. The wrapper converts between these
bits and the byte enables of the core, and reverses the order of the DWs in each beat. The PHY
declares a big endian byte order.

The hard IP takes an MSI request with a 5-bit vector. The wrapper raises that request on the rising
edge of the valid signal of the `msi` stream, and takes the acknowledge of the hard IP as ready.

## Lattice CertusPro-NX {#hard-lfcpnx}

The Lattice PHY drives the x4 PCIe hard IP of the CertusPro-NX family (`LFCPNXPCIEPHY`). It takes
4 lanes, a 128-bit hard IP interface and a 64-bit or 128-bit core. BAR0 is 64 KiB by default.

At reset, a configuration sequencer writes the IP registers through the LMMI configuration port.
It disables the MSI capability and sets the MSI-X table and pending bit array offsets to `0x2000`
and `0x1808`. It then reads the bus, device and function numbers of the device.

The raw TLP interface of this IP has no MSI request input. Interrupts are therefore sent as MSI-X
memory writes by the core; the `msi` stream of the PHY is not connected.

## IP generation {#hard-ip-generation}

Each vendor delivers its hard IP in a different way. The wrappers generate it, find it or download
it during the build, so that a design needs no manual step except on Cyclone V.

| Family | How the IP is obtained |
|-------------------|------------------------------------------------------------------------|
| Xilinx | Tcl `create_ip` and `synth_ip` before synthesis, from the wrapper parameters |
| Cyclone V | Platform Designer system generated by the user, given to the wrapper |
| Stratix V | Sources from Quartus; reconfiguration controller generated and cached |
| GW5A, CertusPro-NX | Archive downloaded into the build directory and unzipped |

**Xilinx.** The wrapper writes the IP configuration as a list of `CONFIG` properties: link width
and rate, user clock, interface width, BAR0, interrupts and device ID. `update_config` adds or
overrides properties. `use_external_hard_ip` takes an existing `.xci` file instead of generating
the IP.

**Cyclone V.** `use_external_hard_ip` is mandatory: it adds the `pcie_phy.qip` file of the
generated system. Without it, the build stops with an error.

**Stratix V.** The wrapper locates Quartus from the `PATH` or from `quartus_bindir`. It generates
the reconfiguration controller with `qsys-generate` at the first build and reuses it while its
script is unchanged. The defaults follow Quartus 25.1std (`acds_version`).

**GW5A and CertusPro-NX.** The IP sources come as an archive at a fixed URL, fetched
with `wget` and extracted with `unzip` into the build directory. The first build therefore needs
both tools and network access.

### Device IDs {#hard-device-ids}

The driver binds to a device by its vendor and device IDs ([Linux driver and tools](#software)).
The Xilinx wrappers derive the device ID from the family, the rate and the lane count.

| PHY | Vendor ID | Device ID, x1 to x8 |
|-------------------|-----------|-----------------------------------------------|
| 7-Series | `0x10ee` | `0x7021` to `0x7028` |
| UltraScale | `0x10ee` | `0x8021` to `0x8028` (Gen2), `0x8031` to `0x8038` (Gen3) |
| UltraScale+ | `0x10ee` | `0x9021` to `0x9028`, `0x9031` to `0x9038`, `0x9041` to `0x9048` (Gen2 to Gen4) |
| Stratix V | `0x1172` | `0xe001`, a parameter |
| GW5A | `0x22c2` | `0x1100` in the driver table |
| CertusPro-NX | `0x1204` | `0x9c25` in the driver table |

The wrapper adds the lane count to a decimal base (7020, 8020, 8030, 9020, 9030 or 9040). Vivado
reads the result as hexadecimal digits: 9030 plus 8 gives 9038, so the device ID is `0x9038`. Up
to x8, the last digit is the lane count.

At UltraScale+ x16, the same sum gives `0x9036`, `0x9046` and `0x9056` (Gen2 to Gen4). The driver
table lists `0x902f` and `0x903f` instead, so it does not bind to an x16 design. Set
`PF0_DEVICE_ID` with `update_config`, or add the ID to the driver table.

The GW5A and CertusPro-NX IDs are set by the downloaded IP configuration, not by the wrapper.

## LTSSM tracer {#hard-ltssm-tracer}

When a link does not train, the sequence of LTSSM states shows where it stops
([PCI Express in a nutshell](#pcie-primer)). The tracer records each change of the LTSSM state
reported by the hard IP in a 128-entry FIFO (`LTSSMTracer`). The 7-Series, UltraScale and
UltraScale+ PHYs add it with `add_ltssm_tracer()`, as does the [Soft PHY](#soft-phy).

Each read of the history register returns one transition: the new state, the old state, an
overflow flag and a valid flag. The overflow flag means that the FIFO was full and intermediate
states were lost. An empty FIFO reads with the valid flag clear.

The tracer samples the state through a synchronizer in the `sys` clock domain, because the `pcie`
clock domain is held in reset during most of the training. A change can therefore show an invalid
intermediate value for one cycle.

The bench script reads the history through a `litex_server` and prints each transition with the
state names. The state encoding differs between families: pass `7series` or `ultrascale`.

```sh
python3 bench/test_ltssm_tracer.py --csr-csv csr.csv --family 7series
```

Each line gives the old state and the new state, in hexadecimal and by name. A healthy training
goes through Detect, Polling and Configuration to L0. A link that falls back to Detect or loops in
Recovery shows it in these lines; [Debugging](#debugging) has the procedure.

## Limitations {#hard-limitations}

The wrappers expose what the core needs and leave the rest of each hard IP unused. The points
below are the known gaps, by family.

- **7-Series.** Gen2 at most: the hard block stops at 5.0 GT/s. With `msi-multi-vector`, the IP
  still advertises one MSI vector.
- **UltraScale and UltraScale+.** The wrappers configure MSI and no MSI-X capability; they have no
  MSI-X enable register. At x16, the device ID is not in the driver table
  ([Device IDs](#hard-device-ids)).
- **Cyclone V.** No status registers. The generator does not support this PHY yet. LiteX
  `add_pcie` does not pass the qword alignment to the Wishbone bridge: pass it by hand.
- **Stratix V.** No x1, no Gen3, no MSI-X, no AER, no configuration via protocol (CvP). BAR0 answers
  32-bit accesses only: a byte read aborts and returns `0xff`. Byte enables are qword granular.
- **GW5A interrupts.** The MSI request rises on the rising edge of the valid signal. Two MSIs back
  to back keep valid high, so the second one gets no edge and the interrupts may stall.
- **GW5A byte order.** It is declared big endian, which the code does not confirm. MPS and MRRS
  are reported as 128 bytes, not read from the configuration space.
- **CertusPro-NX interrupts.** The IP has no MSI request pins: use MSI-X. In a LiteX SoC,
  `add_pcie` with its default MSI type gets no interrupt; pass `msi_type="msi-x"`.
- **CertusPro-NX status.** MPS and MRRS are reported as 128 bytes, and only the link up bit of the
  link status is driven. The generator does not support this PHY yet.

## In the code {#hard-code}

| File | Content |
|-------------------------|------------------------------------------------------------|
| `common.py` | Common datapaths, 128-bit aligner, LTSSM tracer, BAR helper |
| `s7pciephy.py` | `S7PCIEPHY` |
| `uspciephy.py` | `USPCIEPHY` |
| `usppciephy.py` | `USPPCIEPHY`, `USPHBMPCIEPHY` |
| `axis_adapters.py` | RQ, RC, CQ and CC adapters of the UltraScale PHYs |
| `c5pciephy.py` | `C5PCIEPHY` |
| `svpciephy.py` | `SVPCIEPHY`, qword aligners, IP sources and reconfiguration |
| `gw5apciephy.py` | `GW5APCIEPHY` |
| `lfcpnxpciephy.py` | `LFCPNXPCIEPHY` and its LMMI configuration sequencer |

The files are in `litepcie/phy/`. The LTSSM history reader is `bench/test_ltssm_tracer.py`; the
unit tests of the datapaths, adapters and Intel PHYs are in `test/`.

Where to go next: [Soft PHY](#soft-phy) for the PHY without hard IP,
[Integration](#integration) to instantiate a PHY, [Supported FPGAs and boards](#boards) for the
boards of each family.
