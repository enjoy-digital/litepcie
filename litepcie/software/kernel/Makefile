# Makefile for kernel module
KERNEL_VERSION:=$(shell uname -r)
KERNEL_PATH?=/lib/modules/$(KERNEL_VERSION)/build
ARCH?=$(shell uname -m)

obj-m = litepcie.o liteuart.o
litepcie-objs = main.o
#liteuart-objs = liteuart.o


all: litepcie.ko liteuart.ko

litepcie.ko: main.c
	make -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) modules

litepcie.ko: litepcie.h config.h flags.h csr.h soc.h

liteuart.ko: liteuart.c
	make -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) modules

clean:
	make -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) clean
	rm -f *~
