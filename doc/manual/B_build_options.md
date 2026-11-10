# Build options {#build-options}

This appendix lists the command line options of the bench targets, of the soft PHY targets and
scripts, of the simulation scripts, and the keys of the generator configuration. The options come
from the argument parsers of the scripts; `--help` prints the same list with the defaults of the
installed version.

## Hard-IP bench targets {#opt-hard}

The targets `kc705`, `kcu105`, `xcu1525` and `fk33` share their options. Run without `--build`, a
target elaborates the design and writes the sources and the `csr.csv` without calling the FPGA
toolchain. [Hard-IP bench targets](#ex-hard) describes the design they build.

| Option | Default | Effect |
|---------------------------|------------------------------|----------------------------------------------------|
| `--build` | off | Build the bitstream with the FPGA toolchain |
| `--load` | off | Load the bitstream into the FPGA (volatile) |
| `--driver` | off | Generate the driver and the tools for this design in `<output-dir>/driver` |
| `--nlanes` | 4 | Lanes: 1, 4 or 8 (`kc705`); 4 or 8 (`kcu105`); 4, 8 or 16 (`xcu1525`, `fk33`) |
| `--speed` | `gen3` | PCIe speed, `gen3` only (`kcu105`, `xcu1525`, `fk33`) |
| `--output-dir` | `build/<target>` | Build directory |
| `--csr-csv` | `csr.csv` | Register map file, in the current directory |

The `acorn` target, which instantiates a generated core, has only `--build` and `--load`; it runs
from the `bench/` directory (see [Standalone core in a SoC](#ex-acorn)).

## Soft PHY targets {#opt-soft}

The soft PHY targets are in `bench/soft/`. Without `--with-endpoint` they build the physical layer
alone; [Soft PHY targets](#ex-soft) describes the three designs.

| Option | Default | Effect |
|-------------------------------------|--------------------------------------|---------------------------------|
| `--build` | off | Build the bitstream |
| `--with-endpoint` | off | Full endpoint: `SoftPCIEPHY`, MMAP, one DMA, MSI |
| `--ltssm-autostart` | off | LTSSM enabled at reset, not disabled by PERST# |
| `--driver` | off | Generate the driver and the tools |
| `--output-dir` | `build/soft_<target>` | Build directory |

The options below exist only on some targets.

| Option | Targets | Default | Effect |
|---------------------------------------|--------------|------------------|-------------------------------------|
| `--load` | `acorn` | off | Load the bitstream (volatile) |
| `--variant` | `acorn` | `cle-215+` | Board variant: `cle-101`, `cle-215`, `cle-215+` |
| `--lane` | `acorn` | 3 | Lane of the x4 connector used as x1 |
| `--with-jtagbone` | `acorn` | off | JTAGBone instead of UARTBone |
| `--with-debug` | `acorn` | off | Debug registers on the full endpoint |
| `--with-ltssm-tracer` | `acorn` | off | LTSSM tracer on the full endpoint |
| `--with-analyzer` | `acorn`, `ypcb` | off | LiteScope analyzer on Lane 0 |
| `--hard-ip` | `acorn`, `ypcb` | off | Same endpoint on the hard IP |
| `--speed` | `ypcb`, `ku3p` | `gen1` | Highest speed: `gen1`, `gen2`; `gen3` on `ypcb` with `--with-endpoint` |
| `--nlanes` | `ypcb`, `ku3p` | 1 | Lanes: 1, 2, 4 or 8 (`ypcb`; x2 soft PHY only); 1 (`ku3p`) |

The Acorn target uses lane 3 of the x4 connector by default, the lane that the LiteX Acorn
Baseboard Mini wires to its x1 slot. The `ypcb` and `ku3p` targets write `csr.csv` in their build
directory, the `acorn` target in the current directory. The `ypcb_gen3` lane test has only
`--build` and `--output-dir` (`build/soft_ypcb_gen3`).

### Host scripts {#opt-scripts}

The soft PHY status script is `bench/soft/status.py`, the LTSSM tracer script
`bench/test_ltssm_tracer.py`.

| Script | Option | Default | Effect |
|-----------------------------------------|--------------------|--------------------|----------------------------|
| `status.py` | `--csr-csv` | `csr.csv` | Register map of the build |
| `status.py` | `--host` | `localhost` | `litex_server` host |
| `status.py` | `--port` | 1234 | `litex_server` port |
| `test_ltssm_tracer.py` | `--csr-csv` | `csr.csv` | Register map of the build |
| `test_ltssm_tracer.py` | `--port` | 1234 | `litex_server` port |
| `test_ltssm_tracer.py` | `--family` | `7series` | State table: `7series` or `ultrascale` |

`status.py` takes a list of commands, `status` by default; [Soft PHY debug](#debug-soft) lists
them.

## Simulation scripts {#opt-sim}

The four Verilator simulations of `bench/soft/` share the options below.
[Soft PHY system simulations](#sim-soft) describes what each one checks.

| Option | Default | Effect |
|----------------------------|------------------------------------------|--------------------------------------|
| `--trace` | off | Write a VCD of the simulation; not on `sim_wide.py` |
| `--max-cycles` | `2**22` (`sim.py`: `2**24`) | Timeout, in system clock cycles |
| `--output-dir` | `build/soft_sim_<name>` | Build directory (`build/soft_sim` for `sim.py`) |
| `--timer-scale` | 100 | Divide the LTSSM timers (1: specification timers); not on `sim_wide.py` |
| `--ts1-min` | 64 (`sim.py`: 1024) | TS1 sent in Polling.Active (specification: 1024); not on `sim_wide.py` |

`sim.py` also takes `--trace-start` and `--trace-end`, the cycles where the VCD starts and ends.

### `sim.py` {#opt-sim-link}

| Option | Default | Effect |
|---------------------------------------------|--------------|--------------------------------------------------|
| `--packets` | 64 | Packets exchanged in each direction |
| `--with-dll` | off | Data link layers on both sides: TLPs, ACKs, replays |
| `--gen2` | off | Speed change to 5.0 GT/s after the training |
| `--fail-5g` | off | With `--gen2`: the upstream port cannot receive at 5.0 GT/s |
| `--corrupt-every N` | 0 | Corrupt a lane word after every Nth upstream TLP |
| `--drop-dllp-every N` | 0 | Drop every Nth downstream DLLP |
| `--debug` | off | Print the DLLPs and the data link layer states |

### `sim_endpoint.py` and `sim_soc.py` {#opt-sim-soc}

| Option | Script | Default | Effect |
|--------------------------------|-----------------------------|--------------|---------------------------------|
| `--data-width` | `sim_endpoint` | 64 | Data width of the core: 64, 128 or 256 |
| `--nlanes` | both | 1 | Lanes of the design (above x1: 32 bits per lane) |
| `--dead-lanes` | both | 0 | Device lanes out of service (mask): a narrower link |
| `--width` | `sim_endpoint` | none | Width expected in the Link Status register |
| `--dma-size` | `sim_soc` | 1024 | DMA buffer size, in bytes |
| `--dma-buffers` | `sim_soc` | 4 | Number of DMA buffers |
| `--full-rate` | `sim_soc` | off | Lanes at the 5.0 GT/s rate |
| `--gen3` | `sim_soc` | off | Speed change to 8.0 GT/s before the script |
| `--mps` | `sim_soc` | 256 | Max Payload Size: 128, 256 or 512 |

### `sim_wide.py` {#opt-sim-wide}

| Option | Default | Effect |
|------------------------------------|---------------|----------------------------------------------------------|
| `--ndw` | the lanes | DWs per cycle of the data link layers |
| `--nlanes` | 4 | Link width |
| `--tlps` | 200 | TLPs exchanged in each direction |
| `--corrupt-every` | 0 | Corrupt every Nth TLP from one side to the other (power of 2) |
| `--phy` | off | Add the multi-lane physical layers and transceiver models |
| `--gen2` | off | With `--phy`: speed change to 5.0 GT/s |
| `--gen3` | off | With `--phy`: speed change to 8.0 GT/s, with equalization |
| `--eq-preset` | none | With `--gen3`: preset requested by the root port |
| `--fail-8g` | off | With `--gen3`: nothing received at 8.0 GT/s, fallback |
| `--rate-stall` | 0 | With `--phy`: receivers stopped after a rate change, per lane |
| `--dead-lanes` | 0 | With `--phy`: upstream lanes out of service (mask) |

## Generator {#opt-gen}

The generator builds a standalone core from a YAML configuration. [Integration](#integration)
describes the generated core and its ports; [Generator configurations](#ex-gen) lists the
examples.

```sh
litepcie_gen <config> [--output-dir build] [--header-dir ./] [--doc]
```

| Option | Default | Effect |
|----------------------------|--------------|-------------------------------------------------------------------|
| `--output-dir` | `build` | Build directory; the core is `gateware/litepcie_core.v` |
| `--header-dir` | `./` | Directory of the `csr.h`, `soc.h` and `mem.h` headers |
| `--doc` | off | Also build the register documentation of the core (Sphinx) |

### Configuration keys {#opt-gen-keys}

The tables below give every key that `litepcie/gen.py` reads, with its default; "required" marks the
keys without one. The PHY keys come first.

| Key | Default | Effect |
|--------------------------------------------------|-----------------|-----------------------------------------|
| `phy` | required | PHY class, see below |
| `phy_device` | required | FPGA device of the vendor platform (`xc7a`, `xcku`) |
| `phy_lanes` | required | Number of lanes |
| `phy_speed` | PHY default | `speed` of the PHY (`gen2`, `gen3`, `gen4`) |
| `phy_data_width` | required | Data width of the core, in bits |
| `phy_pcie_data_width` | 64 | Data width of the hard IP; 256 on GW5A, 128 on CertusPro-NX |
| `phy_bar0_size` | required | BAR0 size, in bytes |
| `clk_freq` | `125e6` | Frequency of the user clock, in Hz |
| `clk_external` | `False` | User clock from the `clk` input instead of the PCIe clock |
| `csr_ordering` | `big` | Ordering of the registers wider than 32 bits |
| `ep_address_width` | 32 | DMA address width: 32 or 64 |
| `ep_max_pending_requests` | 4 | Read requests in flight |
| `ptm` | `False` | PTM capability and requester, with the 7-Series or UltraScale+ PHY |

The `phy` key takes `S7PCIEPHY`, `USPCIEPHY`, `USPPCIEPHY`, `SVPCIEPHY`, `GW5APCIEPHY` or
`SoftPCIEPHY`. `SVPCIEPHY` requires `clk_external: True`, because its transceiver reconfiguration
controller needs a free-running clock, and takes no `phy_pcie_data_width`. The parser also knows
`C5PCIEPHY` and `LFCPNXPCIEPHY`, but the generator does not support these two PHYs yet.

| Key | Default | Effect |
|-------------------------------------------|------------------|-----------------------------------------------|
| `ctrl` | `False` | AXI-Lite slave port to the registers of the core |
| `mmap` | `False` | AXI-Lite master: host accesses to a BAR0 window |
| `mmap_base` | required | Base of the window in BAR0, with `mmap` |
| `mmap_size` | required | Size of the window, with `mmap` |
| `mmap_translation` | 0 | Address translation of the AXI-Lite master |
| `mmap_slave` | `False` | AXI slave port: user accesses to the host memory |
| `mmap_slave_axi_full` | `False` | 128-bit AXI slave instead of AXI-Lite |

| Key | Default | Effect |
|-------------------------------------------|------------------------------|-----------------------------------|
| `dma_channels` | required | Number of channels, or a dictionary of channels |
| `dma_data_width` | `phy_data_width` | Width of the DMA streams, in bits |
| `dma_writer` | `True` | Writer (FPGA to host) of each channel |
| `dma_reader` | `True` | Reader (host to FPGA) of each channel |
| `dma_buffering` | 1024 | Buffering of each direction, in bytes; 0 for none |
| `dma_loopback` | `True` | Loopback plug-in |
| `dma_synchronizer` | `False` | Synchronizer plug-in |
| `dma_monitor` | `False` | Monitor plug-in |
| `msi_irqs` | required | User interrupt inputs: up to 16 with MSI, 32 with MSI-X |
| `msi_multivector` | `False` | Multi-vector MSI instead of single-vector |
| `msi_x` | `False` | MSI-X instead of MSI; `True` by default on CertusPro-NX |
| `msi_x_default_enable` | `False` | MSI-X vectors enabled at reset |

When `dma_channels` is a dictionary, each entry names a channel and takes the `dma_` keys above as
its own settings (`examples/kcu105.yml`). The DMA interrupts take the first vectors; the user
interrupts start at vector 16 with MSI and 32 with MSI-X.

Where to go next: [Example designs and targets](#examples) for the designs these options build,
and [Simulation and verification](#simulation) for the simulation scripts.
