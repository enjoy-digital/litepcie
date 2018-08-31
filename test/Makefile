PYTHON = python3

CMD = $(PYTHON)

examples:
	cd ../examples && $(PYTHON) make.py -t dma -p kc705 -Ob run False build-bitstream

all: examples

clean:
	rm -f *.v
