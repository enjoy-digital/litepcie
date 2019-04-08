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

module sv_reconfig_bundle_to_ip #(
        parameter native_ifs        = 1   // number of native reconfig interfaces
) (
        // bundled reconfig buses
        input  wire [native_ifs*altera_xcvr_functions::W_S5_RECONFIG_BUNDLE_TO_XCVR-1:0] reconfig_to_xcvr, // all inputs from reconfig block to native xcvr reconfig ports

        // native bus expansion:
        output wire reconfig_busy,  // deprecated - kept for backwards compatibility
        output wire oc_cal_busy,
        output wire tx_cal_busy,
        output wire rx_cal_busy
);

  localparam  w_bundle_to_xcvr = altera_xcvr_functions::W_S5_RECONFIG_BUNDLE_TO_XCVR;

  tri0  [native_ifs*1 -1:0] oc_cal_busy_bus;
  tri0  [native_ifs*1 -1:0] tx_cal_busy_bus;
  tri0  [native_ifs*1 -1:0] rx_cal_busy_bus;

  assign  oc_cal_busy = |oc_cal_busy_bus;
  assign  tx_cal_busy = |tx_cal_busy_bus;
  assign  rx_cal_busy = |rx_cal_busy_bus;

  assign  reconfig_busy = oc_cal_busy;

  genvar pi;
  generate
    for (pi=0; pi<native_ifs; ++pi) begin: pif
      assign oc_cal_busy_bus[pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+46 +:  1];
      assign tx_cal_busy_bus[pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+47 +:  1];
      assign rx_cal_busy_bus[pi*1  +:  1] = reconfig_to_xcvr[pi*w_bundle_to_xcvr+48 +:  1];
    end
  endgenerate

endmodule
