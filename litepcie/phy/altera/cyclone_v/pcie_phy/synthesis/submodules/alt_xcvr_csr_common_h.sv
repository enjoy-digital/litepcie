// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


//
// Common control & status register map for transceiver PHY IP
// Applies to Stratix V-generation basic PHY components
//
// $Header$
//
// PACKAGE DECLARATION

`timescale 1 ps / 1 ps

package alt_xcvr_csr_common_h;

	localparam alt_xcvr_csr_addr_width = 8;

	// register bitmap ---------------------------------------------------------
	// common blocks, interrupt control
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_INTERRUPT_CH_BITMASK = 1;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_INTERRUPT_ENABLE_BITMASK = 2;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_INTERRUPT_SOURCE = 3;
	
	// common blocks, loopback control
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PHY_LOOPBACK_SERIAL = 6;
	
	// common blocks, reset control
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_RESET_CONTROL_BASE = 64;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_RESET_CH_BITMASK = ADDR_RESET_CONTROL_BASE + 8'd1;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_RESET_CONTROL = ADDR_RESET_CONTROL_BASE + 8'd2;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_RESET_FINE_CONTROL = ADDR_RESET_CONTROL_BASE + 8'd4;

	// common blocks, PMA common control & status
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PMA_COMMON_BASE = 32;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PMA_PLL_IS_LOCKED = ADDR_PMA_COMMON_BASE + 8'd2;
	// common blocks, PMA channel control & status
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PMA_CHANNEL_BASE = 96;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PMA_LOOPBACK_SERIAL = ADDR_PMA_CHANNEL_BASE + 8'd1;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PMA_RX_SIGNALDETECT = ADDR_PMA_CHANNEL_BASE + 8'd3;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PMA_RX_SET_LOCKTODATA = ADDR_PMA_CHANNEL_BASE + 8'd4;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PMA_RX_SET_LOCKTOREF = ADDR_PMA_CHANNEL_BASE + 8'd5;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PMA_RX_IS_LOCKEDTODATA = ADDR_PMA_CHANNEL_BASE + 8'd6;
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PMA_RX_IS_LOCKEDTOREF = ADDR_PMA_CHANNEL_BASE + 8'd7;

	// external block for PCS control & status
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PCS_BASE = 128; // 128-255

	// First word in every PCS CSR is lane # (or lane group # as appropriate)
	localparam [alt_xcvr_csr_addr_width-1:0] ADDR_PCS_LANE_GROUP = ADDR_PCS_BASE + 8'd0;

endpackage
