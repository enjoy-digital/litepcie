# Makefile for kernel module
KERNEL_VERSION:=$(shell uname -r)
KERNEL_PATH:=/lib/modules/$(KERNEL_VERSION)/build

obj-m = litepcie.o
litepcie-objs = main.o


all: litepcie.ko

litepcie.ko: main.c
	make -C $(KERNEL_PATH) M=$(shell pwd) modules

clean:
	make -C $(KERNEL_PATH) M=$(shell pwd) clean
	rm -f *~
