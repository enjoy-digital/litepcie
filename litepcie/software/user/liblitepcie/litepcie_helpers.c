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
#include "litepcie_helpers.h"
#include "litepcie.h"

int64_t get_time_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000 + (ts.tv_nsec / 1000000U);
}

uint32_t litepcie_readl(int fd, uint32_t addr) {
    struct litepcie_ioctl_reg m;
    m.is_write = 0;
    m.addr = addr;
    ioctl(fd, LITEPCIE_IOCTL_REG, &m);
    return m.val;
}

void litepcie_writel(int fd, uint32_t addr, uint32_t val) {
    struct litepcie_ioctl_reg m;
    m.is_write = 1;
    m.addr = addr;
    m.val = val;
    ioctl(fd, LITEPCIE_IOCTL_REG, &m);
}

void litepcie_reload(int fd) {
    struct litepcie_ioctl_icap m;
    m.addr = 0x4;
    m.data = 0xf;
    ioctl(fd, LITEPCIE_IOCTL_ICAP, &m);
}
