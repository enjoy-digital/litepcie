/*
 * LitePCIe library
 *
 * This file is part of LitePCIe.
 *
 * Copyright (C) 2018-2020 / EnjoyDigital  / florent@enjoy-digital.fr
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <sys/ioctl.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include "litepcie_flash.h"
#include "litepcie_helpers.h"
#include "litepcie.h"

#ifdef CSR_FLASH_BASE

//#define FLASH_FULL_ERASE
#define FLASH_RETRIES 16

static void flash_spi_cs(int fd, uint8_t cs_n)
{
    litepcie_writel(fd, CSR_FLASH_CS_N_OUT_ADDR, cs_n);
}

static uint64_t flash_spi(int fd, int tx_len, uint8_t cmd,
                          uint32_t tx_data)
{
    struct litepcie_ioctl_flash m;
    flash_spi_cs(fd, 0);
    m.tx_len = tx_len;
    m.tx_data = tx_data | ((uint64_t)cmd << 32);
    checked_ioctl(fd, LITEPCIE_IOCTL_FLASH, &m);
    flash_spi_cs(fd, 1);
    return m.rx_data;
}

uint32_t flash_read_id(int fd, int reg)
{
    return flash_spi(fd, 32, reg, 0) & 0xffffff;
}

static void flash_write_enable(int fd)
{
    flash_spi(fd, 8, FLASH_WREN, 0);
}

static void flash_write_disable(int fd)
{
    flash_spi(fd, 8, FLASH_WRDI, 0);
}

static uint8_t flash_read_status(int fd)
{
    return flash_spi(fd, 16, FLASH_RDSR, 0) & 0xff;
}

static __attribute__((unused)) void flash_write_status(int fd, uint8_t value)
{
    flash_spi(fd, 16, FLASH_WRSR, value << 24);
}

static __attribute__((unused)) void flash_erase_sector(int fd, uint32_t addr)
{
    flash_spi(fd, 32, FLASH_SE, addr << 8);
}

static __attribute__((unused)) uint8_t flash_read_sector_lock(int fd, uint32_t addr)
{
    return flash_spi(fd, 40, FLASH_WRSR, addr << 8) & 0xff;
}

static __attribute__((unused)) void flash_write_sector_lock(int fd, uint32_t addr, uint8_t byte)
{
    flash_spi(fd, 40, FLASH_WRSR, (addr << 8) | byte);
}

static void flash_write(int fd, uint32_t addr, uint8_t byte)
{
    flash_spi(fd, 40, FLASH_PP, (addr << 8) | byte);
}

static void flash_write_buffer(int fd, uint32_t addr, uint8_t *buf, uint16_t size)
{
    int i;

    struct litepcie_ioctl_flash m;

    if (size == 1) {
        flash_write(fd, addr, buf[0]);
    } else {
        /* set cs_n */
        flash_spi_cs(fd, 0);

        /* send cmd */
        m.tx_len = 32;
        m.tx_data = ((uint64_t)FLASH_PP << 32) | ((uint64_t)addr << 8);
        checked_ioctl(fd, LITEPCIE_IOCTL_FLASH, &m);

        /* send bytes */
        for (i=0; i<size; i++) {
            m.tx_len = 8;
            m.tx_data = ((uint64_t)buf[i] << 32);
            checked_ioctl(fd, LITEPCIE_IOCTL_FLASH, &m);
        }

        /* release cs_n */
        flash_spi_cs(fd, 1);
    }
}

uint8_t litepcie_flash_read(int fd, uint32_t addr)
{
    return flash_spi(fd, 40, FLASH_READ, addr << 8) & 0xff;
}

