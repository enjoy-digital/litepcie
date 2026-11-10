# Getting started {#getting-started}

This chapter takes you from a fresh machine to a board that enumerates on a Linux host and moves
DMA data. It installs the tools, checks the installation without hardware, then builds and loads
the KC705 target, loads the driver and runs the tools. Each step gives the commands, what you
should see, and what to check when you do not.

## Prerequisites {#gs-install}

The project is a Python package built on LiteX and needs Python 3.8 or newer. Install LiteX
following the installation page of its wiki (`litex_setup.py`): it installs Migen, LiteX,
LiteX-Boards and the cores, LitePCIe included. To work on a clone of the repository, install it
in development mode:

```sh
git clone https://github.com/enjoy-digital/litepcie
cd litepcie
pip3 install -e .
```

The other tools depend on what you run. The table below lists them.

| Task | Tools |
|------------------------------|------------------------------------------------------------------|
| Tests without hardware | Python 3, pytest; Icarus Verilog for the Verilog tests |
| Soft PHY system simulations | Verilator and a C++ compiler |
| AMD 7-Series, UltraScale(+) | Vivado |
| Intel Cyclone V, Stratix V | Quartus |
| Gowin GW5A | Gowin IDE |
| Lattice CertusPro-NX | Radiant |
| Loading over JTAG | The programmer of the platform: OpenOCD, openFPGALoader or Vivado |
| Host computer | Kernel headers, `make`, `gcc`, `lspci` (pciutils) |

