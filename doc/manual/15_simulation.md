# Simulation and verification {#simulation}

This chapter describes how the project is verified before a bitstream is built: the host models,
the unit tests, the Verilator simulations of the soft PHY and the continuous integration. It is for
contributors who change the gateware and for integrators who want to reproduce a problem without a
board.

## Verification strategy {#sim-strategy}

A PCIe problem is slow to diagnose on a board: a host that hangs at boot, a device that does not
enumerate, a buffer lost once per minute. Each layer is therefore checked in simulation first, at
the cheapest level that exercises it.

| Level | What runs | Partner | Simulator |
|------------------------|--------------------------------------|---------------------------|--------------------|
| Unit | One module (packetizer, adapter, DMA) | Python stimulus and models | Migen |
| Core | Endpoint, crossbar, DMA, MMAP, MSI-X | Python host model | Migen |
| Generated Verilog | Bridges and PTM receivers | Verilog testbench | Icarus Verilog |
| Soft PHY system | Two soft PHYs, or a SoC on the soft PHY | Soft root built from the same layers | Verilator |
| Elaboration | Bench targets and generator | None | None |
| Hardware | Bench target on a board | Linux host | |

The hard IPs have no simulation model in the project. Their wrappers are tested at their
interfaces: the AXI-Stream adapters of UltraScale(+), the 128-bit receive path of 7-Series, and the
alignment and MSI logic of Stratix V. The soft PHY is simulated whole, down to the symbols on the
lanes.

## Host model {#sim-host-model}

The core must be tested against a host, but no root complex exists as gateware. The project provides
a host model in Python (`test/model/`), simulated with Migen next to the design under test, as the
figure below shows.

![Migen unit tests: the host model exchanges TLPs with the endpoint and the DMA under test through
a PHY model, without hard IP or transceiver.](sim_host_model.svg)

| Model | File | Role |
|--------------|-------------------------------------------------|----------------------------------------------|
| Host | `test/model/host.py` | Host memory; answers the reads and writes of the device |
| Chipset | `test/model/chipset.py` | Completions, splitting at 64, 128 or 256 bytes, reordering |
| PHY | `test/model/phy.py` | Sends and receives TLPs on the PHY streams of the core |
| TLP | `test/model/tlp.py` | Encoding and decoding of MemRd, MemWr, Cpl and CplD headers |

The chipset model splits the completions of a read the way a root complex does, and can return them
out of order. The DMA tests use it to check that the TLP controller reorders the completions and
that every byte lands at its place.

The PHY model can also present the 128-bit receive interface of the 7-Series hard IP, which does not
mark the end of the packets.

The soft PHY has its own reference models in `test/model/soft/`: the scrambler, the LCRC and DLLP
CRC checked against `zlib.crc32`, and the DLLP and TLP framing. They are written from the
specification, independently of the gateware.

## Unit tests {#sim-tests}

The tests are Python `unittest` classes and pytest functions run by pytest, in `test/`. The table
below groups the files by area.

| Area | Test files |
|-------------------|------------------------------------------------------------------------------------------|
| TLP layer | `test_header_inserter`, `test_header_inserter_tails`, `test_header_extracter`, `test_request_packetizer`, `test_completion_packetizer`, `test_tlp_controller` |
| Hard-IP PHYs | `test_xilinx_pciephy`, `test_xilinx_request_mapping`, `test_xilinx_tuser_mapping`, `test_m_axis_cq_adapter`, `test_m_axis_rc_adapter`, `test_s_axis_cc_adapter`, `test_s_axis_rq_adapter`, `test_axis_adapter_cross_width_properties`, `test_phy_rx_widths`, `test_phy_rx_128b_eof_byte_enables`, `test_phy_tx_packet_buffer`, `test_c5pciephy`, `test_svpciephy`, `test_svpciephy_msi` |
| DMA | `test_dma`, `test_dma_reader_retire`, `test_dma_reader_retire_widths`, `test_dma_status` |
| MMAP and interrupts | `test_wishbone`, `test_wishbone_read_pipeline`, `test_msix` |
| PTM | `test_ptm_filter`, `test_ptm_native`, `test_ptm_pipe`, `test_ptm_pipe_rtl`, `test_ptm_pipe_tap`, `test_ptm_s7_tap`, `test_ptm_gen34`, `test_ptm_lane_buffer_rtl` |
| Soft PHY, physical layer | `test_soft_coding`, `test_soft_scrambler`, `test_soft_datapath`, `test_soft_ordered_sets`, `test_soft_ltssm`, `test_soft_pipe`, `test_soft_phy`, `test_soft_lanes`, `test_soft_rate`, `test_soft_gen3`, `test_soft_gt`, `test_soft_serdes` |
| Soft PHY, upper layers | `test_soft_crc`, `test_soft_dll`, `test_soft_dll_buffer`, `test_soft_dll_framing`, `test_soft_dll_replay`, `test_soft_dll_wide`, `test_soft_tl` |
| System (Verilator) | `test_soft_sim` |
| Targets and software | `test_examples`, `test_kernel_mmap` |

