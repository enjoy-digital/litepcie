# PTM requester integration

PTM remains opt-in. The established 7-series Gen1/Gen2 x1 path keeps its
original decoder. An experimental receiver adds 7-series x2/x4/x8 and
UltraScale+ Gen2 x1/x2/x4/x8 support.

| PHY | Receive path | Restrictions |
| --- | --- | --- |
| 7-series x1 | Existing decoder | Gen1/Gen2 |
| 7-series x2/x4/x8 | Per-lane descrambling, SKP removal, deskew and de-striping | Gen1/Gen2; negotiated-width fallback and full lane reversal |
| UltraScale+ PCIE4/PCIE4C | Native PIPE tap and the multi-lane decoder | Explicit Gen2; lane reversal disabled; at least 128-bit AXI interface |

UltraScale, UltraScale+ Gen3/Gen4 and x16 are not implemented. Unsupported
UltraScale+ PTM configurations fail during construction. Enabling PTM never
silently reduces the requested link speed or width.

## Integration

Instantiate `S7PCIEPHY(..., with_ptm=True)` or
`USPPCIEPHY(..., speed="gen2", with_ptm=True)`, and enable PTM on the endpoint:

```python
self.pcie_endpoint = LitePCIeEndpoint(self.pcie_phy, with_ptm=True)
self.pcie_ptm_sniffer = self.pcie_phy.create_ptm_sniffer()
self.ptm_capabilities = PTMCapabilities(self.pcie_endpoint)
self.ptm_requester = PTMRequester(
    self.pcie_endpoint, self.pcie_ptm_sniffer, sys_clk_freq)
```

Drive the requester's `time_clk`, `time_rst`, and nanosecond `time` inputs.
Software controls the requester through its existing CSRs. The new paths
preserve the response interface and requester register layout. Their receive
latency differs from x1; the existing PHY delay estimates need hardware
calibration before using timestamps for precise synchronization.

The standalone generator accepts `ptm: true`. Use `phy_lanes: 1/2/4/8` for
`S7PCIEPHY`. For `USPPCIEPHY`, also set `phy_speed: gen2` and
`phy_pcie_data_width` to at least 128. Normal generator/PHY defaults remain
unchanged when PTM is disabled.

## Configuration and transmit interfaces

7-series retains extended configuration at DWORD address `0x6b`. UltraScale+
uses the native configuration-extend interface: PF0's application window
starts at byte `0x480` on PCIE4 and `0xe80` on PCIE4C. The capability responder
provides a read-only PTM header and requester capability, byte-enabled control
writes, and zero-filled unused registers. It does not respond outside this
window or for other functions. The generated vendor capability chain points
at this application window.

The optional RQ conversion emits a native no-data Message descriptor for a
PTM Request, with message code `0x52` and local routing `100b`. Memory traffic
continues through the existing adapter; PTM-looking payload bytes do not
change a packet's type. Tests cover 128/256/512-bit interfaces, stalls and
interleaved DMA packets.

## Receive tap and builds

The hard IP filters PTM responses before the normal receive interface.
`create_ptm_sniffer()` owns the passive tap and post-synthesis connections.
Every source net and destination pin is checked before any connection changes;
a missing object stops the build instead of leaving a placeholder counter.

The 7-series tap uses the generated `pcie_s7` hierarchy. Each physical lane
occupies a 32-data-bit / 4-K-bit vendor slot, with the lower 16 / 2 bits used.
The UltraScale+ tap finds exactly one PCIE40E4/PCIE4CE4 primitive, and connects
its PIPE clock, clock enable, per-lane RxValid, data and K pins. It requires
the generated vendor core; custom/external hard-IP wrappers need separate
qualification.

After reconnecting the tap, the helper resolves the actual receive clock(s)
and constrains the asynchronous response FIFO crossing to the system clock.
This includes both clocks of the 7-series rate-select mux; on UltraScale+ the
native PIPE clock differs from the PCIe user clock used during synthesis.
Paths within each clock domain remain timed.

The multi-lane receiver reacquires COM alignment after link training,
width/reversal changes or elastic-buffer overflow. It compacts SKP symbols
independently on each lane and pipelines reconstruction/header parsing.
A response is published only after END; EDB, truncated payloads and invalid
TLP lengths discard it. Like the established
x1 receive path, this passive parser does not independently validate LCRC.

Simulation covers the existing x1 scrambler as a reference, independent serial
scrambling vectors, skew, SKP, width fallback, reversal, RxValid bubbles,
retraining, packet alignment, non-PTM traffic and backpressure. Tcl tests check
literal bus indices and failure before netlist mutation. A vendor-version or
hierarchy change still requires an actual Vivado build.

## Remaining work

Gen3/Gen4 requires 128b/130b block framing, per-lane descrambling and block/SKP
alignment; it cannot reuse the 8b/10b parser directly. x16 also requires a
wider packet parser that can handle a complete response within one beat.

[AMD PG213](https://www.xilinx.com/support/documents/ip_documentation/pcie4_uscale_plus/v1_3/pg213-pcie4-ultrascale-plus.pdf),
table 59, has no PTM message-routing selector. Enabling vendor-defined-message
routing therefore does not establish reception or preserve the full PTM
header. The configuration and RQ paths above can be reused when adding the
higher-speed receive decoder.

A successful build verifies synthesis, tap connectivity, implementation and
constraints. Host interoperability, error injection and timestamp offset/jitter
remain hardware qualification tasks.
