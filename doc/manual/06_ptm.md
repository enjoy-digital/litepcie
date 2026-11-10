# Precision Time Measurement {#ptm}

This chapter describes the PTM requester: the frontend that measures the time of the root complex
from the device, so that a clock in the FPGA can follow the host clock. Read it to add PTM to a
design or to understand its tap on the receive lanes. PTM itself is introduced in
[PCI Express in a nutshell](#pcie-primer).

## At a glance {#ptm-glance}

| Item | Value |
|---------------------|-------------------------------------------------------------------|
| Classes | `PTMCapabilities`, `PTMRequester` (`litepcie/frontend/ptm/core.py`) |
| Role | PTM requester (endpoint only) |
| PHYs | 7-Series (`S7PCIEPHY`), UltraScale+ (`USPPCIEPHY`), `with_ptm=True` |
| Receive path | Passive tap on the receive lanes of the hard IP |
| Time input | 64-bit time in ns, in its own clock domain |
| Results | t1, t4, master time and link delay, in ns, in registers and signals |
| Generator | `ptm: true` |

## PTM in one exchange {#ptm-exchange}

PTM lets a device read the time of the root complex with the delay of the link taken out:
[Precision Time Measurement](#primer-ptm) in the primer explains the exchange and its four times.
The figure below recalls which side records which time.

![PTM dialog. Look at the four times: the requester records t1 and t4 with its local time, the
responder records t2 and t3 and sends its time in the ResponseD.](ptm_exchange.svg)

The requester takes t1 when the packetizer accepts its PTM Request, before the request crosses
the hard IP. It takes t4 when the receive tap delivers the ResponseD, after the tap has decoded it
and brought it to the `sys` clock domain. Both times therefore include PHY latencies, which the
`phy_tx_delay` and `phy_rx_delay` estimates stand for (see [Requester](#ptm-requester)).

The ResponseD carries the master time of the root complex and a 32-bit delay field. The requester
stores both as received, as `master_time` and `link_delay`, next to t1 and t4. It does not
compute an offset: software or user logic combines these values and the PHY delays to correct
its local clock.

The requester treats a response whose master time is zero as a PTM Response without timing data:
the responder has no valid time yet. It then waits 1 µs and sends a new request.

## Support {#ptm-support}

The x1 receive path of the 7-Series PHY is the established one. The other paths are experimental
and need hardware qualification, as [Limitations](#ptm-limits) lists.

| PHY | Speeds | Widths | Receive path |
|------------------|------------|------------|------------------------------------------------|
| 7-Series | Gen1, Gen2 | x1 | Single-lane decoder |
| 7-Series | Gen1, Gen2 | x2, x4, x8 | Multi-lane 8b/10b receiver; width fallback and full lane reversal |
| UltraScale+ | Gen2 | x1 to x8 | Native PIPE tap, multi-lane 8b/10b receiver |
| UltraScale+ | Gen3, Gen4 | x4, x8 | Native PIPE tap, 128b/130b receiver |

The UltraScale+ paths need a PCIe datapath of at least 128 bits and work with lane reversal
disabled. UltraScale, UltraScale+ at Gen3 or Gen4 in x1 or x2, and x16 links are not supported.
An unsupported UltraScale+ configuration fails when the PHY is built: enabling PTM never lowers
the requested speed or width.

## Integration {#ptm-integration}

A PTM design enables PTM on the PHY and on the endpoint, then adds the receive tap, the
capability and the requester. The example below is the sequence of `doc/ptm.md`, which the
generator also follows.

```python
from litepcie.core         import LitePCIeEndpoint
from litepcie.frontend.ptm import PTMCapabilities, PTMRequester

self.pcie_phy = S7PCIEPHY(platform, pads, data_width=64, with_ptm=True)
self.pcie_endpoint    = LitePCIeEndpoint(self.pcie_phy, with_ptm=True)
self.pcie_ptm_sniffer = self.pcie_phy.create_ptm_sniffer()
self.ptm_capabilities = PTMCapabilities(self.pcie_endpoint)
self.ptm_requester    = PTMRequester(self.pcie_endpoint, self.pcie_ptm_sniffer,
    sys_clk_freq)

# Local time, in ns, in its own clock domain.
self.comb += [
    self.ptm_requester.time_clk.eq(time_clk),
    self.ptm_requester.time_rst.eq(time_rst),
    self.ptm_requester.time.eq(time_ns),
]
```

The time input is a 64-bit count of nanoseconds, from the clock that PTM disciplines. The
requester brings it to the `sys` clock domain and samples it at t1 and t4.

With the generator, `ptm: true` builds the same chain with an S7 or UltraScale+ PHY. The core then
has a `ptm` port with `time_clk`, `time_rst` and `time_ns`. Select the lanes with `phy_lanes` for
the 7-Series PHY, and `phy_speed` with a `phy_pcie_data_width` of at least 128 for the
UltraScale+ PHY. [Integration](#integration) describes the generator.

## PTM capability {#ptm-capability}

The host enables PTM on a device that advertises the PTM extended capability in its configuration
space. The hard IPs do not provide it, so LitePCIe adds it: `PTMCapabilities` answers the
configuration accesses to its three registers.

| Register | Content |
|------------|------------------------------------------------------------------------|
| Header | Capability ID `0x1f`, version 1, last capability of the list |
| Capability | Requester capable; local clock granularity 8 ns |
| Control | PTM Enable, Root Select, Effective Granularity, written by the host |

The two PHYs reach the capability in different ways:

- **7-Series**: the hard IP forwards the accesses to its extended configuration space, from
  DW `0x6b` (byte `0x1ac`), as CfgRd0 and CfgWr0 TLPs. The endpoint decodes them
  (`with_ptm=True`) and the capability answers reads with a CplD.
- **UltraScale+**: the hard IP has a configuration extension interface. Its application window
  starts at byte `0x480` on PCIE4 and `0xe80` on PCIE4C. The capability answers the accesses of
  function 0 in this window, with zeros for its unused registers.

The capability outputs the PTM Enable bit and the effective granularity that the host wrote.

## Requester {#ptm-requester}

The requester runs the PTM dialog. Software or user logic enables it and triggers each
measurement; the requester sends the request, waits for the response and stores the results. Its
class is `PTMRequester`.

| State | Meaning |
|------------------|-------------------------------------------------------------------|
| Invalid context | Enabled, no measurement yet; waits for a trigger |
| Request | Sends a PTM Request; t1 sampled when the packetizer accepts it |
| Wait response | Waits for a PTM Response from the receive tap |
| Valid context | Results valid; a trigger starts a new measurement |

The PTM Request goes through the request packetizer of the endpoint. On the 7-Series PHY it
leaves as a TLP like any other. On the UltraScale+ PHY, the request adapter turns it into a
message descriptor of the hard IP, with message code `0x52` and local routing.

The register bank `ptm_requester` gives software control and results. The `phy_tx_delay` and
`phy_rx_delay` registers are constants of 40 ns and 100 ns: the estimated delays of the PHY
logic, for software to subtract. [PTM registers](#reg-ptm) lists the bank.

| Register | Content |
|-----------------------------------|---------------------------------------------------|
| `control` | `enable`; `trigger`, a pulse that starts a measurement |
| `status` | `valid` (results valid), `busy` (measurement in progress) |
| `t1_time`, `t4_time` | Local times of the request and of the response, ns |
| `master_time`, `link_delay` | Fields of the last PTM ResponseD, ns |
| `phy_tx_delay`, `phy_rx_delay` | Estimated PHY delays, ns |

## Receive tap {#ptm-tap}

The hard IPs consume the PTM Responses they receive and do not pass them to the user interface.
LitePCIe therefore listens to the receive lanes of the hard IP, as the figure below shows. The
tap decodes the link symbols again and gives the PTM Responses to the requester; the hard IP
works as before.

![PTM paths. Follow the cyan path: the receive tap copies the symbols from the transceivers to
the requester, while the PTM Request leaves through the packetizer and the hard
block.](ptm_tap.svg)

`create_ptm_sniffer()` builds the tap that matches the PHY, its speed and its lanes. The tap is
passive: it reads the lanes and never drives them.

### Tap connections {#ptm-tap-connections}

The receive lanes are internal nets of the hard IP. The tap is a placeholder module in the
design, whose inputs are connected to these nets after synthesis by Vivado commands that the PHY
adds to the build. Each net and each pin is checked before any connection changes: a missing one
stops the build.

| PHY | Tapped nets |
|-------------|----------------------------------------------------------------------------|
| 7-Series | Receive data and K bits of the transceivers, in the generated `pcie_s7` hierarchy |
| UltraScale+ | PIPE pins of the one PCIE40E4 or PCIE4CE4 primitive: clock, per-lane valid, data |

At Gen2 the UltraScale+ tap also takes the K pins; at Gen3 and Gen4 it takes the data valid,
start block and sync header pins. The tap needs the vendor core generated by the PHY: an external
or custom hard IP wrapper needs its own qualification.

After the connections, the helper finds the real receive clocks and constrains the crossing of
the response FIFO to the `sys` clock. Paths inside each clock domain stay timed.

### Receivers {#ptm-receivers}

The tap decodes what the hard IP has already decoded once: descrambling, lane alignment and TLP
framing. The figure below shows the multi-lane receiver at Gen1 and Gen2.

![Multi-lane Gen1 and Gen2 PTM receiver. Follow the cyan path: each lane is descrambled and freed
of its SKP symbols, the lanes are deskewed and merged, and the parser extracts the PTM
Responses.](ptm_rx.svg)

There are three receivers:

- **7-Series x1**: one lane of 16 bits per clock, converted to 32-bit words, descrambled and
  aligned on the TLP framing. PTM TLPs are kept and decoded by a depacketizer.
- **Gen1 and Gen2, x1 to x8**: two symbols per lane and per clock. Each lane is descrambled and
  its SKP symbols are removed; the lanes are then deskewed and de-striped. The receiver aligns
  again on a COM after link training, a change of width or reversal, or a buffer overflow.
- **Gen3 and Gen4, x4 and x8**: each lane assembles 128-bit blocks and takes its scrambler seed
  from an SOS. Ordered sets are removed and per-lane FIFOs deskew the data. The receiver finds the
  STP token and the PTM Response in the striped bytes, also across a block boundary.

A response is published only after its END symbol; EDB, truncated payloads and invalid lengths
discard it. The receivers do not check the LCRC of the responses.

## Calibration and results {#ptm-results}

The PHY delays of the requester are estimates, and the multi-lane receivers have a different
latency from the x1 one. Before using the timestamps for precise synchronization, calibrate these
delays on hardware.

The figure below is a scope capture of the PPS (pulse per second) outputs of two cards whose
clocks are disciplined by PTM, in persistence mode. The spread of the second edge against the
first is the skew between the two cards; the scope statistics at the bottom report it over the
recorded edges, for this setup only.

![PPS skew between two PTM-disciplined cards. Look at the purple edges: they spread around a
fixed offset from the reference edge; the statistics at the bottom give the skew between the two
cards.](ptm_pps_jitter.png)

## Limitations {#ptm-limits}

- Requester only: no PTM responder or root capability.
- The receivers do not check the LCRC; a corrupted response could give a wrong time.
- UltraScale+: lane reversal disabled. Gen3 and Gen4: x4 and x8 at the configured width only; a
  width downshift needs another build.
- Gen3 and Gen4 receiver: one response per block.
- To qualify on hardware: SOS seed extraction, the Gen4 PIPE mapping, interoperability with
  hosts, skew tolerance, error rejection, offset and jitter calibration.

## In the code {#ptm-code}

The files below are in the `litepcie/frontend/ptm/` directory.

| File | Main classes | Role |
|------------------|----------------------------------|------------------------------|
| `core.py` | `PTMCapabilities` | Capability registers |
| `core.py` | `PTMRequester` | PTM dialog, registers |
| `sniffer.py` | `S7PCIePTMSniffer` | 7-Series x1 receiver |
| `pipe.py` | `PCIePTM8b10bReceiver` | Gen1 and Gen2 multi-lane receiver |
| `pipe_gen34.py` | `PCIePTM128b130bReceiver` | Gen3 and Gen4 receiver |

The 7-Series multi-lane tap is `S7PCIePTMMultiLaneSniffer`; the UltraScale+ taps are
`USPPCIePTMGen2Sniffer` and `USPPCIePTMGen34Sniffer`. The checked tap connections are made by
`add_checked_tap_connections` in `pipe.py`. The tests are the `test/test_ptm_*.py`
files: scrambling, skew, SKP, width fallback, reversal, retraining, the Tcl of the taps and the
Gen3 and Gen4 blocks.

Where to go next: [Hard-IP PHYs](#hard-phys) for the PHYs that support PTM,
[Integration](#integration) for the generator options, [Register reference](#registers) for the
PTM registers.