static void litepcie_flash_read_buffer(int fd, uint32_t addr, uint8_t *buf, uint16_t size)
{
    int i;

    struct litepcie_ioctl_flash m;

    if (size == 1) {
        buf[0] = litepcie_flash_read(fd, addr);

    } else {
        /* set cs_n */
        flash_spi_cs(fd, 0);

        /* send cmd */
        m.tx_len = 32;
        m.tx_data = ((uint64_t)FLASH_READ << 32) | ((uint64_t)addr << 8);
        checked_ioctl(fd, LITEPCIE_IOCTL_FLASH, &m);

        /* read bytes */
        for (i=0; i<size; i++) {
            m.tx_len = 8;
            checked_ioctl(fd, LITEPCIE_IOCTL_FLASH, &m);
            buf[i] = m.rx_data;
        }

        /* release cs_n */
        flash_spi_cs(fd, 1);
    }
}

int litepcie_flash_get_erase_block_size(int fd)
{
    return FLASH_SECTOR_SIZE;
}

static int litepcie_flash_get_flash_program_size(int fd)
{
    int software_cs = 1;
    /* if software cs control, program in blocks to speed up update */
    litepcie_writel(fd, CSR_FLASH_CS_N_OUT_ADDR, 0);
    software_cs &= ((litepcie_readl(fd, CSR_FLASH_CS_N_OUT_ADDR) & 0x1) == 0);
    litepcie_writel(fd, CSR_FLASH_CS_N_OUT_ADDR, 1);
    software_cs &= ((litepcie_readl(fd, CSR_FLASH_CS_N_OUT_ADDR) & 0x1) == 1);
    if (software_cs)
        return 256;
    else
        return 1;
}

int litepcie_flash_write(int fd,
                     uint8_t *buf, uint32_t base, uint32_t size,
                     void (*progress_cb)(void *opaque, const char *fmt, ...),
                     void *opaque)
{
    int i;
    int retries;
    uint16_t flash_program_size;

    flash_program_size = litepcie_flash_get_flash_program_size(fd);
    printf("flash_program_size: %d\n", flash_program_size);

    uint8_t cmp_buf[256];

    /* dummy command because in some case the first erase does not
       work. */
    flash_read_id(fd, 0);

    /* disable write protection */
     flash_write_enable(fd);

#ifndef FLASH_FULL_ERASE
    /* erase */
    for(i = 0; i < size; i += FLASH_SECTOR_SIZE) {
        if (progress_cb) {
            progress_cb(opaque, "Erasing @%08x\r", base + i);
        }
        flash_write_enable(fd);
        flash_erase_sector(fd, base + i);
        while (flash_read_status(fd) & FLASH_WIP) {
            usleep(1000);
        }
    }
    if (progress_cb) {
        progress_cb(opaque, "\n");
    }
#else
    /* erase full flash */
    printf("Erasing...\n");
    flash_write_enable(fd);
    flash_spi(fd, 8, 0xC7, 0);
    while (flash_read_status(fd) & FLASH_WIP) {
        usleep(1000);
    }
#endif
    flash_write_disable(fd);

    i = 0;
    retries = 0;
    while (i < size) {
        if (progress_cb && (i % FLASH_SECTOR_SIZE) == 0) {
            progress_cb(opaque, "Writing @%08x\r", base + i);
        }

        /* wait flash to be ready */
        while (flash_read_status(fd) & FLASH_WIP)
            usleep(100);

        /* write flash page */
        flash_write_enable(fd);
        flash_write_buffer(fd, base + i, buf + i, flash_program_size);
        flash_write_disable(fd);

        /* wait flash to be ready*/
        while (flash_read_status(fd) & FLASH_WIP)
            usleep(100);

        /* verify flash page */
        litepcie_flash_read_buffer(fd, base + i, cmp_buf, flash_program_size);
        if (memcmp(buf + i, cmp_buf, flash_program_size) != 0) {
            retries += 1;
        } else {
            i += flash_program_size;
            retries = 0;
        }

        if (retries > FLASH_RETRIES) {
            printf("Not able to write page\n");
            return 1;
        }
    }

    if (progress_cb) {
        progress_cb(opaque, "\n");
    }

    return 0;
}

#endif
