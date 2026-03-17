#
# This file is part of LitePCIe.
#
# SPDX-License-Identifier: BSD-2-Clause

__all__ = ["LitePCIeEndpoint", "LitePCIeMSI", "LitePCIeMSIMultiVector", "LitePCIeMSIX"]


def __getattr__(name):
    if name == "LitePCIeEndpoint":
        from litepcie.core.endpoint import LitePCIeEndpoint
        return LitePCIeEndpoint
    if name in ["LitePCIeMSI", "LitePCIeMSIMultiVector", "LitePCIeMSIX"]:
        from litepcie.core.msi import LitePCIeMSI, LitePCIeMSIMultiVector, LitePCIeMSIX
        return {
            "LitePCIeMSI": LitePCIeMSI,
            "LitePCIeMSIMultiVector": LitePCIeMSIMultiVector,
            "LitePCIeMSIX": LitePCIeMSIX,
        }[name]
    raise AttributeError(name)
