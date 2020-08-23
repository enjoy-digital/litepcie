/*
 * LitePCIe library
 *
 * This file is part of LitePCIe.
 *
 * Copyright (C) 2018-2020 / EnjoyDigital  / florent@enjoy-digital.fr
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef LITEPCIE_LIB_H
#define LITEPCIE_LIB_H

int64_t get_time_ms(void);

/* ioctl */

uint32_t litepcie_readl(int fd, uint32_t addr);
void litepcie_writel(int fd, uint32_t addr, uint32_t val);
void litepcie_reload(int fd);

void litepcie_dma(int fd, uint8_t loopback_enable);
void litepcie_dma_reader(int fd, uint8_t enable, int64_t *hw_count, int64_t *sw_count);
void litepcie_dma_writer(int fd, uint8_t enable, int64_t *hw_count, int64_t *sw_count);
void litepcie_set_pattern(int fd, uint8_t mode, uint8_t enable, uint8_t format);

uint8_t litepcie_request_dma_reader(int fd);
uint8_t litepcie_request_dma_writer(int fd);
void litepcie_release_dma_reader(int fd);
void litepcie_release_dma_writer(int fd);

#define countof(x) (sizeof(x) / sizeof(x[0]))

/* flash */

#define FLASH_READ_ID_REG 0x9F

#define FLASH_READ    0x03
#define FLASH_WREN    0x06
#define FLASH_WRDI    0x04
#define FLASH_PP      0x02
#define FLASH_SE      0xD8
#define FLASH_BE      0xC7
#define FLASH_RDSR    0x05
#define FLASH_WRSR    0x01
/* status */
#define FLASH_WIP     0x01

#define FLASH_SECTOR_SIZE (1 << 16)

uint8_t litepcie_flash_read(int fd, uint32_t addr);
int litepcie_flash_get_erase_block_size(int fd);
int litepcie_flash_write(int fd,
                     uint8_t *buf, uint32_t base, uint32_t size,
                     void (*progress_cb)(void *opaque, const char *fmt, ...),
                     void *opaque);

#endif /* LITEPCIE_LIB_H */
