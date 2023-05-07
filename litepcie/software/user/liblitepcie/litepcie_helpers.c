/*
 * LitePCIe library
 *
 * This file is part of LitePCIe.
 *
 * Copyright (C) 2018-2020 / EnjoyDigital  / florent@enjoy-digital.fr
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <time.h>
#include <sys/ioctl.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include "litepcie_helpers.h"
#include "litepcie.h"

int64_t get_time_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000 + (ts.tv_nsec / 1000000U);
}

uint32_t litepcie_readl(int fd, uint32_t addr) {
    struct litepcie_ioctl_reg m = {0};
    m.is_write = 0;
    m.addr = addr;
    checked_ioctl(fd, LITEPCIE_IOCTL_REG, &m);
    return m.val;
}

void litepcie_writel(int fd, uint32_t addr, uint32_t val) {
    struct litepcie_ioctl_reg m = {0};
    m.is_write = 1;
    m.addr = addr;
    m.val = val;
    checked_ioctl(fd, LITEPCIE_IOCTL_REG, &m);
}

void litepcie_reload(int fd) {
    struct litepcie_ioctl_icap m;
    m.addr = 0x4;
    m.data = 0xf;
    checked_ioctl(fd, LITEPCIE_IOCTL_ICAP, &m);
}

void _check_ioctl(int status, const char *file, int line) {
    if (status) {
        fprintf(stderr, "Failed ioctl at %s:%d: %s\n", file, line, strerror(errno));
        abort();
    }
}

#ifdef NV_DMA
void _check_cuda_call(CUresult status, const char *file, int line) {
    if (status != CUDA_SUCCESS) {
        const char *perrstr = 0;
        CUresult ok = cuGetErrorString(status, &perrstr);
        if (ok == CUDA_SUCCESS) {
            if (perrstr) {
                fprintf(stderr, "CUDA error at %s:%d: %s\n", file, line, perrstr);
            } else {
                fprintf(stderr, "CUDA error at %s:%d: unknown error\n", file, line);
            }
        }
        abort();
    }
}
#endif
