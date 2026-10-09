# Makefile for kernel module
KERNEL_VERSION:=$(shell uname -r)
KERNEL_PATH?=/lib/modules/$(KERNEL_VERSION)/build
ARCH?=$(shell uname -m)

# Driver/device name: $(LITEPCIE_NAME).ko module, /dev/$(LITEPCIE_NAME)N devices.
LITEPCIE_NAME?=litepcie

obj-m = $(LITEPCIE_NAME).o liteuart.o
$(LITEPCIE_NAME)-objs = main.o
#liteuart-objs = liteuart.o
ccflags-y += -DLITEPCIE_NAME=\"$(LITEPCIE_NAME)\"


all: $(LITEPCIE_NAME).ko liteuart.ko

$(LITEPCIE_NAME).ko: main.c
	make -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) modules

$(LITEPCIE_NAME).ko: litepcie.h config.h flags.h csr.h soc.h

liteuart.ko: liteuart.c
	make -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) modules

clean:
	make -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) clean
	rm -f *~
