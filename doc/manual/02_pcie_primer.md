# PCI Express in a nutshell {#pcie-primer}

This chapter explains PCI Express to an FPGA engineer who has never read the specification. After
the topology and the layers, it follows the data from the wire up to the software: the lanes, the
training of the link, the packets and their acknowledgement, the configuration space and the
interrupts.

Each section starts with the idea, then gives the mechanism, and ends with the part of LitePCIe
that implements it.

The reference is the PCI Express Base Specification 4.0, and the section numbers given as "PCIe
section 4.2.6" follow it. The physical layer is described for Gen1 and Gen2 first, because every
link starts at 2.5 GT/s; [Generations at a glance](#primer-gens)
lists what changes at Gen3 and Gen4.

## The topology {#primer-topology}

PCI Express is a tree of point-to-point links, not a shared bus. At the root sits the *root
complex*: the part of the host chipset that connects the CPU and the memory to the PCI Express
links.

Each of its *root ports* drives one link. A *switch* fans one link out into several, and an
*endpoint*, such as a network card or an FPGA, terminates a branch. The figure below shows a small
tree.

![A PCI Express tree. The root complex connects the CPU and the memory to its root ports; each
link joins two ports; a switch adds links. Each function is named by its bus, device and function
numbers (example numbering).](primer_topology.svg)

Software names each function by three numbers, written `bus:device.function`: this is the *BDF*,
also called the requester ID or completer ID in packets. The bus is 8 bits, the device 5 bits and
the function 3 bits.

The host assigns the bus numbers when it enumerates the tree, so they can change from one machine
or one boot to the next.

Traffic flows in both directions. The host reads and writes the registers of an endpoint, and an
endpoint can read and write the host memory directly: this is *bus mastering*, the basis of DMA.

In LitePCIe, the FPGA is normally an endpoint (`LitePCIeEndpoint`). On Xilinx 7-Series,
UltraScale and UltraScale+ it can also be a root port, driving a downstream device such as an NVMe
drive (`LitePCIeRootPort`, see [Core architecture](#core-architecture)).

## Three layers {#primer-layers}

A PCI Express port is a small network stack. Each layer solves one problem and talks only to the
same layer on the other side of the link, through the layer below it. The figure below shows the
three layers and the units each pair exchanges.

![The three layers of a PCI Express port. Each layer exchanges its own units with its peer: TLPs
at the top, DLLPs and the sequence numbers and LCRC of the TLPs in the middle, symbols and ordered
sets at the bottom.](primer_layers.svg)

| Layer | Moves | Main jobs |
|-------------------|------------------------|-----------------------------------------------------|
| Transaction layer | TLPs | Build and parse requests and completions, match completions to requests, configuration space |
| Data link layer | DLLPs, TLP envelopes | Number, protect and acknowledge the TLPs, replay the bad ones, exchange flow control credits |
| Physical layer | Symbols, ordered sets | Detect the partner, train the link, code and scramble, compensate the clocks |

The specification describes the transaction layer in chapter 2, the data link layer in chapter 3
and the physical layer in chapter 4.

In LitePCIe, a hard IP implements the physical and data link layers and part of the transaction
layer: the configuration space and the flow control. The core implements the rest of the
transaction layer, on raw TLPs. The soft PHY implements the physical and data link layers and the
configuration space itself, in `litepcie/phy/soft/` ([Soft PHY](#soft-phy)).

## The wire {#primer-wire}

A *lane* is two differential pairs, one per direction, so both directions run at the same time at
the full rate. A *link* groups 1, 2, 4, 8 or 16 lanes, written x1 to x16; the data are spread
over the lanes byte by byte. The figure below shows a link and its side signals.

![A PCI Express link. Each lane has one transmit pair per side, AC coupled. The slot also brings a
100 MHz reference clock and the PERST# reset.](primer_link.svg)

The pairs are AC coupled: a series capacitor blocks the DC level, so each side sets its own common
mode voltage. The data must stay DC balanced on average, which is one job of the line coding.

A port detects its partner by measuring the load on its transmit pairs: a receiver presents a
termination, an empty slot does not. This *receiver detection* is the first step of a link, and
it also tells which lanes are connected.

The slot provides a 100 MHz reference clock to both sides, and many hosts modulate it with spread
spectrum clocking (SSC) to spread the radiated energy. A receiver recovers the clock of its
partner from the data transitions (clock and data recovery, CDR). Clock compensation, described in
[Coding and scrambling](#primer-coding), absorbs the remaining difference.

PERST# is the fundamental reset of the slot. The host holds it while the power and the reference
clock settle, then releases it. From then on, the device has a short time, set by the
specification, to train its link and answer configuration requests. An FPGA that is still loading
its bitstream at that point misses the enumeration.

Board layout is forgiving. A receiver detects swapped wires in a pair and inverts its input
(*polarity inversion*). The lane numbers are negotiated, so a link can be wired in reverse order
(*lane reversal*) when one of the two ports supports it.

In LitePCIe, the FPGA transceivers are the electrical layer: serializer, CDR, termination and
electrical idle. A hard IP drives them itself; the soft PHY drives them through LiteICLink
(`litepcie/phy/soft/serdes/`).

## Coding and scrambling {#primer-coding}

A serial link needs three things from its data: as many ones as zeros (DC balance), frequent
transitions (for clock recovery) and a way to mark boundaries that data can never imitate.

Gen1 and Gen2 use 8b/10b coding: every byte is sent as a 10-bit *symbol*. The data symbols are
written Dx.y; a few extra codes, the *K symbols* (Kx.y), never appear in data and serve as
markers.

| Symbol | Code | Use |
|--------|-------|---------------------------------------------------------------------|
| COM | K28.5 | Comma: symbol alignment, first symbol of every ordered set |
| STP | K27.7 | Start of a TLP |
| SDP | K28.2 | Start of a DLLP |
| END | K29.7 | End of a good TLP or DLLP |
| EDB | K30.7 | End bad: a nullified TLP |
| PAD | K23.7 | Padding, and unassigned link or lane numbers in TS1 and TS2 |
| SKP | K28.0 | Skip: clock compensation |
| FTS | K28.1 | Fast training sequence, to leave L0s |
| IDL | K28.3 | Electrical idle ordered set |
| EIE | K28.7 | Electrical idle exit ordered set (5.0 GT/s) |

Long runs of identical data would still concentrate the radiated energy at a few frequencies. The
transmitter therefore *scrambles* each data symbol: it XORs it with the output of a 16-bit LFSR
(polynomial X^16^ + X^5^ + X^4^ + X^3^ + 1). The receiver runs the same LFSR and removes it.

K symbols and the symbols of TS1 and TS2 are not scrambled. COM resets both LFSRs and SKP does
not advance them, so both sides stay in step. PCIe section 4.2.1 describes the coding and the scrambling.

Clock compensation uses SKP. The two sides may run up to 600 ppm apart, so each transmitter
regularly inserts a *SKP ordered set*: COM followed by three SKP symbols. Each receiver passes the
data through an *elastic buffer* that crosses from the recovered clock to its own clock. It drops
or adds SKP symbols to stay half full.

Gen3 and Gen4 replace 8b/10b by 128b/130b coding: 16 bytes are sent as one *block* with a 2-bit
sync header that says whether the block holds data or an ordered set. The overhead drops from 20%
to about 1.5%. The scrambler becomes a 23-bit LFSR, and packets are framed by tokens inside the
data blocks instead of K symbols.

In LitePCIe, the hard IPs do all of this. The soft PHY implements it in a few files
([Soft PHY](#soft-phy)):

| File | Content |
|--------------------------------------------|----------------------------------------------|
| `litepcie/phy/soft/coding.py` | 8b/10b code tables and receive checker |
| `litepcie/phy/soft/scrambler.py` | Gen1 and Gen2 scrambler |
| `litepcie/phy/soft/datapath.py` | SKP insertion and removal, elastic buffer |
| `litepcie/phy/soft/gen3.py` | 128b/130b scrambler, gearboxes, block alignment |

## Link training and the LTSSM {#primer-ltssm}

A receiver cannot decode anything until it has locked on the bits and found the symbol
boundaries, and the two ports must agree on the width, the lane numbers and the rate. *Training*
gives them each of these in turn. The ports exchange *ordered sets*, fixed patterns that start
with COM:

- TS1 and TS2, the *training sequences*, carry the link and lane numbers, the rates a port
  supports and control bits that request a Hot Reset, a disabled link, a loopback or no
  scrambling.
- The electrical idle ordered set (EIOS) announces that the transmitter goes quiet; the electrical
  idle exit ordered set (EIEOS) helps the receiver wake up at 5.0 GT/s and above.
- The SKP ordered set compensates the clocks, and the FTS ordered set retrains the receiver
  quickly on the exit of L0s.

The Link Training and Status State Machine (LTSSM) is the heart of the physical layer. It decides
when to detect, when to train and when the link can carry packets. The figure below shows its
main states; each one is a group of substates in the specification, described in PCIe section
4.2.6.

![Simplified LTSSM. Follow the thick arrows: a port detects its partner and trains through Polling
and Configuration into L0. Recovery retrains the link, changes its rate and brings it back from
L1; when it fails, the port returns to Detect. L0s, L2 and the test states are left
out.](primer_ltssm.svg)

| State | What happens |
|----------------------|---------------------------------------------------------------------|
| Detect | Receiver detection on each transmit pair; Detect.Quiet then Detect.Active |
| Polling | Bit lock and symbol lock on TS1, polarity inversion, then TS2 (Polling.Active, Polling.Configuration) |
| Configuration | Link number, lane numbers and width agreed, then logical idle (Configuration.Idle) |
| L0 | The link is up: TLPs and DLLPs flow |
| Recovery | Retraining with TS1 and TS2: on errors, on a rate change, on the exit of L1 |
| L0s, L1, L2 | Power states: L0s and L1 save power on an idle link, L2 keeps only auxiliary power |
| Hot Reset, Disabled | Entered on a request in the TS1 control bits; Hot Reset resets the upper layers |
| Loopback, Compliance | Test modes |

Every link first trains at 2.5 GT/s. When both ports advertise a higher rate, they move to it
through Recovery (*Recovery.Speed*), and fall back if the new rate fails. At 8.0 GT/s and above
the ports also adjust the transmitter equalization of each lane, in a few phases of
*Recovery.Equalization*.

A healthy link spends almost all its time in L0. A link that keeps entering Recovery usually has a
signal integrity or clocking problem.

In LitePCIe, the LTSSM runs in the hard IP, and most PHYs report its state in their `link_status`
register. The Xilinx PHYs also record the state history in a 128-entry buffer, the LTSSM tracer
(`LTSSMTracer`). The soft PHY has its own LTSSM (`PCIeLTSSM`), which reports its states with the
same encoding as the Xilinx UltraScale hard IP.

## Data link layer {#primer-dll}

The data link layer guarantees that every TLP arrives once, in order and intact, and only when the
receiver has room for it. It uses its own small packets, the DLLPs, and two mechanisms:
acknowledgements and flow control credits. Chapter 3 of the specification describes it.

Before a TLP leaves, the data link layer prefixes it with a 12-bit *sequence number* and appends a
32-bit CRC, the *LCRC*. It keeps a copy in a *replay buffer*.

The receiver checks the LCRC and the sequence number. It answers a good TLP with an ACK DLLP and a
bad one with a NAK; both carry the sequence number of the last good TLP.

An ACK frees the acknowledged copies. A NAK, or a *replay timer* that expires without an ACK, makes
the transmitter send again every TLP after the acknowledged one. Repeated replays force the link
into Recovery. The figure below shows both mechanisms.

![The data link layer. Flow control is initialized with InitFC1 and InitFC2 before DL_Active.
Each TLP is acknowledged by sequence number; a NAK replays from the first unacknowledged TLP;
UpdateFC returns credits.](primer_dll.svg)

A receiver has buffers for three kinds of TLPs: *posted* requests (memory writes and messages),
*non-posted* requests (reads and configuration requests) and *completions*. For each kind it
advertises header credits and data credits; a data credit is 16 bytes. A transmitter sends a TLP
only when it holds enough credits for it.

The credits are first advertised with InitFC1 and InitFC2 DLLPs, then returned with UpdateFC DLLPs
as the receiver frees its buffers. Once flow control is initialized, the data link layer reports
*DL_Active* and the TLPs can flow.

| DLLP | Meaning |
|-----------------------|-----------------------------------------------------------------|
| ACK, NAK | TLPs received good up to this sequence number, or a TLP received bad |
| InitFC1, InitFC2 | Initial credits, per kind of TLP |
| UpdateFC | Credits returned by the receiver |
| PM DLLPs | Power management handshakes, such as the entry to L1 |

In LitePCIe, the hard IPs implement the data link layer, and the core sees only the TLPs. The
soft PHY implements it in `litepcie/phy/soft/dll/`: framing, LCRC, sequence numbers, replay
buffer, ACK and NAK, and flow control credits.

## Transaction layer packets {#primer-tlp}

A TLP is a header of three or four 32-bit words (DW), followed by an optional payload. The first
DW is common to every TLP, as the figure below shows. *Fmt* gives the header size and whether a
payload follows; *Type* gives the kind of TLP; *Length* is the payload size in DW, up to 1024.

![TLP headers, one row per DW, bit 31 on the left. DW0 is common to every TLP. A request carries
the requester ID, a tag and the byte enables, then a 32-bit or a 64-bit address. A completion
carries the status and the byte count of the request it answers.](primer_tlp.svg)

A request uses a 3DW header for an address below 4 GiB and a 4DW header above. The byte enables
select the valid bytes of the first and the last DW, so a request can address any byte range. The
table below lists the TLPs that LitePCIe builds and parses.

| TLP | Kind | Use |
|-------------------|---------------|---------------------------------------------------------|
| MemWr | Posted | Write to memory: no answer |
| MemRd | Non-posted | Read from memory: answered by completions |
| CplD, Cpl | Completion | Answer with data (CplD), or without: write done or error (Cpl) |
| CfgRd0, CfgWr0 | Non-posted | Type 0 configuration read and write (root port) |
| PTM Request, PTM Response | Posted message | Precision Time Measurement exchange |

A *posted* request is fire and forget: a write leaves and needs no answer. A *non-posted* request
waits for its completions. Each read carries a *tag*, and its completions carry the same tag and
the requester ID, so the requester can match them. A completion also has a status: successful
(SC), unsupported request (UR), retry (CRS) or completer abort (CA).

The figure below shows a write and two reads from the FPGA to the host memory.

![A posted write needs no answer. Each read is answered by completions that carry its tag; the
root complex may split a read into several completions, and completions of different tags may
interleave.](primer_read.svg)

Three sizes govern the traffic:

- The *Max Payload Size* (MPS) caps the payload of a write or a completion. It is 128 bytes to
  4096 bytes, set by the host for the whole path; its reset value is 128 bytes.
- The *Max Read Request Size* (MRRS) caps the size of one read request.
- The *Read Completion Boundary* (RCB), 64 or 128 bytes, is where a completer may split a read
  into several completions. The *Byte Count* field of each completion gives the bytes still to
  come, its own included, so the requester knows when a read is complete.

The ordering rules keep the producer and consumer model working. A read does not pass a write sent
before it in the same direction, so a read after a write returns the written data. The completions
of one read arrive in address order, but the completions of different reads may arrive in any
order.

In LitePCIe, the packetizer and the depacketizer build and parse the headers on 64 to 512-bit
datapaths (`litepcie/tlp/`). The TLP controller allocates the tags and reorders the completions,
so that each frontend receives its data in request order (`LitePCIeTLPController`). The DMA splits
its transfers at MPS and MRRS ([Scatter-gather DMA](#dma)).

## Configuration space and enumeration {#primer-config}

Every function has a *configuration space* of 4 KiB: registers that identify it and let the host
set it up. The first 256 bytes are compatible with PCI; the *extended configuration space* starts
at `0x100`. Configuration requests (CfgRd and CfgWr TLPs) address it by BDF and register number,
and chapter 7 of the specification describes it.

The first 64 bytes of an endpoint form the *Type 0 header*; bridges and root ports use a Type 1
header. The figure below shows the Type 0 header.

![The Type 0 configuration header. The host identifies the function by its vendor and device IDs,
sizes and places its BARs, enables it in the Command register and follows the capability
pointer.](primer_config.svg)

A *Base Address Register* (BAR) asks for a window of the host address space. Its low bits are read
only: bit 0 is 0 for memory, bits 2:1 give a 32-bit or a 64-bit BAR, bit 3 marks it prefetchable.
The host sizes a BAR in three steps:

1. It writes all ones to the BAR.
2. It reads it back. The device returns zeros in the address bits below its size: a 1 MiB, 32-bit
   memory BAR reads `0xfff00000`.
3. It writes the base address it chose. The window is a power of two, aligned on its size.

The *capabilities* form a linked list that starts at the capability pointer (`0x34`). Each one
holds an ID and the offset of the next. Endpoints have the PCI Express capability (link and device
control and status, MPS, MRRS), the power management capability and the MSI or MSI-X
capability. The extended capabilities, such as PTM, form a second list from `0x100`.

*Enumeration* is the walk of the tree by the host firmware and the operating system. They read the
vendor ID of every possible BDF; `0xffff` means no function. They number the buses, size and place
the BARs, and set the MPS.

A driver then binds to the function by its vendor and device IDs, sets *Memory Space Enable* and
*Bus Master Enable* in the Command register, and enables the interrupts.

In LitePCIe, the hard IP holds the configuration space; the PHY reports the values the host wrote,
such as bus master enable, MPS and MRRS, in its registers ([Hard-IP PHYs](#hard-phys)).

BAR0 is a 32-bit memory BAR whose size is a power of two from 128 bytes to 2 GiB. The soft PHY has
its own Type 0 configuration space (`PCIeConfigSpace`). A root port generates CfgRd0 and CfgWr0
requests when built with `with_configuration`.

## Interrupts {#primer-irq}

PCI Express has no interrupt wires. A device signals an interrupt with a memory write to an
address the host chose: a *message signalled interrupt*. The legacy INTx interrupts, emulated with
messages, also exist; LitePCIe does not use them. The figure below compares the two kinds of
message signalled interrupts.

![MSI and MSI-X. Both send a MemWr to the host. MSI takes one address and one data from its
capability; MSI-X takes an address and a data per vector from a table in a BAR, and keeps masked
vectors pending in the PBA.](primer_msi.svg)

| | MSI | MSI-X |
|------------------|-------------------------------------------|-------------------------------------------|
| Vectors | 1 to 32, a power of two | Up to 2048 |
| Where the host writes the setup | MSI capability, in configuration space | Table of 16 bytes per vector, in a BAR |
| Message | One address; the vector number in the low bits of the data | One address and one data per vector |
| Masking | Optional, per vector | Per vector and per function, with the pending bit array (PBA) |

With MSI, the vectors share one address and one data value, and the device writes the vector
number into the low bits of the data. With MSI-X, each vector has its own address and data, so the operating system can
steer each one to a different CPU.

In LitePCIe, the interrupt controller collects the interrupts of the DMA and of the user logic
(`litepcie/core/msi.py`).

With MSI, the hard IP sends the message: the controller hands it the vector on the `msi` stream of
the PHY. With MSI-X, the controller holds the table and the PBA in registers mapped in BAR0 and
sends the MemWr itself, through the crossbar. [Memory-mapped bridges and interrupts](#mmap-irq)
describes both.

## Precision Time Measurement {#primer-ptm}

*Precision Time Measurement* (PTM) lets a device read the time of the root complex and measure the
delay of its link, to align its own clock with the host. It is an optional extended capability and
uses its own messages.

The device, the *requester*, sends a PTM Request and notes its local time t1. The root complex,
the *responder*, receives it at t2 and answers at t3. Its response with timing information, the
PTM ResponseD, carries the time of the root complex. The device notes the arrival time t4.

The link delay is half the round trip, minus the time spent in the responder:
((t4 - t1) - (t3 - t2)) / 2.

In LitePCIe, the PTM requester runs the exchange and reports t1, t4, and the master time and link
delay of the last ResponseD in its registers (`PTMRequester`). Hard IPs do not pass PTM responses to the user logic, so LitePCIe taps the
receive path of the hard IP to catch them ([Precision Time Measurement](#ptm)).

## Generations at a glance {#primer-gens}

Each generation roughly doubles the data rate per lane and keeps the same packets, so a Gen4
device and a Gen1 slot still train a link together, at Gen1. The table below sums up the rates;
the data rate is per lane and per direction, after the line coding.

| Generation | Rate | Coding | Data rate per lane | LitePCIe PHYs |
|--------------|-----------|-------------|--------------------|-------------------------------------|
| Gen1 | 2.5 GT/s | 8b/10b | 2.0 Gb/s | All |
| Gen2 | 5.0 GT/s | 8b/10b | 4.0 Gb/s | All |
| Gen3 | 8.0 GT/s | 128b/130b | 7.88 Gb/s | UltraScale, UltraScale+, CertusPro-NX; soft PHY in simulation |
| Gen4 | 16.0 GT/s | 128b/130b | 15.75 Gb/s | UltraScale+ |

The data rate is the ceiling of the link. The headers, the DLLPs and the SKP ordered sets take
their share, so the payload rate a DMA reaches is lower and depends on MPS and MRRS
([Performance and resources](#performance)).

## Where to go next {#primer-next}

[Core architecture](#core-architecture) maps these concepts to the modules of the core;
[Hard-IP PHYs](#hard-phys) and [Soft PHY](#soft-phy) do the same for the PHYs.
