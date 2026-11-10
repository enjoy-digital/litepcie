# Performance and resources {#performance}

This appendix gathers the throughputs and FPGA resources recorded in the repository, and the
bandwidth figures that follow from the PCIe line coding and the width of the core.

Use it to size a design and to know what to expect before building. The measured figures all come
from the bring-up of the soft PHY (`doc/softphy.md`), which compared each soft PHY design with the
same design on the hard IP.

## Test conditions {#perf-conditions}

| Item | Value |
|--------------------------|-----------------------------------------------------------------------------------|
| Host | PC, board in a PCIe slot, Linux with the LitePCIe driver |
| Device design | `add_pcie` with one DMA channel, loopback, MSI, 64-bit addresses |
| Host tool | `litepcie_util dma_test`: DMA loopback, data checked |
| Statistics | One line every 200 ms |
| Throughput unit | Gb/s, as `litepcie_util` prints it |

The hard-IP columns are the same design on `S7PCIEPHY` (`--hard-ip`), or the LiteX-Boards target
with `--with-pcie` for the Alibaba XCKU3P at 8.0 GT/s. The hard-IP bench targets of
[Hard-IP bench targets](#ex-hard) have no recorded throughput.

## Measured throughput {#perf-throughput}

The table below gives the `dma_test` throughput on the YPCB-00338-1P1 (Kintex-7 GTX). The soft PHY
runs the core at 32 bits per lane above x1; the hard IP designs use a 64-bit core at x1 and a
128-bit core at x4 and x8.

| Link | Soft PHY | Hard IP |
|----------------------------------------|----------------------------------------|-----------------------------|
| 2.5 GT/s x1 | 1.72 Gb/s | |
| 5.0 GT/s x1 | 3.39 Gb/s | 3.36 Gb/s |
| 5.0 GT/s x2 | 6.45 Gb/s | |
| 5.0 GT/s x4 | 11.57 Gb/s | 13.33 Gb/s |
| 5.0 GT/s x8 | 14.97 Gb/s | 13.3 Gb/s |

Above about 13 Gb/s the data check of `dma_test` cannot keep up: it loses whole buffers on both
PHYs. Without the data check, the soft PHY x8 design reaches 18.15 Gb/s. What limits it there,
against 32 Gb/s on the link, is not identified.

| Alibaba XCKU3P | Soft PHY (GTY) | Hard IP |
|---------------------------------------------------|------------------------------------|---------------------|
| 2.5 GT/s x1 | 1.72 Gb/s | |
| 5.0 GT/s x1 | 3.39 Gb/s | |
| 8.0 GT/s x8 | 23.8 Gb/s, data checked | 9.45 Gb/s |

The soft PHY figure at 8.0 GT/s x8 comes from a test program on the library of the driver that
checks each received buffer, since `dma_test` does not keep up at that rate.

A link narrowed by width negotiation is a little slower than a design of that width: 2.97 Gb/s
for an x8 design trained at x1, against 3.39 Gb/s for an x1 design. The beats of a wider design are
split between fewer lanes, with Logical Idle in them.

## Stability {#perf-stability}

The runs below read the correctable error status of the root port every second. "Lost buffers"
counts the 200 ms rows where the driver reported buffers lost by the application.

| Board and link | Run | Result |
|-------------------------------------------|----------------------------|--------------------------------------|
| YPCB-00338-1P1, soft 2.5 GT/s x1 | `dma_test`, 1 hour | 1.72 Gb/s, 0 errors, no correctable error |
| YPCB-00338-1P1, soft 2.5 GT/s x1 | 100 link cycles | 100 passed, DL_Active back in 14 ms at most |
| YPCB-00338-1P1, soft 2.5 GT/s x1 | 20 warm reboots | 20 passed |
| YPCB-00338-1P1, soft 5.0 GT/s x1 | `dma_test`, 15 min | 3.39 Gb/s, 0 of 900 seconds with errors |
| YPCB-00338-1P1, hard 5.0 GT/s x1 | `dma_test`, 15 min | 3.36 Gb/s, 0 of 900 seconds with errors |
| YPCB-00338-1P1, soft x2 to x8 | `dma_test`, 15 min each | 0 seconds with correctable errors |
| Alibaba XCKU3P, soft 2.5 and 5.0 GT/s x1 | 15 min soak, 20 link cycles | 0 errors, 20 of 20 cycles |

At 5.0 GT/s x1 the soft and hard designs lost buffers in 1 and 2 rows of 4477, against 1 and 3
"too late" messages of the driver. At this rate the ring of 256 buffers lasts about 5 ms: the losses
are the host not keeping up, and the hard IP had more of them.

## Link bandwidth (computed) {#perf-link}

The figures of this section are computed from the specification rates, not measured. The line
coding first removes 20 % of the raw rate at 2.5 and 5.0 GT/s (8b/10b), and 1.5 % at 8.0 and
16.0 GT/s (128b/130b). The table gives the data rate left per direction.

| Generation | Rate | Coding | x1 | x4 | x8 | x16 |
|--------------------|-----------|-------------------|-------------|--------------|---------------|---------------|
| Gen1 | 2.5 GT/s | 8b/10b | 2.0 Gb/s | 8.0 Gb/s | 16.0 Gb/s | 32.0 Gb/s |
| Gen2 | 5.0 GT/s | 8b/10b | 4.0 Gb/s | 16.0 Gb/s | 32.0 Gb/s | 64.0 Gb/s |
| Gen3 | 8.0 GT/s | 128b/130b | 7.88 Gb/s | 31.51 Gb/s | 63.02 Gb/s | 126.03 Gb/s |
| Gen4 | 16.0 GT/s | 128b/130b | 15.75 Gb/s | 63.02 Gb/s | 126.03 Gb/s | 252.06 Gb/s |

Each TLP then carries 8 bytes of framing, sequence number and LCRC, plus its header: 16 bytes for a
MemWr with a 64-bit address, 12 bytes for a CplD. The payload efficiency below is the payload
divided by the payload plus these overheads. It is an upper bound: it ignores the DLLPs and the
SKP Ordered Sets that share the link.

| Payload | MemWr, 64-bit address | CplD |
|----------------------------------------|------------------------------------------|--------------------------|
| 64 bytes | 72.7 % | 76.2 % |
| 128 bytes | 84.2 % | 86.5 % |
| 256 bytes | 91.4 % | 92.8 % |
| 512 bytes | 95.5 % | 96.2 % |

The DMA writer sends MemWr TLPs of the Max Payload Size, so an MPS left at 128 bytes caps a Gen2 x8
link at about 27 Gb/s instead of 29 Gb/s with 256 bytes.

The DMA reader receives the completions as the host splits them; a host that splits them at the
64-byte Read Completion Boundary leaves 76 % of the link to the data, as the CplD column shows.

## Core bandwidth (computed) {#perf-core}

The figures below assume that the core moves one beat of its data width per cycle of its clock,
in each direction, with no idle cycle. Its bandwidth must exceed the link's, or the core becomes
the limit. The table gives it for the configurations of the bench targets.

| Data width | Clock | Core bandwidth | Used by |
|------------------|----------------|-------------------------|------------------------------------------------|
| 64 bits | 125 MHz | 8.0 Gb/s | `kc705` x1, soft PHY x1 |
| 128 bits | 125 MHz | 16.0 Gb/s | YPCB-00338-1P1 hard IP x4 and x8 (`--hard-ip`) |
| 128 bits | 200 MHz | 25.6 Gb/s | `kc705` x4 and x8; `kcu105`, `xcu1525`, `fk33` x4 |
| 256 bits | 125 MHz | 32.0 Gb/s | Soft PHY x8 at 5.0 GT/s |
| 256 bits | 200 MHz | 51.2 Gb/s | `kcu105`, `xcu1525` and `fk33` x8 |
| 512 bits | 200 MHz | 102.4 Gb/s | `xcu1525` and `fk33` x16 |

A Gen2 x8 link carries 32 Gb/s after coding, and a 128-bit core needs 250 MHz to match it. The
YPCB-00338-1P1 hard-IP design runs its 128-bit core at 125 MHz. This matches its x8 result, no
faster than x4, though the repository does not record the cause.

With the same assumption, every 200 MHz bench configuration at Gen3 is below its link after
coding: 25.6 against 31.5 Gb/s at x4, 51.2 against 63.0 Gb/s at x8, 102.4 against 126 Gb/s at
x16. So is the KC705 at Gen2 x8, 25.6 against 32 Gb/s. No throughput of these targets is
recorded to confirm it.

## What limits the throughput {#perf-limits}

| Limit | Effect | Lever |
|----------------------------|------------------------------------------------|---------------------------------|
| Line coding | 20 % at Gen1 and Gen2, 1.5 % at Gen3 and Gen4 | Higher generation |
| Max Payload Size | About 16 % of overhead at 128 bytes, 9 % at 256 bytes | Host programming both ends |
| Completion size | Reads split at 64 bytes lose about a quarter | Host setting |
| Core datapath | Data width times clock, per direction | Wider core or faster clock |
| Host application | Lost buffers above about 13 Gb/s in `dma_test` | Lighter processing, zero copy |

## Resources {#perf-resources}

The table below compares the same SoC on the soft PHY and on the hard IP on the Acorn CLE-215+
(XC7A200T, Vivado 2024.1): x1, 64-bit core, one DMA channel, loopback, MSI, 125 MHz system clock.
The figures are for the whole design, so the difference between the columns is the cost of the
PHY.

| Resource | Soft | Soft, debug and tracer | Hard IP |
|--------------------------------------------------|-----------------|-----------------------|------------------|
| Slice LUTs | 8463 | 8764 | 4538 |
| Slice Registers | 6395 | 7022 | 3650 |
| Block RAM tiles | 28 | 28 | 32.5 |
| `PCIE_2_1` | 0 | 0 | 1 |
| `GTPE2_CHANNEL` | 1 | 1 | 1 |
| Setup WNS | 0.083 ns | 0.167 ns | 0.667 ns |
| Estimated power | 0.648 W | 0.679 W | 0.804 W |

The debug registers cost about 600 registers; the LTSSM tracer is too small to separate from the
spread between builds. On the YPCB-00338-1P1 (Kintex-7), the size grows with the link width, as the
table below shows.

| Design | Slice LUTs | Slice Registers | Setup WNS |
|-----------------------------------|--------------------|---------------------------|---------------------------|
| Soft PHY x1, 2.5 GT/s | 8617 | 7045 | 0.641 ns |
| Soft PHY x2 | 11895 | 9746 | 0.845 ns |
| Soft PHY x4 | 20095 | 13750 | 0.463 ns |
| Soft PHY x8 | 41553 | 22107 | 0.391 ns |
| Hard IP x1, 5.0 GT/s | 4672 | 3755 | 0.739 ns |
| Hard IP x4 | 7076 | 5570 | 0.524 ns |
| Hard IP x8 | 8407 | 7370 | -0.012 ns |

On the Alibaba XCKU3P (Kintex UltraScale+), the soft PHY x1 design uses 9465 CLB LUTs at
2.5 GT/s and 9825 at 5.0 GT/s, with 1.104 and 0.804 ns of setup slack.

Where to go next: [Soft PHY](#soft-phy) for the status of the soft PHY, [Scatter-gather DMA](#dma)
for the DMA parameters, and [Debugging](#debugging) for lost buffers.
