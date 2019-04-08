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


`timescale 1ps/1ps

import altera_xcvr_functions::*; 

module sv_reconfig_bundle_merger
  #(
      parameter reconfig_interfaces = 1 // number of reconfig interfaces
  ) (
    // Reconfig buses to/from reconfig controller
    input   wire [reconfig_interfaces*W_S5_RECONFIG_BUNDLE_TO_XCVR   -1:0]  rcfg_reconfig_to_xcvr,   // inputs from reconfig block to native xcvr
    output  wire [reconfig_interfaces*W_S5_RECONFIG_BUNDLE_FROM_XCVR -1:0]  rcfg_reconfig_from_xcvr, // outputs to reconfig block from native xcvr

    // Reconfig buses to/from native xcvr
    output  wire [reconfig_interfaces*W_S5_RECONFIG_BUNDLE_TO_XCVR   -1:0]  xcvr_reconfig_to_xcvr,   // outputs to native xcvr from reconfig block
    input   wire [reconfig_interfaces*W_S5_RECONFIG_BUNDLE_FROM_XCVR -1:0]  xcvr_reconfig_from_xcvr  // inputs from native xcvr to reconfig block
  );

// Reconfig bundle width
localparam  W_BUNDLE_TO_XCVR        = W_S5_RECONFIG_BUNDLE_TO_XCVR;
localparam  W_TOTAL_BUNDLE_TO_XCVR  = W_BUNDLE_TO_XCVR * reconfig_interfaces;

// Indices for signals that require sharing
localparam  IDX_CLK           = 0;
localparam  IDX_RST           = 1;
localparam  IDX_INTERFACESEL  = 44;
localparam  IDX_SERSHIFTLOAD  = 45;

// Pass reconfig_from_xcvr signals through without alteration
assign  rcfg_reconfig_from_xcvr = xcvr_reconfig_from_xcvr;

// We need to connect the shared signals from the first reconfig bundle to the remaining bundles.
// All other signals pass through without change
genvar pi;
generate
  for (pi=0; pi<W_TOTAL_BUNDLE_TO_XCVR; ++pi) begin: signal_assigns
    assign xcvr_reconfig_to_xcvr[pi] = 
      ((pi%W_BUNDLE_TO_XCVR)==IDX_CLK          ) ? rcfg_reconfig_to_xcvr[IDX_CLK         ]:
      ((pi%W_BUNDLE_TO_XCVR)==IDX_RST          ) ? rcfg_reconfig_to_xcvr[IDX_RST         ]:
      ((pi%W_BUNDLE_TO_XCVR)==IDX_INTERFACESEL ) ? rcfg_reconfig_to_xcvr[IDX_INTERFACESEL]:
      ((pi%W_BUNDLE_TO_XCVR)==IDX_SERSHIFTLOAD ) ? rcfg_reconfig_to_xcvr[IDX_SERSHIFTLOAD]:
      rcfg_reconfig_to_xcvr[pi];
  end
endgenerate

endmodule
