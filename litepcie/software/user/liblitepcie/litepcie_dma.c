/*
 * LitePCIe library
 *
 * This file is part of LitePCIe.
 *
 * Copyright (C) 2018-2020 / EnjoyDigital  / florent@enjoy-digital.fr
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <sys/ioctl.h>
#include "litepcie_dma.h"
#include "litepcie.h"


void litepcie_dma(int fd, uint8_t loopback_enable) {
    struct litepcie_ioctl_dma m;
    m.loopback_enable = loopback_enable;
    ioctl(fd, LITEPCIE_IOCTL_DMA, &m);
}

void litepcie_dma_writer(int fd, uint8_t enable, int64_t *hw_count, int64_t *sw_count) {
    struct litepcie_ioctl_dma_writer m;
    m.enable = enable;
    ioctl(fd, LITEPCIE_IOCTL_DMA_WRITER, &m);
    *hw_count = m.hw_count;
    *sw_count = m.sw_count;
}

void litepcie_dma_reader(int fd, uint8_t enable, int64_t *hw_count, int64_t *sw_count) {
    struct litepcie_ioctl_dma_reader m;
    m.enable = enable;
    ioctl(fd, LITEPCIE_IOCTL_DMA_READER, &m);
    *hw_count = m.hw_count;
    *sw_count = m.sw_count;
}

/* lock */

uint8_t litepcie_request_dma_reader(int fd) {
    struct litepcie_ioctl_lock m;
    m.dma_reader_request = 1;
    m.dma_writer_request = 0;
    m.dma_reader_release = 0;
    m.dma_writer_release = 0;
    ioctl(fd, LITEPCIE_IOCTL_LOCK, &m);
    return m.dma_reader_status;
}

uint8_t litepcie_request_dma_writer(int fd) {
    struct litepcie_ioctl_lock m;
    m.dma_reader_request = 0;
    m.dma_writer_request = 1;
    m.dma_reader_release = 0;
    m.dma_writer_release = 0;
    ioctl(fd, LITEPCIE_IOCTL_LOCK, &m);
    return m.dma_writer_status;
}

void litepcie_release_dma_reader(int fd) {
    struct litepcie_ioctl_lock m;
    m.dma_reader_request = 0;
    m.dma_writer_request = 0;
    m.dma_reader_release = 1;
    m.dma_writer_release = 0;
    ioctl(fd, LITEPCIE_IOCTL_LOCK, &m);
}

void litepcie_release_dma_writer(int fd) {
    struct litepcie_ioctl_lock m;
    m.dma_reader_request = 0;
    m.dma_writer_request = 0;
    m.dma_reader_release = 0;
    m.dma_writer_release = 1;
    ioctl(fd, LITEPCIE_IOCTL_LOCK, &m);
}
