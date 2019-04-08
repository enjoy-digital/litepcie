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

module alt_xcvr_reconfig_eyemon #(
    parameter device_family = "Stratix IV",      
    parameter number_of_reconfig_interfaces = 1,
    parameter enable_ber_counter = 0
)
    (
    input wire reconfig_clk,        
    input wire reset,
    
    //user
    input  wire [2:0]  eyemon_address,       
    input  wire [31:0] eyemon_writedata,
    input  wire        eyemon_write,
    input  wire        eyemon_read,
    output wire [31:0] eyemon_readdata,     
    output wire        eyemon_waitrequest,
    output wire        eyemon_done,
      
    // basic
    input  wire        eyemon_irq_from_base,
    input  wire        eyemon_waitrequest_from_base,
    output wire [2:0]  eyemon_address_base,   
    output wire [31:0] eyemon_writedata_base,  
    output wire        eyemon_write_base,                  
    output wire        eyemon_read_base,  
    input  wire [31:0] eyemon_readdata_base, 
    output wire        arb_req,
    input  wire        arb_grant,

    //testbus
    input  wire [7:0]  eyemon_testbus
);

import altera_xcvr_functions::*;
localparam is_s4 = has_s4_style_hssi(device_family);
localparam is_s5 = has_s5_style_hssi(device_family);
 
generate
    if (is_s4)
         begin: gen_eyemon_tgx   
             alt_xcvr_reconfig_eyemon_tgx  #(
    	         .device_family                 (device_family),      
                 .number_of_reconfig_interfaces (number_of_reconfig_interfaces)
               ) 
             eyemon_tgx (
                .reconfig_clk                 (reconfig_clk),
                .reset                        (reset),

                .eyemon_address               (eyemon_address),
                .eyemon_writedata             (eyemon_writedata),
                .eyemon_write                 (eyemon_write),
                .eyemon_read                  (eyemon_read),
                .eyemon_readdata              (eyemon_readdata),
                .eyemon_waitrequest           (eyemon_waitrequest),
                .eyemon_irq                   (eyemon_done),

                .eyemon_irq_from_base         (eyemon_irq_from_base),
                .eyemon_waitrequest_from_base (eyemon_waitrequest_from_base),
                .eyemon_address_base          (eyemon_address_base),
                .eyemon_writedata_base        (eyemon_writedata_base),  
                .eyemon_write_base            (eyemon_write_base),
                .eyemon_read_base             (eyemon_read_base),
                .eyemon_readdata_base         (eyemon_readdata_base)
            );
            assign arb_req = 1'b0;

        end 
    else if (is_s5) 
        begin: gen_eyemon_sv
            alt_xcvr_reconfig_eyemon_sv #(
    	        .number_of_reconfig_interfaces (number_of_reconfig_interfaces),
                .enable_ber_counter            (enable_ber_counter)
            ) 
            eyemon_sv (
                .reconfig_clk                 (reconfig_clk),
                .reset                        (reset),

                .eyemon_address               (eyemon_address),
                .eyemon_writedata             (eyemon_writedata),
                .eyemon_write                 (eyemon_write),
                .eyemon_read                  (eyemon_read),
                .eyemon_readdata              (eyemon_readdata),
                .eyemon_waitrequest           (eyemon_waitrequest),
                .eyemon_irq                   (eyemon_done),

                .eyemon_irq_from_base         (eyemon_irq_from_base),
                .eyemon_waitrequest_from_base (eyemon_waitrequest_from_base),
                .eyemon_address_base          (eyemon_address_base),
                .eyemon_writedata_base        (eyemon_writedata_base),  
                .eyemon_write_base            (eyemon_write_base),
                .eyemon_read_base             (eyemon_read_base),
                .eyemon_readdata_base         (eyemon_readdata_base),
                .arb_req                      (arb_req),
                .arb_grant                    (arb_grant),

                .eyemon_testbus               (eyemon_testbus)
          );

         end
    else
         begin
             assign eyemon_readdata = 32'b0;
             assign eyemon_waitrequest = 1'b0;
             assign eyemon_done = 1'b1;
             assign eyemon_address_base = 3'b0;
             assign eyemon_writedata_base = 32'b0;
             assign eyemon_write_base = 1'b0;
             assign eyemon_read_base = 1'b0;
             assign arb_req = 1'b0;
        end

endgenerate 


endmodule

