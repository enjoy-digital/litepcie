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
// This direction for bundle to separate buses inside the sv_xcvr_reconfig_basic block
//
// $Header$
//

`timescale 1 ns / 1 ns

// altera message_off 10720
// altera message_off 13024 21074

module sv_reconfig_bundle_to_xcvr #(
    parameter native_ifs = 1        // number of native reconfig interfaces
) (
  // bundled reconfig buses
  input  wire [native_ifs*altera_xcvr_functions::W_S5_RECONFIG_BUNDLE_TO_XCVR -1:0]  reconfig_to_xcvr, // all inputs from reconfig block to native xcvr reconfig ports
  output wire [native_ifs*altera_xcvr_functions::W_S5_RECONFIG_BUNDLE_FROM_XCVR-1:0] reconfig_from_xcvr, // all outputs from native xcvr reconfig ports to reconfig block
  
  // native reconfig sources
  input  wire [native_ifs*16 -1:0] native_reconfig_readdata,  // Avalon DPRIO readdata
  input  wire [native_ifs*3*8-1:0] pif_testbus,               // testbus from native reconfig, for all physical interfaces
  
  // native reconfig sinks
  output wire [native_ifs*1  -1:0] native_reconfig_clk,
  output wire [native_ifs*1  -1:0] native_reconfig_reset,
  output wire [native_ifs*16 -1:0] native_reconfig_writedata, // Avalon DPRIO writedata
  output wire [native_ifs*12 -1:0] native_reconfig_address,   // Avalon DPRIO address
  output wire [native_ifs*1  -1:0] native_reconfig_write,     // Avalon DPRIO write
  output wire [native_ifs*1  -1:0] native_reconfig_read,      // Avalon DPRIO read
  output wire [native_ifs*12 -1:0] pif_testbus_sel,           // 4 bits per physical channel
  output wire [native_ifs*1  -1:0] pif_interface_sel,
  output wire [native_ifs*1  -1:0] pif_ser_shift_load, 
  output wire                      tx_cal_busy,               
  output wire                      rx_cal_busy               
);

  localparam  w_bundle_to_xcvr  = altera_xcvr_functions::W_S5_RECONFIG_BUNDLE_TO_XCVR;
  localparam  w_bundle_from_xcvr= altera_xcvr_functions::W_S5_RECONFIG_BUNDLE_FROM_XCVR;

//  tri0  [native_ifs*1 -1:0] oc_cal_busy_bus;
  tri0  [native_ifs*1 -1:0] tx_cal_busy_bus;
  tri0  [native_ifs*1 -1:0] rx_cal_busy_bus;

//  assign  oc_cal_busy = |oc_cal_busy_bus;
  //NOTE: This bus is just a fanout from a single source in the Reconfig controller. This OR gate should optimize away.
  assign  tx_cal_busy = |tx_cal_busy_bus; 
  assign  rx_cal_busy = |rx_cal_busy_bus;

  genvar pi;
  generate
    for (pi=0; pi<native_ifs; ++pi) begin: pif
      // !!!!!!!!!!!!!!!!!!!!!!!!!!!! NOTE !!!!!!!!!!!!!!!!!!!!!!!!
      // Any changes to the bit mappings here must also be made in:
      //    - sv_reconfig_bundle_to_basic
      //    - sv_reconfig_bundle_to_ip
      //    - sv_reconfig_bundle_merger
      // native reconfig sinks
      assign native_reconfig_clk      [pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr    +:  1];
      assign native_reconfig_reset    [pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+1  +:  1];
      assign native_reconfig_writedata[pi*16 +: 16] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+2  +: 16];
      assign native_reconfig_write    [pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+18 +:  1];
      assign native_reconfig_read     [pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+19 +:  1];
      assign native_reconfig_address  [pi*12 +: 12] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+20 +: 12];
      assign pif_testbus_sel          [pi*12 +: 12] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+32 +: 12];
      assign pif_interface_sel        [pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+44 +:  1];
      assign pif_ser_shift_load       [pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+45 +:  1];
    //  assign oc_cal_busy_bus          [pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+46 +:  1];
      assign tx_cal_busy_bus          [pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+47 +:  1];
      assign rx_cal_busy_bus          [pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+48 +:  1];

      
      // native reconfig sources
      assign reconfig_from_xcvr[pi*w_bundle_from_xcvr    +: 16] = native_reconfig_readdata[pi*16 +: 16];
      assign reconfig_from_xcvr[pi*w_bundle_from_xcvr+16 +: 24] = pif_testbus             [pi*24 +: 24];
      assign reconfig_from_xcvr[pi*w_bundle_from_xcvr+40 +:  6] = {6{1'b0}};  // reserved
    end
  endgenerate
endmodule
