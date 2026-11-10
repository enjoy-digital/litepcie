# Soft PHY {#soft-phy}

**In development:** the status of the soft PHY changes often. This chapter gives its
architecture and the state it has reached; `doc/softphy.md` holds the detailed developer
notes, with every measurement and bring-up step.

The soft PHY implements the physical and data link layers of PCIe, and the configuration space of
an endpoint, in the FPGA fabric, on top of the FPGA transceivers. It presents the same contract as the hard-IP
PHYs ([Hard-IP PHYs](#hard-phys)), so the core, the driver and the generator use it unchanged.
Readers who only need a working link on a supported FPGA should start with a hard-IP PHY.

## At a glance {#soft-glance}

| Item | Value |
|--------------------|------------------------------------------------------------------|
| Class | `SoftPCIEPHY` |
| Rates | `gen1` (2.5 GT/s), `gen2` (5.0 GT/s), `gen3` (8.0 GT/s, host link on GTY only) |
| Lanes | 1, 2, 4, 8 on GTX and GTP; 1 on GTY, and 1, 4, 8 at 8.0 GT/s |
| Transceivers | Artix-7 GTP, Kintex-7 GTX, Kintex UltraScale+ GTY (KU3P, KU5P) |
| Core width | x1 below 8.0 GT/s: 64 to 512 bits; else 32 bits per lane, 64 at 8.0 GT/s |
| Reference clock | 100 MHz, from the slot |
| IDs | Vendor `0x10ee`, device `0x7020` plus the lane count, by default |
| Interrupts | MSI, 1 vector by default; no MSI-X |
| Role | Endpoint; the downstream role exists in simulation only |

The table below gives the state of each part. The hardware runs used the YPCB-00338-1P1 (Kintex-7
GTX) and the Alibaba XCKU3P (Kintex UltraScale+ GTY) in a PC slot, with the driver and the tools.

| Scope | State |
|------------------------------------|------------------------------------------------------|
| Gen1 and Gen2, x1 to x8, GTX | On hardware: enumeration, BAR0, MSI, DMA |
| Gen1 and Gen2 x1, GTY | On hardware: enumeration, BAR0, MSI, DMA |
| Width negotiated down to x1 | On hardware, GTX |
| Artix-7 GTP | Built, not run on hardware |
| 8.0 GT/s, GTY | On hardware x1, x4, x8: enumeration, BAR0, MSI, DMA |
| 8.0 GT/s, GTX | Simulated x1 to x8; x4 near-end loopback; no host link |
| Lane reversal, power management | Not implemented |
| Root port on the soft PHY | Downstream LTSSM simulated; not on hardware |

## Why a soft PHY {#soft-why}

A hard block fixes the rate, the lanes and the quads a design can use, and some FPGAs have no hard
block at all. The soft PHY moves these choices to the fabric. Its uses, as
`litepcie/phy/soft/advantages.md` lists them:

- Gen3 on Kintex-7 GTX transceivers, whose hard block stops at 5.0 GT/s.
- Links on any transceiver quad, and several links in one FPGA.
- No vendor IP, and the same code for every vendor behind LiteICLink.
- FPGAs without a usable PCIe block, such as the Lattice ECP5-5G with an open-source toolchain.
- Visibility: LTSSM trace, per-lane status and protocol counters, and errors injected for testing.
- The whole stack in Verilator, from the transceivers to the DMA, for continuous integration.

The cost is logic. On the Acorn CLE-215+, the same x1 SoC takes 8463 LUTs on the soft PHY against
4538 on the hard IP. On the YPCB-00338-1P1, a Gen2 x8 design takes 41553 LUTs on the soft PHY
against 8407 on the hard IP.

## Architecture {#soft-architecture}

The soft PHY replaces the hard IP by four layers between the core and the transceivers. The figure
below shows them in the order a TLP crosses them.

![Layers of the soft PHY: from the core to the FPGA transceivers, a TLP crosses the clock domain
crossing and width adapters, the transaction layer glue, the data link layer and the physical
layer with its LTSSM.](soft_layers.svg)

| Layer | Role | Files |
|--------------------|----------------------------------------------------|------------------------|
| Datapath | Clock domain crossing to the core, TLP stream adapters | `core.py`, `tl/adapter.py` |
| Transaction layer glue | Type 0 configuration space, Unsupported Requests, MSI writes, BAR0 filter | `tl/` |
| Data link layer | Framing, LCRC, sequence numbers, ACK/NAK and replay, flow control | `dll/` |
| Physical layer | LTSSM, Ordered Sets, multi-lane striping and deskew, lane datapaths | `pipe.py`, `lanes.py`, `ltssm.py` |
| Transceivers | Lane contract, clocking, GTP, GTX and GTY adapters, model | `serdes/` |

The files are in `litepcie/phy/soft/`. The transaction layer glue does what a hard IP does above
its data link layer. It answers the configuration requests and sends the MSIs itself, and passes
the other TLPs to the core unchanged.

The configuration space advertises the power management, MSI and PCI Express capabilities, and the
Secondary PCI Express capability at 8.0 GT/s. The rest of the endpoint behaviour is the core's.

### Clock domains {#soft-clocks}

The soft PHY runs in its own clock domains, between the recovered clocks of the transceivers and
the core clock domain. The figure below shows the main ones and where the data crosses from one to
the next.

![Clock domains of the soft PHY: dotted arrows are clock domain crossings (receive lanes into the
lane clock, lane clock into the link clock, pcie into the core); pcie_link and pcie share one
clock.](soft_clocks.svg)

| Domain | Frequency | Content |
|--------------------|------------------------------|----------------------------------------|
| `pcie_pipe_rxN` | Recovered from the partner | Receive lane datapath of lane N |
| `pcie_pipe` | 62.5 MHz at 2.5 GT/s, 125 MHz at 5.0 GT/s | Lane datapaths, Ordered Sets |
| `pcie_g3` | `pcie_pipe`, or 200 MHz at 8.0 GT/s | 128b/130b lane datapath (GTX, `gen3`) |
| `pcie_link` | 125 MHz, always running | LTSSM, data link layer |
| `pcie` | Same clock as `pcie_link` | Transaction layer glue, held in reset until DL_Active |
| `pcie_oob` | 50 MHz | Out-of-band clock input of the transceivers |

An MMCM on the reference clock, halved by its input buffer, makes the lane, link and out-of-band
clocks. The same reference clock feeds the transceiver PLLs, so the link follows the spread
spectrum clocking of the host. The lane clock switches with the negotiated rate; the link clock
does not, which keeps the LTSSM timers exact.

The `pcie` domain plays the role of the user reset of a hard IP. The core sees no TLP until the
data link layer is active (DL_Active); the TLPs received before wait in its buffers.

### Lane datapath {#soft-lanes}

Each lane exchanges words of four 8-bit Symbols with the transceiver, 40 raw bits once encoded.
The figure below shows the datapath of one lane.

![Lane datapath of the soft PHY: SKP insertion and scrambling on transmit; descrambling, SKP
removal and the elastic buffer on receive; 8b/10b coding in the fabric.](soft_lanes.svg)

On transmit, the lane inserts a SKP Ordered Set every 352 words between packets and Ordered Sets,
then scrambles the data Symbols. The scrambler uses the polynomial of the specification,
G(X) = X^16 + X^5 + X^4 + X^3 + 1, and skips the training sequences by itself.

On receive, the lane decodes 8b/10b, descrambles and removes the SKP Ordered Sets in the recovered
clock domain. An elastic buffer then brings the words into the lane clock; it drops and counts
words when it overflows.

The receiver has no word aligner. The phase of the received words is arbitrary, so the Ordered Set
detectors find training sequences at any Symbol position. The packet framing of the data link
layer realigns on the start of each packet.

### LTSSM {#soft-ltssm}

The LTSSM runs in the fixed link clock and sees the lanes through events: training sequences
received with their fields, sequences transmitted, idle handshakes and Electrical Idle. It takes
the upstream role in a device and the downstream role in the simulated root
([PCI Express in a nutshell](#pcie-primer)).

| Implemented | Not implemented |
|----------------------------------------------------|------------------------------------|
| Detect, Polling.Active, Polling.Configuration | Polling.Compliance, Loopback |
| Configuration with link and lane numbers | L0s, L1, L2 |
| L0, Recovery, Hot Reset, Disabled | Lane reversal |
| Recovery.Speed (Gen2), Recovery.Equalization (Gen3) | |

The states that are not implemented go back to Detect. The state encoding is the one of the
Xilinx UltraScale hard IP, with L0 at `0x10`, so the LTSSM tracer and its reader work unchanged
with `--family ultrascale` ([LTSSM tracer](#hard-ltssm-tracer)).

### Multi-lane links {#soft-multilane}

Above x1, the data link layer works on beats of one DW per lane, at 125 MHz whatever the width.
The core width must then be 32 bits per lane: 256 bits for a Gen2 x8 design. At 8.0 GT/s, each
lane gives two DWs per cycle, so the width doubles to 64 bits per lane. An x1 design at 8.0 GT/s
takes this multi-lane path too, with a 64-bit core.

The physical layer sends the Ordered Sets on all lanes at once, stripes the packets, and deskews
the lanes on the COM Symbols of the training sequences. The width is negotiated in Configuration:
the largest of x1, x2, x4 and x8 with the lanes that answer, from Lane 0. The width field of the
`pcie_phy_link_status` register gives the negotiated width as its base 2 logarithm, as most
hard-IP PHYs: `0b00` for x1, `0b01` for x2, `0b10` for x4 and `0b11` for x8.

### 5.0 and 8.0 GT/s {#soft-speed}

With `speed="gen2"`, the link trains at 2.5 GT/s and the root port then moves it to 5.0 GT/s. The
fallback to 2.5 GT/s after a failed change is simulated only.

With `speed="gen3"` (GTX and GTY, x1 to x8), the link also trains at 2.5 GT/s first. The lanes add
the 128b/130b blocks, their scrambling and alignment, and the equalization of the transmitter.

On the Alibaba XCKU3P (GTY), x1, x4 and x8 links train at 8.0 GT/s with a host, through the four
phases of the equalization, and enumerate. In near-end loopback on the GTX, four lanes ran 10
minutes at 8.0 GT/s without error; with a host, no training sequence is received at 8.0 GT/s on
the GTX yet. `doc/softphy.md` records both.

## Measured results {#soft-results}

The repository records the DMA loopback throughput of the tools against the hard IP of the same
board. The table below gives the YPCB-00338-1P1 results, at 32 bits per lane.

| Link | Soft PHY | Hard IP |
|----------------|------------|------------|
| 2.5 GT/s x1 | 1.72 Gb/s | Not measured |
| 5.0 GT/s x1 | 3.39 Gb/s | 3.36 Gb/s |
| 5.0 GT/s x2 | 6.45 Gb/s | Not built |
| 5.0 GT/s x4 | 11.57 Gb/s | 13.33 Gb/s |
| 5.0 GT/s x8 | 14.97 Gb/s | 13.3 Gb/s |

Above about 13 Gb/s, the software check of the test loses whole buffers on both PHYs. The x8
figures therefore measure the link, but do not prove the data on their own.

On the Alibaba XCKU3P, the soft PHY gives 1.72 Gb/s at 2.5 GT/s x1 and 3.39 Gb/s at 5.0 GT/s x1.
At 8.0 GT/s x8, a test program on the library of the driver received 23.8 Gb/s and checked the
data of every buffer.

## How to try it {#soft-try}

The simulations need Verilator and no hardware. They run two soft PHYs, or a soft PHY and a
scripted root, through transceiver models, and end with `SIM OK`.

```sh
# Unit tests of the soft PHY
python3 -m pytest -v test/test_soft_*.py
# Two physical layers, then with the data link layers
python3 bench/soft/sim.py --timer-scale 100
python3 bench/soft/sim.py --with-dll
# SoC with DMA against a host model, x8 at 8.0 GT/s
python3 bench/soft/sim_soc.py --gen3 --nlanes 8
```

On hardware, each bench target builds the endpoint on the soft PHY with `--with-endpoint`. With
`--hard-ip`, the YPCB-00338-1P1 and Acorn targets build the same design on the hard IP, for
comparison. The targets are in `bench/soft/`.

| Target | Board | Rates and lanes | Main options |
|------------|-------------------|--------------------|---------------------------|
| `ypcb.py` | YPCB-00338-1P1, GTX | Gen1 to Gen3, x1 to x8 | `--speed`, `--nlanes`, `--hard-ip` |
| `ku3p.py` | Alibaba XCKU3P, GTY | Gen1, Gen2 x1; Gen3 x1, x4, x8 | `--speed`, `--nlanes` |
| `acorn.py` | Acorn CLE-215+, GTP | Gen1, x1 | `--with-debug`, `--hard-ip` |

The bring-up registers keep the LTSSM disabled at reset and while PERST# is asserted. A design
that hangs the host therefore does not hang it again at the next boot; software enables the LTSSM
once the host is up (`--ltssm-autostart` removes this hold).

```sh
python3 bench/soft/ypcb.py --with-endpoint --driver --build
python3 bench/soft/status.py --csr-csv build/soft_ypcb/csr.csv \
    enable status trace
```

After enabling the LTSSM, rescan the PCI bus on the host. When the BIOS saw no device at boot,
remove the root port before the rescan. `status.py` shows the LTSSM state, the counters and the
LTSSM history. The generator accepts the soft PHY too: see `examples/acorn_soft.yml`.

**Options.** `add_debug()` adds the bring-up registers: LTSSM enable and retrain, per-lane status
and counters. `add_ltssm_tracer()` adds the LTSSM history of the hard-IP PHYs. Without them, the
LTSSM starts on its own.

## Limitations {#soft-limitations}

The points below are the known gaps; `doc/softphy.md` tracks them with the status of each step.

- No 8.0 GT/s link with a host on the GTX yet; at 8.0 GT/s, the width is the full width of the
  design.
- No lane reversal, and no retimer SKP Ordered Sets of other lengths.
- No link power management: no ASPM, L0s, L1 or L2, and no PME_TO_Ack at shutdown.
- No MSI-X; the MSI-X enable register always reads 0.
- Receiver detection is stubbed: a partner is always present.
- A blocked non-posted request blocks the TLPs behind it: there is a single transmit queue.
- The data link layer timers are fixed values, not yet checked against the specification tables.
- Artix-7 GTP not run on hardware; the GTY runs at x1 only at 2.5 and 5.0 GT/s.

## In the code {#soft-code}

| File | Content |
|-----------------------|------------------------------------------------------------------|
| `core.py` | `SoftPCIEPHY`: layers, clock domains, registers, options |
| `pipe.py`, `lanes.py` | Physical layer, x1 and multi-lane |
| `ltssm.py` | `PCIeLTSSM`, upstream and downstream roles |
| `datapath.py` | Lane datapaths: SKP, error substitution, elastic buffer |
| `ordered_sets.py` | Training sequence generator and checker, Ordered Set detector |
| `scrambler.py`, `coding.py` | Scrambler, 8b/10b tables and checker |
| `gen3.py` | 128b/130b blocks, scrambler, alignment, equalization |
| `dll/`, `tl/` | Data link layer, transaction layer glue and configuration space |
| `serdes/` | Lane contract, clocking, GTP, GTX, GTY adapters, simulation model |
| `debug.py` | Bring-up registers (`SoftPHYDebug`) |

The files are in `litepcie/phy/soft/`; the bench targets and simulations are in `bench/soft/`.

Where to go next: [Simulation](#simulation) for the Verilator runs, [Debugging](#debugging) for
the bring-up procedure, [Hard-IP PHYs](#hard-phys) for the PHYs on vendor IP.
