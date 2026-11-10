```{=latex}
\part{The core}
```

```{=html}
<h1 class="part">Part II. The core</h1>
```

# Core architecture {#core-architecture}

This chapter describes the core: the layer between a PHY and the frontends that turns raw TLPs
into requests and completions and routes them. Read it before connecting your own logic to the
crossbar or choosing the endpoint parameters. The protocol objects it handles (TLPs, tags,
completions, BARs) are explained in [PCI Express in a nutshell](#pcie-primer).

## At a glance {#core-glance}

| Item | Value |
|-------------------|---------------------------------------------------------------------|
| Top-level class | `LitePCIeEndpoint` (`litepcie/core/endpoint.py`) |
| Roles | Endpoint; root port with `LitePCIeRootPort` and a PHY in RootPort mode |
| Datapath widths | 64, 128, 256 or 512 bits: the `data_width` of the PHY |
| TLPs sent | MemRd, MemWr, CplD, CfgRd0, CfgWr0, PTM Request |
| TLPs received | MemRd and MemWr with a 3DW header, CplD, Cpl, CfgRd0, CfgWr0, PTM messages |
| Request addresses | Host requests: BAR0 offset; FPGA requests: 32 or 64 bits |
| Outstanding reads | `max_pending_requests` tags (4 by default), completions reordered |
| Request size | Buffers sized for 512-byte reads and writes |
| Clock | The user clock domain of the PHY (`cd`, `sys` by default) |

## Architecture {#core-overview}

The core sits between the PHY and the frontends, as the figure below shows. The PHY delivers
whole TLPs as a stream of beats, and the depacketizer sorts them into host requests and
completions. The crossbar routes host requests to slaves and arbitrates the requests of the
frontends. The packetizer builds the TLPs that go back to the PHY.

![Core architecture. Look at the three kinds of crossbar ports on the right: host requests go to
the slave ports, FPGA writes take the write-only ports directly, and every frontend that reads goes
through the TLP controller (cyan).](core_blocks.svg)

The endpoint bundles the packetizer, the depacketizer and the crossbar. The frontends are added
next to it and take ports from its crossbar. They are described in [Scatter-gather DMA](#dma),
[Memory-mapped bridges and interrupts](#mmap-irq) and [Precision Time Measurement](#ptm); the PTM
requester sends its request straight to the packetizer.

The whole core runs in one clock domain, at the width of the PHY user side. The PHY does the
clock domain crossing and the width conversion towards the hard IP, so the frontends and user
logic see a single clock. The PHYs are described in [Hard-IP PHYs](#hard-phys) and
[Soft PHY](#soft-phy).

## Usage {#core-usage}

A design needs a PHY, an endpoint and the frontends it uses. In a LiteX SoC, `add_pcie` builds
this chain; [Integration](#integration) describes it. The example below follows the explicit
chain of the KC705 target (`bench/kc705.py`): a bridge from BAR0 to the registers, one DMA
channel and single-vector MSI.

```python
from litepcie.phy.s7pciephy     import S7PCIEPHY
from litepcie.core              import LitePCIeEndpoint, LitePCIeMSI
from litepcie.frontend.dma      import LitePCIeDMA
from litepcie.frontend.wishbone import LitePCIeWishboneBridge

# PHY: 7-Series hard IP, x4, 128-bit, 128 KiB BAR0.
self.pcie_phy = S7PCIEPHY(platform, platform.request("pcie_x4"),
    data_width = 128,
    bar0_size  = 0x20000)

# Endpoint: packetizer, depacketizer, crossbar.
self.pcie_endpoint = LitePCIeEndpoint(self.pcie_phy,
    endianness           = self.pcie_phy.endianness,
    max_pending_requests = 8)

# BAR0 to the CSR bus of the SoC.
self.pcie_bridge = LitePCIeWishboneBridge(self.pcie_endpoint,
    base_address = self.mem_map["csr"])
self.bus.add_master(master=self.pcie_bridge.wishbone)

# One DMA channel.
self.pcie_dma0 = LitePCIeDMA(self.pcie_phy, self.pcie_endpoint,
    with_buffering = True, buffering_depth=1024,
    with_loopback  = True)

# Its interrupts on single-vector MSI.
self.pcie_msi = LitePCIeMSI()
self.comb += self.pcie_msi.source.connect(self.pcie_phy.msi)
self.comb += self.pcie_msi.irqs[0].eq(self.pcie_dma0.reader.irq)
self.comb += self.pcie_msi.irqs[1].eq(self.pcie_dma0.writer.irq)
```

The endianness of the endpoint must be the one of the PHY: each PHY class gives it as an
attribute, and `add_pcie` passes it on. The table below lists the endpoint parameters.

| Parameter | Default | Meaning |
|----------------------------------|----------|------------------------------------------------|
| `phy` | none | The PHY instance |
| `max_pending_requests` | 4 | Read requests in flight; a power of two |
| `address_width` | 32 | Address width of FPGA-initiated requests: 32 or 64 |
| `endianness` | `"big"` | Byte order of the DWs of the PHY: `"big"` or `"little"` |
| `cmp_bufs_buffered` | `True` | Completion buffers with an output register |
| `with_ptm` | `False` | PTM Request generation, configuration TLP decoding |
| `with_configuration` | `False` | CfgRd0 and CfgWr0 requests on the master ports |
| `address_mask` | BAR0 mask | Mask applied to the addresses of host requests |

`add_pcie` uses 8 pending requests by default, the generator 4 (`ep_max_pending_requests`). More
pending reads keep more data in flight on a link with a long round trip, at the cost of one
completion buffer per tag.

## The PHY contract {#core-phy-contract}

The endpoint uses the PHY through a few attributes, the same for every hard IP and for the soft
PHY. A new PHY works with the core and its frontends once it provides them. The table below lists
them.

| Attribute | Meaning |
|----------------------------|--------------------------------------------------------------|
| `data_width` | Width of the TLP streams, in bits |
| `sink`, `source` | TLP streams to and from the link (`phy_layout`: `dat`, `be`) |
| `req_sink`, `cmp_sink` | Separate request and completion streams, instead of `sink` |
| `req_source`, `cmp_source` | Separate request and completion streams, instead of `source` |
| `id` | Bus, device and function numbers of the port, 16 bits |
| `bar0_mask` | Address mask of BAR0, from the BAR0 size |
| `max_payload_size` | Max Payload Size programmed by the host, in bytes |
| `max_request_size` | Max Read Request Size programmed by the host, in bytes |
| `msi` | MSI request stream: one 8-bit vector number per message |
| `endianness` | Byte order of the DWs on the streams |
| `qword_aligned` | Payloads aligned on 64-bit boundaries by the PHY |

A TLP is one stream packet: `first` on its first beat, `last` on its last one. The byte enables
mark the valid bytes of each beat. The figure below shows how a header and its payload share the
beats.

![TLP beats. Look at where the payload starts: right after the header, in the same beat, so a 3DW
header shares a beat with the first payload DW, and the last beat of a TLP may hold invalid
DWs.](core_tlp_beats.svg)

The UltraScale and UltraScale+ hard IPs have separate interfaces for the requests they receive
and for the completions they return. Their PHYs therefore provide four streams, and the endpoint
builds one packetizer or depacketizer per stream. The other PHYs share one stream per direction.

The host programs the Max Payload Size and the Max Read Request Size in the configuration space
of the device ([Transaction layer packets](#primer-tlp)). The PHY reads them from the hard IP and
the DMA splits its transfers to fit (see [Splitter](#dma-splitter)). The buffers of the core are
built for 512 bytes, so the PHYs limit both values:

| PHY | Max Payload Size | Max Read Request Size |
|-----------------------------|-------------------------|-------------------------|
| Xilinx PHYs, soft PHY | Host value, up to 512 bytes | Host value, up to 512 bytes |
| Gowin GW5A, CertusPro-NX | Fixed, 128 bytes | Fixed, 128 bytes |
| Cyclone V, Stratix V | Host value | Host value |

The two Intel PHYs pass the host values on without a limit. The host keeps the Max Payload Size
within what the hard IP advertises (256 bytes on Stratix V), but it may program a Max Read
Request Size above 512 bytes: keep it at 512 bytes or less on these PHYs.

The Cyclone V PHY sets `qword_aligned`, because its Avalon-ST interface places payloads on 64-bit
boundaries. The memory-mapped bridges then pick the right half of the beat; the generator passes
the attribute to them. The Stratix V PHY undoes this alignment itself.

## TLP layer {#core-tlp}

### Packetizer {#core-packetizer}

The packetizer turns requests, completions, configuration requests and PTM messages into TLPs.
Each kind has its own encoder; an arbiter picks one TLP at a time, and the header inserter places
its header in front of the payload. Its class is `LitePCIeTLPPacketizer`.

Requests are written in whole DWs. The first byte enables are all set, and so are the last ones
when the request is longer than one DW. Reads carry no payload; writes carry `len` DWs.

With a 64-bit address width, the packetizer uses a 4DW header only when the upper 32 bits of the
address are not zero; lower addresses keep a 3DW header. On UltraScale and UltraScale+ devices at
256 or 512 bits, it always uses 4DW headers, even with a 32-bit address width. The specification
asks for a 3DW header below 4 GiB, so these requests rely on a host that accepts the 4DW form.

### Depacketizer {#core-depacketizer}

The depacketizer extracts the header of each TLP and dispatches the TLP by its format and type.
Its class is `LitePCIeTLPDepacketizer`. The table below lists where each kind goes; a TLP of any
other kind is discarded.

| TLP | Goes to | Capability |
|-------------------------|------------------------------------------|--------------------|
| MemRd, MemWr (3DW header) | Request source, then the crossbar slaves | `REQUEST` |
| CplD, Cpl | Completion source, then the crossbar masters | `COMPLETION` |
| CfgRd0, CfgWr0 | Configuration source | `CONFIGURATION` |
| PTM Request, PTM Response | PTM source | `PTM` |

On a host request, the depacketizer clears the address bits above the BAR0 size with the address
mask, so slaves see the offset inside BAR0. BAR0 is a 32-bit memory BAR, which the host addresses
with 3DW headers.

On a completion, the depacketizer sets two flags. The `end` flag marks the last completion of a
request: its length equals its remaining byte count. The `err` flag marks a status other than
Successful Completion, such as Unsupported Request or Completer Abort.

### Byte order {#core-byte-order}

Hard IPs do not all present the bytes of a DW in the same order. When the PHY is big-endian, the
packetizer and the depacketizer reverse the bytes of each DW of the headers and payloads. The
crossbar and the frontends therefore see the same DWs on every PHY.

| Byte order | PHYs |
|------------|------------------------------------------------------------|
| Big | 7-Series, Gowin GW5A, Lattice CertusPro-NX, soft PHY |
| Little | UltraScale, UltraScale+, Cyclone V, Stratix V |

## Crossbar {#core-crossbar}

The crossbar connects the frontends to the TLP layer through ports. A slave port receives host
requests and returns their completions. A master port sends requests to the host and receives
the completions of its reads. The class is `LitePCIeCrossbar`; the frontends ask it for their
ports.

| Method | Port | Used by |
|------------------------------------------------|--------|--------------------------|
| `get_slave_port(address_decoder)` | Slave | Wishbone master bridge, PTM capability |
| `get_master_port(read_only=True)` | Master | DMA Reader, AXI slave reads |
| `get_master_port(write_only=True)` | Master | DMA Writer, DMA status, AXI slave writes |
| `get_master_port()` | Master | Wishbone slave bridge, MSI-X |

### Slave path {#core-crossbar-slave}

Each slave port has an address decoder: a function of the request address that is true when the
port serves it. The crossbar sends each host request to the port whose decoder matches, and
arbitrates the completions of the slaves towards the packetizer. The Wishbone master bridge takes
every address of BAR0 by default.

### Master path {#core-crossbar-master}

Each master port gets a channel number when it is created. The crossbar writes it into every
request and routes each completion back by its channel. The figure below shows how the ports are
grouped.

![Crossbar master path. Follow the cyan path: read-only and read-write ports share an arbiter and
the TLP controller; write-only ports have their own arbiter, so writes keep flowing while reads
wait for a free tag.](core_crossbar.svg)

The TLP controller holds a read when all its tags are in use, and the next requests of the
read-only and read-write ports wait behind it, writes included. Write-only ports bypass it, so a
DMA Writer is never blocked by the reads of a DMA Reader. A final arbiter merges both groups into
the packetizer, and every completion goes back through the TLP controller.

## TLP controller {#core-controller}

The host may return the completions of several reads out of order, and may split one read into
several completions. The TLP controller hides both: it numbers the reads with tags, keeps each
completion in a buffer per tag and releases the buffers in the order of the requests. Its class
is `LitePCIeTLPController`.

![TLP controller. Follow the completions from right to left: the demultiplexer stores them by tag,
and the multiplexer releases the buffers in the order of the request queue; a tag returns to the
tag queue once its last completion is out.](core_reorder.svg)

The controller works in five steps:

1. At reset, the tag queue is filled with `max_pending_requests` tags.
2. A read leaves only when a tag is free. The controller writes the tag into the request and
   pushes it, with its channel, on the request queue.
3. Each completion goes into the buffer of its tag.
4. The multiplexer reads the buffer of the oldest request of the request queue. It moves to the
   next request after the completion marked `end` or `err`.
5. The tag of that request then goes back to the tag queue.

An error completion carries no data, so it never reaches the full byte count of its request. It
still retires the request: a read the host rejects does not leak a tag and stall the DMA Reader.

Each buffer holds one read of 512 bytes plus one beat, for a read that does not start on a beat
boundary. The FIFO has one entry per beat of 512 bytes, and its output register holds the extra
beat; without the output register (`cmp_bufs_buffered=False`), the FIFO has one more entry. A
128-bit core with 8 tags thus has 8 buffers of 32 entries (`get_completion_buffer_depth`).

## Root port {#core-rootport}

LitePCIe can also drive a link as the root port, with a device such as an NVMe SSD downstream.
The figure below shows the roles: user logic sends configuration and memory requests to the
device, and the device reads and writes the memory of the FPGA design.

![Root port. Look at the direction of the requests: user logic on the left drives the device
through the root port (cyan), and the DMA of the device arrives on the slave
side.](core_rootport.svg)

A root port needs three pieces:

- A PHY in RootPort mode: `S7PCIEPHY`, `USPCIEPHY` or `USPPCIEPHY` with `mode="RootPort"`. The
  hard IP then trains as the downstream port and reports a bridge class code.
- `LitePCIeRootPort`: the endpoint with an address mask of 0. The slaves see the full address of
  the requests of the device instead of a BAR0 offset.
- `with_configuration=True`: master ports carry configuration fields. A request with `is_cfg`
  set becomes a CfgRd0 or CfgWr0 of one DW to a bus, device, function and register.

The hard IP has its own configuration space, which the root port must program too, for example
its Max Payload Size. The 7-Series and UltraScale+ PHYs expose the configuration management port
of the hard IP with `with_cfg_mgmt=True`, in the `pcie` clock domain.

Enumeration, BAR assignment and bus mastering of the device are left to the software that drives
the root port; [Integration](#integration) describes root-port designs. The root port and the
256-bit and 512-bit datapaths are less used than the endpoint at 64 and 128 bits: test them
explicitly in a new design.

## In the code {#core-code}

The files below are in the `litepcie/` directory.

| File | Main classes | Role |
|-------------------------------|--------------------------------------|---------------------------|
| `common.py` | `request_layout`, `completion_layout` | Stream layouts, `get_bar_mask` |
| `core/endpoint.py` | `LitePCIeEndpoint` | Packetizers, depacketizers, crossbar |
| `core/rootport.py` | `LitePCIeRootPort` | Endpoint without address mask |
| `core/crossbar.py` | `LitePCIeCrossbar` | Slave and master ports, arbitration |
| `core/common.py` | `LitePCIeMasterPort`, `LitePCIeSlavePort` | Port bundles |
| `tlp/packetizer.py` | `LitePCIeTLPPacketizer` | TLP encoders, header inserters |
| `tlp/depacketizer.py` | `LitePCIeTLPDepacketizer` | Header extracters, dispatch |
| `tlp/controller.py` | `LitePCIeTLPController` | Tags, completion reordering |
| `tlp/common.py` | `fmt_type_dict`, headers | TLP encodings, byte order swap |

The unit tests of this layer are in `test/test_header_inserter.py`,
`test/test_header_extracter.py`, `test/test_request_packetizer.py`,
`test/test_completion_packetizer.py` and `test/test_tlp_controller.py`; see
[Simulation and verification](#simulation).

## Limitations {#core-limits}

- Host requests are MemRd and MemWr with a 3DW header, to BAR0. I/O requests, host messages and
  host requests with a 4DW header are discarded.
- FPGA-initiated requests are whole DWs; byte-granular writes are not generated.
- One function and one BAR; the core builds its requests with traffic class 0.

Where to go next: [Scatter-gather DMA](#dma) for the main frontend,
[Memory-mapped bridges and interrupts](#mmap-irq) for BAR0 and MSI, [Integration](#integration)
to build a design.
