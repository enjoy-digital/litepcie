#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY common definitions: 8b/10b Special Symbols (PCIe Base 4.2.1.1.1, Table 4-1), Ordered
Sets (4.2.4) and Training Sequence fields (4.2.4.1), lane word layout.

A lane word carries nsymbols (4 by default) Symbols: Symbol i is data[8*i:8*(i+1)] with ctrl[i] set
for a K Symbol. Symbol 0 is transmitted first (same convention as the LiteICLink SerDes streams).
"""

# Helpers ------------------------------------------------------------------------------------------

def K(x, y):
    """K code value, ex: K(28, 5) is COM."""
    return (y << 5) | x

def D(x, y):
    """D code value, ex: D(10, 2) is the TS1 identifier."""
    return (y << 5) | x

# Special Symbols (Table 4-1) ----------------------------------------------------------------------

class Symbol:
    """Symbol definition with name, 8-bit value and description."""
    def __init__(self, name, value, description=""):
        self.name        = name
        self.value       = value
        self.description = description

    def __repr__(self):
        return f"{self.name}(0x{self.value:02x})"

COM = Symbol("COM", K(28, 5), "Comma: Symbol alignment, LFSR initialization")
STP = Symbol("STP", K(27, 7), "Start TLP")
SDP = Symbol("SDP", K(28, 2), "Start DLLP")
END = Symbol("END", K(29, 7), "End of a good packet")
EDB = Symbol("EDB", K(30, 7), "End Bad: nullified TLP")
PAD = Symbol("PAD", K(23, 7), "Pad: unassigned TS1/TS2 Link/Lane number")
SKP = Symbol("SKP", K(28, 0), "Skip: clock compensation (SKP Ordered Set)")
FTS = Symbol("FTS", K(28, 1), "Fast Training Sequence (FTS Ordered Set)")
IDL = Symbol("IDL", K(28, 3), "Idle (Electrical Idle Ordered Set)")
EIE = Symbol("EIE", K(28, 7), "Electrical Idle Exit (5.0 GT/s)")
ERR = Symbol("ERR", K(28, 4), "Reserved K code, substituted to received 8b/10b errors")

symbols = [COM, STP, SDP, END, EDB, PAD, SKP, FTS, IDL, EIE, ERR]

LOGICAL_IDLE = D(0, 0) # Logical Idle: D0.0 (scrambled) when nothing else is transmitted.

# Ordered Sets (4.2.4) -----------------------------------------------------------------------------

class OrderedSet(list):
    """Ordered Set: list of Symbols (K codes) and integers (D code values) with a name."""
    def __init__(self, name, values, description=""):
        self.name        = name
        self.description = description
        list.__init__(self, values)

    def to_bytes(self):
        return bytes([e.value if isinstance(e, Symbol) else e for e in self])

    def to_symbols(self):
        """(value, k) tuples."""
        return [(e.value, 1) if isinstance(e, Symbol) else (e, 0) for e in self]

SKP_OS = OrderedSet("SKP",   [COM] + [SKP]*3, "Skip Ordered Set (clock compensation)")
FTS_OS = OrderedSet("FTS",   [COM] + [FTS]*3, "Fast Training Sequence Ordered Set (L0s exit)")
EIOS   = OrderedSet("EIOS",  [COM] + [IDL]*3, "Electrical Idle Ordered Set")

# Training Sequences (4.2.4.1, Tables 4-2/4-3) -----------------------------------------------------

TS_LENGTH = 16

# Symbols 6-15: identifiers, and their values when the lane polarity is inverted (4.2.4.4).
TS1_ID     = D(10, 2) # 0x4a
TS2_ID     = D( 5, 2) # 0x45
TS1_ID_INV = D(21, 5) # 0xb5 = ~TS1_ID
TS2_ID_INV = D(26, 5) # 0xba = ~TS2_ID

# Symbol 4: Data Rate Identifier.
RATE_2_5GT        = 0b00000010 # Bit 1: 2.5 GT/s supported.
RATE_5_0GT        = 0b00000100 # Bit 2: 5.0 GT/s supported.
RATE_AUTONOMOUS   = 0b01000000 # Bit 6: Autonomous Change / Selectable De-emphasis.
RATE_SPEED_CHANGE = 0b10000000 # Bit 7: Speed change.

# Symbol 5: Training Control.
CTRL_HOT_RESET          = 0b00000001
CTRL_DISABLE_LINK       = 0b00000010
CTRL_LOOPBACK           = 0b00000100
CTRL_DISABLE_SCRAMBLING = 0b00001000
CTRL_COMPLIANCE_RECEIVE = 0b00010000

def training_sequence(ts=1, link=None, lane=None, n_fts=255, rate=RATE_2_5GT, ctrl=0, inverted=False):
    """TS1/TS2 Ordered Set: COM, Link Number (PAD or 0-255), Lane Number (PAD or 0-31), N_FTS, Data
    Rate Identifier, Training Control and 10 identifiers (inverted: the identifiers a receiver with
    inverted polarity sees, used to detect the inversion).
    """
    assert ts in (1, 2)
    assert link is None or (0 <= link <= 255)
    assert lane is None or (0 <= lane <= 31)
    ident = {1: TS1_ID, 2: TS2_ID}[ts] if not inverted else {1: TS1_ID_INV, 2: TS2_ID_INV}[ts]
    return OrderedSet(f"TS{ts}", [
        COM,
        PAD if link is None else link,
        PAD if lane is None else lane,
        n_fts,
        rate,
        ctrl,
    ] + [ident]*10)

TS1 = training_sequence(ts=1)
TS2 = training_sequence(ts=2)

# Lane Word Layout ---------------------------------------------------------------------------------

def lane_layout(nsymbols=4):
    """Stream layout of a lane word: nsymbols Symbols, data[8*i:8*(i+1)]/ctrl[i] for Symbol i."""
    return [("data", 8*nsymbols), ("ctrl", nsymbols)]
