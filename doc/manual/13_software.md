# Linux driver and tools {#software}

This chapter describes the software of the project: the Linux kernel driver, the user library
`liblitepcie` and the tools built on it. It explains how the software is generated for a design,
how the driver moves DMA buffers, and the interface an application uses. Read it to write your
own application or to understand what the tools print.

## At a glance {#sw-glance}

| Item | Value |
|-------------------------|----------------------------------------------------------------|
| Driver | `litepcie.ko`, sources in `litepcie/software/kernel` |
| Device files | `/dev/litepcieN`, one per DMA channel |
| Library | `liblitepcie`, static library in `litepcie/software/user/liblitepcie` |
| Tools | `litepcie_util`, `litepcie_test`; `rescan.py` |
| DMA buffers | 256 buffers of 8 KiB per direction and per channel |
| Interrupts | MSI or MSI-X, up to 32 vectors; one every 32 buffers |
| Generation | `generate_litepcie_software`, `--driver` option of the targets |
| License | BSD-2-Clause; the kernel module as a whole is GPL |

The figure below shows the software stack. An application calls the library, which talks to the
driver through the device file of a DMA channel. The driver reads and writes the registers of the
FPGA through BAR0, and the DMA channels of the FPGA read and write the DMA buffers of the driver
in host memory, signalling their progress with MSIs.

![The software stack. The cyan arrow is the DMA data between the buffers of the driver and the DMA
channels of the FPGA; register accesses go through BAR0, and the DMA channels signal the driver
with MSIs.](sw_stack.svg)

## Generating the software {#sw-generate}

The driver and the tools are compiled for one design: they take the register addresses, the
number of DMA channels and the interrupt numbers from headers generated with the gateware. The
`--driver` option of the targets calls `generate_litepcie_software`, which copies the sources and
writes these headers.

```python
from litepcie.software import generate_litepcie_software

generate_litepcie_software(soc, "build/my_soc/driver", name="litepcie")
```

The destination gets `kernel/` (driver), `user/` (library and tools) and `rescan.py`. The
headers `csr.h`, `soc.h` and `mem.h` go into `kernel/`, where the tools find them too. The
standalone generator writes the same headers in its `--header-dir`; copy them into `kernel/`.

The `name` argument sets the name of the module and of the device files: `<name>.ko` and
`/dev/<name>N`. It must match `[a-z_][a-z0-9_]*`. Two designs with different names can be loaded
side by side; the `LITEPCIE_NAME` variable of the Makefiles and of `init.sh` sets the same name.

```sh
cd build/my_soc/driver/kernel
make
sudo ./init.sh
cd ../user
make
```

The kernel Makefile builds against `/lib/modules/$(uname -r)/build`; `KERNEL_PATH`, `ARCH` and
`CROSS_COMPILE` select another kernel or a cross compiler. Rebuild the driver and the tools after
each change of the gateware: stale headers give wrong register addresses.

## The driver {#sw-driver}

The driver binds to the vendor and device IDs of the hard IPs and of the soft PHY. On probe, it
enables the device, checks that BAR0 is a memory BAR and maps it, then resets the core through the
control register when the SoC has one. It prints the identifier of the SoC, read from its
identifier memory, in the kernel log.

It then enables bus mastering and sets the DMA mask to `DMA_ADDR_WIDTH` bits. It allocates up to
32 MSI-X vectors when the SoC has an MSI-X controller, up to 32 MSI vectors otherwise, and
requests an interrupt handler on each. Last, it allocates the DMA buffers and creates one device
file per DMA channel.

| Vendor | Vendor ID | Device IDs |
|-----------------------|-------------|-------------------------------------------------------|
| Xilinx 7-Series | `0x10ee` | `0x7021` to `0x7028` (Gen2 x1 to x8) |
| Xilinx UltraScale | `0x10ee` | `0x8021` to `0x8028` (Gen2), `0x8031` to `0x8038` (Gen3) |
| Xilinx UltraScale+ | `0x10ee` | `0x9021` to `0x9028`, `0x9036` (Gen2), `0x9031` to `0x9038`, `0x9046` (Gen3), `0x9041` to `0x9048`, `0x9056` (Gen4) |
| Lattice CertusPro-NX | `0x1204` | `0x9c25` |
| Gowin GW5A | `0x22c2` | `0x1100` |
| Intel Stratix V | `0x1172` | `0xe001` |

