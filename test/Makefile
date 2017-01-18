PYTHON = python3

CMD = $(PYTHON)

example_designs:
	cd ../example_designs && $(PYTHON) make.py -t dma -p kc705 -Ob run False build-bitstream

all: example_designs

clean:
	rm -f *.v
