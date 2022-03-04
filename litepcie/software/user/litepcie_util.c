/*
 * LitePCIe util
 *
 * This file is part of LitePCIe.
 *
 * Copyright (C) 2018-2020 / EnjoyDigital  / florent@enjoy-digital.fr
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <inttypes.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include "liblitepcie.h"

#define DMA_CHECK_DATA
#define DMA_RANDOM_DATA

static char litepcie_device[1024];
static int litepcie_device_num;

sig_atomic_t keep_running = 1;

void intHandler(int dummy) {
    keep_running = 0;
}

/* info */

static void info(void)
{
    int fd;
    int i;
    unsigned char fpga_identification[256];

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    for (i = 0; i < 256; i ++)
        fpga_identification[i] = litepcie_readl(fd, CSR_IDENTIFIER_MEM_BASE + 4 * i);
    printf("FPGA identification: %s\n", fpga_identification);
#ifdef CSR_DNA_BASE
    printf("FPGA dna: 0x%08x%08x\n",
        litepcie_readl(fd, CSR_DNA_ID_ADDR + 4 * 0),
        litepcie_readl(fd, CSR_DNA_ID_ADDR + 4 * 1)
    );
#endif
#ifdef CSR_XADC_BASE
    printf("FPGA temperature: %0.1f °C\n",
           (double)litepcie_readl(fd, CSR_XADC_TEMPERATURE_ADDR) * 503.975/4096 - 273.15);
    printf("FPGA vccint: %0.2f V\n",
           (double)litepcie_readl(fd, CSR_XADC_VCCINT_ADDR) / 4096 * 3);
    printf("FPGA vccaux: %0.2f V\n",
           (double)litepcie_readl(fd, CSR_XADC_VCCAUX_ADDR) / 4096 * 3);
    printf("FPGA vccbram: %0.2f V\n",
           (double)litepcie_readl(fd, CSR_XADC_VCCBRAM_ADDR) / 4096 * 3);
#endif
    close(fd);
}

#ifdef CSR_FLASH_BASE
/* flash */

static void flash_progress(void *opaque, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vprintf(fmt, ap);
    fflush(stdout);
    va_end(ap);
}

static void flash_program(uint32_t base, const uint8_t *buf1, int size1)
{
    int fd;

    uint32_t size;
    uint8_t *buf;
    int sector_size;
    int errors;

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    sector_size = litepcie_flash_get_erase_block_size(fd);

    /* pad to sector_size */
    size = ((size1 + sector_size - 1) / sector_size) * sector_size;

    buf = calloc(1, size);
    if (!buf) {
        fprintf(stderr, "%d: alloc failed\n", __LINE__);
        exit(1);
    }
    memcpy(buf, buf1, size1);

    printf("Programming (%d bytes at 0x%08x)\n", size, base);

    errors = litepcie_flash_write(fd, buf, base, size, flash_progress, NULL);

    /* result */
    if (errors) {
        printf("Failed %d errors\n", errors);
        exit(1);
    } else {
        printf("Success\n");
    }

    free(buf);

    close(fd);
}

static void flash_write(const char *filename, uint32_t offset)
{
    uint8_t *data;
    int size;
    FILE * f;

    f = fopen(filename, "rb");
    if (!f) {
        perror(filename);
        exit(1);
    }

    fseek(f, 0L, SEEK_END);
    size = ftell(f);
    fseek(f, 0L, SEEK_SET);
    data = malloc(size);
    if (!data) {
        fprintf(stderr, "%d: malloc failed\n", __LINE__);
        exit(1);
    }
    ssize_t ret = fread(data, size, 1, f);
    fclose(f);

    if (ret != 1)
        perror(filename);
    else
        flash_program(offset, data, size);

    free(data);
}

