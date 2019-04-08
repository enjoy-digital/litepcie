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
// Transceiver native reconfig adapter for Stratix V & derivatives.
// Translates from native reconfig wire bundles to separate Av reconfig and testbus signals
//
// This direction for bundle to separate buses inside the sv_xcvr_protocol_native block
//
// $Header$
//

`timescale 1 ns / 1 ns

module sv_reconfig_bundle_to_basic #(
    parameter native_ifs = 1        // number of native reconfig interfaces
) (
  // bundled reconfig buses
  output wire [native_ifs*altera_xcvr_functions::W_S5_RECONFIG_BUNDLE_TO_XCVR  -1:0] reconfig_to_xcvr,  // all inputs from reconfig block to native xcvr reconfig ports
  input  wire [native_ifs*altera_xcvr_functions::W_S5_RECONFIG_BUNDLE_FROM_XCVR-1:0] reconfig_from_xcvr,// all input s from native xcvr reconfig ports to reconfig block
  
  // native reconfig sources
  output wire [native_ifs*16 -1:0] native_reconfig_readdata,  // Avalon DPRIO readdata
  output wire [native_ifs*3*8-1:0] pif_testbus,               // testbus from native reconfig, for all physical interfaces
  
  // native reconfig sinks
  input  wire [native_ifs*1  -1:0] native_reconfig_clk,
  input  wire [native_ifs*1  -1:0] native_reconfig_reset,
  input  wire [native_ifs*16 -1:0] native_reconfig_writedata, // Avalon DPRIO writedata
  input  wire [native_ifs*12 -1:0] native_reconfig_address,   // Avalon DPRIO address
  input  wire [native_ifs*1  -1:0] native_reconfig_write,     // Avalon DPRIO write
  input  wire [native_ifs*1  -1:0] native_reconfig_read,      // Avalon DPRIO read
  input  wire [native_ifs*12 -1:0] pif_testbus_sel,           // 4 bits per physical channel
  input  wire [native_ifs*1  -1:0] pif_interface_sel,
  input  wire [native_ifs*1  -1:0] pif_ser_shift_load,
  input  wire                      oc_cal_busy,
  input  wire                      tx_cal_busy,
  input  wire                      rx_cal_busy
);

  localparam  w_bundle_to_xcvr  = altera_xcvr_functions::W_S5_RECONFIG_BUNDLE_TO_XCVR;
  localparam  w_bundle_from_xcvr= altera_xcvr_functions::W_S5_RECONFIG_BUNDLE_FROM_XCVR;

  wire  [native_ifs*1 -1:0] oc_cal_busy_bus;
  wire  [native_ifs*1 -1:0] tx_cal_busy_bus;
  wire  [native_ifs*1 -1:0] rx_cal_busy_bus;

  assign  oc_cal_busy_bus = {native_ifs{oc_cal_busy}};
  assign  tx_cal_busy_bus = {native_ifs{tx_cal_busy}};
  assign  rx_cal_busy_bus = {native_ifs{rx_cal_busy}};

  genvar pi;
  generate
    for (pi=0; pi<native_ifs; ++pi) begin: pif
      // !!!!!!!!!!!!!!!!!!!!!!!!!!!! NOTE !!!!!!!!!!!!!!!!!!!!!!!!
      // Any changes to the bit mappings here must also be made in:
      //    - sv_reconfig_bundle_to_xcvr
      //    - sv_reconfig_bundle_to_ip
      //    - sv_reconfig_bundle_merger
      // native reconfig sinks
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr    +:  1] = native_reconfig_clk       [pi*1  +:  1];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+1  +:  1] = native_reconfig_reset     [pi*1  +:  1];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+2  +: 16] = native_reconfig_writedata [pi*16 +: 16];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+18 +:  1] = native_reconfig_write     [pi*1  +:  1];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+19 +:  1] = native_reconfig_read      [pi*1  +:  1];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+20 +: 12] = native_reconfig_address   [pi*12 +: 12];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+32 +: 12] = pif_testbus_sel           [pi*12 +: 12];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+44 +:  1] = pif_interface_sel         [pi*1  +:  1];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+45 +:  1] = pif_ser_shift_load        [pi*1  +:  1];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+46 +:  1] = oc_cal_busy_bus           [pi*1  +:  1];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+47 +:  1] = tx_cal_busy_bus           [pi*1  +:  1];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+48 +:  1] = rx_cal_busy_bus           [pi*1  +:  1];
      assign reconfig_to_xcvr[pi*w_bundle_to_xcvr+49 +: 21] = {21{1'b0}}; // reserved
      
      // native reconfig sources
      assign native_reconfig_readdata[pi*16 +: 16] = reconfig_from_xcvr[pi*w_bundle_from_xcvr    +: 16];
      assign pif_testbus             [pi*24 +: 24] = reconfig_from_xcvr[pi*w_bundle_from_xcvr+16 +: 24];
    end
  endgenerate
endmodule
