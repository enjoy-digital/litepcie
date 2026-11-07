#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Type 0 configuration space (PCIe Base chapter 7): header with one 32-bit memory BAR,
Power Management, MSI and PCI Express (version 2) capabilities. No extended capabilities (DW 40h
reads as 0), unimplemented registers read as 0 and ignore writes. Single function, no INTx.
"""

from migen import *

from litex.gen import *

# Capability offsets (bytes).
PM_CAP   = 0x40
MSI_CAP  = 0x48
PCIE_CAP = 0x60

class PCIeConfigSpace(LiteXModule):
    """adr: DW address, read combinational (dat_r), write with we/be/dat_w (registers little-endian:
    byte 0 of the register on bits 7:0, as in the TLP payload)."""
    def __init__(self, bar0_mask, nlanes=1, vendor_id=0x10ee, device_id=0x7021, class_code=0x058000,
        msi_vectors=1, gen2_capable=False, gen3_capable=False):
        assert msi_vectors in [1, 2, 4, 8, 16, 32]

        # Access.
        self.adr   = Signal(10) # i
        self.we    = Signal()   # i
        self.be    = Signal(4)  # i
        self.dat_w = Signal(32) # i
        self.dat_r = Signal(32) # o

        # Status inputs.
        self.link_speed  = Signal(4, reset=1) # i: Link Status speed.
        self.link_width  = Signal(6, reset=1) # i: Link Status width.
        self.ur_detected = Signal()           # i (Pulse): Unsupported Request received.

        # Outputs.
        self.mse         = Signal()   # o: Memory Space Enable.
        self.bme         = Signal()   # o: Bus Master Enable.
        self.msi_enable  = Signal()   # o
        self.msi_mme     = Signal(3)  # o: Multiple Message Enable.
        self.msi_address = Signal(64) # o
        self.msi_data    = Signal(16) # o
        self.mps         = Signal(3)  # o: Max Payload Size (Device Control).
        self.mrrs        = Signal(3)  # o: Max Read Request Size (Device Control).

        # # #

        cases = {}
        def add(offset, ro=0, reset=0, mask=0):
            """Register at byte offset: bits in mask are writable (from reset), the others read as ro."""
            adr = offset//4
            if mask:
                storage = Signal(32, reset=reset)
                read = (storage & mask) | (Constant(ro, 32) if isinstance(ro, int) else ro)
                for b in range(4):
                    byte_mask = (mask >> 8*b) & 0xff
                    if byte_mask:
                        self.sync += If(self.we & self.be[b] & (self.adr == adr),
                            storage[8*b:8*(b+1)].eq(self.dat_w[8*b:8*(b+1)] & byte_mask)
                        )
            else:
                storage = None
                read = ro
            cases[adr] = self.dat_r.eq(read)
            return storage

        log2_vectors = {1: 0, 2: 1, 4: 2, 8: 3, 16: 4, 32: 5}[msi_vectors]

        # Header ------------------------------------------------------------------------------------
        add(0x00, ro=(device_id << 16) | vendor_id)
        command = add(0x04, ro=(1 << 20), mask=0x00000546) # Status: Capabilities List.
        add(0x08, ro=(class_code << 8))
        add(0x0c, mask=0x000000ff) # Cache Line Size.
        bar0 = add(0x10, mask=bar0_mask) # 32-bit, non-prefetchable memory BAR.
        add(0x2c, ro=(device_id << 16) | vendor_id)
        add(0x34, ro=PM_CAP)
        add(0x3c, mask=0x000000ff) # Interrupt Line, no Interrupt Pin.

        # Power Management --------------------------------------------------------------------------
        add(PM_CAP + 0x00, ro=(0x0003 << 16) | (MSI_CAP << 8) | 0x01)
        add(PM_CAP + 0x04, ro=(1 << 3), mask=0x00000003) # No_Soft_Reset, PowerState.

        # MSI (64-bit address) ----------------------------------------------------------------------
        msi_ctrl = add(MSI_CAP + 0x00,
            ro   = (((1 << 7) | (log2_vectors << 1)) << 16) | (PCIE_CAP << 8) | 0x05,
            mask = (0x71 << 16))
        msi_lo   = add(MSI_CAP + 0x04, mask=0xfffffffc)
        msi_hi   = add(MSI_CAP + 0x08, mask=0xffffffff)
        msi_data = add(MSI_CAP + 0x0c, mask=0x0000ffff)

        # PCI Express (version 2, Endpoint) ---------------------------------------------------------
        add(PCIE_CAP + 0x00, ro=(0x0002 << 16) | 0x10)
        # Device Capabilities: 512-byte Max Payload Size, Role-Based Error Reporting.
        add(PCIE_CAP + 0x04, ro=0x00008002)
        # Device Control (reset: Relaxed Ordering, No Snoop, 512-byte MRRS; Extended Tag, Phantom Functions
        # and Aux Power PM hardwired to 0), Device Status: Unsupported Request Detected (bit 19, write 1
        # to clear).
        ur = Signal()
        self.sync += [
            If(self.we & self.be[2] & (self.adr == (PCIE_CAP + 0x08)//4) & self.dat_w[19],
                ur.eq(0)
            ),
            If(self.ur_detected,
                ur.eq(1)
            )
        ]
        devctl = add(PCIE_CAP + 0x08, ro=Cat(Constant(0, 19), ur), reset=0x00002810, mask=0x000078ff)
        # Link Capabilities: speeds, width, no ASPM (Link Control's ASPM Control is hardwired to 0).
        speed = 3 if gen3_capable else 2 if gen2_capable else 1 # Max Link Speed: 2.5, 5.0, 8.0 GT/s.
        add(PCIE_CAP + 0x0c, ro=(speed | (nlanes << 4)))
        # Link Control (Read Completion Boundary, Common Clock, Extended Sync), Link Status: Slot Clock.
        add(PCIE_CAP + 0x10, ro=Cat(Constant(0, 16), self.link_speed, self.link_width, Constant(0, 2), Constant(1, 1)),
            mask=0x000000c8)
        # Link Capabilities 2 (Supported Link Speeds), Link Control 2 (Target Link Speed).
        add(PCIE_CAP + 0x2c, ro=(((1 << speed) - 1) << 1))
        add(PCIE_CAP + 0x30, ro=speed)

        self.comb += [
            self.dat_r.eq(0),
            Case(self.adr, cases),
            self.mse.eq(command[1]),
            self.bme.eq(command[2]),
            self.msi_enable.eq(msi_ctrl[16]),
            self.msi_mme.eq(msi_ctrl[20:23]),
            self.msi_address.eq(Cat(Constant(0, 2), msi_lo[2:32], msi_hi)),
            self.msi_data.eq(msi_data[0:16]),
            self.mps.eq(devctl[5:8]),
            self.mrrs.eq(devctl[12:15]),
        ]
        self.bar0 = bar0