Up to x8, the last digit of the Xilinx IDs is the number of lanes. An UltraScale+ x16 design gets
`0x9036`, `0x9046` or `0x9056`, because the wrapper adds 16 to a decimal base, as [Device
IDs](#hard-device-ids) explains. The soft PHY uses the 7-Series IDs by default. A design with
other IDs needs them in `config.h` and in the device table of `main.c`, in
`litepcie/software/kernel`.

Some features of the driver depend on the registers of the SoC, tested at compile time in
`csr.h`. The table lists them.

| Feature | Present when the SoC has | Interface |
|-----------------------|------------------------------|-----------------------------------------------|
| DMA channels 0 to 7 | `pcie_dma0` to `pcie_dma7` | `/dev/litepcieN` |
| MSI-X | An MSI-X controller | Same handler, one vector per interrupt |
| Core reset | The `ctrl` reset register | Reset at probe |
| SPI flash | A SPI flash core | `FLASH` |
| FPGA reload | An ICAP core | `ICAP` |
| Serial console | A crossover UART | `liteuart.ko`, `/dev/ttyLXU` devices |

With a crossover UART, the driver registers a platform device for the LiteUART module: the
console of a CPU in the SoC appears as a serial port of the host. `init.sh` loads `liteuart.ko`
after the driver. The driver also builds on 32 and 64-bit Arm hosts.

### DMA buffers {#sw-dma}

Each DMA channel has 256 buffers of 8 KiB per direction in host memory, allocated once at probe.
When a program enables a direction, the driver writes one descriptor per buffer into the table of
the DMA engine and starts it in Loop mode: after the last buffer, the engine starts again with
the first one. The figure below shows the ring.

![The DMA ring of one direction. The FPGA fills buffers ahead of `hw_count`, the program consumes
them up to `sw_count`; the cyan buffers are ready for the program. The descriptors of buffers 0,
32 and every 32nd one request an MSI.](sw_dma_ring.svg)

Only one descriptor in 32 requests an interrupt, so the host takes one MSI per 256 KiB. On each
interrupt, the driver reads the loop status of the engine (descriptor index and loop count) and
computes `hw_count`, the number of buffers the engine has completed since the start. The program
side keeps `sw_count`, the number of buffers it consumed or produced.

The difference between the two counts is what the program can process:

- **FPGA to host (Writer)**: `read()` copies whole ready buffers, waiting for at least one. When
  the Writer is more than 128 buffers ahead, the buffers it overwrote are lost and the kernel log
  says "Reading too late" with their number.
- **Host to FPGA (Reader)**: `write()` copies whole buffers while fewer than 128 are queued ahead
  of the Reader, and waits otherwise.
- **poll()**: readable when more than 2 buffers are ready, writable when fewer than 128 are queued.

Reads and writes move multiples of 8 KiB: a remainder is left for the next call. Opening the
device file does not start the DMA; the `LITEPCIE_IOCTL_DMA_WRITER` and `LITEPCIE_IOCTL_DMA_READER` ioctls do, and
closing the file stops the directions the program had locked.

**Zero-copy mode.** `mmap()` maps the buffers of a channel into the program: the 256 Reader
buffers at offset 0, then the 256 Writer buffers at offset 2 MiB, as `LITEPCIE_IOCTL_MMAP_DMA_INFO`
reports. The program then reads and writes the buffers in place and reports its progress with the
`LITEPCIE_IOCTL_MMAP_DMA_WRITER_UPDATE` and `LITEPCIE_IOCTL_MMAP_DMA_READER_UPDATE` ioctls, instead of `read()` and `write()`.

### ioctls {#sw-ioctls}

The device files take the ioctls below, defined in `litepcie/software/kernel/litepcie.h` with the
magic number `'S'`; their names start with `LITEPCIE_IOCTL_`. The library wraps each of them.

| Number | ioctl | Use |
|--------|------------------------------------|--------------------------------------------------|
| 0 | `REG` | Read or write a register of BAR0 |
| 1 | `FLASH` | SPI transfer to the configuration flash |
| 2 | `ICAP` | Write an ICAP register (FPGA reload) |
| 20 | `DMA` | Enable the loopback of the channel |
| 21 | `DMA_WRITER` | Start or stop the Writer, read its counts |
| 22 | `DMA_READER` | Start or stop the Reader, read its counts |
| 24 | `MMAP_DMA_INFO` | Offsets, sizes and counts of the buffers |
| 25 | `LOCK` | Request or release the Reader or Writer |
| 26 | `MMAP_DMA_WRITER_UPDATE` | Report the Writer buffers consumed |
| 27 | `MMAP_DMA_READER_UPDATE` | Report the Reader buffers produced |

The register ioctl checks that the address is aligned and inside BAR0. The lock gives each
direction of a channel to one program at a time: a second request fails until the first program
releases it or closes the file.

## The library {#sw-lib}

`liblitepcie` is a static C library, built with the tools, that hides the ioctls and the buffer
accounting. Its header `liblitepcie.h` includes the three parts below and can be used from C++.

| Function | Use |
|----------------------------------------------|----------------------------------------------|
| `litepcie_readl`, `litepcie_writel` | Register access through BAR0 |
| `litepcie_dma_init` | Open a channel, lock it, map or allocate the buffers |
| `litepcie_dma_process` | Update the counts, poll, read or write ready buffers |
| `litepcie_dma_next_read_buffer` | Next buffer received from the FPGA, or none |
| `litepcie_dma_next_write_buffer` | Next free buffer to send to the FPGA, or none |
| `litepcie_dma_cleanup` | Stop the DMA, release the lock, free the buffers |
| `litepcie_dma_writer` | Start or stop the Writer directly |
| `litepcie_dma_reader` | Start or stop the Reader directly |
| `litepcie_request_dma` | Lock directions of a channel |
| `litepcie_release_dma` | Release directions of a channel |
| `litepcie_flash_read` | Read the SPI flash |
| `litepcie_flash_write` | Program the SPI flash |
| `litepcie_reload` | Reload the FPGA through ICAP |

The DMA functions work on a `litepcie_dma_ctrl` structure. Set `use_writer` to receive data from
the FPGA, `use_reader` to send data to it, and `loopback` to loop the channel in the FPGA. The
loop below records the stream of the FPGA, as `litepcie_test record` does.

```c
#include "liblitepcie.h"

static struct litepcie_dma_ctrl dma = {.use_writer = 1};

if (litepcie_dma_init(&dma, "/dev/litepcie0", 0)) /* 1: zero-copy. */
    exit(1);
dma.writer_enable = 1;
while (running) {
    char *buf;
    litepcie_dma_process(&dma);
    while ((buf = litepcie_dma_next_read_buffer(&dma)) != NULL)
        consume(buf, DMA_BUFFER_SIZE);
}
litepcie_dma_cleanup(&dma);
```

`litepcie_dma_process` waits up to 100 ms for the device. With zero-copy, the buffers returned
point into the mapping of the driver; otherwise the library copies them with `read()` and
`write()`.

## Tools {#sw-tools}

`litepcie_util` checks a design: identification, register access, DMA and flash. Its options come
before the command; `-c N` selects the device file `/dev/litepcieN`, 0 by default.

| Command | Use |
|----------------------------------------------|------------------------------------------------|
| `info` | SoC identifier; FPGA DNA and XADC values when present |
| `scratch_test` | Write and read back the scratch register |
| `dma_test` | DMA loopback with data check and throughput |
| `flash_write file [offset]` | Program a file into the SPI flash |
| `flash_read file size [offset]` | Read the SPI flash into a file |
| `flash_reload` | Reload the FPGA from its flash through ICAP |

The flash commands exist only when the SoC has a flash core. After `flash_reload`, reboot the host
or rescan the bus: the device disappears while the FPGA reconfigures.

`dma_test` sends a pseudo-random sequence on the Reader and checks what comes back on the Writer.
It skips the first 128 loops of the ring, then prints a line every 200 ms. Its columns are the
throughput in Gb/s, the transmit and receive buffer counts, their difference, and the errors since
the last line.

| Option | Use |
|----------------|--------------------------------------------------------------------|
| `-z` | Zero-copy mode |
| `-e` | External loopback in user logic, instead of the loopback of the DMA |
| `-w width` | Width of the checked data, 1 to 32 bits (default 16) |
| `-a` | Find the delay of an external loopback before checking |
| `-t seconds` | Duration of the test, infinite by default |

The data check itself costs host time: at high rates it can lose whole buffers, which shows as
errors and as "Reading too late" in the kernel log. [Performance and resources](#performance)
discusses the measured limits.

`litepcie_test` streams files: `record [file] [size]` writes the stream of the FPGA to a file, and
`play file [loops]` sends a file to the FPGA. Both print the throughput in Gb/s and take `-c` and
`-z` like `litepcie_util`.

`rescan.py` removes the LitePCIe devices from the bus, rescans it and reloads the driver, after a
new bitstream for example. It knows every ID of the table above;
`--device vendor:device`, repeated as needed, replaces that list. It unloads the module first
(`--no-rmmod` to skip) and reloads it with `modprobe`, which needs an installed module;
`--no-modprobe` skips that step, and `init.sh` then loads the module again.

```sh
python3 build/kc705/driver/rescan.py --no-modprobe
cd build/kc705/driver/kernel && sudo ./init.sh
```

## License {#sw-license}

The gateware, the library and the tools are released under the BSD-2-Clause license. The kernel
module combines BSD-2-Clause files (`main.c` and the headers) with GPL-2.0 files from the Linux
LiteUART driver (`liteuart.c`, `litex.h`), so the module as a whole is GPL
(`MODULE_LICENSE("GPL")`).

Where to go next: [Getting started](#getting-started) to build and load the driver,
[Scatter-gather DMA](#dma) for the DMA engines behind the device files, [Debugging](#debugging)
when the driver does not probe or the DMA loses data.
