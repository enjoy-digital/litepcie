# Debugging {#debugging}

This chapter explains how to debug a PCIe design on a board: a device that does not enumerate, a
link that trains at the wrong speed, a DMA that stalls, an interrupt that never comes. It describes
the method, the registers and scripts to use at each step, and ends with a troubleshooting table.
Read it before touching hardware.

## Method {#debug-method}

The approach is to observe before changing anything. The host already tells a lot through its PCIe
tools and its kernel log, and the registers of the design answer most of the other questions. A
logic analyzer capture is only worth taking once the question is narrow.

1. Check the host view first: the device in `lspci`, its link status, the kernel messages.
2. Check the design: the bridge answers and the identifier matches the build.
3. Read the registers: link status, LTSSM history, DMA table levels, interrupt state.
4. Capture a narrow LiteScope trace only when the question is about timing.
5. Reproduce the finding in simulation, fix it there, then check again on the board (see
   [Simulation and verification](#simulation)).

The figure below shows what each view tells. The registers are read either by the host through
BAR0 or, when the link is down, through the bridge of the target (UARTBone or JTAGBone) with
`litex_server`.

![Debug views. The dotted arrows show which part of the datapath each view observes, from the host
on the left to the interrupts on the right.](debug_taps.svg)

| View | Tool | Tells |
|---------------------|-----------------------------------------------|----------------------------------------|
| Host | `lspci -vv`, `dmesg` | Enumeration, link speed and width, driver probe |
| PHY registers | `litex_cli`, tracer script | Link up, rate, width, LTSSM state and history |
| Soft PHY debug | `bench/soft/status.py` | LTSSM control, counters, lanes, data link layer |
| DMA registers | `litepcie_util`, `litex_cli` | Table levels, loop status, FIFO levels |
| MSI registers | `litex_cli` | Enabled interrupts, pending vector |

The register names of this chapter are those of [Register reference](#registers). The `AGENTS.md`
file of the repository and the LiteX wiki page on debugging a SoC on hardware describe the same
method.

## Access to the design {#debug-access}

Before reading registers, make sure the client talks to the right design. A bench target has a
bridge that works without the PCIe link: UARTBone on most targets, JTAGBone on the FK33, the
YPCB-00338-1P1 and the Alibaba XCKU3P targets. `litex_cli` then reads any register by name through
the `csr.csv` of the build. The `--jtag-config` file depends on the JTAG cable.

```sh
litex_server --jtag --jtag-config openocd_xc7_ft232.cfg &
litex_cli --csr-csv build/soft_ypcb/csr.csv --ident
litex_cli --csr-csv build/soft_ypcb/csr.csv --read pcie_phy_link_status
```

The identifier must match the build. The soft PHY targets add the build date to it, which tells a
fresh load from a design reloaded from the flash after a warm reboot; on the other targets,
change the identifier when in doubt. Over BAR0, the driver prints the same identifier when it
probes the device, and `litepcie_util info` reads it too.

## Enumeration failures {#debug-enum}

A device that does not appear in `lspci` is often a host problem rather than a gateware one: the
slot, the BIOS settings or Secure Boot. Check the host side first, from the bottom up.

```sh
# Devices with the Xilinx vendor ID, with their link status
sudo lspci -vv -d 10ee:
# Kernel messages of the driver
sudo dmesg | grep litepcie
```

- **Reboot or rescan after a load.** The BIOS enumerates the bus once, at boot. A bitstream
  loaded after the boot needs a warm reboot, a rescan (`echo 1 > /sys/bus/pci/rescan`) or the
  helper `rescan.py` of [Tools](#sw-tools), which also removes and reloads a device already seen.
- **Remove the host port when the BIOS saw nothing.** On a host tested with the soft PHY, a rescan
  alone assigned the memory window without programming the port of the host above the slot, and
  BAR reads returned all-ones. Remove that port before the rescan, as [Getting
  started](#gs-enumeration) shows.
- **Check the build after a reboot.** A warm reboot usually keeps the design loaded, but one warm
  reboot of the soft PHY bring-up reloaded the FPGA from its flash. Read the identifier again
  after each reboot.
- **Keep a hanging design off at boot.** Some hosts hang when a device times out on configuration
  reads during the boot. The soft PHY targets keep their LTSSM disabled until it is enabled from
  the bridge, after the boot.

When the device enumerates but the driver does not bind, the kernel log names the step that failed.
The driver prints the identifier of the design once BAR0 is mapped, then the number of interrupts
it got.

| Kernel message | Meaning |
|-------------------------------------------------|------------------------------------------------------------|
| "Version" and the identifier | BAR0 mapped, identifier read: the register path works |
| "N MSI IRQs allocated." | MSI enabled with N vectors ("MSI-X IRQs" with MSI-X) |
| "Cannot enable device" | The kernel could not enable the PCI device |
| "Unsupported device version" | Revision ID of the configuration space above 1 |
| "Invalid BAR0 configuration" | BAR0 is not a memory BAR |
| "Could not request regions" | BAR0 already claimed |
| "Could not map BAR0" | The kernel could not map BAR0 |
| "Failed to set DMA mask" | The DMA address width is refused by the host |
| "Failed to enable MSI" | No MSI or MSI-X vector granted |

The driver module itself may refuse to load. `init.sh` handles the common cases: it rebuilds the
module on "Invalid module format" (a new kernel), and reports Secure Boot on "Required key not
available". An unsigned module cannot load with Secure Boot on; disable it in the BIOS.

## Link status and LTSSM tracer {#debug-ltssm}

Once the device is seen, check that the link trained at the expected rate and width. The host shows
it in the `LnkSta` line of `lspci -vv`, for the device and for its root port. On the design side the
`pcie_phy_link_status` register has four fields.

| Field | Content |
|------------------------|-------------------------------------------------------------------------------------|
| `status` | Link up, as the PHY reports it |
| `rate` | Negotiated rate, raw value of the PHY |
| `width` | Negotiated width, base 2 logarithm of the lanes (`3` for x8, `4` for x16); one bit per width on UltraScale |
| `ltssm` | LTSSM state, in the encoding of the hard IP |

A link that does not come up, or that drops, needs the history of the LTSSM. The LTSSM tracer
(`add_ltssm_tracer()`, built by every bench target) records each state change in a 128-entry FIFO.
Each read of `pcie_phy_ltssm_tracer_history` returns one transition, with the old and the new
state, until `valid` reads 0.

```sh
python3 bench/test_ltssm_tracer.py --csr-csv csr.csv --family 7series
```

The script decodes the states with the table of the hard IP: `7series` for the 7-Series PHY,
`ultrascale` for the UltraScale and UltraScale+ PHYs and for the soft PHY, which uses the same
encoding (L0 is `0x10`).

An overflow flag on an entry means that states were lost while the FIFO was full. The tracer samples
the state without a handshake, so a transition can show an intermediate value for one cycle.

The table below is general PCIe guidance, not a record of LitePCIe failures: it maps the last
state of a failed training to the usual causes, following the LTSSM of [PCIe primer](#pcie-primer).

| Last state reached | Usual causes |
|-----------------------------------------|--------------------------------------------------------------------|
| Detect | Reference clock, PERST#, lanes not connected |
| Polling | Receiver not locked, polarity, lane order |
| Configuration | Lane numbers, width, lanes missing |
| Recovery, in a loop | Signal quality, speed change failing |
| L0, then back to Detect | Data link layer not reaching DL_Active, PERST# |

## MPS and MRRS {#debug-mps}

The DMA splits its transfers at the sizes negotiated by the host: writes at the Max Payload Size
(MPS), reads at the Max Read Request Size (MRRS). The PHY reports both in `pcie_phy_max_payload_size`
and `pcie_phy_max_request_size`, in bytes; the host shows them as `MaxPayload` and `MaxReadReq` in
the `DevCtl` line of `lspci -vv`.

The MPS stays at the 128-byte reset value unless both ends of the link are programmed with a larger
one. A host that leaves it at 128 bytes lowers the DMA throughput, as
[Performance and resources](#performance) computes. The Xilinx, Intel and soft PHYs cap both sizes
at 512 bytes, so a larger host value reads as 512.
A root port design programs its own MPS through `with_cfg_mgmt`, as [Integration](#integration)
explains.

## DMA stalls and lost buffers {#debug-dma}

`litepcie_util dma_test` loops the DMA writer back to the reader and checks the data. It prints a
line every 200 ms with the throughput in Gb/s, the buffer counts of both directions, their
difference and the data errors. A DMA problem shows as a throughput of zero, a growing difference,
or errors.

```sh
# Internal loopback, data checked, 10 seconds
./litepcie_util dma_test -t 10
# Through the user logic (external loopback), with RX delay calibration
./litepcie_util -e -a dma_test
```

The driver keeps a ring of 256 buffers of 8 KiB per direction and the DMA raises an interrupt every
32 buffers.

When the application does not keep up, the hardware overtakes it and the driver reports it in the
kernel log: "Reading too late, N buffers lost" for the writer, "Writing too late, N buffers lost"
for the reader. The driver drops the buffers the writer is more than 128 buffers ahead on: at
3.39 Gb/s, 128 buffers of 8 KiB last about 2.5 ms, so a busy host loses buffers.

Above about 13 Gb/s the data check of `dma_test` itself cannot keep up and loses whole buffers, on
the hard IP as on the soft PHY. At these rates the lost buffers measure the host, not the link. When
the throughput is zero instead, read the DMA registers of the channel.

| Register | Healthy | Stalled |
|-----------------------------------------------------------|-----------------|--------------------------------|
| `pcie_phy_bus_master_enable` | 1 | 0: the host has not enabled DMA |
| `writer_enable`, `reader_enable` | 1 while the test runs | 0: the application did not start it |
| `writer_table_loop_status` | Index and count advance | Frozen: no descriptor completes |
| `writer_table_level` | Stable | 0: the table is empty, not refilled |
| `buffering_*_fifo_status` | Moves | Full (writer) or empty (reader) |

The reader only sends a read request when its FIFO has room for the data, so a reader stalled with a
full FIFO waits for the user logic. With the monitor plug-in, the `writer_monitor_overflows` and
`reader_monitor_underflows` counters count the overflows and underflows of the user streams.

## MSI issues {#debug-msi}

Without interrupts the driver never sees the DMA progress: `dma_test` shows no buffers while the DMA
registers advance. Check the chain from the host to the design.

1. The kernel log line "N MSI IRQs allocated." and `/proc/interrupts`: the driver got its vectors
   and their counts grow.
2. `pcie_phy_msi_enable` or `pcie_phy_msix_enable` reads 1: the host enabled the capability in the
   configuration space.
3. `pcie_msi_enable` has the bits of the DMA interrupts set, and `pcie_msi_vector` shows the
   pending ones.

The driver chooses MSI-X when the design has an MSI-X controller (the `pcie_msi_pba` register),
otherwise MSI. On 7-Series and CertusPro-NX, the MSI-X table and PBA offsets set in the hard IP
(`0x2000` and `0x1808`) must match the register map of the design. The generator and `add_pcie`
with `msi_type="msi-x"` place `pcie_msi_table` and `pcie_msi_pba` there, and `add_pcie` stops with
an error when it cannot ([Interrupt types](#integ-msi)); `csr.csv` shows the result.

An MSI-X vector with a non-zero upper address is treated as masked unless the endpoint has 64-bit
addresses.

Three PHYs have their own limits. The Gowin GW5A PHY raises an MSI request on the rising edge of
the request valid, so two MSIs back to back may stall (issue #244). The UltraScale and UltraScale+
PHYs send an MSI vector chosen from the Multiple Message Enable of the host, not the vector of the
request (issue #243): a multi-vector MSI does not reach the right handler there.

The Lattice CertusPro-NX hard IP has no MSI request pins: use MSI-X (`msi_type="msi-x"` in
`add_pcie`, the default of the generator for this PHY), since the default MSI type gets no
interrupts.

## Soft PHY debug {#debug-soft}

The soft PHY exposes much more than a hard IP: its LTSSM can be held, retrained and traced, and
counters cover every layer. The debug registers are added by `add_debug()` and read with
`bench/soft/status.py`, through `litex_server` on the bridge of the target.

```sh
python3 bench/soft/status.py --csr-csv build/soft_ypcb/csr.csv enable status trace
```

| Command | Effect |
|----------------------------------|---------------------------------------------------------------------------|
| `status` | LTSSM state, rate, link and lane numbers, lanes, counters, data link layer |
| `trace` | LTSSM history, decoded |
| `enable`, `disable` | Start or stop the LTSSM |
| `retrain` | Link Retrain through Recovery |
| `speed` | Directed speed change, when the partner advertises a higher rate |
| `disable=MASK` | Keep lanes out of the link, to test width negotiation |
| `loopback=N` | Transceiver loopback mode (2: near-end PMA) |
| `g3force=N` | Force the 8.0 GT/s datapath (1) or release it (0), for lane tests |

The bring-up of a soft PHY board follows the steps below; the counters tell how far the link went.

1. Boot the host with the LTSSM disabled, which is the reset state of the debug designs.
2. Start `litex_server` on the bridge, check `serdes_ready` in the status, then `enable`.
3. Read the status: the state should reach L0 (`0x10`) and `l0` read 1.
4. On the host, rescan: the device enumerates once DL_Active is set.

| Counter | Meaning |
|----------------------------------------------|---------------------------------------------------------------|
| `rx_ts`, `rx_ts_errors` | Training Sequences received, and corrupted ones |
| `rx_errors` | 8b/10b errors, in words |
| `rx_overflows` | Elastic buffer overflows, words dropped |
| `rx_dllp`, `rx_tlp` | DLLPs and TLPs started in L0: the partner's data link layer is up |
| `dll_replays`, `dll_rx_errors` | TLP replays; LCRC, sequence and framing errors |
| `dll_link_errors` | Replay rollovers, each requesting Recovery |

In the physical-layer-alone design, the host InitFC DLLPs counted in `rx_dllp` prove L0 at the data
link layer, while the root port shows the link up with `DLActive-`.

With `--with-analyzer`, the Acorn and YPCB-00338-1P1 targets add a LiteScope analyzer on Lane 0: the
received and transmitted symbols, Electrical Idle, receive errors, the Training Sequence and EIOS
detection and the LTSSM state, 2048 samples in the lane clock domain. Its configuration is written to
`analyzer.csv` for the LiteScope host tools.

At 8.0 GT/s, the `g3` commands of `status.py` read the block counters, raw words, a 1024-word raw
capture of Lane 0 and a trace of the rate change sequence. The transceiver DRP is reachable from the
registers, and a DRP program played right after the change to 8.0 GT/s runs the eye scans.

### Hardware findings {#debug-soft-findings}

`doc/softphy.md` records the bring-up of the soft PHY; two findings matter for debugging.

- **BAR read before the device is enabled.** On warm reboots with the design kept, the first BAR
  read before the device was enabled timed out at the host, as an Advisory Non-Fatal Error. It was
  not seen after a fresh load; the cause is not found.
- **No 8.0 GT/s link with a host on the GTX.** On the YPCB-00338-1P1, the speed change and the rate sequence
  complete, but no Training Sequence is received at 8.0 GT/s. The eye is open in near-end loopback
  and closed from the root port, which points to the channel of this board at 8.0 GT/s.

## Troubleshooting {#debug-troubleshooting}

| Symptom | Likely cause | Check | Chapter |
|--------------------------|--------------------------|-------------------------------------|-------------------|
| Wrong identifier | Wrong `csr.csv`, design reloaded from flash | `--csr-csv` of the build, reload | Debugging |
| No device in `lspci` | Loaded after boot, slot, BIOS | Warm reboot or rescan | Getting started |
| BAR reads all-ones after rescan | Host port not reprogrammed | Remove the host port, rescan | Debugging |
| Host hangs at boot | Configuration timeouts at boot | LTSSM disabled at reset (soft PHY) | Soft PHY |
| Driver does not load | Secure Boot, new kernel | `init.sh` message, rebuild | Linux driver |
| Probe fails in `dmesg` | BAR0, DMA mask, MSI | Kernel message table above | Linux driver |
| Link at a lower width | Lanes missing, lane order | `link_status` width, LTSSM history | Hard-IP PHYs |
| Link at a lower rate | Speed change failed, slot | `LnkSta`, Recovery in the history | Primer |
| Low DMA throughput | MPS at 128 bytes, narrow core | `max_payload_size`, data width | Performance |
| DMA throughput zero | Bus mastering, empty table | DMA register table above | DMA |
| "Reading too late" in `dmesg` | Application too slow | Buffer handling of the application | Linux driver |
| No interrupt | MSI not enabled, wrong MSI type | `msi_enable`, `pcie_msi_enable` | MMAP and IRQ |
| MSIs stall (GW5A) | Edge-triggered request | Space the interrupts | Hard-IP PHYs |
| No interrupt (CertusPro-NX) | MSI requested | Use MSI-X | Hard-IP PHYs |
| `SoCError` on MSI-X (`add_pcie`) | Paging, location taken | Paging `0x800`, no `csr_map` at 3 or 4 | Integration |
| Soft PHY stuck before L0 | Lock, polarity, lanes | `status.py status`, counters | Soft PHY |

Work through the rows from the top: each one assumes the checks above it pass. The chapters named
in the last column are [Getting started](#getting-started), [Soft PHY](#soft-phy),
[Linux driver and tools](#software), [Hard-IP PHYs](#hard-phys), [PCIe primer](#pcie-primer),
[Performance and resources](#performance), [Scatter-gather DMA](#dma),
[Memory-mapped bridges and interrupts](#mmap-irq) and [Integration](#integration); "Debugging"
points to [Access to the design](#debug-access).

Where to go next: [Register reference](#registers) for every register named here, and
[Build options](#build-options) for the debug options of the targets.
