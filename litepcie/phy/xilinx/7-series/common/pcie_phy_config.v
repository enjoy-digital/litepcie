//-----------------------------------------------------------------------------
//
// (c) Copyright 2010-2011 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Series-7 Integrated Block for PCI Express
// File       : xilinx_pcie_config.v
// Version    : 1.10
//--
//-- Description:  PCI Express Endpoint sample application
//--               design.
//--
//------------------------------------------------------------------------------
// changes (florent Kermarrec):
// ----------------------------
// - simplify and change filename
//------------------------------------------------------------------------------


`define PCI_EXP_EP_OUI                           24'h000A35
`define PCI_EXP_EP_DSN_1                         {{8'h1},`PCI_EXP_EP_OUI}
`define PCI_EXP_EP_DSN_2                         32'h00000001

module  pcie_phy_config #(
  parameter C_DATA_WIDTH = 64
)(
  // Flow Control
  output [2:0]                  fc_sel,

  // CFG
  output                        cfg_err_cor,
  output                        cfg_err_ur,
  output                        cfg_err_ecrc,
  output                        cfg_err_cpl_timeout,
  output                        cfg_err_cpl_unexpect,
  output                        cfg_err_cpl_abort,
  output                        cfg_err_atomic_egress_blocked,
  output                        cfg_err_internal_cor,
  output                        cfg_err_malformed,
  output                        cfg_err_mc_blocked,
  output                        cfg_err_poisoned,
  output                        cfg_err_norecovery,
  output                        cfg_err_acs,
  output                        cfg_err_internal_uncor,
  output                        cfg_pm_halt_aspm_l0s,
  output                        cfg_pm_halt_aspm_l1,
  output                        cfg_pm_force_state_en,
  output [1:0]                  cfg_pm_force_state,
  output                        cfg_err_posted,
  output                        cfg_err_locked,
  output [47:0]                 cfg_err_tlp_cpl_header,
  output                        cfg_interrupt_assert,
  output                        cfg_turnoff_ok,
  output                        cfg_trn_pending,
  output                        cfg_pm_wake,

  output                        cfg_interrupt_stat,
  output  [4:0]                 cfg_pciecap_interrupt_msgnum,

  output  [1:0]                 pl_directed_link_change,
  output  [1:0]                 pl_directed_link_width,
  output                        pl_directed_link_speed,
  output                        pl_directed_link_auton,
  output                        pl_upstream_prefer_deemph,

  output [127:0]                cfg_err_aer_headerlog,
  output   [4:0]                cfg_aer_interrupt_msgnum,

  output [31:0]                 cfg_mgmt_di,
  output  [3:0]                 cfg_mgmt_byte_en,
  output  [9:0]                 cfg_mgmt_dwaddr,
  output                        cfg_mgmt_wr_en,
  output                        cfg_mgmt_rd_en,
  output                        cfg_mgmt_wr_readonly,

  output [63:0]                 cfg_dsn

);


  //----------------------------------------------------------------------------------------------------------------//
  // PCIe Block EP Config                                                                                           //
  //----------------------------------------------------------------------------------------------------------------//

  assign fc_sel = 3'b0;

  assign cfg_err_cor = 1'b0;                       // Never report Correctable Error
  assign cfg_err_ur = 1'b0;                        // Never report UR
  assign cfg_err_ecrc = 1'b0;                      // Never report ECRC Error
  assign cfg_err_cpl_timeout = 1'b0;               // Never report Completion Timeout
  assign cfg_err_cpl_abort = 1'b0;                 // Never report Completion Abort
  assign cfg_err_cpl_unexpect = 1'b0;              // Never report unexpected completion
  assign cfg_err_posted = 1'b0;                    // Never qualify cfg_err_* inputs
  assign cfg_err_locked = 1'b0;                    // Never qualify cfg_err_ur or cfg_err_cpl_abort
  assign cfg_pm_wake = 1'b0;                       // Never direct the core to send a PM_PME Message
  assign cfg_trn_pending = 1'b0;                   // Never set the transaction pending bit in the Device Status Register

  assign cfg_err_atomic_egress_blocked = 1'b0;     // Never report Atomic TLP blocked
  assign cfg_err_internal_cor = 1'b0;              // Never report internal error occurred
  assign cfg_err_malformed = 1'b0;                 // Never report malformed error
  assign cfg_err_mc_blocked = 1'b0;                // Never report multi-cast TLP blocked
  assign cfg_err_poisoned = 1'b0;                  // Never report poisoned TLP received
  assign cfg_err_norecovery = 1'b0;                // Never qualify cfg_err_poisoned or cfg_err_cpl_timeout
  assign cfg_err_acs = 1'b0;                       // Never report an ACS violation
  assign cfg_err_internal_uncor = 1'b0;            // Never report internal uncorrectable error
  assign cfg_pm_halt_aspm_l0s = 1'b0;              // Allow entry into L0s
  assign cfg_pm_halt_aspm_l1 = 1'b0;               // Allow entry into L1
  assign cfg_pm_force_state_en  = 1'b0;            // Do not qualify cfg_pm_force_state
  assign cfg_pm_force_state  = 2'b00;              // Do not move force core into specific PM state

  assign cfg_err_aer_headerlog = 128'h0;           // Zero out the AER Header Log
  assign cfg_aer_interrupt_msgnum = 5'b00000;      // Zero out the AER Root Error Status Register

  assign cfg_interrupt_stat = 1'b0;                // Never set the Interrupt Status bit
  assign cfg_pciecap_interrupt_msgnum = 5'b00000;  // Zero out Interrupt Message Number

  assign cfg_interrupt_assert = 1'b0;              // Always drive interrupt de-assert
  assign cfg_interrupt = 1'b0;                     // Never drive interrupt by qualifying cfg_interrupt_assert

  assign pl_directed_link_change = 2'b00;          // Never initiate link change
  assign pl_directed_link_width = 2'b00;           // Zero out directed link width
  assign pl_directed_link_speed = 1'b0;            // Zero out directed link speed
  assign pl_directed_link_auton = 1'b0;            // Zero out link autonomous input
  assign pl_upstream_prefer_deemph = 1'b1;         // Zero out preferred de-emphasis of upstream port

  assign cfg_interrupt_di = 8'b0;                  // Do not set interrupt fields

  assign cfg_err_tlp_cpl_header = 48'h0;           // Zero out the header information

  assign cfg_mgmt_di = 32'h0;                      // Zero out CFG MGMT input data bus
  assign cfg_mgmt_byte_en = 4'h0;                  // Zero out CFG MGMT byte enables
  assign cfg_mgmt_dwaddr = 10'h0;                  // Zero out CFG MGMT 10-bit address port
  assign cfg_mgmt_wr_en = 1'b0;                    // Do not write CFG space
  assign cfg_mgmt_rd_en = 1'b0;                    // Do not read CFG space
  assign cfg_mgmt_wr_readonly = 1'b0;              // Never treat RO bit as RW

  assign cfg_dsn = {`PCI_EXP_EP_DSN_2, `PCI_EXP_EP_DSN_1};  // Assign the input DSN

endmodule
