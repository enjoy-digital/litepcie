#!/usr/bin/env python3

import sys
from setuptools import setup
from setuptools import find_packages


if sys.version_info[:3] < (3, 3):
    raise SystemExit("You need Python 3.3+")


setup(
	name="litepcie",
	version="1.0",
	description="small footprint and configurable PCIe core",
	long_description=open("README").read(),
	author="Florent Kermarrec",
	author_email="florent@enjoy-digital.fr",
	url="http://enjoy-digital.fr",
	download_url="https://github.com/enjoy-digital/litepcie",
    license="BSD",
    platforms=["Any"],
    keywords="HDL ASIC FPGA hardware design",
	classifiers=[
		"Topic :: Scientific/Engineering :: Electronic Design Automation (EDA)",
		"Environment :: Console",
		"Development Status :: Alpha",
		"Intended Audience :: Developers",
        "License :: OSI Approved :: BSD License",
		"Operating System :: OS Independent",
		"Programming Language :: Python",
    ],
    packages=find_packages(),
    include_package_data=True,
)
