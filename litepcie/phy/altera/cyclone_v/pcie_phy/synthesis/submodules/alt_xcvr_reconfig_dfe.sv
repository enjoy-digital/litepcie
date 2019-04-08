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


`timescale 1 ps / 1 ps

module alt_xcvr_reconfig_dfe #(
    parameter device_family = "Stratix IV",      
    parameter number_of_reconfig_interfaces = 1
)
    (
    input wire reconfig_clk,        
    input wire reset,
    input wire hold,

    //user
    input  wire [2:0]  dfe_address,       
    input  wire [31:0] dfe_writedata,
    input  wire        dfe_write,
    input  wire        dfe_read,
    output wire [31:0] dfe_readdata,     
    output wire        dfe_waitrequest,
    output wire        dfe_done,
      
    // basic
    input  wire        dfe_irq_from_base,
    input  wire        dfe_waitrequest_from_base,
    output wire [2:0]  dfe_address_base,   
    output wire [31:0] dfe_writedata_base,  
    output wire        dfe_write_base,                  
    output wire        dfe_read_base,  
    input  wire [31:0] dfe_readdata_base, 
    output wire        arb_req,
    input  wire        arb_grant,
    input  wire [7:0]  dfe_testbus
);

import altera_xcvr_functions::*;
localparam is_s4 = has_s4_style_hssi(device_family);
localparam is_s5 = has_s5_style_hssi(device_family);
 
generate
    if (is_s4)
         begin   
             alt_xcvr_reconfig_dfe_tgx  #(
    	         .device_family(device_family),      
                 .number_of_reconfig_interfaces(number_of_reconfig_interfaces)
               ) 
             dfe_tgx (
                .reconfig_clk              (reconfig_clk),
                .reset                     (reset),

                .dfe_address               (dfe_address),
                .dfe_writedata             (dfe_writedata),
                .dfe_write                 (dfe_write),
                .dfe_read                  (dfe_read),
                .dfe_readdata              (dfe_readdata),
                .dfe_waitrequest           (dfe_waitrequest),
                .dfe_irq                   (dfe_done),

                .dfe_irq_from_base         (dfe_irq_from_base),
                .dfe_waitrequest_from_base (dfe_waitrequest_from_base),
                .dfe_address_base          (dfe_address_base),
                .dfe_writedata_base        (dfe_writedata_base),  
                .dfe_write_base            (dfe_write_base),
                .dfe_read_base             (dfe_read_base),
                .dfe_readdata_base         (dfe_readdata_base)
            );
            assign arb_req = 1'b0;

        end 
    else if (is_s5) 
        begin   
            alt_xcvr_reconfig_dfe_sv #(
    	        .number_of_reconfig_interfaces(number_of_reconfig_interfaces)
            ) 
            dfe_sv (
                .reconfig_clk              (reconfig_clk),
                .reset                     (reset),
		.hold                      (hold),

                .dfe_address               (dfe_address),
                .dfe_writedata             (dfe_writedata),
                .dfe_write                 (dfe_write),
                .dfe_read                  (dfe_read),
                .dfe_readdata              (dfe_readdata),
                .dfe_waitrequest           (dfe_waitrequest),
                .dfe_irq                   (dfe_done),

                .dfe_irq_from_base         (dfe_irq_from_base),
                .dfe_waitrequest_from_base (dfe_waitrequest_from_base),
                .dfe_address_base          (dfe_address_base),
                .dfe_writedata_base        (dfe_writedata_base),  
                .dfe_write_base            (dfe_write_base),
                .dfe_read_base             (dfe_read_base),
                .dfe_readdata_base         (dfe_readdata_base),
                .arb_req                   (arb_req),
                .arb_grant                 (arb_grant),
                .dfe_testbus               (dfe_testbus)
          );

         end
    else
         begin
             assign dfe_readdata = 32'b0;
             assign dfe_waitrequest = 1'b0;
             assign dfe_done = 1'b1;
             assign dfe_address_base = 3'b0;
             assign dfe_writedata_base = 32'b0;
             assign dfe_write_base = 1'b0;
             assign dfe_read_base = 1'b0;
             assign arb_req = 1'b0;
        end

endgenerate 


endmodule

