# What a soft PCIe PHY makes possible

Possible uses of the soft PHY (`SoftPCIEPHY`) compared with the vendors' hard PCIe IPs, and what they cost.
Each point says whether it is shown on hardware, in simulation only, or only possible with the current design.
State of the work and hardware results: [`doc/softphy.md`](../../../doc/softphy.md).

## More bandwidth on existing FPGAs

- **Gen3 on 7-Series GTX.** The Kintex-7/Virtex-7 hard block (`PCIE_2_1`) stops at 5.0 GT/s, the GTX
  transceivers go to 10.3/12.5 GT/s. Gen3 x8 in soft logic would double the bandwidth of the hard IP on
  the same device, on widely available Kintex-7 boards. *State: 8.0 GT/s datapath simulated up to x8 (512-bit
  LitePCIe), GTX 8.0 GT/s near-end loopback on hardware, link with a host in progress.*
- **Gen4 on UltraScale(+) GTH/GTY**, where the hard block is Gen3 and the transceivers are faster. *State: not
  started (16.0 GT/s equalization, timing).*
- No gain in speed on transceivers the hard block already covers (Artix-7 GTP: Gen2 at most on both).

## Freedom from the hard block

- **Any transceiver quad, several links.** A hard block has fixed quads and there are one or a few per
  device. The soft PHY can use other quads, or several independent links in one FPGA (several endpoints,
  endpoint and root port, multi-host cards). *State: one link per design tested.*
- **Board layout.** Lane order (lane numbers negotiated in Configuration), per-lane polarity (Polling) and lane
  skew are handled in the fabric. *State: polarity and deskew on hardware; lane reversal not implemented.*
- **No vendor IP.** No IP catalog, no wrapper tied to a tool version: the same code for all vendors, behind
  LiteICLink.
- **An open root port**, for NVMe or other PCIe devices from an FPGA without the vendor's root port support.
  *State: downstream LTSSM simulated (the simulated root of the tests), not on hardware.*

## FPGAs without hard PCIe

- Devices with transceivers but no usable PCIe block, for example the **Lattice ECP5-5G** (Gen1/Gen2), with
  an **open-source toolchain** (Yosys/nextpnr): a fully open PCIe endpoint. Also some Gowin, Efinix and
  GateMate parts. *State: not ported (needs a LiteICLink/SerDes adapter and timing at their speeds).*

## Visibility and control

- **Debug:** LTSSM trace, per-lane status, raw words, Training Sequence, DLLP, TLP and error counters, rate
  trace at 8.0 GT/s (`debug.py`, `bench/soft/status.py`). Useful for difficult hosts, slots and
  customers' bring-ups. *State: used for every hardware step so far.*
- **Protocol testing:** errors injected at the Physical and Data Link Layers (bad LCRC, NAK, replays,
  framing), host and root complex behaviour tests, security research on PCIe and DMA.
- **Link analyzer:** the receive path (deskew, descrambling, framing) on spare transceivers could follow a
  PCIe link passively.
- **Timing:** Symbol-level timestamps at the PHY could improve PTM and time synchronization
  ([PTM chapter of the manual](../../../doc/manual/06_ptm.md)).

## Simulation and CI

- The whole stack runs in Verilator, from the PHY to the DMA, with two PHYs connected, no vendor models
  (`bench/soft/sim*.py`, `test/test_soft_sim.py`): full-system PCIe simulation for LitePCIe's CI, including
  the wide (256/512-bit) datapaths. *State: in the tests.*

## Costs

- **Resources:** about twice the LUTs of the hard IP at Gen1 x1 on the Acorn (8463 against 4538 LUTs for the
  whole SoC, see `doc/softphy.md`). Gen3 x4 on the YPCB-00338-1P1: about 59k LUTs for the whole design.
- **Timing:** the 125 MHz `pcie_link` domain with 256/512-bit datapaths and the 200 MHz 8.0 GT/s lane
  domain are tight, each change needs a check.
- **Missing:** ASPM and L1/L0s, lane reversal, retimer SKP Ordered Sets, receiver equalization evaluation,
  compliance testing.
- **Maturity:** Gen1 and Gen2 run on hardware up to x8; Gen3 doesn't run with a host yet.

## Order suggested

1. Gen3 x8 on Kintex-7: soft PCIe faster than the hard IP on the same device.
2. ECP5 Gen1/Gen2 with the open-source toolchain.
3. Several links per FPGA, root port.
4. Debug and analyzer tools.
