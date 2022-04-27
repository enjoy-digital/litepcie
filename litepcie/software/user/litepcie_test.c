/*
 * LitePCIe test
 *
 * This file is part of LitePCIe.
 *
 * Copyright (C) 2018-2022 / Enjoy-Digital  / florent@enjoy-digital.fr
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <signal.h>
#include "liblitepcie.h"

/* Variables */
/*-----------*/

sig_atomic_t keep_running = 1;

void intHandler(int dummy) {
    keep_running = 0;
}

/* Record (DMA RX) */
/*-----------------*/

static void litepcie_record(const char *device_name, const char *filename, uint32_t size, uint8_t zero_copy)
{
    static struct litepcie_dma_ctrl dma = {.use_writer = 1};

    FILE * fo = NULL;
    int i = 0;
    size_t len;
    size_t total_len = 0;
    int64_t last_time;
    int64_t writer_sw_count_last = 0;

    /* Open File to write to. */
    if (filename != NULL) {
        fo = fopen(filename, "wb");
        if (!fo) {
            perror(filename);
            exit(1);
        }
    }

    /* Initialize DMA. */
    if (litepcie_dma_init(&dma, device_name, zero_copy))
        exit(1);

    /* Test Loop. */
    last_time = get_time_ms();
    for (;;) {
        /* Exit loop on CTRL+C. */
        if (!keep_running)
            break;

        /* Update DMA status. */
        litepcie_dma_process(&dma);

        /* Read from DMA. */
        while (1) {
            /* Get Read buffer. */
            char *buf_rd = litepcie_dma_next_read_buffer(&dma);
            /* Break when no buffer available for Read. */
            if (!buf_rd)
                break;
            /* Copy Read data to File. */
            if (filename != NULL) {
                len = fwrite(buf_rd, 1, fmin(size - total_len, DMA_BUFFER_SIZE), fo);
                total_len += len;
            }
            /* Stop when specified size is reached */
            if (size > 0 && total_len >= size)
                keep_running = 0;
        }

        /* Statistics every 200ms. */
        int64_t duration = get_time_ms() - last_time;
        if (duration > 200) {
            /* Print banner every 10 lines. */
            if (i % 10 == 0)
                printf("\e[1mSPEED(Gbps)\tBUFFERS SIZE(MB)\e[0m\n");
            i++;
            /* Print statistics. */
            printf("%10.2f\t%10" PRIu64 "\t%8" PRIu64 "\n",
                    (double)(dma.writer_sw_count - writer_sw_count_last) * DMA_BUFFER_SIZE * 8 / ((double)duration * 1e6),
                    dma.writer_sw_count,
                    (size > 0) ? ((dma.writer_sw_count) * DMA_BUFFER_SIZE) / 1024 / 1024 : 0);
            /* Update time/count. */
            last_time = get_time_ms();
            writer_sw_count_last = dma.writer_sw_count;
        }
    }

    /* Cleanup DMA. */
    litepcie_dma_cleanup(&dma);

    /* Close File. */
    if (filename != NULL)
        fclose(fo);
}

/* Play (DMA TX) */
/*---------------*/