The host needs a PCIe slot and a Linux kernel; [Host requirements](#boards-host) lists what else
it needs. The photo below shows the kind of setup this chapter assumes: an FPGA card in a PC slot,
here the YPCB-00338-1P1, with its JTAG cable.

![An FPGA card, the YPCB-00338-1P1, in the PCIe slot of a PC, with its JTAG
cable.](ypcb_in_slot.jpg){width=70%}

## Step 1: check the installation {#gs-check}

The test suite checks every module of the core, the PHY datapaths and the DMA against Python
models of the host, with no board and no FPGA tool. The selection below skips the long tests, as
the continuous integration does first.

```sh
python3 -m pytest -v -m "not slow"
```

The KC705 target and the generator can then run without Vivado. Without `--build`, the target
writes the Verilog of the SoC and its register map, and stops before the vendor tools.

```sh
python3 bench/kc705.py --csr-csv build/kc705/csr.csv
litepcie_gen examples/acorn.yml --output-dir build/acorn --header-dir build/acorn
```

**What you should see.** All selected tests pass; the tests that need Icarus Verilog are skipped
without it. The target writes `build/kc705/gateware/kc705.v` and `build/kc705/csr.csv`; the
generator writes `build/acorn/gateware/litepcie_core.v` and the `csr.h`, `soc.h` and `mem.h`
headers.

**If not.** An import error names the missing package: LiteX-Boards provides the platform of the
KC705, and PyYAML the configuration reader of the generator. Rerun the LiteX installation or
`pip3 install -e .`.

## Step 2: build the KC705 target {#gs-build}

The KC705 target builds a Gen2 x4 endpoint by default: the hard IP, the endpoint, a Wishbone
bridge on BAR0, two DMA channels with loopback, MSI and an LTSSM tracer. `--driver` copies the
driver and the tools into the build directory, with the headers of this build.

```sh
python3 bench/kc705.py --build --driver --csr-csv build/kc705/csr.csv
```

**What you should see.** Vivado generates the PCIe hard IP from the parameters of the PHY, then
synthesizes and implements the design. The bitstream is `build/kc705/gateware/kc705.bit`; the
driver sources are in `build/kc705/driver/kernel` and the tools in `build/kc705/driver/user`.

**If not.** Vivado reports the error in its logs in `build/kc705/gateware`. A timing failure at
x4 or x8 comes from the 200 MHz system clock; `--nlanes 1` builds the 64-bit configuration at
125 MHz, which is easier to close.

Keep the `--csr-csv` option: by default the target writes `csr.csv` in the current directory. The
generated headers fix the register addresses the driver and the tools use, so rebuild both after
every change of the gateware.

## Step 3: load the board {#gs-load}

Power the host off and plug the KC705 into a PCIe slot of at least x4. Connect its JTAG port and
its USB-UART port to the host, or to another computer. Then power the host on and load the
bitstream:

```sh
python3 bench/kc705.py --load
```

`--load` programs the FPGA through JTAG with the programmer of the platform, OpenOCD on the
KC705. It writes the volatile configuration memory only: a power cycle brings the board back to
the bitstream of its flash, if any.

**What you should see.** OpenOCD programs the device without error. The host enumerated the bus
at boot, before the design was there, so it has to see the device again: warm reboot the host, or
rescan the bus as the next step shows.

A warm reboot usually keeps the FPGA configured, but in the soft PHY bring-up one warm reboot
reloaded the FPGA from its flash. After a reboot, check that the identifier is the one of your
build (Step 6).

**If not.** A load error usually means the JTAG cable is not found or the board is not powered.

## Step 4: check the enumeration {#gs-enumeration}

The device enumerates with the vendor ID `0x10ee` and the device ID of the hard IP: `0x7024` for
a 7-Series Gen2 x4 design. `lspci` shows it, and its verbose mode shows its link and BAR0.

```sh
lspci -d 10ee:
sudo lspci -vv -d 10ee:7024
```

**What you should see.** One device. In the verbose output, look for a 32-bit, non-prefetchable
memory region 0 of 128K (the BAR0 of the target), a `LnkSta` line with a speed of 5 GT/s and a
width of x4, and the MSI capability.

**If not.** When the device is missing, rescan the bus. When the BIOS saw no device at boot, a
rescan alone may leave BAR0 unusable: remove the host port above the slot first, then rescan.
`<host port>` is the PCI address of that port, as `lspci -t` shows it.

```sh
echo 1 | sudo tee /sys/bus/pci/rescan
# When the BIOS saw no device: remove the host port, then rescan.
echo 1 | sudo tee /sys/bus/pci/devices/<host port>/remove
echo 1 | sudo tee /sys/bus/pci/rescan
```

A link at a lower speed or width points to the slot or to the board. The LTSSM tracer of the
target records the link training states; read it through UARTBone, with a `litex_server` on the
serial port of the board:

```sh
litex_server --uart --uart-port /dev/ttyUSBx &
python3 bench/test_ltssm_tracer.py --csr-csv build/kc705/csr.csv --family 7series
```

[Link status and LTSSM tracer](#debug-ltssm) explains how to read the trace.

## Step 5: load the driver {#gs-driver}

The driver is a kernel module built against the running kernel. `init.sh` loads it and opens its
device files to all users; it also loads the LiteUART module built next to it.

```sh
cd build/kc705/driver/kernel
make
sudo ./init.sh
sudo dmesg | tail
```

**What you should see.** The kernel log shows the driver probing the device, the identifier of
the SoC after `Version`, the number of MSI vectors allocated, and one device file per DMA channel:
`/dev/litepcie0` and `/dev/litepcie1` on the KC705 target.

**If not.** "Kernel may have changed" means the module was built for another kernel; `init.sh`
rebuilds it. "secure boot is probably enabled" means the kernel refuses unsigned modules: disable
Secure Boot or sign the module. No probe message means the device is not enumerated (Step 4).
`sudo rmmod litepcie` removes the driver.

## Step 6: run the tools {#gs-tools}

`litepcie_util` reads the identifier of the SoC, tests register accesses through BAR0 and runs a
DMA loopback test. The tools are built against the same headers as the driver.

```sh
cd ../user
make
./litepcie_util info
./litepcie_util scratch_test
./litepcie_util dma_test -t 10
```

**What you should see.** `info` prints the SoC identifier, "LitePCIe example design on KC705
(gen2:x4)" for the default build. `scratch_test` writes `0x12345678` then `0xdeadbeef` to the
scratch register and reads each value back. `dma_test` prints a line every 200 ms under the
columns `DMA_SPEED(Gbps)`, `TX_BUFFERS`, `RX_BUFFERS`, `DIFF` and `ERRORS`: the errors stay at 0.

**If not.** "Could not init driver" means the device file is missing or not readable (Step 5).
"DMA not available" means another program holds the DMA channel. For errors in `dma_test`, or
"Reading too late" in the kernel log, see [DMA stalls and lost buffers](#debug-dma).

`dma_test` loops the data through the DMA of the FPGA by default: the Reader sends the buffers of
the host to the Writer, which writes them back. `-e` uses an external loopback in user logic
instead; the other options are in [Tools](#sw-tools).

## Other boards {#gs-other-boards}

The other hard-IP targets follow the same steps with their own bridge and default link, given in
[Example designs and targets](#ex-glance). The UltraScale and UltraScale+ targets take `--speed`,
and their device IDs start with `0x80` and `0x90`: `0x8034` and `0x9034` for Gen3 x4.

```sh
python3 bench/kcu105.py --build --driver --nlanes 8 --csr-csv build/kcu105/csr.csv
python3 bench/xcu1525.py --build --driver --nlanes 8 --csr-csv build/xcu1525/csr.csv
```

The Acorn CLE-215+ on the LiteX Acorn Baseboard Mini builds a Gen2 x1 endpoint on its hard IP
with the soft PHY target and `--hard-ip`. It enumerates as `10ee:7021` with one DMA channel; its
bridge is UARTBone, or JTAGBone with `--with-jtagbone`. This target writes `csr.csv` in the
current directory.

```sh
python3 bench/soft/acorn.py --hard-ip --driver --build --load
```

The soft PHY targets with their debug registers keep the LTSSM disabled until it is enabled
through the bridge, so that a design that hangs the host cannot do it again at the next boot. The
sequence below brings up the soft PHY on the YPCB-00338-1P1. This target has no `--load`: load the
bitstream of `build/soft_ypcb/gateware` with the JTAG tool of your cable. [Soft PHY
debug](#debug-soft) explains each step.

```sh
python3 bench/soft/ypcb.py --with-endpoint --driver --build
# Load the bitstream; the configuration file depends on the JTAG cable.
litex_server --jtag --jtag-config openocd_xc7_ft232.cfg &
python3 bench/soft/status.py --csr-csv build/soft_ypcb/csr.csv enable status trace
# Once status shows dl_active: 1, remove the host port and rescan.
echo 1 | sudo tee /sys/bus/pci/devices/<host port>/remove
echo 1 | sudo tee /sys/bus/pci/rescan
```

Where to go next: [Integration](#integration) to add LitePCIe to your own design, [Linux driver
and tools](#software) for the software, [Debugging](#debugging) when a step fails.
