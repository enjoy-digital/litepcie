# AGENTS.md: LitePCIe

PCIe core for LiteX: endpoint and root port on the vendors' hard IPs (Xilinx 7-Series/UltraScale(+),
Intel, Gowin GW5A, Lattice CertusPro-NX), TLP layer, MSI/MSI-X, scatter-gather DMA, MMAP bridges,
PTM, Linux driver, standalone generator.

Read the LiteX agent page first: https://github.com/enjoy-digital/litex/wiki/LiteX-for-AI-Agents (framework map, conventions, how to
verify a change, contribute back). Index of the whole wiki for agents: https://github.com/enjoy-digital/litex/wiki/llms.txt.

## Where things are

- `litepcie/phy/`: hard-IP wrappers (`s7pciephy.py`, `uspciephy.py`, `usppciephy.py`, `c5pciephy.py`, `svpciephy.py`, `gw5apciephy.py`, `lfcpnxpciephy.py`).
- `litepcie/phy/soft/`: soft PHY on FPGA transceivers through LiteICLink (work in progress, `doc/softphy.md`).
- `litepcie/tlp/`, `litepcie/core/` (endpoint, MSI/MSI-X, crossbar), `litepcie/frontend/` (DMA, MMAP, PTM).
- `litepcie/software/` (Linux kernel driver, user tools); `litepcie/gen.py` (`litepcie_gen examples/<board>.yml`); `doc/ptm.md`; `bench/`.

## Verify a change

```sh
python3 -m pytest -v -n auto -m "not slow"                         # CI job "Tests" (pytest-xdist)
python3 -m pytest -v -n auto -m "slow"                             # CI job "Slow Tests" (in parallel)
litepcie_gen examples/acorn.yml                                    # generator smoke test
python3 -m litex_boards.targets.<board> --with-pcie --build --no-compile
```

- Enumeration and DMA need a board and a host (`lspci`, the driver's tests); a host's slot,
  BIOS or Secure Boot can be the problem rather than the gateware.
- Max payload size stays at the 128-byte reset value unless both ends are programmed.
- Root-port and wide (256/512-bit) data paths are less used than the endpoint 64/128-bit ones:
  test them explicitly.

## Rules

- Style: https://github.com/enjoy-digital/litex/blob/master/doc/coding_style.md (match the
  surrounding file; `module: Description of the change.` commit titles; one change per commit).
- Never edit generated files (`build/`, `csr.h`, `csr.csv`, the Verilog): change the Python.
- One topic per pull request, from `master`, with what was tested and on which hardware; say
  that an agent wrote it and who supervised. Do not rename options or reformat unrelated code.
- Hardware: never flash a board or write its SPI flash unless the user asked; `--load` (volatile)
  is the default for experiments.

## Debug on hardware

Method: https://github.com/enjoy-digital/litex/wiki/Debug-A-SoC-On-Hardware (check the link and `--ident` first, registers before
traces, narrow LiteScope captures). `litex_mcp` gives the same loop as MCP tools (CSRs by name,
LiteScope captures, builds with parsed timing, simulation): https://github.com/enjoy-digital/litex/wiki/LiteX-for-AI-Agents#drive-a-soc-through-mcp.
