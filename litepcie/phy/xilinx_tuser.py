#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import C, Cat


def rc_tuser_full_to_raw_expr(tuser_full, pcie_data_width):
    if pcie_data_width == 512:
        tkeep_width = pcie_data_width // 8
        return Cat(tuser_full[0:tkeep_width], C(0, 85 - tkeep_width))
    return Cat(tuser_full, C(0, 10))


def cq_tuser_full_to_raw_expr(tuser_full, pcie_data_width):
    if pcie_data_width == 512:
        return Cat(
            tuser_full[0:80],
            C(0, 16),
            tuser_full[96],
            C(0, 159),
        )
    return Cat(tuser_full, C(0, 256 - 88))
