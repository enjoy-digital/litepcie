/*
 * LitePCIe library
 *
 * This file is part of LitePCIe.
 *
 * Copyright (C) 2018-2020 / EnjoyDigital  / florent@enjoy-digital.fr
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef LITEPCIE_LIB_HELPERS_H
#define LITEPCIE_LIB_HELPERS_H

#include <stdint.h>

int64_t get_time_ms(void);

uint32_t litepcie_readl(int fd, uint32_t addr);
void litepcie_writel(int fd, uint32_t addr, uint32_t val);
void litepcie_reload(int fd);

#endif /* LITEPCIE_LIB_HELPERS_H */