static void flash_read(const char *filename, uint32_t size, uint32_t offset)
{
    int fd;
    FILE * f;
    uint32_t base;
    uint32_t sector_size;
    uint8_t byte;
    int i;

    f = fopen(filename, "wb");
    if (!f) {
        perror(filename);
        exit(1);
    }

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    base = offset;
    sector_size = litepcie_flash_get_erase_block_size(fd);
    for (i = 0; i < size; i++) {
        if ((i % sector_size) == 0) {
            printf("Dumping %08x\r", base + i);
            fflush(stdout);
        }
        byte = litepcie_flash_read(fd, base + i);
        fwrite(&byte, 1, 1, f);
    }

    fclose(f);

    close(fd);
}

static void flash_reload(void)
{
    int fd;

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    /* reload fpga */
    litepcie_reload(fd);

    printf("================================================================\n");
    printf("= PLEASE REBOOT YOUR HARDWARE TO START WITH NEW FPGA GATEWARE  =\n");
    printf("================================================================\n");

    close(fd);
}
#endif

/* dma */

static inline int64_t add_mod_int(int64_t a, int64_t b, int64_t m)
{
    a += b;
    if (a >= m)
        a -= m;
    return a;
}

#ifdef DMA_CHECK_DATA
static inline uint32_t seed_to_data(uint32_t seed)
{
#ifdef DMA_RANDOM_DATA
    return seed * 69069 + 1;
#else
    return seed;
#endif
}

static int get_next_pow2(int data_width)
{
    int x = 1;
    while (x < data_width)
        x <<= 1;
    return x;
}

static uint32_t get_data_mask(int data_width)
{
    int i;
    uint32_t mask;
    mask = 0;
    for (i = 0; i < 32/get_next_pow2(data_width); i++) {
        mask <<= get_next_pow2(data_width);
        mask |= (1 << data_width) - 1;
    }
    return mask;
}

static void write_pn_data(uint32_t *buf, int count, uint32_t *pseed, int data_width)
{
    int i;
    uint32_t seed;
    uint32_t mask = get_data_mask(data_width);

    seed = *pseed;
    for(i = 0; i < count; i++) {
        buf[i] = (seed_to_data(seed) & mask);
        seed = add_mod_int(seed, 1, DMA_BUFFER_SIZE / sizeof(uint32_t));
    }
    *pseed = seed;
}

static int check_pn_data(const uint32_t *buf, int count, uint32_t *pseed, int data_width)
{
    int i, errors;
    uint32_t seed;
    uint32_t mask = get_data_mask(data_width);

    errors = 0;
    seed = *pseed;
    for (i = 0; i < count; i++) {
        if (buf[i] != (seed_to_data(seed) & mask)) {
            errors ++;
        }
        seed = add_mod_int(seed, 1, DMA_BUFFER_SIZE / sizeof(uint32_t));
    }
    *pseed = seed;
    return errors;
}
#endif

