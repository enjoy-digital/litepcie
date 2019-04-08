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
module alt_xcvr_reconfig_mif #(
    parameter device_family = "Stratix V",
    parameter enable_mif    = 1
)
(

input wire reconfig_clk,        
input wire reset,

////////////////////////////////
// User Avalon Slave interface
// User input MM slave
input wire [2:0]    mif_reconfig_address,             
input wire [31:0]   mif_reconfig_writedata,
input wire          mif_reconfig_write,
input wire          mif_reconfig_read,

// User output MM slave
output wire [31:0]  mif_reconfig_readdata,      
output wire         mif_reconfig_waitrequest,
output wire         mif_reconfig_done,
 
/////////////////////////////// 
// PLL reconfiguration interface
// input from PLL reconfig
input wire          mif_pll_busy,
input wire          mif_pll_err,

// output from PLL reconfig
output wire         mif_pll_go,
output wire         mif_pll_type, //0=Refclk switching, 1=CGB switching
output wire [9:0]   mif_pll_lch,
output wire [3:0]   mif_pll_data,
output wire         mif_pll_pll_type, //0=CDR/CMU, 1=ATX

//////////////////////////////////
// Avalon Master streaming interface
// output to MIF entity (ROM)
output wire [31:0]  mif_stream_address,   
output wire         mif_stream_read,

// input from MIF entity (ROM)
input  wire         mif_stream_waitrequest, 
input  wire [15:0]  mif_stream_readdata,                         


//////////////////////////////////
// Basic block interface 
// output to base_reconfig
output wire [2:0]   mif_base_address,   
output wire [31:0]  mif_base_writedata,  
output wire         mif_base_write,                         
output wire         mif_base_read,                          

// input from base reconfig
input wire [31:0]   mif_base_readdata,         
input wire          mif_base_waitrequest, 
input wire          mif_base_irq,        

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
         sv_xcvr_reconfig_mif #(
            .MIF_ADDR_WIDTH(8),
            .MIF_DATA_WIDTH(16),
            .enable_mif( enable_mif )
        ) mif_strm_sv 
         (
          .reconfig_clk             ( reconfig_clk       ),
          .reset                    ( reset              ),
          
      //User I/F
          .mif_reconfig_address         ( mif_reconfig_address       ),
          .mif_reconfig_writedata       ( mif_reconfig_writedata     ),
          .mif_reconfig_write           ( mif_reconfig_write         ),
          .mif_reconfig_read            ( mif_reconfig_read          ),
          .mif_reconfig_readdata        ( mif_reconfig_readdata      ),
          .mif_reconfig_waitrequest     ( mif_reconfig_waitrequest   ),
          .mif_reconfig_done            ( mif_reconfig_done          ),
          
      //PLL Reconf I/F
          .mif_pll_busy         ( mif_pll_busy    ),
          .mif_pll_err          ( mif_pll_err     ),
          .mif_pll_go           ( mif_pll_go      ),
          .mif_pll_type         ( mif_pll_type    ),
          .mif_pll_lch          ( mif_pll_lch     ),
          .mif_pll_data         ( mif_pll_data    ),
          .mif_pll_pll_type     ( mif_pll_pll_type),

      //Stream interface
          .mif_stream_address       ( mif_stream_address    ),   
          .mif_stream_read          ( mif_stream_read       ), 
          .mif_stream_waitrequest   ( mif_stream_waitrequest ), 
          .mif_stream_readdata      ( mif_stream_readdata   ),
          
      //Basic I/F
          .mif_base_waitrequest     ( mif_base_waitrequest ),
          .mif_base_address         ( mif_base_address     ),
          .mif_base_writedata       ( mif_base_writedata   ),  
          .mif_base_write           ( mif_base_write       ),
          .mif_base_read            ( mif_base_read        ),
          .mif_base_readdata        ( mif_base_readdata    ),
          .mif_base_irq             ( mif_base_irq        ),
         
      //Arbiter interface
          .arb_req              ( arb_req     ),
          .arb_grant            ( arb_grant   )
          );

      end else if ( is_a5 || is_c5 ) begin   
         av_xcvr_reconfig_mif #(
            .MIF_ADDR_WIDTH(8),
            .MIF_DATA_WIDTH(16),
            .enable_mif( enable_mif )
        ) mif_strm_av 
         (
          .reconfig_clk             ( reconfig_clk       ),
          .reset                    ( reset              ),
          
      //User I/F
          .mif_reconfig_address         ( mif_reconfig_address       ),
          .mif_reconfig_writedata       ( mif_reconfig_writedata     ),
          .mif_reconfig_write           ( mif_reconfig_write         ),
          .mif_reconfig_read            ( mif_reconfig_read          ),
          .mif_reconfig_readdata        ( mif_reconfig_readdata      ),
          .mif_reconfig_waitrequest     ( mif_reconfig_waitrequest   ),
          .mif_reconfig_done            ( mif_reconfig_done          ),
          
      //PLL Reconf I/F
          .mif_pll_busy         ( mif_pll_busy  ),
          .mif_pll_err          ( mif_pll_err   ),
          .mif_pll_go           ( mif_pll_go    ),
          .mif_pll_type         ( mif_pll_type  ),
          .mif_pll_lch          ( mif_pll_lch   ),
          .mif_pll_data         ( mif_pll_data  ),

      //Stream interface
          .mif_stream_address       ( mif_stream_address    ),   
          .mif_stream_read          ( mif_stream_read       ), 
          .mif_stream_waitrequest   ( mif_stream_waitrequest ), 
          .mif_stream_readdata      ( mif_stream_readdata   ),
          
      //Basic I/F
          .mif_base_waitrequest     ( mif_base_waitrequest ),
          .mif_base_address         ( mif_base_address     ),
          .mif_base_writedata       ( mif_base_writedata   ),  
          .mif_base_write           ( mif_base_write       ),
          .mif_base_read            ( mif_base_read        ),
          .mif_base_readdata        ( mif_base_readdata    ),
          .mif_base_irq             ( mif_base_irq        ),
         
      //Arbiter interface
          .arb_req              ( arb_req     ),
          .arb_grant            ( arb_grant   )
          );

      end else begin
         // Default case for unsupported families, just tie off outputs to idle states.
         assign mif_reconfig_readdata       = 32'b0;
         assign mif_reconfig_waitrequest    =  1'b0;
         assign mif_reconfig_done           =  1'b1;
         
         assign mif_pll_go              = 1'b0;
         assign mif_pll_type            = 1'd0;
         assign mif_pll_data            = 4'd0;
         assign mif_pll_lch             = 8'd0;
         assign mif_pll_pll_type        = 1'd0;

         assign mif_base_address            =  3'b0;
         assign mif_base_writedata          = 32'b0;
         assign mif_base_write              =  1'b0;
         assign mif_base_read               =  1'b0;
      end
      
   endgenerate 



endmodule
