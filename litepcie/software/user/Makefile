CFLAGS=-O2 -Wall -g -I../kernel -Iliblitepcie -MMD -fPIC
LDFLAGS=-g
CC=$(CROSS_COMPILE)gcc
AR=ar

NV_DMA?=false
CUDA_PATH?=/usr/local/cuda

ifeq ($(NV_DMA),true)
ifeq ($(wildcard $(CUDA_PATH)/include/cuda.h),)
$(error cuda.h not found in CUDA_PATH=$(CUDA_PATH))
endif
CFLAGS += -I$(CUDA_PATH)/include -DLITEPCIE_NVIDIA_P2P
LDFLAGS += -L$(CUDA_PATH)/lib64 -L$(CUDA_PATH)/lib
NV_LDLIBS += -lcuda
endif

PROGS=litepcie_util litepcie_test

all: $(PROGS)

liblitepcie/liblitepcie.a: liblitepcie/litepcie_dma.o liblitepcie/litepcie_flash.o liblitepcie/litepcie_helpers.o
	ar rcs $@ $+
	ranlib $@

litepcie_util: litepcie_util.o liblitepcie/liblitepcie.a
	$(CC) $(LDFLAGS) -o $@ $^ $(NV_LDLIBS)

litepcie_test: litepcie_test.o liblitepcie/liblitepcie.a
	$(CC) $(LDFLAGS) -o $@ $^ -lm

clean:
	rm -f $(PROGS) *.o *.a *.d *~ liblitepcie/*.a liblitepcie/*.o liblitepcie/*.d

%.o: %.c
	$(CC) -c $(CFLAGS) -o $@ $<

liblitepcie/%.o: liblitepcie/%.c
	$(CC) -c $(CFLAGS) -o $@ $<

-include $(wildcard *.d)