static void litepcie_play(const char *device_name, const char *filename, uint32_t loops, uint8_t zero_copy)
{
    static struct litepcie_dma_ctrl dma = {.use_reader = 1};

    FILE * fo;
    int i = 0;
    size_t len;
    int64_t reader_sw_count_last = 0;
    int64_t last_time;
    uint32_t current_loop = 0;
    uint64_t sw_underflows = 0;

    /* Open File to read from. */
    fo = fopen(filename, "rb");
    if (!fo) {
        perror(filename);
        exit(1);
    }

    /* Initialize DMA. */
    if (litepcie_dma_init(&dma, device_name, zero_copy))
        exit(1);

    /* Test Loop. */
    last_time = get_time_ms();
    for (;;) {
        /* Exit loop on CTRL+C. */
        if (!(keep_running))
            break;

        /* Update DMA status. */
        litepcie_dma_process(&dma);

        /* Write to DMA. */
        while (1) {
            /* Get Write buffer. */
            char *buf_wr = litepcie_dma_next_write_buffer(&dma);
            /* Break when no buffer available for Write. */
            if (!buf_wr)
                break;
            /* Detect DMA underflows. */
            if (dma.reader_sw_count - dma.reader_hw_count < 0)
                sw_underflows += (dma.reader_hw_count - dma.reader_sw_count);
            /* Read data from File and fill Write buffer */
            len = fread(buf_wr, 1, DMA_BUFFER_SIZE, fo);
            if (feof(fo)) {
                /* Rewind on end of file. */
                current_loop += 1;
                if (current_loop >= loops)
                    keep_running = 0;
                rewind(fo);
                len += fread(buf_wr + len, 1, DMA_BUFFER_SIZE - len, fo);
            }
        }

        /* Statistics every 200ms. */
        int64_t duration = get_time_ms() - last_time;
        if (duration > 200) {
             /* Print banner every 10 lines. */
            if (i % 10 == 0)
                printf("\e[1mSPEED(Gbps)\tBUFFERS\tSIZE(MB)\tLOOP\tUNDERFLOWS\e[0m\n");
            i++;
            /* Print statistics. */
            printf("%10.2f\t%10" PRIu64 "\t%10" PRIu64 "\t%6d\t%10ld\n",
                   (double)(dma.reader_sw_count - reader_sw_count_last) * DMA_BUFFER_SIZE * 8 / ((double)duration * 1e6),
                   dma.reader_sw_count,
                   (dma.reader_sw_count * DMA_BUFFER_SIZE) / 1024 / 1024,
                   current_loop,
                   sw_underflows);
           /* Update time/count/underflows. */
            last_time = get_time_ms();
            reader_sw_count_last = dma.reader_hw_count;
            sw_underflows = 0;
        }
    }

    /* Cleanup DMA. */
    litepcie_dma_cleanup(&dma);

    /* Close File. */
    fclose(fo);
}

/* Help */
/*------*/

static void help(void)
{
    printf("LitePCIe testing utilities\n"
           "usage: litepcie_test [options] cmd [args...]\n"
           "\n"
           "options:\n"
           "-h                               Help.\n"
           "-c device_num                    Select the device (default = 0).\n"
           "-z                               Enable zero-copy DMA mode.\n"
           "\n"
           "record [filename] [size]         Record DMA stream to file.\n"
           "play filename [loops]            Play DMA stream from file.\n"
           );
    exit(1);
}

/* Main */
/*------*/

int main(int argc, char **argv)
{
    const char *cmd;
    int c;
    static char litepcie_device[1024];
    static int litepcie_device_num;
    static uint8_t litepcie_device_zero_copy;

    litepcie_device_num = 0;
    litepcie_device_zero_copy = 0;

    signal(SIGINT, intHandler);

    /* Parameters. */
    for (;;) {
        c = getopt(argc, argv, "hc:z");
        if (c == -1)
            break;
        switch(c) {
        case 'h':
            help();
            break;
        case 'c':
            litepcie_device_num = atoi(optarg);
            break;
        case 'z':
            litepcie_device_zero_copy = 1;
            break;
        default:
            exit(1);
        }
    }

    /* Show help when too much args. */
    if (optind >= argc)
        help();

    /* Select device. */
    snprintf(litepcie_device, sizeof(litepcie_device), "/dev/litepcie%d", litepcie_device_num);

    cmd = argv[optind++];

    /* Record cmd. */
    if (!strcmp(cmd, "record")) {
        const char *filename = NULL;
        uint32_t size = 0;
        if (optind != argc) {
            if (optind + 2 > argc)
                goto show_help;
            filename = argv[optind++];
            size = strtoul(argv[optind++], NULL, 0);
        }
        litepcie_record(litepcie_device, filename, size, litepcie_device_zero_copy);
    /* Play cmd. */
    } else if (!strcmp(cmd, "play")) {
        const char *filename;
        uint32_t loops = 1;
        if (optind + 1 > argc)
            goto show_help;
        filename = argv[optind++];
        if (optind < argc)
            loops = strtoul(argv[optind++], NULL, 0);
        litepcie_play(litepcie_device, filename, loops, litepcie_device_zero_copy);
    /* Show help otherwise. */
    } else
show_help:
        help();

    return 0;
}
