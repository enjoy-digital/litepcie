import os
from distutils.dir_util import copy_tree

from litex.build import tools

from litex.soc.integration.export import get_csr_header, get_soc_header, get_mem_header


def copy_litepcie_software(dst):
    src = os.path.abspath(os.path.dirname(__file__))
    copy_tree(src, dst)

def generate_litepcie_software_headers(soc, dst):
    csr_header = get_csr_header(soc.csr_regions, soc.constants, with_access_functions=False)
    tools.write_to_file(os.path.join(dst, "csr.h"), csr_header)
    soc_header = get_soc_header(soc.constants, with_access_functions=False)
    tools.write_to_file(os.path.join(dst, "soc.h"), soc_header)
    mem_header = get_mem_header(soc.mem_regions)
    tools.write_to_file(os.path.join(dst, "mem.h"), mem_header)

def generate_litepcie_software(soc, dst):
    copy_litepcie_software(dst)
    generate_litepcie_software_headers(soc, os.path.join(dst, "kernel"))