static void dma_test(uint8_t zero_copy, uint8_t external_loopback, int data_width, int auto_rx_delay)
{
    static struct litepcie_dma_ctrl dma = {.use_reader = 1, .use_writer = 1};
    dma.loopback = external_loopback ? 0 : 1;

    if (data_width > 32 || data_width < 1) {
        fprintf(stderr, "Invalid data width %d\n", data_width);
        exit(1);
    }

    /* stats */
    int i = 0;
    int64_t reader_sw_count_last = 0;
    int64_t last_time;
    uint32_t errors = 0;

#ifdef DMA_CHECK_DATA
    uint32_t seed_wr = 0;
    uint32_t seed_rd = 0;
    uint8_t  run = (auto_rx_delay == 0);
#endif

    signal(SIGINT, intHandler);

    if (litepcie_dma_init(&dma, litepcie_device, zero_copy))
        exit(1);

    /* test loop */
    last_time = get_time_ms();
    for (;;) {
        /* exit loop on ctrl+c pressed */
        if (!keep_running)
            break;

        litepcie_dma_process(&dma);

#ifdef DMA_CHECK_DATA
        char *buf_wr;
        char *buf_rd;

        /* write tx-buffers */
        while (1) {
            /* get buffer */
            buf_wr = litepcie_dma_next_write_buffer(&dma);

            /* break when no buffer available */
            if (!buf_wr)
                break;

            /* write buffer */
            write_pn_data((uint32_t *) buf_wr, DMA_BUFFER_SIZE / sizeof(uint32_t), &seed_wr, data_width);
        }

        /* read/check rx-buffers */
        while (1) {
            /* get buffer */
            buf_rd = litepcie_dma_next_read_buffer(&dma);

            /* break when no buffer available */
            if (!buf_rd)
                break;

            /* skip the first 128 dma loop */
            if (dma.writer_hw_count < 128*DMA_BUFFER_COUNT)
                break;

            if (run) {
                /* check buffer */
                errors += check_pn_data((uint32_t *) buf_rd, DMA_BUFFER_SIZE / sizeof(uint32_t), &seed_rd, data_width);
                memset(buf_rd, 0, DMA_BUFFER_SIZE);
            } else {
                /* find delay/seed */
                uint32_t errors_min = 0xffffffff;
                for (int delay = 0; delay < DMA_BUFFER_SIZE / sizeof(uint32_t); delay++) {
                    seed_rd = delay;
                    errors = check_pn_data((uint32_t *) buf_rd, DMA_BUFFER_SIZE / sizeof(uint32_t), &seed_rd, data_width);
                    //printf("delay: %d / errors: %d\n", delay, errors);
                    if (errors < errors_min)
                        errors_min = errors;
                    if (errors < (DMA_BUFFER_SIZE / sizeof(uint32_t)) / 2) {
                        printf("RX_DELAY: %d (errors: %d)\n", delay, errors);
                        run = 1;
                        break;
                    }
                }
                if (!run) {
                    printf("Unable to find DMA RX_DELAY (min errors: %d/%ld), exiting.\n",
                        errors_min,
                        DMA_BUFFER_SIZE / sizeof(uint32_t));
                    goto end;
                }
            }

        }
#endif

        /* statistics */
        int64_t duration = get_time_ms() - last_time;
        if (run & (duration > 200)) {
            if (i % 10 == 0)
                printf("\e[1mDMA_SPEED(Gbps)\tTX_BUFFERS\tRX_BUFFERS\tDIFF\tERRORS\e[0m\n");
            i++;
            printf("%14.2f\t%10" PRIu64 "\t%10" PRIu64 "\t%4" PRIu64 "\t%6u\n",
                   (double)(dma.reader_sw_count - reader_sw_count_last) * DMA_BUFFER_SIZE * 8 * data_width / (get_next_pow2(data_width) * (double)duration * 1e6),
                   dma.reader_sw_count,
                   dma.writer_sw_count,
                   dma.reader_sw_count - dma.writer_sw_count,
                   errors);
            errors = 0;
            last_time = get_time_ms();
            reader_sw_count_last = dma.reader_sw_count;
        }
    }

end:
    litepcie_dma_cleanup(&dma);
}


void scratch_test(void)
{
    int fd;

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    printf("Write 0x12345678 to scratch register:\n");
    litepcie_writel(fd, CSR_CTRL_SCRATCH_ADDR, 0x12345678);
    printf("Read: 0x%08x\n", litepcie_readl(fd, CSR_CTRL_SCRATCH_ADDR));

    printf("Write 0xdeadbeef to scratch register:\n");
    litepcie_writel(fd, CSR_CTRL_SCRATCH_ADDR, 0xdeadbeef);
    printf("Read: 0x%08x\n", litepcie_readl(fd, CSR_CTRL_SCRATCH_ADDR));

    close(fd);
}

#ifdef CSR_UART_XOVER_RXTX_ADDR
void uart_test(void)
{
    int fd;

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    litepcie_writel(fd, CSR_CTRL_RESET_ADDR, 1); /* reset CPU */

    while (1) {
        if ((litepcie_readl(fd, CSR_UART_XOVER_RXEMPTY_ADDR) & 0x1) == 0) {
            printf("%c", litepcie_readl(fd, CSR_UART_XOVER_RXTX_ADDR) & 0xff);
        }
    }

    close(fd);
}
#endif

