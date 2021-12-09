#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include "liblitepcie.h"

sig_atomic_t keep_running = 1;

void intHandler(__attribute__((unused)) int dummy) {
    keep_running = 0;
}

void dma_test(const char *device_name, uint8_t zero_copy)
{
    static struct litepcie_dma_ctrl dma = {.use_reader = 1, .use_writer = 1, .loopback = 1};

    int64_t stat_last_time = get_time_ms();
    static uint64_t stat_read_counter, stat_write_counter;

    litepcie_dma_init(&dma, device_name, zero_copy);

    while (1)
    {
        if (!keep_running)
            break;

        litepcie_dma_process(&dma);

        while (1) {
            // process all incoming data from the device buffer by buffer
            char *buf_rd = litepcie_dma_next_read_buffer(&dma);
            if (!buf_rd)
                break;
            //
            // use the data in buf_rd here, buffer size is DMA_BUFFER_SIZE
            //
            stat_read_counter++;
        }
        while (1) {
            // send as much data as possible right now to the device buffer by buffer
            char *buf_wr = litepcie_dma_next_write_buffer(&dma);
            if (!buf_wr)
                break;
            //
            // write data into buf_wr here, buffer size is DMA_BUFFER_SIZE
            //
            stat_write_counter++;
        }

        int64_t stat_current_time = get_time_ms();
        if (stat_current_time - stat_last_time > 200) {
            printf("buffers: read - %lu, written - %lu\n", stat_read_counter, stat_write_counter);
            stat_last_time = stat_current_time;
        }
    }

    litepcie_dma_cleanup(&dma);
}

int main(int argc, char **argv)
{
    signal(SIGINT, intHandler);
    if (argc < 2)
    {
        printf("use: litepcie_dma_test /dev/litepcieX");
        exit(1);
    }
    dma_test(argv[1], 1);
}
