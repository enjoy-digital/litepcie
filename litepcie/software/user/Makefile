CFLAGS=-O2 -Wall -g -I../kernel -MMD
LDFLAGS=-g
CC=$(CROSS_COMPILE)gcc
AR=ar

PROGS=litepcie_util litepcie_test

all: $(PROGS)

litepcie_util: liblitepcie.o litepcie_util.o
	$(CC) $(LDFLAGS) -o $@ $^ -lrt -lm

litepcie_test: liblitepcie.o litepcie_test.o
	$(CC) $(LDFLAGS) -o $@ $^ -lrt -lm

clean:
	rm -f $(PROGS) *.o *.a *.d *~

%.o: %.c
	$(CC) -c $(CFLAGS) -o $@ $<

-include $(wildcard *.d)
