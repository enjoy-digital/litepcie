MSCDIR = ../../../../
PYTHON = python3

CMD = PYTHONPATH=$(MSCDIR) $(PYTHON)

wishbone_tb:
	$(CMD) wishbone_tb.py

dma_tb:
	$(CMD) dma_tb.py

example_designs:
	cd ../example_designs && $(PYTHON) make.py -t dma -p kc705 -Ob run False build-bitstream
