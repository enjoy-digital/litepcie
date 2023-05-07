# Makefile for kernel module
KERNEL_VERSION:=$(shell uname -r)
KERNEL_PATH?=/lib/modules/$(KERNEL_VERSION)/build
ARCH?=$(shell uname -m)

# Export `REPO_DIR` so that when the kernel's byzantine makefile system re-includes us,
# it's already set properly and doesn't get re-set with the wrong path.
REPO_DIR ?= $(shell dirname $(shell dirname $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))))
export REPO_DIR

NVIDIA_PATH ?= ~/open-gpu-kernel-modules/

NV_DMA ?= false

obj-m = litepcie.o liteuart.o
litepcie-objs = main.o
#liteuart-objs = liteuart.o

ifeq ($(NV_DMA),true)
ccflags-y += -I$(NVIDIA_PATH)/kernel-open/nvidia -DNV_DMA=$(NV_DMA)

# don't warn about missing NVIDIA symbols; they'll be available
# TODO: create our own Module.symvers,
#       https://github.com/NVIDIA/gds-nvidia-fs/blob/af3f7de96b4e500abf30e3034e5827749953bd68/src/Makefile#L108-L112
KBUILD_MODPOST_WARN=1
endif

all: litepcie.ko liteuart.ko

litepcie.ko liteuart.ko &: main.c liteuart.c litepcie.h config.h flags.h #csr.h soc.h
	$(MAKE) -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) modules

modules: litepcie.ko liteuart.ko

modules_install: modules
	$(MAKE) -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) modules_install

clean:
	$(MAKE) -C $(KERNEL_PATH) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(shell pwd) clean
	rm -f *~

print-%  : ; @echo $* = $($*)