The DMA tests run the core against the host model at 64, 128 and 256
bits, with 32-bit and 64-bit addresses and awkward lengths.

The `_rtl` tests and `test_wishbone_read_pipeline` simulate the generated Verilog with Icarus
Verilog and are skipped when it is not installed. `test_examples` elaborates the four hard-IP
targets and runs the generator on `examples/ac701.yml`, and `test_kernel_mmap` compiles the mmap
path of the driver against a mock of the kernel.

### Markers and commands {#sim-commands}

Tests carry pytest markers, declared in `pytest.ini`, that select them by cost. The table lists
the markers the tests use.

| Marker | Content |
|--------------------------|------------------------------------------------------------------------------------|
| `sim` | Simulation-based tests (Migen or Verilator) |
| `slow` | Long simulations and generation tests |
| `examples` | Elaboration of the bench targets and of the generator |

```sh
# Fast suite, as the CI job "Tests" runs it (-n auto: one worker per core, pytest-xdist)
python3 -m pytest -v -n auto -m "not slow"
# Long tests, as the CI job "Slow Tests" runs them; Verilator simulations when it is installed
python3 -m pytest -v -n auto -m slow
# One area
python3 -m pytest -v test/test_soft_*.py
```

The Migen simulator runs about 15 cycles per second on a whole soft link, far too slow for a link
training. The Migen tests of the soft PHY therefore stop at the LTSSM pair and the elaboration of
the physical layer; the link itself is simulated with Verilator.

## Soft PHY system simulations {#sim-soft}

Four scripts of `bench/soft/` build a system simulation with the LiteX Verilator simulator. Each
puts the soft PHY face to face with a partner built from the same layers, through two transceiver
models (`PCIeSerDesModel`). The figure below shows the most complete one, `sim_soc.py`.

![Soft PHY SoC simulation: a root made of the soft data link and physical layers with a host model,
and the LitePCIe SoC on `SoftPCIEPHY`. The cyan arrows are the only link between the two sides; the
symbol shift and the lane skew apply there.](sim_soft_link.svg)

| Script | Root side | Device side | Checks |
|--------------------------------|-------------------------|-----------------------|----------------------------|
| `sim.py` | Physical layer (downstream) | Physical layer (upstream) | Training, packets, Recovery |
| `sim_wide.py` | Wide data link layer | Wide data link layer | TLPs at every length, replays |
| `sim_endpoint.py` | Scripted root | LitePCIe endpoint | Configuration, BAR0, MSI |
| `sim_soc.py` | Host model, driver sequence | SoC with `add_pcie` | DMA loopback, MSIs |

`sim.py` trains two physical layers to L0, exchanges packets both ways, retrains the link through
Recovery and exchanges packets again. With `--with-dll` both sides get a data link layer, and the
run checks flow control, DL_Active and the delivery of every TLP once and in order.

`sim_wide.py` runs two data link layers of several DWs per cycle on ideal lanes. With `--phy` it
adds the multi-lane physical layers with a symbol shift and a skew per lane, the speed change to
5.0 or 8.0 GT/s and the 8.0 GT/s equalization.

