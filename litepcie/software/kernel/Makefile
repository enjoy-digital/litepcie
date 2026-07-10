# Makefile for kernel module
KERNEL_VERSION:=$(shell uname -r)
KERNEL_PATH?=/lib/modules/$(KERNEL_VERSION)/build
ARCH?=$(shell uname -m)

NV_DMA?=false
NVIDIA_PATH?=/usr/src/nvidia
KBUILD_OPTIONS=

obj-m = litepcie.o liteuart.o
litepcie-objs = main.o
#liteuart-objs = liteuart.o

ifeq ($(NV_DMA),true)
ifeq ($(wildcard $(NVIDIA_PATH)/nv-p2p.h),)
$(error nv-p2p.h not found in NVIDIA_PATH=$(NVIDIA_PATH))
endif
ccflags-y += -I$(NVIDIA_PATH) -DLITEPCIE_NVIDIA_P2P
# NVIDIA's exported symbols are resolved when its kernel module is loaded.
KBUILD_OPTIONS += KBUILD_MODPOST_WARN=1
endif

.PHONY: all clean

all: main.c liteuart.c litepcie.h config.h flags.h csr.h soc.h
	+$(MAKE) -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) \
		M=$(shell pwd) $(KBUILD_OPTIONS) modules

clean:
	+$(MAKE) -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) clean
	rm -f *~
