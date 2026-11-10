# Memory-mapped bridges and interrupts {#mmap-irq}

This chapter describes the frontends that complete the DMA: the bridges between PCIe memory
requests and bus cycles, in both directions, and the interrupt controllers. Read it to give the
host access to the registers, to let FPGA logic reach host memory, or to choose between MSI and
MSI-X. BARs, MSI and MSI-X are explained in
[PCI Express in a nutshell](#pcie-primer).

## At a glance {#mmap-glance}

| Frontend | Class | Direction | Port |
|-------------------|--------------------------------------|---------------------------|--------|
| Wishbone master bridge | `LitePCIeWishboneMaster` | Host BAR0 accesses to the SoC bus | Slave |
| Wishbone slave bridge | `LitePCIeWishboneSlave` | SoC Wishbone cycles to host memory | Master |
| AXI slave bridge | `LitePCIeAXISlave` | SoC AXI bursts to host memory | Master |
| MSI | `LitePCIeMSI` | Interrupts, one message vector | PHY |
| Multi-vector MSI | `LitePCIeMSIMultiVector` | Interrupts, one vector per interrupt | PHY |
| MSI-X | `LitePCIeMSIX` | Interrupts as MemWr TLPs, up to 64 vectors | Master |

## BAR0 {#mmap-bar0}

The device exposes one memory region to the host: BAR0, a 32-bit, non-prefetchable memory BAR.
Its size is the `bar0_size` parameter of the PHY: 1 MiB by default, 64 KiB on the CertusPro-NX
PHY. On the Xilinx hard IPs it is a power of two from 128 bytes to 2 GiB.

The host maps BAR0 at an address of its choice during enumeration. The core never needs to know
it: the depacketizer keeps only the address bits below the BAR0 size (see
[Depacketizer](#core-depacketizer)). Every slave therefore sees offsets from 0 to the BAR0 size.

## Wishbone master bridge {#mmap-wishbone-master}

The Wishbone master bridge gives the host access to the SoC bus through BAR0. Each host access
becomes a 32-bit Wishbone cycle at the BAR0 offset plus a base address, as the figure below
shows. In a LiteX SoC the base is the start of the CSR region, so BAR0 offsets are the register
offsets of `csr.h`.

![Host access to BAR0. Follow the cyan arrow: the depacketizer gives the BAR0 offset, and the
Wishbone master adds the base address of the CSR region before driving the SoC
bus.](mmap_bar0.svg)

The bridge serves the two kinds of request differently:

- **Write**: the bridge writes each DW of the request in turn, to consecutive bus addresses. The
  first DW takes the first byte enables of the request, the last DW its last byte enables, and the
  DWs in between all four. A DW without any byte enable is skipped, so a zero-length write writes
  nothing. A 64-bit write therefore writes two registers, and a byte write changes only its byte.
- **Read**: the bridge reads each DW of the request in turn, with the byte enables of the
  request, and returns one CplD per DW. Reads of several DWs and zero-length reads are supported.

The bridge takes a slave port of the crossbar with an address decoder that accepts every address
by default. Several slaves can share BAR0 by giving each bridge a decoder for its part of the
offsets. Its class is also available under its first name, `LitePCIeWishboneBridge`.

| Parameter | Default | Meaning |
|----------------------|----------------|-----------------------------------------------|
| `endpoint` | none | The endpoint |
| `address_decoder` | all addresses | Function of the BAR0 offset: true when served |
| `base_address` | `0x00000000` | Bus address of BAR0 offset 0 |
| `qword_aligned` | `False` | Payload on 64-bit boundaries (Cyclone V PHY) |

## Bridges to host memory {#mmap-slaves}

Two bridges let FPGA logic read and write host memory as if it were on the SoC bus, as the
figure below shows. Both take master ports of the crossbar and need a host address: the host
allocates the memory and gives its bus address to the design, through a register for example.

![FPGA access to host memory. Follow the cyan arrows: a SoC master drives the Wishbone slave or
the AXI slave, which issue MemRd and MemWr TLPs through master ports of the
crossbar.](mmap_slave.svg)

### Wishbone slave bridge {#mmap-wishbone-slave}

The Wishbone slave bridge turns each 32-bit Wishbone cycle into a request of one DW. A write
becomes a MemWr; the cycle ends as soon as the request is accepted, since PCIe writes are posted.
A read becomes a MemRd; the cycle ends with the data of its completion. The class is
`LitePCIeWishboneSlave`.

A cycle that gets no answer within 65536 clock cycles ends with the Wishbone error signal. A
processor on the SoC bus therefore never hangs on a host that does not answer. A read that the
host answers with an error completion, Unsupported Request or Completer Abort, ends the same way:
the cycle ends with the acknowledge and error signals, and the read data are all-ones, as for a
timeout.

| Parameter | Default | Meaning |
|-----------------|----------|-------------------------------------------------|
| `address_width` | 32 | Wishbone address width |
| `data_width` | 32 | Wishbone data width; only 32 is supported |
| `addressing` | `"word"` | Wishbone addresses in words or bytes |
| `qword_aligned` | `False` | Payload on 64-bit boundaries (Cyclone V PHY) |

### AXI slave bridge {#mmap-axi-slave}

The AXI slave bridge serves full AXI bursts. Each write or read burst becomes a descriptor for a
DMA Writer or Reader built without a table: the burst address and its length in bytes. The DMA
then splits it into requests, as for any descriptor (see [Splitter](#dma-splitter)). The class is
`LitePCIeAXISlave`.

The bridge handles one write burst and one read burst at a time, with 32-bit host addresses and
incrementing bursts. It answers a write with an OKAY response once it has taken the last data
beat, before the data reaches host memory, and it ignores the write strobes: every byte of the
burst is written. Its parameters are the AXI `data_width` (32 by default) and `id_width` (1).

## Interrupts {#irq}

The host learns about events of the device through interrupts: in LitePCIe, a DMA descriptor done
or a user event. PCIe carries them as MSI or MSI-X messages, memory writes to an address the host
chose. LitePCIe offers three controllers, picked at build time.

| Controller | Messages | Host side |
|------------------|-------------------------------------|------------------------------------------|
| MSI | One vector for all interrupts | Driver reads `vector`, writes `clear` |
| Multi-vector MSI | One vector per interrupt | One handler per vector |
| MSI-X | One table entry per interrupt | One handler per vector, table in BAR0 |

All three have an `irqs` input of `width` bits, one bit per interrupt, and an `enable` register
with one bit per interrupt. An interrupt whose enable bit is 0 is ignored. The Linux driver is
built against the `csr.h` of the design: it asks for up to 32 MSI-X vectors when that file
defines the MSI-X registers, and up to 32 MSI vectors otherwise.

### MSI {#irq-msi}

The MSI controller keeps one pending bit per interrupt in its `vector` register and sends one
message for any number of new interrupts, as the figure below shows. The PHY turns each element
of its MSI stream into an MSI request of the hard IP. The class is `LitePCIeMSI`.

![MSI. Follow the dotted path: the driver reads the `vector` register through BAR0 to find the
sources, then writes the handled bits to `clear`.](irq_msi.svg)

The driver handles an MSI in three steps:

1. Read `vector` and `enable`, and keep the enabled pending bits.
2. Serve each source: for a DMA engine, read its loop status.
3. Write the served bits to `clear`.

A bit of `irqs` that stays high keeps its pending bit set, so the input is a pulse for each event.
The DMA engines give such pulses.

### Multi-vector MSI {#irq-msi-multi}

The multi-vector controller sends one message per pending interrupt, with the interrupt number as
the vector, lowest number first. A pending bit clears when its message is sent, so `enable` is
its only register. The class is `LitePCIeMSIMultiVector`.

The host must grant one vector per interrupt, and the PHY must pass the vector number to its hard
IP. The soft PHY does both, with its `msi_vectors` parameter. The 7-Series and Stratix V PHYs
configure their hard IP for a single vector, and the UltraScale, UltraScale+ (issue #243) and
Cyclone V PHYs do not pass the vector number on. On these PHYs, use the single-vector MSI, or
MSI-X where the PHY has it.

### MSI-X {#irq-msix}

The MSI-X controller writes the messages itself as MemWr TLPs, through a master port of the
crossbar, as the figure below shows. The host writes the address and data of each vector into the
MSI-X table, which sits in BAR0 among the registers. The class is `LitePCIeMSIX`.

![MSI-X. Follow the cyan path: the controller picks the lowest pending interrupt, reads its four
table words and sends the message as a MemWr; the host fills the table through BAR0 (dotted
path).](irq_msix.svg)

Each vector has four 32-bit table words: lower address, upper address, message data and vector
control. Bit 0 of vector control masks the vector; all vectors are masked at reset. The pending
bits form the Pending Bit Array (PBA), the `pba` register.

The controller sends one message at a time:

1. It picks the lowest pending interrupt that it has not skipped.
2. It reads the four table words of its vector.
3. If the vector is masked, it skips the interrupt and leaves it pending.
4. Otherwise it sends a MemWr of one DW, the message data, to the message address, and clears
   the pending bit.

Once every pending interrupt has been skipped, the controller scans them again, so an interrupt
unmasked by the host is sent. On an endpoint with 32-bit addresses, a vector with a non-zero upper
address cannot be reached: the controller handles it as masked instead of writing to a truncated
address.

| Parameter | Default | Meaning |
|--------------------|---------|-------------------------------------------------|
| `endpoint` | none | The endpoint, for its crossbar master port |
| `width` | 32 | Number of vectors, up to 64 |
| `default_enable` | 0 | 1: all interrupts enabled at reset |
| `csr_ordering` | `"big"` | Ordering of the registers wider than 32 bits |

The host reads the PBA as little endian 64-bit words: bit N is vector N, vectors 0 to 31 in the
32-bit word at the PBA offset. With 64 vectors and the default big ordering, the upper half of a
64-bit register is at the lower address, so the controller swaps the two halves of the PBA. Pass
the `csr_ordering` of the SoC; the generator passes its own.

The hard IP advertises where the table and the PBA are in BAR0, so the register map must put them
there. In MSI-X mode (`msi_type="msi-x"` on the PHY), the 7-Series PHY advertises 32 vectors, the
table at BAR0 offset `0x2000` and the PBA at `0x1808`. The CertusPro-NX PHY programs the same two
offsets.

These offsets follow from the register map, as the table below shows: the CSR region starts at
BAR0 offset 0, each register bank takes a page of `0x800` bytes (the LiteX default), and the PBA
is the third 32-bit word of the `pcie_msi` bank. The generator and LiteX `add_pcie` with
`msi_type="msi-x"` both reserve the two locations. `add_pcie` stops with an error when the
register paging does not divide the offsets or when another bank already holds a location.

| Bank | Location | BAR0 offset | Content |
|----------------------|----------|-------------|---------------------------------------|
| `pcie_msi` | 3 | `0x1800` | `enable`, then `pba` at `0x1808` |
| `pcie_msi_table` | 4 | `0x2000` | Table, four words per vector |

## Interrupt numbering {#irq-numbering}

The designs number the interrupts by sorting their names: each DMA engine gives an interrupt
named after its channel and direction. The table below shows the result for the two channels of
the KC705 target. Each number is also written to the headers as a constant, which the driver
reads to know which bit belongs to which engine.

| Interrupt | Constant | Number |
|------------------|-------------------------------|--------|
| DMA0 Reader | `PCIE_DMA0_READER_INTERRUPT` | 0 |
| DMA0 Writer | `PCIE_DMA0_WRITER_INTERRUPT` | 1 |
| DMA1 Reader | `PCIE_DMA1_READER_INTERRUPT` | 2 |
| DMA1 Writer | `PCIE_DMA1_WRITER_INTERRUPT` | 3 |

The generator follows the same order and adds the user interrupts of its `msi_irqs` input after
them: from bit 16, with MSI as with MSI-X (16 user interrupts at most).
[Integration](#integration) gives the details of the generator.

## PHY support {#irq-phy-support}

MSI and multi-vector MSI need the MSI interface of the hard IP; MSI-X needs only the crossbar and
a hard IP that advertises the MSI-X capability. On 7-Series, the generator option `msi_x` also
puts the hard IP in MSI-X mode. Three cases have restrictions:

- **Gowin GW5A**: the PHY requests an MSI on the rising edge of the stream `valid`, so two
  messages back to back may stall (issue #244).
- **Lattice CertusPro-NX**: the hard IP wrapper has no MSI request interface, and the PHY
  disables its MSI capability. Use MSI-X: `add_pcie` with its default MSI type gets no
  interrupts on this PHY. The generator selects MSI-X for it by default.
- **UltraScale and UltraScale+**: the PHYs have no MSI-X capability. Their MSI path ignores the
  vector of the request and sends one vector chosen from the Multiple Message Enable of the host
  (issue #243): use the single-vector MSI there.

## Registers {#mmap-irq-registers}

The interrupt controllers have a register bank, `pcie_msi`, described in
[MSI registers](#reg-pcie-msi) and [MSI-X registers](#reg-pcie-msix). The MSI-X table is the
`pcie_msi_table` memory next to it. The bridges have no registers; the PHY reports in its own
bank whether the host enabled MSI or MSI-X and bus mastering ([PHY status](#reg-pcie-phy)).

## In the code {#mmap-irq-code}

The files below are in the `litepcie/` directory.

| File | Main classes | Role |
|---------------------------------|--------------------------------------------|-------------------|
| `frontend/wishbone.py` | `LitePCIeWishboneMaster`, `LitePCIeWishboneSlave` | Wishbone bridges |
| `frontend/axi.py` | `LitePCIeAXISlave` | AXI slave bridge |
| `core/msi.py` | `LitePCIeMSI`, `LitePCIeMSIMultiVector`, `LitePCIeMSIX` | Interrupt controllers |

The tests are `test/test_wishbone.py`, `test/test_wishbone_read_pipeline.py` and
`test/test_msix.py`.

Where to go next: [Precision Time Measurement](#ptm) for the last frontend,
[Linux driver and tools](#software) for the host side of BAR0 and interrupts,
[Integration](#integration) to wire the interrupts of a design.