`sim_endpoint.py` enumerates a LitePCIe endpoint on `SoftPCIEPHY` from a scripted root. It checks
the configuration space, the BAR0 accesses and their byte order, the Unsupported Requests, MSI and
the reads and writes of the device, with the TLPs compared on the wire.

`sim_soc.py` runs the SoC of the Acorn target against a host model that plays the register sequence
of the Linux driver. The completions are split at the 64-byte Read Completion Boundary, as a host
does.

In `sim_soc.py`, the link clock and the core clock are the same signal by default. On hardware
they are unrelated: the core clock comes from a local oscillator and the link clock from the
reference clock of the host.

`--sys-link-ratio` gives the link clock, and the lane clock derived from it, a clock unrelated to
the core clock, at the ratio of the two frequencies. The crossings between the SoC and the soft
PHY then see two asynchronous clocks. Run it with a ratio below and above 1.

```sh
# Link training, packets, Recovery (scaled timers)
python3 bench/soft/sim.py --timer-scale 100
# Same with the data link layers and lane corruption
python3 bench/soft/sim.py --with-dll --corrupt-every 5
# Speed change to 5.0 GT/s, then fallback when 5.0 GT/s fails
python3 bench/soft/sim.py --gen2 --with-dll
python3 bench/soft/sim.py --gen2 --fail-5g --with-dll
# x8 at 8.0 GT/s with the equalization, root requesting preset 8
python3 bench/soft/sim_wide.py --phy --gen3 --nlanes 8 --eq-preset 8
# SoC with DMA, then at 8.0 GT/s on x8
python3 bench/soft/sim_soc.py --mps 256 --dma-size 1024 --dma-buffers 4
python3 bench/soft/sim_soc.py --gen3 --nlanes 8
# Core clock slower, then faster than the link clock, on unrelated clocks
python3 bench/soft/sim_soc.py --sys-link-ratio 0.8333 --dma-size 4096 --dma-buffers 2
python3 bench/soft/sim_soc.py --sys-link-ratio 1.37 --dma-size 4096 --dma-buffers 2
```

Every script ends with `SIM OK`, or with a timeout or mismatch message. `--timer-scale` divides the
LTSSM timers to shorten the runs; `--timer-scale 1` uses the timers of the specification.
`--trace` writes a VCD in the build directory, except on `sim_wide.py`. [Simulation
scripts](#opt-sim) lists all the options.

`test/test_soft_sim.py` runs these scripts with pytest, marked `slow` and `sim`, and checks their
output: L0 reached, no data error, DL_Active on both sides, the rate after a speed change, no
return to Detect after the first L0. It is skipped when Verilator is not installed.

## Continuous integration {#sim-ci}

The CI workflow (`.github/workflows/ci.yml`) runs on every push and pull request. It installs Icarus
Verilog, LiteX with its cores through `litex_setup.py`, and the project, on Ubuntu 22.04 with
Python 3.9, in two jobs that run in parallel:

1. "Tests", the fast suite (`-m "not slow"`);
2. "Slow Tests", the long tests (`-m slow`).

Each job spreads its tests over the cores of the runner (`pytest-xdist`, `-n auto`) and lists its
15 slowest tests at the end of its log. A run lasts as long as the slower job, which is bound by its
longest single simulations rather than by the number of tests.

The workflow does not install Verilator, so `test_soft_sim.py` skips the soft PHY system
simulations there. Run them locally, with Verilator installed, before changing the soft PHY.

The documentation workflow (`.github/workflows/doc.yml`) checks the figures and this manual; the
[Maintenance](#maintenance) appendix describes it.

## Adding a test {#sim-add-test}

A new test goes in `test/test_<area>.py`, with the reference model of the rule it checks.

- Prefer a Migen unit test against the host model or a Python reference; keep Verilator for what
  needs a whole soft link.
- Mark a test of more than a minute with `slow`, and a test that needs Verilator with `sim`;
  skip it when the simulator is not found, as `test_soft_sim.py` does.
- Seed every random generator, so that a failure replays.
- Test the root port and the 256 and 512-bit datapaths explicitly: they are less used than the
  endpoint at 64 and 128 bits.

Where to go next: [Debugging](#debugging) for the hardware side, and [Build options](#build-options)
for every option of the simulation scripts.