static void help(void)
{
    printf("LitePCIe utilities\n"
           "usage: litepcie_util [options] cmd [args...]\n"
           "\n"
           "options:\n"
           "-h                                Help\n"
           "-c device_num                     Select the device (default = 0)\n"
           "-z                                Enable zero-copy DMA mode\n"
           "-e                                Use external loopback (default = internal)\n"
           "-w data_width                     Width of data bus (default = 16)\n"
           "-a                                Automatic DMA RX-Delay calibration\n"
           "\n"
           "available commands:\n"
           "info                              Board information\n"
           "dma_test                          Test DMA\n"
           "scratch_test                      Test Scratch register\n"
#ifdef CSR_UART_XOVER_RXTX_ADDR
           "uart_test                         Test CPU Crossover UART\n"
#endif
           "\n"
#ifdef CSR_FLASH_BASE
           "flash_write filename [offset]     Write file contents to SPI Flash\n"
           "flash_read filename size [offset] Read from SPI Flash and write contents to file.\n"
           "flash_reload                      Reload FPGA Image.\n"
#endif
           );
    exit(1);
}

int main(int argc, char **argv)
{
    const char *cmd;
    int c;
    static uint8_t litepcie_device_zero_copy;
    static uint8_t litepcie_device_external_loopback;
    static int litepcie_data_width;
    static int litepcie_auto_rx_delay;


    litepcie_device_num = 0;
    litepcie_data_width = 16;
    litepcie_auto_rx_delay = 0;
    litepcie_device_zero_copy = 0;
    litepcie_device_external_loopback = 0;

    /* parameters */
    for (;;) {
        c = getopt(argc, argv, "hc:w:zea");
        if (c == -1)
            break;
        switch(c) {
        case 'h':
            help();
            break;
        case 'c':
            litepcie_device_num = atoi(optarg);
            break;
        case 'w':
            litepcie_data_width = atoi(optarg);
            break;
        case 'z':
            litepcie_device_zero_copy = 1;
            break;
        case 'e':
            litepcie_device_external_loopback = 1;
            break;
        case 'a':
            litepcie_auto_rx_delay = 1;
            break;
        default:
            exit(1);
        }
    }

    if (optind >= argc)
        help();

    /* select device */
    snprintf(litepcie_device, sizeof(litepcie_device), "/dev/litepcie%d", litepcie_device_num);

    cmd = argv[optind++];

    if (!strcmp(cmd, "info"))
        info();
    else if (!strcmp(cmd, "dma_test"))
        dma_test(
            litepcie_device_zero_copy,
            litepcie_device_external_loopback,
            litepcie_data_width,
            litepcie_auto_rx_delay);
    else if (!strcmp(cmd, "scratch_test"))
        scratch_test();
#ifdef CSR_UART_XOVER_RXTX_ADDR
    else if (!strcmp(cmd, "uart_test"))
        uart_test();
#endif
#if CSR_FLASH_BASE
    else if (!strcmp(cmd, "flash_write")) {
        const char *filename;
        uint32_t offset = 0;
        if (optind + 1 > argc)
            goto show_help;
        filename = argv[optind++];
        if (optind < argc)
            offset = strtoul(argv[optind++], NULL, 0);
        flash_write(filename, offset);
    }
    else if (!strcmp(cmd, "flash_read")) {
        const char *filename;
        uint32_t size = 0;
        uint32_t offset = 0;
        if (optind + 2 > argc)
            goto show_help;
        filename = argv[optind++];
        size = strtoul(argv[optind++], NULL, 0);
        if (optind < argc)
            offset = strtoul(argv[optind++], NULL, 0);
        flash_read(filename, size, offset);
    }
    else if (!strcmp(cmd, "flash_reload"))
        flash_reload();
#endif
    else
        goto show_help;

    return 0;

show_help:
        help();

    return 0;
}
