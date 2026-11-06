#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Transaction Layer glue: what the vendors' hard IPs do above the Data Link Layer
and below the LitePCIe TLP stream (Type 0 configuration space, configuration completions,
Unsupported Requests, MSI generation, stream adaptation)."""
