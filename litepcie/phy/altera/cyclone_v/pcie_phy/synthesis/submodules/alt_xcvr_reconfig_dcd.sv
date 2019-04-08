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


// $Header$

`timescale 1 ns / 1 ps

module alt_xcvr_reconfig_dcd #(
    parameter device_family = "Stratix IV",      
    parameter enable_dcd_power_up = 1,
    parameter number_of_reconfig_interfaces = 1
)
    (
    input  wire         reconfig_clk,        
    input  wire         reset,
    input  wire         hold,
	
	input  wire        lch_atbout,
    
    //user
    input  wire [2:0]  dcd_address,       
    input  wire [31:0] dcd_writedata,
    input  wire        dcd_write,
    input  wire        dcd_read,
    output wire [31:0] dcd_readdata,     
    output wire        dcd_waitrequest,
    output wire        dcd_done,
      
    // basic
    input  wire        dcd_irq_from_base,
    input  wire        dcd_waitrequest_from_base,
    output wire [2:0]  dcd_address_base,   
    output wire [31:0] dcd_writedata_base,  
    output wire        dcd_write_base,                  
    output wire        dcd_read_base,  
    input  wire [31:0] dcd_readdata_base, 
    output wire        arb_req,
    input  wire        arb_grant
    );

import altera_xcvr_functions::*;
localparam is_s4 = has_s4_style_hssi(device_family);
localparam is_s5 = has_s5_style_hssi(device_family);
localparam is_a5 = has_a5_style_hssi(device_family);
localparam is_c5 = has_c5_style_hssi(device_family);
 
generate
//   // if (is_s5)
//      if (0) // disable DCD pending algorithm modification 
//        begin   
//            alt_xcvr_reconfig_dcd_sv #(
//    	          .number_of_reconfig_interfaces(number_of_reconfig_interfaces)
//            ) 
//            inst_alt_xcvr_reconfig_dcd_sv (
//                .reconfig_clk              (reconfig_clk),
//                .reset                     (reset),
//                .hold                      (hold),
//
//                .dcd_address               (dcd_address),
//                .dcd_writedata             (dcd_writedata),
//                .dcd_write                 (dcd_write),
//                .dcd_read                  (dcd_read),
//                .dcd_readdata              (dcd_readdata),
//                .dcd_waitrequest           (dcd_waitrequest),
//                .dcd_irq                   (dcd_done),
//
//                .dcd_irq_from_base         (dcd_irq_from_base),
//                .dcd_waitrequest_from_base (dcd_waitrequest_from_base),
//                .dcd_address_base          (dcd_address_base),
//                .dcd_writedata_base        (dcd_writedata_base),  
//                .dcd_write_base            (dcd_write_base),
//                .dcd_read_base             (dcd_read_base),
//                .dcd_readdata_base         (dcd_readdata_base),
//                .arb_req                   (arb_req),
//                .arb_grant                 (arb_grant)
//          );
//         end
//    else
      if (is_a5 || is_c5) 
        begin   
            alt_xcvr_reconfig_dcd_av #(
    	          .number_of_reconfig_interfaces(number_of_reconfig_interfaces),
    	          .enable_dcd_power_up(enable_dcd_power_up)
            ) 
            inst_alt_xcvr_reconfig_dcd_av (
                .reconfig_clk              (reconfig_clk),
                .reset                     (reset),
                .hold                      (hold),
			        	.lch_atbout                (lch_atbout),
                .dcd_address               (dcd_address),
                .dcd_writedata             (dcd_writedata),
                .dcd_write                 (dcd_write),
                .dcd_read                  (dcd_read),
                .dcd_readdata              (dcd_readdata),
                .dcd_waitrequest           (dcd_waitrequest),
                .dcd_irq                   (dcd_done),

                .dcd_irq_from_base         (dcd_irq_from_base),
                .dcd_waitrequest_from_base (dcd_waitrequest_from_base),
                .dcd_address_base          (dcd_address_base),
                .dcd_writedata_base        (dcd_writedata_base),  
                .dcd_write_base            (dcd_write_base),
                .dcd_read_base             (dcd_read_base),
                .dcd_readdata_base         (dcd_readdata_base),
                .arb_req                   (arb_req),
                .arb_grant                 (arb_grant)
          );
         end
    else
         begin
             assign dcd_readdata = 32'b0;
             assign dcd_waitrequest = 1'b0;
             assign dcd_done = 1'b1;

             assign dcd_address_base = 3'b0;
             assign dcd_writedata_base = 32'b0;
             assign dcd_write_base = 1'b0;
             assign dcd_read_base = 1'b0;
             assign arb_req = 1'b0;
        end
		  
endgenerate 

endmodule

