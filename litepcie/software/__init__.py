import os
import re
from shutil import copytree

from litex.build import tools

from litex.soc.integration.export import get_csr_header, get_soc_header, get_mem_header


def copy_litepcie_software(dst):
    src = os.path.abspath(os.path.dirname(__file__))
    copytree(src, dst, dirs_exist_ok=True)

def set_litepcie_software_name(dst, name="litepcie"):
    # Driver/device name: <name>.ko module, /dev/<name>N devices, class/driver name.
    if not re.fullmatch(r"[a-z_][a-z0-9_]*", name):
        raise ValueError(f"Invalid driver name: {name} (expected [a-z_][a-z0-9_]*).")
    for filename, default in [
        (os.path.join(dst, "kernel", "Makefile"), "LITEPCIE_NAME?=litepcie"),
        (os.path.join(dst, "user",   "Makefile"), "LITEPCIE_NAME?=litepcie"),
        (os.path.join(dst, "kernel", "init.sh"),  "NAME=${LITEPCIE_NAME:-litepcie}"),
    ]:
        with open(filename, "r", encoding="utf-8") as f:
            content = f.read()
        assert default in content
        content = content.replace(default, default.replace("litepcie", name))
        with open(filename, "w", encoding="utf-8") as f:
            f.write(content)

def generate_litepcie_software_headers(soc, dst):
    csr_header = get_csr_header(soc.csr_regions, soc.constants, with_access_functions=False)
    tools.write_to_file(os.path.join(dst, "csr.h"), csr_header)
    soc_header = get_soc_header(soc.constants, with_access_functions=False)
    tools.write_to_file(os.path.join(dst, "soc.h"), soc_header)
    mem_header = get_mem_header(soc.mem_regions)
    tools.write_to_file(os.path.join(dst, "mem.h"), mem_header)

def generate_litepcie_software(soc, dst, name="litepcie"):
    copy_litepcie_software(dst)
    set_litepcie_software_name(dst, name)
    generate_litepcie_software_headers(soc, os.path.join(dst, "kernel"))
