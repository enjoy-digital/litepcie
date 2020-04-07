#!/usr/bin/env python3

from setuptools import setup
from setuptools import find_packages

setup(
    name="litepcie",
    description="Small footprint and configurable PCIe core",
    author="Florent Kermarrec",
    author_email="florent@enjoy-digital.fr",
    url="http://enjoy-digital.fr",
    download_url="https://github.com/enjoy-digital/litepcie",
    test_suite="test",
    license="BSD",
    python_requires="~=3.6",
    install_requires=["pyyaml"],
    packages=find_packages(exclude=("test*", "sim*", "doc*", "examples*")),
    include_package_data=True,
    entry_points={
        "console_scripts": [
            "litepcie_gen=litepcie.gen:main",
        ],
    },
)
