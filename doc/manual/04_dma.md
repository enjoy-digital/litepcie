# Scatter-gather DMA {#dma}

This chapter describes the DMA frontend: the channels that move streams of data between the FPGA
and host memory without the host processor. Read it to connect user logic to a DMA channel, to
choose its plug-ins, or to write software that programs it. The driver that uses it on Linux is
described in [Linux driver and tools](#software).

## At a glance {#dma-glance}

| Item | Value |
|-------------------|----------------------------------------------------------------------|
| Top-level class | `LitePCIeDMA` (`litepcie/frontend/dma.py`) |
| Directions | Writer: FPGA stream to host memory; Reader: host memory to FPGA stream |
| Descriptors | 32-bit or 64-bit address, 24-bit length in bytes, two control bits |
| Descriptor table | 256 entries by default, Prog and Loop modes |
| TLPs | MemWr up to the Max Payload Size, MemRd up to the Max Read Request Size |
| Interrupts | One per descriptor, unless disabled in the descriptor |
| User streams | `sink` (Writer) and `source` (Reader), `data` of `data_width` bits |
| Plug-ins | Loopback, synchronizer, buffering, monitor, status writer |
| Channels | One `LitePCIeDMA` per channel; the driver handles up to 8 |

## Overview {#dma-overview}

A DMA channel has two independent engines, as the figure below shows. The Writer stores the
stream it receives from user logic into host memory with MemWr TLPs. The Reader fetches host
memory with MemRd TLPs and delivers the completion data as a stream. Each engine has its own
descriptor table, splitter and crossbar master port.

![DMA channel. Follow the cyan streams: user logic writes into `sink` and reads from `source`
through the plug-ins; on the right, the Writer sends MemWr TLPs, and the Reader sends MemRd TLPs
and receives their CplD.](dma_overview.svg)

Software tells each engine where to move data with descriptors: a host address and a length.
Scatter-gather means that a transfer can span many host buffers, one descriptor each, that do not
have to be contiguous. The Linux driver uses 256 buffers of 8 KiB per direction.

The plug-ins sit between the engines and user logic. They are optional and built in at
elaboration time; [Plug-ins](#dma-plugins) describes them.

## Usage {#dma-usage}

The example below builds one channel with a 1 KiB buffer in each direction and the loopback
plug-in, as the KC705 target does. User logic then connects to the `sink` and `source` streams
of the channel.

```python
from litepcie.frontend.dma import LitePCIeDMA

self.pcie_dma0 = LitePCIeDMA(self.pcie_phy, self.pcie_endpoint,
    with_buffering = True, buffering_depth=1024,
    with_loopback  = True)

# User logic: a stream to the host, a stream from the host.
self.comb += my_source.connect(self.pcie_dma0.sink)
self.comb += self.pcie_dma0.source.connect(my_sink)
```

| Parameter | Default | Meaning |
|------------------------------------|---------|-----------------------------------------|
| `with_table` | `True` | Descriptor tables; without them, a `desc_sink` stream per engine |
| `table_depth` | 256 | Descriptors per table |
| `address_width` | 32 | Host address width: 32 or 64 |
| `data_width` | PHY | Width of the user streams, in bits |
| `with_writer`, `with_reader` | `True` | Build the Writer, the Reader |
| `with_loopback` | `False` | Loopback plug-in (needs both engines) |
| `with_synchronizer` | `False` | Synchronizer plug-in (needs both engines) |
| `with_buffering` | `False` | Buffering plug-in |
| `buffering_depth` | 2048 | Buffering FIFO size, in bytes, for both directions |
| `writer_buffering_depth` | none | Writer FIFO size, overrides `buffering_depth` |
| `reader_buffering_depth` | none | Reader FIFO size, overrides `buffering_depth` |
| `with_monitor` | `False` | Overflow and underflow counters on the user streams |
| `with_status` | `False` | Status writer to host memory (needs both engines) |
| `status_width` | 32 | Loop status width of the status writer: 32 or 64 |

A user stream narrower than the PHY is converted by each engine. Each word of a user stream is a
whole number of DWs, and the low two bits of a descriptor length are ignored: lengths are
multiples of 4 bytes.

## Descriptors {#dma-descriptors}

A descriptor is written through two registers of the engine, as the figure below shows. The first
write sets the 64-bit `value` register: address bits 31:0, length and control bits. The write to
`we` then pushes the descriptor into the table, with address bits 63:32 when the address width is
64.

![Descriptor registers. Look at the order: `value` holds the low address, the length and the two
control bits; the write to `we` gives the high address and pushes the
descriptor.](dma_descriptor.svg)

| Field | Bits | Meaning |
|------------------|-------|----------------------------------------------------------------|
| `address_lsb` | 31:0 | Host address bits 31:0, in bytes |
| `length` | 55:32 | Length in bytes, up to 16 MiB minus 1 |
| `irq_disable` | 56 | No interrupt when this descriptor completes |
| `last_disable` | 57 | Ignore stream boundaries for this descriptor |

The `last_disable` bit decides how a descriptor relates to the packets of the user stream:

- **Writer, `last_disable` at 0**: a `last` on the user stream ends the descriptor with the
  current write request; the rest of its length is skipped. Each stream packet then starts a new
  host buffer, with the restrictions that [Writer](#dma-writer) lists.
- **Reader, `last_disable` at 0**: the Reader sets `last` on the final word of the descriptor, so
  each host buffer becomes one stream packet.
- **`last_disable` at 1**: descriptors and packets are independent; the data flows as one
  continuous stream. The Linux driver sets it on every descriptor.

## Descriptor table {#dma-table}

The table is a FIFO of descriptors that software fills and the engine empties. It works in two
modes, selected by the `loop_prog_n` register, as the figure below shows. The class is
`LitePCIeDMAScatterGather`.

![Descriptor table. Follow the dotted path: in Loop mode, each descriptor that leaves the table is
written back into it, so the same ring of host buffers is used again and
again.](dma_table.svg)

- **Prog mode** (`loop_prog_n` at 0): software pushes descriptors, and each one is executed once.
  The engine stops when the table is empty.
- **Loop mode** (`loop_prog_n` at 1): each descriptor taken by the engine is pushed back into the
  table. The engine runs through the ring of buffers until it is disabled.

The usual sequence programs the ring in Prog mode, then switches to Loop mode and enables the
engine. The Linux driver does it in six steps for each engine:

1. Disable the engine (`enable` at 0).
2. Reset the table (write `reset`).
3. Select Prog mode (`loop_prog_n` at 0).
4. Push the 256 descriptors (`value`, then `we`), interrupts enabled on one buffer out of 32.
5. Select Loop mode (`loop_prog_n` at 1).
6. Enable the engine (`enable` at 1).

### Loop status {#dma-loop-status}

Software follows the progress of an engine with the `loop_status` register. In Loop mode, its
`index` field is the position in the table of the last completed descriptor, and its `count`
field the number of times the engine went back to the first descriptor. Both fields are 16 bits
wide and wrap.

`count` times the table size plus `index` is the rank of the last completed buffer, counted from
0; the Linux driver uses this value as its hardware counter. The register reads 0 both before and
just after the first descriptor completes, so software compares successive values rather than
reading one alone.

The loop status is the reference for software, not the interrupts. An interrupt only tells that
the status moved; a late or merged interrupt loses nothing, because the next read of
`loop_status` gives the exact position. The `level` register gives the number of descriptors in
the table, and bit 1 of `enable` reads 1 when the engine is idle.

## Splitter {#dma-splitter}

A descriptor can be 16 MiB long, but a TLP carries at most the Max Payload Size for a write and
the Max Read Request Size for a read. The splitter cuts each descriptor into requests of these
sizes, as the PHY reports them (see [The PHY contract](#core-phy-contract)). The class is
`LitePCIeDMADescriptorSplitter`.

The splitter increments the address by the request size at each step, and the last request takes
the remainder. It does not check the 4 KiB boundaries that a request must not cross. A descriptor
that starts on a 4 KiB boundary, as a buffer allocated in memory pages does, never makes a request
cross one.

## Writer {#dma-writer}

The Writer sends a write request only when its data FIFO holds the whole payload of the request,
or a `last` of the user stream (see below). The stream from user logic fills the FIFO; the Writer
then sends the request header and its payload without a gap. The FIFO holds four requests of 512
bytes. The class is `LitePCIeDMAWriter`.

The Writer raises its interrupt when the last request of a descriptor leaves, unless the
descriptor disables it. While the Writer is disabled, it accepts and drops the user stream, and
its FIFO and splitter stay in reset.

A descriptor that a `last` of the user stream cuts short (`last_disable` at 0) behaves
differently, which matters for packet-based user logic:

- The write request that holds the `last` leaves as soon as the `last` is in the FIFO, with the
  data received so far: the end of a packet does not wait for the next one.
- That request keeps its full length. The Writer repeats the last word up to its end, and nothing
  tells the host how many bytes are valid: the stream must carry its own length or framing. The
  `progress_bytes` signal of the Writer also counts the full length of the request.
- The Writer raises its interrupt for this descriptor, unless the descriptor disables it, and the
  loop status moves, as for a descriptor that runs to its end.

## Reader {#dma-reader}

The Reader sends a read request only when its data FIFO has room for the whole answer. It counts
the words requested and not yet delivered, so the completions never overflow the FIFO. The host
answers at its own pace and user logic reads at its own pace. The class is
`LitePCIeDMAReader`.

The FIFO holds four times the data of all pending reads: 4 x `max_pending_requests` x 512 bytes.
The TLP controller of the endpoint returns the completions in request order (see
[TLP controller](#core-controller)), so the stream follows the host buffers in order.

A descriptor completes when the last completion of its last read enters the Reader. The loop
status then moves and the interrupt fires, unless the descriptor disables it. At that point
software can reuse the host buffer, even if user logic has not yet read the data out of the FIFO.

The Reader marks the first word of each descriptor with `first` on its output stream. When the
user stream is narrower than the PHY, the Reader converter drops the invalid words at the end of
a completion, so a length that is not a multiple of the beat size gives no padding.

## Plug-ins {#dma-plugins}

The plug-ins are stream stages between the engines and user logic. Each one takes the streams of
the stage below and gives new ones to the stage above. The figure below shows their order when
all are built.

![DMA plug-ins. Look at the order: the loopback is closest to the engines, then the synchronizer,
then the buffering next to user logic; each plug-in passes both streams.](dma_plugins.svg)

### Loopback {#dma-loopback}

The loopback connects the Reader stream to the Writer stream when its `enable` register is set.
Data read from host memory is written back to host memory, which tests the driver, the link and
both engines without user logic. While it is enabled, user logic receives nothing and its writes
are not taken. The class is `LitePCIeDMALoopback`.

### Synchronizer {#dma-synchronizer}

The synchronizer holds both streams until a time reference arrives, for applications where the
start of the data must be aligned on an event, such as a PPS (pulse per second) signal. It
releases them on the `pps` input when its `ready` input is high. The class is
`LitePCIeDMASynchronizer`; its two registers select the behaviour.

| `bypass` | `mode` | Behaviour |
|----------|--------|-------------------------------------------------------------------|
| 1 | any | Streams always connected |
| 0 | `0b00` | Streams blocked |
| 0 | `0b01` | Released on the first PPS with Reader data available |
| 0 | `0b10` | Released on the first PPS |

While the streams are blocked, the Reader stream is held and user data for the Writer is dropped.
A design with the synchronizer therefore needs software to set `bypass` or a mode before any
data flows.

### Buffering {#dma-buffering}

The buffering plug-in adds a FIFO in each direction. The link is shared, so the engines deliver
and accept data in bursts; the FIFOs smooth these gaps for user logic that runs at a fixed rate
and cannot stall. The class is `LitePCIeDMABuffering`.

The FIFO size is fixed at build time, in bytes. Software can lower the usable depth at run time
with the `depth` field of the control register, to trade latency against margin. The status
register gives the FIFO level, in bytes as well. Both values count whole beats of the user
stream; the gateware descriptions of these fields, and so the register reference, call them
words, but the code works in bytes.

| Field | Meaning |
|--------------|---------------------------------------------------------------------------|
| `depth` | Usable depth, in bytes, up to the build-time size |
| `scratch` | 4 bits free for software |
| `level_mode` | 0: present level; 1: minimum (Reader) or maximum (Writer) since last read |

In `level_mode` 1, the Reader FIFO reports its lowest level and the Writer FIFO its highest one,
reset when software writes the status register. They tell how close user logic came to an underflow or an
overflow. Each FIFO is reset while its engine is disabled.

### Monitor {#dma-monitor}

The monitor counts the cycles where user logic offers data that the Writer does not take
(overflows) and the cycles where user logic waits for Reader data (underflows). The counters are
16 bits wide; software resets them and latches their value with two strobe registers. They show
whether a fixed-rate design loses data.

### Status writer {#dma-status}

The status writer copies the state of the channel into host memory, so software can poll memory
instead of reading registers through the link. It writes a block of 16 words of 32 bits at the
address of its `address_lsb` and `address_msb` registers. The class is `LitePCIeDMAStatus`.

| Word | Content |
|------|----------------------------------------------------------------------------|
| 0 | Sync word `0x5aa55aa5` |
| 1 | Writer loop status |
| 2 | Reader loop status |
| 3 | Writer loop status bits 63:32 (`status_width=64`), else reserved |
| 4 | Reader loop status bits 63:32 (`status_width=64`), else reserved |
| 5 to 7 | Reserved |
| 8 to 15 | External status from user logic (`external_status`) |

With a 64-bit status width, words 3 and 4 count the wraps of the 16-bit loop count, so software
gets a loop count that does not wrap. The `update` field of the control register selects the
event that writes the block.

| `update` | Event |
|----------|---------------------------------------------------------|
| `0b00` | External: `external_update` from user logic |
| `0b01` | Writer interrupt |
| `0b10` | Reader interrupt |
| `0b11` | Software: each write of the control register |

The block is written only when the `enable` field is set. It goes out as MemWr TLPs of one beat
each, through a write-only port of the crossbar.

## Interrupts {#dma-irq}

Each engine has one `irq` output, a pulse per completed descriptor. A design connects them to
the MSI or MSI-X controller; [Memory-mapped bridges and interrupts](#mmap-irq) describes how
they reach the host. The driver disables the interrupt on 31 descriptors out of 32, so a 256
descriptor ring raises 8 interrupts per loop in each direction.

## Multiple channels {#dma-channels}

A design with several channels builds one `LitePCIeDMA` per channel. Each channel takes one
read-only and one write-only master port of the crossbar, and has its own registers and
interrupts. The Writers of all channels share the write-only arbiter; the Readers share the TLP
controller and its tags. [Integration](#integration) gives the interrupt numbering.

## Registers {#dma-registers}

Each channel has a register bank, `pcie_dma0` to `pcie_dmaN`. The table below groups the
registers; [DMA registers](#reg-pcie-dma) gives their offsets and fields.

| Registers | Role |
|---------------------------------------|----------------------------------------------------|
| `writer_enable`, `reader_enable` | Bit 0: enable; bit 1: idle (read) |
| `*_table_value`, `*_table_we` | Descriptor, push |
| `*_table_loop_prog_n` | Prog or Loop mode |
| `*_table_loop_status`, `*_table_level` | Progress, descriptors in the table |
| `*_table_reset` | Empty the table |
| `loopback_enable` | Loopback plug-in |
| `synchronizer_bypass`, `synchronizer_enable` | Synchronizer plug-in |
| `buffering_*_fifo_control`, `*_status` | Buffering plug-in |
| `*_monitor_*` | Monitor counters |
| `status_control`, `status_address_*` | Status writer |

## In the code {#dma-code}

| Class | Role |
|-----------------------------------------------|-------------------------------------------|
| `LitePCIeDMA` | Channel: engines, plug-ins, user streams |
| `LitePCIeDMAWriter` | Stream to host memory (MemWr) |
| `LitePCIeDMAReader` | Host memory to stream (MemRd), completion tracking |
| `LitePCIeDMAScatterGather` | Descriptor table, Prog and Loop modes, loop status |
| `LitePCIeDMADescriptorSplitter` | Descriptors cut to the Max Payload or Read Request Size |
| `LitePCIeDMAReaderDownConverter` | Reader width conversion without trailing padding |
| `LitePCIeDMALoopback` | Reader to Writer loopback |
| `LitePCIeDMASynchronizer` | Stream release on PPS |
| `LitePCIeDMABuffering` | FIFOs with run-time depth |
| `LitePCIeDMAStatus` | Status block written to host memory |

All are in `litepcie/frontend/dma.py`. The tests are `test/test_dma.py` (64 to 512-bit
datapaths, 32-bit and 64-bit addresses, lengths that are not a multiple of the beat),
`test/test_dma_reader_retire.py`, `test/test_dma_reader_retire_widths.py` and
`test/test_dma_status.py`.

Where to go next: [Memory-mapped bridges and interrupts](#mmap-irq) for the interrupts,
[Linux driver and tools](#software) for the software side, [Performance and resources](#performance)
for throughput.
