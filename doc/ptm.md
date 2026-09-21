# PTM requester integration

The currently implemented receive decoder supports **7-series Gen1/Gen2 x1**.
PTM remains opt-in. A multi-lane link cannot use the x1 decoder: symbols are
striped across lanes, which require deskew and lane reconstruction.

For a LiteX SoC, instantiate `S7PCIEPHY(..., with_ptm=True)` and
`LitePCIeEndpoint(..., with_ptm=True)`, then register the receive module:

```python
self.pcie_ptm_sniffer = self.pcie_phy.create_ptm_sniffer()
self.ptm_capabilities = PTMCapabilities(self.pcie_endpoint)
self.ptm_requester = PTMRequester(
    self.pcie_endpoint, self.pcie_ptm_sniffer, sys_clk_freq)
```

Drive the requester's `time_clk`, `time_rst`, and nanosecond `time` inputs.
Software controls the requester through its existing CSRs. The receive module
preserves the original decoder, clock/reset wiring and CDC pipeline.

The standalone generator enables the same path with `"ptm": True`,
`"phy": "S7PCIEPHY"`, and `"phy_lanes": 1`. It also enables the extended
configuration space at DWORD address `0x6b`, required by `PTMCapabilities`.
Other PHY/lane combinations are rejected rather than generating an unusable
PTM requester.

## Receive tap and builds

The 7-series hard IP filters PTM responses before the AXI receive interface.
`create_ptm_sniffer()` owns the passive transceiver tap and its post-synthesis
Vivado connections. The implementation expects the generated `pcie_s7` IP
hierarchy. It checks all 18 source nets and destination pins before connecting
any of them. A missing object stops the build before optimization; it must not
produce a bitstream that samples the placeholder counters.

Changing the IP version or hierarchy therefore requires a Vivado build, not
just Python/RTL generation. The Tcl tests cover literal bus indices and missing
source/destination failures. Generator tests cover Artix-7 and Kintex-7 x1.

## Further PHY support

A wider 7-series receive path needs per-lane descrambling, SKP handling, deskew,
negotiated-width/lane-order handling, and TLP reconstruction at line rate. Keep
the existing x1 path available when adding that decoder.

UltraScale/UltraScale+ also need extended-configuration capability handling and
PTM request conversion to the native RQ descriptor. The current RQ/CQ adapters
do not implement PTM messages. A receive route must be established separately:
AMD PG213 v1.3 (November 16, 2022), table 59, lists the message-routing bits but
provides no PTM selector. Enabling vendor-defined-message routing does not
establish PTM reception or preserve its full timing header. A raw Gen3/Gen4
receive decoder would additionally need 128b/130b block handling and the
appropriate per-lane descramblers.

Reference: [AMD PG213](https://www.xilinx.com/support/documents/ip_documentation/pcie4_uscale_plus/v1_3/pg213-pcie4-ultrascale-plus.pdf),
"Message Requests on the Completer Request Interface".

A successful build verifies synthesis, tap connectivity, implementation and
constraints. Link interoperability and timestamp accuracy remain separate
hardware qualification tasks.
