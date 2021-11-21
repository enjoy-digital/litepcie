/*
 * LitePCIe library
 *
 * This file is part of LitePCIe.
 *
 * Copyright (C) 2018-2020 / EnjoyDigital  / florent@enjoy-digital.fr
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef LITEPCIE_LIB_DMA_H
#define LITEPCIE_LIB_DMA_H

#include <stdint.h>

void litepcie_dma_set_loopback(int fd, uint8_t loopback_enable);
void litepcie_dma_reader(int fd, uint8_t enable, int64_t *hw_count, int64_t *sw_count);
void litepcie_dma_writer(int fd, uint8_t enable, int64_t *hw_count, int64_t *sw_count);
void litepcie_set_pattern(int fd, uint8_t mode, uint8_t enable, uint8_t format);

uint8_t litepcie_request_dma_reader(int fd);
uint8_t litepcie_request_dma_writer(int fd);
void litepcie_release_dma_reader(int fd);
void litepcie_release_dma_writer(int fd);

#endif /* LITEPCIE_LIB_DMA_H */
