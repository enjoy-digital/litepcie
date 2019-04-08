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


// $Header: //acds/rel/18.0std/ip/alt_xcvr_reconfig/alt_xcvr_reconfig_adce/alt_xcvr_reconfig_adce.sv#1 $

`timescale 1 ps / 1 ps

module alt_xcvr_reconfig_adce 
#(
  parameter device_family = "Stratix V",      
  parameter number_of_reconfig_interfaces = 1,
  parameter logic [number_of_reconfig_interfaces-1:0] AUTO_START = { number_of_reconfig_interfaces { 1'b0 } }
)
   (
    input wire         reconfig_clk, 
    input wire         reset,
    input wire         hold,
    
    // user Avalon-MM interface
    input wire [2:0]   adce_address, 
    input wire [31:0]  adce_writedata,
    input wire         adce_write,
    input wire         adce_read,
    output wire [31:0] adce_readdata, 
    output wire        adce_waitrequest,

    output wire        adce_done, // AA What is this for? It's tied to an irq line. 
      
    // Avalon-MM interface to the basic block
    input wire         adce_b_waitrequest,
    output wire [2:0]  adce_b_address, 
    output wire [31:0] adce_b_writedata, 
    output wire        adce_b_write, 
    output wire        adce_b_read, 
    input wire [31:0]  adce_b_readdata, 
    input wire         adce_b_irq, // AA Is this really used?

    // Basic block arbitration
    output wire        adce_b_arb_req,
    input wire         adce_b_arb_grant,

    // Digital test bus
    input wire [7:0]   adce_testbus
    );

   import altera_xcvr_functions::*;
   localparam is_s5 = has_s5_style_hssi(device_family);
   
   generate
      if ( is_s5 ) begin:stratixv
         alt_xcvr_reconfig_adce_sv
         #(
           .number_of_reconfig_interfaces( number_of_reconfig_interfaces ),
           .AUTO_START                   (                    AUTO_START )
           ) 
         adce_sv 
         (
          .clk                ( reconfig_clk       ),
          .reset              ( reset              ),
          .hold               ( hold               ),
          
          .adce_address       ( adce_address       ),
          .adce_writedata     ( adce_writedata     ),
          .adce_write         ( adce_write         ),
          .adce_read          ( adce_read          ),
          .adce_readdata      ( adce_readdata      ),
          .adce_waitrequest   ( adce_waitrequest   ),
          .adce_done          ( adce_done          ),
          
          .adce_b_waitrequest ( adce_b_waitrequest ),
          .adce_b_address     ( adce_b_address     ),
          .adce_b_writedata   ( adce_b_writedata   ),  
          .adce_b_write       ( adce_b_write       ),
          .adce_b_read        ( adce_b_read        ),
          .adce_b_readdata    ( adce_b_readdata    ),
          .adce_b_irq         ( adce_b_irq         ),
          
          .adce_b_arb_req     ( adce_b_arb_req     ),
          .adce_b_arb_grant   ( adce_b_arb_grant   ),
          
          .adce_testbus       ( adce_testbus       )
          );

      end else begin
         // Default case for unsupported families, just tie off outputs to idle states.

         assign adce_readdata    = 32'b0;
         assign adce_waitrequest =  1'b0;
         assign adce_done        =  1'b1;

         assign adce_b_address   =  3'b0;
         assign adce_b_writedata = 32'b0;
         assign adce_b_write     =  1'b0;
         assign adce_b_read      =  1'b0;
         
         assign adce_b_arb_req   =  1'b0;
      end
      
   endgenerate

endmodule : alt_xcvr_reconfig_adce
