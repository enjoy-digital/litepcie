# Glossary {#glossary}

The terms below are used throughout the manual. PCI Express terms follow the PCI Express Base
Specification; [PCI Express in a nutshell](#pcie-primer) explains them in context.

| Term | Meaning |
|----------------------|-------------------------------------------------------------------------|
| 128b/130b | Gen3 and Gen4 line code: 16 bytes sent as a 130-bit block with a 2-bit sync header |
| 8b/10b | Gen1 and Gen2 line code: each byte is sent as a 10-bit symbol, DC balanced, with K symbols for control |
| ACK, NAK | DLLPs that acknowledge the TLPs received good, or report a TLP received bad |
| ASPM | Active State Power Management: L0s and L1 entered by the link when it is idle |
| BAR | Base Address Register: a window of the host address space that maps the registers or memory of a function |
| BDF | Bus, device and function numbers of a function, written `bus:device.function` |
| Bus Master Enable | Bit of the Command register that allows a function to send memory requests, needed for DMA |
| Byte enables | First BE and Last BE fields of a request: the valid bytes of its first and last DW |
| CA | Completer Abort: completion status of a request the completer could not serve |
| Capability | Structure of the configuration space, linked from the capability pointer, that describes an optional feature: PCI Express, power management, MSI, MSI-X, PTM |
| CDR | Clock and Data Recovery: the receiver circuit that recovers the clock from the data |
| CfgRd0, CfgWr0 | Type 0 configuration read and write requests |
| COM | K28.5 comma symbol: symbol alignment and first symbol of every ordered set |
| Completer ID | BDF of the function that answers a request, carried in its completions |
| Completion | TLP that answers a non-posted request: Cpl without data, CplD with data |
| Configuration space | 4 KiB of registers per function: Type 0 or Type 1 header and capabilities |
| CRS | Configuration Request Retry Status: completion status of a function not ready yet |
| DL_Active | State of the data link layer once flow control is initialized: TLPs may flow |
| DLLP | Data Link Layer Packet: ACK, NAK, flow control and power management packets |
| DMA | Direct Memory Access: the device reads or writes host memory without the CPU |
| DW | Double word: 32 bits, the unit of TLP headers and lengths |
| EIEOS | Electrical Idle Exit Ordered Set, sent to wake a receiver at 5.0 GT/s and above |
| EIOS | Electrical Idle Ordered Set, sent before a transmitter goes quiet |
| Elastic buffer | Receive buffer that absorbs the clock difference of the two sides by dropping or adding SKP |
| Endpoint | Function at the end of a branch of the tree, such as the FPGA design |
| Enumeration | Walk of the tree by the host: bus numbers, BAR sizes and addresses, MPS |
| Flow control credits | Header and data credits, per kind of TLP, that a receiver grants a transmitter |
| Gen1 to Gen4 | Generations of PCI Express: 2.5, 5.0, 8.0 and 16.0 GT/s per lane |
| GTP, GTX, GTY | Xilinx transceivers that the soft PHY uses: GTP on Artix-7, GTX on Kintex-7, GTY on Kintex UltraScale+ |
| Hard IP | The PCI Express block of the FPGA vendor |
| InitFC, UpdateFC | DLLPs that advertise the initial flow control credits, then return them |
| K symbol | 8b/10b code that never appears in data, used as a marker: COM, STP, SDP, END, SKP |
| L0, L0s, L1, L2 | Link states: active, then power states that save more and more |
| Lane | Two differential pairs, one per direction; a link has 1 to 16 lanes |
| Lane reversal | Wiring of the lanes of a link in reverse order, undone by one of the two ports |
| LCRC | Link CRC: the 32-bit CRC the data link layer appends to each TLP |
| LFSR | Linear feedback shift register: the pseudo-random generator of the scrambler |
| Link partner | The port at the other end of the link |
| LTSSM | Link Training and Status State Machine of the physical layer |
| MemRd, MemWr | Memory read and memory write requests |
| Message | Posted TLP that signals an event instead of accessing memory, such as a PTM Request or an emulated INTx |
| MMAP | Memory-mapped access: host accesses to BAR0, or device accesses to host memory |
| MPS | Max Payload Size: largest payload of a write or a completion, set by the host |
| MRRS | Max Read Request Size: largest size of one read request |
| MSI | Message Signalled Interrupt: up to 32 vectors that share one address and one data |
| MSI-X | Extended MSI: a table in a BAR with one address and one data per vector |
| Non-posted | Request answered by completions: reads and configuration requests |
| Ordered set | Fixed pattern of the physical layer, such as TS1, TS2, SKP or EIOS; at Gen1 and Gen2 it starts with COM |
| PBA | Pending Bit Array of MSI-X: vectors raised while masked |
| PERST# | Fundamental reset signal of the slot |
| PHY | In this manual, a hard-IP wrapper or the soft PHY |
| Polarity inversion | Swap of the two wires of a pair, detected and undone by the receiver |
| Posted | Request that needs no answer: memory writes and messages |
| PTM | Precision Time Measurement: reading the time of the root complex and the link delay |
| RCB | Read Completion Boundary: 64 or 128 bytes, where a completer may split a read |
| Receiver detection | Detection of the partner by the load it presents on the transmit pairs |
| Recovery | LTSSM state that retrains a link in L0, changes its rate or leaves L1 |
| Replay buffer | Copy of the TLPs sent and not yet acknowledged, sent again after a NAK or a replay timeout |
| Requester ID | BDF of the function that sent a request, copied in its completions |
| Root complex | The part of the host that connects the CPU and memory to the PCI Express links |
| Root port | Port of the root complex that drives one link; also the FPGA design in that role |
| SC | Successful Completion: completion status of a request served |
| Scrambling | XOR of the data with an LFSR to spread the radiated energy |
| Sequence number | 12-bit number the data link layer gives each TLP |
| SKP | Skip symbol, sent in SKP ordered sets for clock compensation |
| Soft PHY | The LitePCIe PHY built on the FPGA transceivers, without the hard IP |
| SSC | Spread Spectrum Clocking: slow modulation of the reference clock |
| Switch | Device that fans one link out into several |
| Symbol | 10-bit unit of 8b/10b coding, one byte of data or a K symbol |
| Tag | Field of a non-posted request, copied in its completions to match them |
| TLP | Transaction Layer Packet: request, completion or message |
| TS1, TS2 | Training sequences: the ordered sets of link training |
| Type 0 header | First 64 bytes of the configuration space of an endpoint |
| UR | Unsupported Request: completion status of a request the completer does not handle |
| x1 to x16 | Width of a link in lanes |
