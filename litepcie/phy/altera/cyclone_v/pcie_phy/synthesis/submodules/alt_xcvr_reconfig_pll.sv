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
module alt_xcvr_reconfig_pll #(
	parameter device_family = "Stratix V"
)
(

input wire reconfig_clk,        
input wire reset,

////////////////////////////////
// User Avalon Slave interface
// User input MM slave
input wire [2:0]  	pll_reconfig_address,             
input wire [31:0] 	pll_reconfig_writedata,
input wire  		pll_reconfig_write,
input wire  		pll_reconfig_read,

// User output MM slave
output wire [31:0] 	pll_reconfig_readdata,      
output wire 		pll_reconfig_waitrequest,
output wire 		pll_reconfig_done,
 
/////////////////////////////// 
// PLL reconfiguration interface
// outputs to MIF reconfig
output wire  		pll_mif_busy,
output wire  		pll_mif_err,

// inputs from MIF reconfig
input wire  	  	pll_mif_go,
input wire       	pll_mif_type,
input wire [3:0] 	pll_mif_data,
input wire [9:0] 	pll_mif_lch,
input wire        pll_mif_pll_type,

//////////////////////////////////
// Basic block interface 
// output to base_reconfig
output wire [2:0] 	pll_base_address,   
output wire [31:0] 	pll_base_writedata,  
output wire 		pll_base_write,                         
output wire 		pll_base_read,                          

// input from base reconfig
input wire [31:0] 	pll_base_readdata,         
input wire  		pll_base_waitrequest,         

//////////////////////////////////
// Arbiter interface
output wire arb_req,
input wire arb_grant
);


import altera_xcvr_functions::*;
localparam is_s5 = has_s5_style_hssi(device_family);
localparam is_a5 = has_a5_style_hssi(device_family);
localparam is_c5 = has_c5_style_hssi(device_family);
   
   generate
      if ( is_s5 ) begin   
         sv_xcvr_reconfig_pll
         pll_reconfig_sv 
         (
          .reconfig_clk        		( reconfig_clk       ),
          .reset              		( reset              ),
          
	  //User I/F
          .pll_reconfig_address         ( pll_reconfig_address       ),
          .pll_reconfig_writedata       ( pll_reconfig_writedata     ),
          .pll_reconfig_write           ( pll_reconfig_write         ),
          .pll_reconfig_read            ( pll_reconfig_read          ),
          .pll_reconfig_readdata        ( pll_reconfig_readdata      ),
          .pll_reconfig_waitrequest     ( pll_reconfig_waitrequest   ),
          .pll_reconfig_done            ( pll_reconfig_done          ),
		  
	  //PLL Reconf I/F
          .pll_mif_busy 		( pll_mif_busy    ),
	  	    .pll_mif_err			( pll_mif_err     ),
	  	    .pll_mif_go			  ( pll_mif_go      ),
	  	    .pll_mif_type 		( pll_mif_type    ),
          .pll_mif_data 		( pll_mif_data    ),
	  	    .pll_mif_lch			( pll_mif_lch     ),
	  	    .pll_mif_pll_type	( pll_mif_pll_type),
		  
	  //Basic I/F
          .pll_base_waitrequest		( pll_base_waitrequest ),
          .pll_base_address    		( pll_base_address     ),
          .pll_base_writedata   	( pll_base_writedata   ),  
          .pll_base_write       	( pll_base_write       ),
          .pll_base_read        	( pll_base_read        ),
          .pll_base_readdata    	( pll_base_readdata    ),
         
	  //Arbiter interface
          .arb_req      		( arb_req     ),
          .arb_grant    		( arb_grant   )
          );
          
      end else if ( is_a5 || is_c5 ) begin   
         av_xcvr_reconfig_pll
         pll_reconfig_av 
         (
          .reconfig_clk        		( reconfig_clk       ),
          .reset              		( reset              ),
          
	  //User I/F
          .pll_reconfig_address         ( pll_reconfig_address       ),
          .pll_reconfig_writedata       ( pll_reconfig_writedata     ),
          .pll_reconfig_write           ( pll_reconfig_write         ),
          .pll_reconfig_read            ( pll_reconfig_read          ),
          .pll_reconfig_readdata        ( pll_reconfig_readdata      ),
          .pll_reconfig_waitrequest     ( pll_reconfig_waitrequest   ),
          .pll_reconfig_done            ( pll_reconfig_done          ),
		  
	  //PLL Reconf I/F
          .pll_mif_busy 		( pll_mif_busy ),
	  	  .pll_mif_err			( pll_mif_err ),
	  	  .pll_mif_go			( pll_mif_go ),
	  	  .pll_mif_type 		( pll_mif_type ),
          .pll_mif_data 		( pll_mif_data ),
	  	  .pll_mif_lch			( pll_mif_lch ),
		  
	  //Basic I/F
          .pll_base_waitrequest		( pll_base_waitrequest ),
          .pll_base_address    		( pll_base_address     ),
          .pll_base_writedata   	( pll_base_writedata   ),  
          .pll_base_write       	( pll_base_write       ),
          .pll_base_read        	( pll_base_read        ),
          .pll_base_readdata    	( pll_base_readdata    ),
         
	  //Arbiter interface
          .arb_req      		( arb_req     ),
          .arb_grant    		( arb_grant   )
          );

      end else begin
         // Default case for unsupported families, just tie off outputs to idle states.
         assign pll_reconfig_readdata    	= 32'b0;
         assign pll_reconfig_waitrequest 	=  1'b0;
         assign pll_reconfig_done        	=  1'b1;
		 
         assign pll_mif_busy                = 1'b0;
         assign pll_mif_err                 = 1'b0;

         assign pll_base_address    		=  3'b0;
         assign pll_base_writedata  		= 32'b0;
         assign pll_base_write      		=  1'b0;
         assign pll_base_read       		=  1'b0;
      end
      
   endgenerate 



endmodule
