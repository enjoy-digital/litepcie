/*
 * LitePCIe test
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
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/poll.h>
#include <time.h>
#include <math.h>
#include <unistd.h>
#include <termios.h>
#include <fcntl.h>
#include <signal.h>

#include "litepcie.h"
#include "config.h"
#include "csr.h"
#include "flags.h"

#include "liblitepcie.h"

static char litepcie_device[1024];
static int litepcie_device_num;
static uint8_t litepcie_device_zero_copy;

sig_atomic_t keep_running = 1;

void intHandler(int dummy) {
    keep_running = 0;
}

/* litepcie */

static void litepcie_init(const char * rate)
{
    int fd;
    int64_t hw_count, sw_count;

    fd = open(litepcie_device, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    /* reset driver */
    printf("Reset Driver...\n");

    /* disable loopback */
    litepcie_dma(fd, 0);

    /* disable dmas */
    litepcie_dma_reader(fd, 0, &hw_count, &sw_count);
    litepcie_dma_writer(fd, 0, &hw_count, &sw_count);

    close(fd);
}

static inline int64_t add_mod_int(int64_t a, int64_t b, int64_t m)
{
    a += b;
    if (a >= m)
        a -= m;
    return a;
}

static void litepcie_record(const char *filename, uint32_t size)
{
    struct pollfd fds;
    FILE * fo = NULL;
    int i, j;
    size_t len;
    size_t total_len;

    int64_t writer_hw_count, writer_sw_count, writer_sw_count_last;

    int64_t duration;
    int64_t last_time;

    char *buf_rd = NULL;

    struct litepcie_ioctl_mmap_dma_info mmap_dma_info;
    struct litepcie_ioctl_mmap_dma_update mmap_dma_update;

    fds.fd = open(litepcie_device, O_RDWR | O_CLOEXEC);
    fds.events = POLLIN;
    if (fds.fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    if (filename != NULL) {
        fo = fopen(filename, "wb");
        if (!fo) {
            perror(filename);
            exit(1);
        }
    }

    /* request dma */
    if (litepcie_request_dma_writer(fds.fd) == 0) {
        printf("DMA not available, exiting.\n");
        goto exit;
    }

    /* disable dma loopback */
    litepcie_dma(fds.fd, 0);

    /* get data buffer */
    if (litepcie_device_zero_copy) {
        /* if mmap: get it from the kernel */
        if (ioctl(fds.fd, LITEPCIE_IOCTL_MMAP_DMA_INFO, &mmap_dma_info) != 0) {
            printf("LITEPCIE_IOCTL_MMAP_DMA_INFO error, exiting.\n");
            goto exit;
        }
        buf_rd = mmap(NULL, DMA_BUFFER_TOTAL_SIZE, PROT_READ,
            MAP_SHARED, fds.fd, mmap_dma_info.dma_rx_buf_offset);
        if (buf_rd == MAP_FAILED) {
            printf("MMAP failed, exiting.\n");
            goto exit;
        }
    } else {
        /* else: allocate it */
        buf_rd = malloc(DMA_BUFFER_SIZE * DMA_BUFFER_COUNT);
        if (!buf_rd) {
            fprintf(stderr, "%d: malloc failed\n", __LINE__);
            goto exit;
        }
    }

    /* test loop */
    i = 0;
    writer_hw_count = 0;
    writer_sw_count = 0;
    writer_sw_count_last = 0;
    total_len = 0;
    last_time = get_time_ms();

    for (;;) {
        /* exit loop on ctrl+c pressed */
        if (!keep_running)
            break;

        /* set / get dma */
        litepcie_dma_writer(fds.fd, 1, &writer_hw_count, &writer_sw_count);

        /* polling */
        poll(&fds, 1, 100);

        /* read event */
        if (fds.revents & POLLIN) {
            /* zero-copy mode */
            if (litepcie_device_zero_copy) {
                int64_t buf_count;
                int64_t buf_offset;

                /* count available buffers and write them to file */
                buf_count = writer_hw_count - writer_sw_count;
                buf_offset = (writer_sw_count%DMA_BUFFER_COUNT)*DMA_BUFFER_SIZE;
                for (j=0; j<buf_count; j++) {
                    if (filename != NULL) {
                        len = fwrite(buf_rd + buf_offset, 1, fmin(size - total_len, DMA_BUFFER_SIZE), fo);
                        total_len += len;
                    }
                    buf_offset = add_mod_int(buf_offset, DMA_BUFFER_SIZE, DMA_BUFFER_TOTAL_SIZE);
                }

                /* exit */
                if (size > 0 && total_len >= size) {
                    break;
                }

                /* update dma sw_count*/
                mmap_dma_update.sw_count = writer_sw_count + buf_count;
                ioctl(fds.fd, LITEPCIE_IOCTL_MMAP_DMA_WRITER_UPDATE, &mmap_dma_update);

            /* non zero-copy mode */
            } else {
                /* read available data and write it to file */
                len = read(fds.fd, buf_rd, DMA_BUFFER_SIZE * DMA_BUFFER_COUNT);
                if(len >= 0) {
                    if (filename != NULL) {
                        fwrite(buf_rd, fmin(size - total_len, len), 1, fo);
                        total_len += len;
                    }

                    /* exit */
                    if (size > 0 && total_len >= size)
                        break;
                }
            }
        }

        /* statistics */
        duration = get_time_ms() - last_time;
        if (duration > 200) {
            if(i%10 == 0)
                printf("\e[1mSPEED(Gbps)    BUFFERS SIZE(MB)\e[0m\n");
            i++;
            printf("%10.2f %10" PRIu64 " %8" PRIu64"\n",
                    (double)(writer_sw_count-writer_sw_count_last) * DMA_BUFFER_SIZE * 8 / ((double)duration * 1e6),
                    writer_sw_count,
                    (size > 0)?((writer_sw_count)*DMA_BUFFER_SIZE)/1024/1024:0);

            last_time = get_time_ms();
            writer_sw_count_last = writer_sw_count;
        }
    }

    litepcie_dma_writer(fds.fd, 0, &writer_hw_count, &writer_sw_count);
    litepcie_release_dma_writer(fds.fd);

exit:
    if (!litepcie_device_zero_copy)
        free(buf_rd);

    close(fds.fd);
    if (filename != NULL)
        fclose(fo);
}

static void litepcie_play(const char *filename, uint32_t loops)
{
    struct pollfd fds;
    FILE * fo;
    int i, j;
    size_t len;

    int64_t reader_hw_count, reader_sw_count, reader_sw_count_last;

    int64_t duration;
    int64_t last_time;

    uint32_t first_loop;
    uint32_t current_loop;

    char *buf_wr = NULL;
    uint32_t buf_wr_offset;
    size_t buf_wr_size;

    uint64_t sw_underflows;

    struct litepcie_ioctl_mmap_dma_info mmap_dma_info;
    struct litepcie_ioctl_mmap_dma_update mmap_dma_update;

    buf_wr_offset = 0;
    buf_wr_size = 0;

    fds.fd = open(litepcie_device, O_RDWR | O_CLOEXEC);
    fds.events = POLLOUT;
    if (fds.fd < 0) {
        fprintf(stderr, "Could not init driver\n");
        exit(1);
    }

    fo = fopen(filename, "rb");
    if (!fo) {
        perror(filename);
        exit(1);
    }

    /* get data buffer */
    if (litepcie_device_zero_copy) {
        /* if mmap: it get it from the kernel */
        if (ioctl(fds.fd, LITEPCIE_IOCTL_MMAP_DMA_INFO, &mmap_dma_info)) {
            printf("LITEPCIE_IOCTL_MMAP_DMA_INFO error, exiting.\n");
            goto exit;
        }
        buf_wr = mmap(NULL, DMA_BUFFER_TOTAL_SIZE, PROT_WRITE,
                MAP_SHARED, fds.fd, mmap_dma_info.dma_tx_buf_offset);
        if (buf_wr == MAP_FAILED) {
            printf("MMAP failed, exiting.\n");
            goto exit;
        }
    } else {
        /* else: allocate it */
        buf_wr = malloc(DMA_BUFFER_SIZE * DMA_BUFFER_COUNT);
        if (!buf_wr) {
            fprintf(stderr, "%d: malloc failed\n", __LINE__);
            goto exit;
        }
    }

    /* request dma */
    if (litepcie_request_dma_reader(fds.fd) == 0) {
        printf("DMA not available, exiting.\n");
        goto exit;
    }

    /* disable dma loopback */
    litepcie_dma(fds.fd, 0);

    /* test loop */
    i = 0;
    first_loop = 1;
    current_loop = 0;
    sw_underflows = 0;
    reader_hw_count = 0;
    reader_sw_count = 0;
    reader_sw_count_last = 0;
    last_time = get_time_ms();
    for (;;) {
        /* exit loop on key or ctrl+c pressed */
        if (!(keep_running))
            break;

        /* polling */
        poll(&fds, 1, 100);

        /* set / get dma */
        litepcie_dma_reader(fds.fd, first_loop != 1, &reader_hw_count, &reader_sw_count);

        /* zero-copy mode */
        if (litepcie_device_zero_copy) {
            /* write event */
            if (fds.revents & POLLOUT) {
                int64_t buf_count;
                int64_t buf_offset;

                /* count available buffers and read them from file */
                buf_count = DMA_BUFFER_COUNT/2 - (reader_sw_count - reader_hw_count);
                buf_offset = (reader_sw_count%DMA_BUFFER_COUNT)*DMA_BUFFER_SIZE;

                if (reader_sw_count - reader_hw_count < 0) {
                    sw_underflows += (reader_hw_count - reader_sw_count);
                } else {
                    for (j=0; j<buf_count; j++) {
                        len = fread(buf_wr + buf_offset, 1, DMA_BUFFER_SIZE, fo);
                        /* if end of file, rewind */
                        if (feof(fo)) {
                            current_loop += 1;
                            if (current_loop >= loops)
                                goto loop_exit;
                            rewind(fo);
                            len += fread(buf_wr + buf_offset + len, 1, DMA_BUFFER_SIZE - len, fo);
                        }
                        buf_offset = add_mod_int(buf_offset, DMA_BUFFER_SIZE, DMA_BUFFER_TOTAL_SIZE);
                    }
                }

                /* update dma sw_count*/
                mmap_dma_update.sw_count = reader_sw_count + buf_count;
                ioctl(fds.fd, LITEPCIE_IOCTL_MMAP_DMA_READER_UPDATE, &mmap_dma_update);

                first_loop = 0;
            }
        }

        /* non zero-copy mode */
        else {
            /* read from file */
            if(buf_wr_size < DMA_BUFFER_TOTAL_SIZE) {
                buf_wr_size = fread(buf_wr, 1, DMA_BUFFER_SIZE, fo);

                /* if end of file, rewind */
                if (feof(fo)) {
                    current_loop += 1;
                    if (current_loop >= loops)
                        goto loop_exit;
                    rewind(fo);
                    buf_wr_size += fread(buf_wr + buf_wr_size, 1, DMA_BUFFER_SIZE - buf_wr_size, fo);
                }
                buf_wr_offset = 0;
            }

            /* write event */
            if (fds.revents & POLLOUT) {
                len = write(fds.fd, buf_wr + buf_wr_offset, buf_wr_size);
                if (len > 0) {
                    buf_wr_size -= len;
                    buf_wr_offset += len;
                }
                first_loop = 0;
            }
        }

        /* statistics */
        duration = get_time_ms() - last_time;
        if (duration > 200) {
            if(i%10 == 0)
                printf("\e[1mSPEED(Gbps)   BUFFERS   SIZE(MB)   LOOP UNDERFLOWS\e[0m\n");
            i++;
            printf("%10.2f %10" PRIu64 " %10" PRIu64 " %6d %10ld\n",
                    (double)(reader_sw_count-reader_sw_count_last) * DMA_BUFFER_SIZE * 8 / ((double)duration * 1e6),
                    reader_sw_count,
                    (reader_sw_count*DMA_BUFFER_SIZE)/1024/1024,
                    current_loop,
                    sw_underflows);
            sw_underflows = 0;
            last_time = get_time_ms();
            reader_sw_count_last = reader_hw_count;
        }
    }

loop_exit:
    litepcie_dma_reader(fds.fd, 0, &reader_hw_count, &reader_sw_count);
    litepcie_release_dma_reader(fds.fd);

exit:
    if (litepcie_device_zero_copy)
        munmap(buf_wr, mmap_dma_info.dma_tx_buf_size * mmap_dma_info.dma_tx_buf_count);
    else
        free(buf_wr);

    close(fds.fd);
    fclose(fo);
}

static void help(void)
{
    printf("LitePCIe testing utilities\n"
           "usage: litepcie_test [options] cmd [args...]\n"
           "\n"
           "options:\n"
           "-h                               Help\n"
           "-c device_num                    Select the device (default = 0)\n"
           "-z                               Enable zero-copy DMA mode\n"
           "\n"
           "record [filename] [size]         Record DMA stream to file\n"
           "play filename [loops]            Play DMA stream from file\n"
           );
    exit(1);
}

int main(int argc, char **argv)
{
    const char *cmd;
    int c;

    litepcie_device_num = 0;
    litepcie_device_zero_copy = 0;

    signal(SIGINT, intHandler);

    for(;;) {
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

    if (optind >= argc)
        help();

    snprintf(litepcie_device, sizeof(litepcie_device), "/dev/litepcie%d", litepcie_device_num);

    cmd = argv[optind++];

    if (!strcmp(cmd, "init")) {
        const char *rate;
        if (optind + 1 > argc)
            goto show_help;
        rate = argv[optind++];
        litepcie_init(rate);
    } else if (!strcmp(cmd, "record")) {
        const char *filename = NULL;
        uint32_t size = 0;
        if (optind != argc) {
            if (optind + 2 > argc)
                goto show_help;
            filename = argv[optind++];
            size = strtoul(argv[optind++], NULL, 0);
        }
        litepcie_record(filename, size);
    } else if (!strcmp(cmd, "play")) {
        const char *filename;
        uint32_t loops = 1;
        if (optind + 1 > argc)
            goto show_help;
        filename = argv[optind++];
        if (optind < argc)
            loops = strtoul(argv[optind++], NULL, 0);
        litepcie_play(filename, loops);
    } else
show_help:
        help();

    return 0;
}
