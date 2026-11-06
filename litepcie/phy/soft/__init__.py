#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY: PCIe Gen1/Gen2 Physical and Data Link Layers on FPGA transceivers (LiteICLink),
without the vendor's hard PCIe IP. See doc/softphy.md for the architecture, status and bring-up.

"""

from litepcie.phy.soft.core import SoftPCIEPHY
