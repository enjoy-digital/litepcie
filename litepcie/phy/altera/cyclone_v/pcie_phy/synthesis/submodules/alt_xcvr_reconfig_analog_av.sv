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


// Top level Analog reconfig file for SV
// data will flow like
// UIF => DATA_CTRL => CIF => RECONFIG BASIC
//
// $Header$

`timescale 1 ns / 1 ps


module alt_xcvr_reconfig_analog_av 
  #(
    parameter number_of_reconfig_interfaces = 1
    ) (
    input wire reconfig_clk,        // this will be the reconfig clk
    input wire reset,
       
       //avalon MM slave
    input wire [2:0] analog_reconfig_address,             // MM address
    input wire [31:0] analog_reconfig_writedata,
    input wire 	      analog_reconfig_write,
    input wire 	      analog_reconfig_read,
       
       //output MM slave
    output reg [31:0] analog_reconfig_readdata,      // from MM
    output reg 	      analog_reconfig_waitrequest,
       
    output wire       analog_reconfig_done,
       
       // input from base_reconfig
    input wire 	      analog_reconfig_irq_from_base,
    input wire 	      analog_reconfig_waitrequest_from_base,  
       
       // output to base_reconfig
       // Avalon MM Master
    output wire [2:0] analog_reconfig_address_base,   // 3 bit MM
    output wire [31:0] analog_reconfig_writedata_base,  
    output wire        analog_reconfig_write_base,                         // start write to GXB
    output wire        analog_reconfig_read_base,                          // start read from GXB
       
       // input from base reconfig
    input wire [31:0]  analog_reconfig_readdata_base,         // data from read command
       
    input 	       arb_grant,
    output 	       arb_req
       
       );
   
   localparam device_family = "StratixV";
   
   
   //------------------------------------------------------------------
   // address |  type   | data
   //---------|---------|----------------------------------------------
   //   0     |  wr/rd  | logical channel address 
   //   1     |  rd     | physical channel address
   //   2     |  wr/rd  | control (write, read) / status (error, busy), status[1:0] = error, busy
   //   3     |  wr/rd  | address offset
   //   4     |  wr/rd  | avalon data
   //------------------------------------------------------------------
   
   //------------------------------------------------------------------
   // addr_offset | data
   //-------------|--------------------------------------------------------
   //   0         |  VOD
   //   1         |  Preemp_0t (not supported in AV)
   //   2         |  Preemp_1t
   //   3         |  Preemp_2t (not supported in AV)
   //   4-15      |  Reserved for TX Analog reconfig
   //   16        |  Eq_ctrl
   //   17        |  Eq_dcgain
   //   18 - 31   |  Reserved for RX Analog reconfig
   //   32        |  Pre-CDR reverse serial loopback
   //   33        |  Post-CDR reverse serial loopback
   //------------------------------------------------------------------

   import alt_xcvr_reconfig_h::*; //alt_xcvr_reconfig/alt_xcvr_reconfig/alt_xcvr_reconfig_h.sv
//  import sv_xcvr_h::*; //altera_xcvr_generic/sv/sv_xcvr_h.sv   

   wire [31:0] uif_writedata;
   wire [5:0]  uif_addr_offset;
   wire [2:0]  uif_mode;
   wire [9:0]  uif_logical_ch_addr;
   wire        uif_go;
   wire [31:0] uif_readdata;
   wire        uif_illegal_pch_error;
   wire        uif_illegal_offset_error;   

   wire        ctrl_go;
   wire [2:0]  ctrl_opcode;
   wire        ctrl_lock;
   wire [10:0] ctrl_addr_offset;
   wire [31:0] ctrl_writedata;
   wire [31:0] ctrl_readdata;
   wire [31:0] ctrl_phreaddata;   
   wire        ctrl_illegal_phy_ch;
   wire        ctrl_waitrequest;
   wire        uif_busy;
   
   
// Common user interface block, this block talks with user
   alt_xreconf_uif
     #(
       .RECONFIG_USER_ADDR_WIDTH(3),
       .RECONFIG_USER_DATA_WIDTH(32),
       .RECONFIG_USER_OFFSET_WIDTH(6)
       ) inst_xreconf_uif (
			    .reconfig_clk(reconfig_clk),
			    .reset(reset),
			    .user_reconfig_address(analog_reconfig_address),
			    .user_reconfig_writedata(analog_reconfig_writedata),
			    .user_reconfig_write(analog_reconfig_write),
			    .user_reconfig_read(analog_reconfig_read),
			    .user_reconfig_readdata(analog_reconfig_readdata),
			    .user_reconfig_waitrequest(analog_reconfig_waitrequest),
			    .user_reconfig_done(analog_reconfig_done),
			    // to /from data control logic
			    .uif_writedata(uif_writedata),  // to data control logic
			    .uif_addr_offset(uif_addr_offset), // to data control logic/rmw block
			    .uif_mode(uif_mode),  // to data control logic
			    .uif_logical_ch_addr(uif_logical_ch_addr), // to data
			    .uif_go(uif_go), // to data control logic
                .uif_ctrl(), //unused
			    .uif_readdata(uif_readdata),// from data control logic
			    .uif_phreaddata(ctrl_phreaddata),// from cif logic			   
			    .uif_illegal_pch_error(uif_illegal_pch_error), // from data control logic
			    .uif_illegal_offset_error(uif_illegal_offset_error), // from data control logic			   
			    .uif_busy(uif_busy)   // from data control logic
			    );
   

// Analog Reconfig data control block, this block sits between uif and cif block
   alt_xreconf_analog_datactrl_av 
     #(
       .RECONFIG_USER_ADDR_WIDTH(3),
       .RECONFIG_USER_DATA_WIDTH(32),
       .RECONFIG_USER_OFFSET_WIDTH(6),
       .RECONFIG_BASIC_OFFSET_ADDR_WIDTH(11)
       ) inst_analog_datactrl (
			       
			       .clk(reconfig_clk),
			       .reset(reset),

			       // to/from uif block
			       .uif_addr_offset(uif_addr_offset),
			       .uif_go(uif_go),
			       .uif_mode(uif_mode),
			       .uif_writedata(uif_writedata),
			       .uif_busy(uif_busy),
			       .uif_illegal_pch_error(uif_illegal_pch_error), // from data control logic
			       .uif_illegal_offset_error(uif_illegal_offset_error), // from data control logic
			       .uif_readdata(uif_readdata),    
			       
			       // to/from control block
			       .ctrl_go(ctrl_go),
			       .ctrl_opcode(ctrl_opcode),
			       .ctrl_lock(ctrl_lock),
			       .ctrl_wait(ctrl_waitrequest),
			       .ctrl_illegal_phy_ch(ctrl_illegal_phy_ch),
			       .ctrl_readdata(ctrl_readdata),  // this is i/p data coming from cif for read modify writes
			       .ctrl_writedata(ctrl_writedata),
			       .ctrl_addr_offset(ctrl_addr_offset),
			       .waitrequest_from_base(analog_reconfig_waitrequest_from_base)
			     );
			    

//Common interface block which talks with reconfig basic B Block

   alt_xreconf_cif 
     #(
       .CIF_RECONFIG_ADDR_WIDTH (3),
       .CIF_RECONFIG_DATA_WIDTH(32),
       .CIF_OFFSET_ADDR_WIDTH(11),
       .CIF_MASTER_ADDR_WIDTH(3),
       .CIF_RECONFIG_OFFSET_WIDTH(6)
       ) inst_xreconf_cif (

			   // user Interface
			   .reconfig_clk(reconfig_clk),
			   .reset(reset),
			   .ctrl_go(ctrl_go),  // from data control 
			   .ctrl_opcode(ctrl_opcode), // from data control
			   .ctrl_lock(ctrl_lock),     // from data control
			   .ctrl_addr_offset(ctrl_addr_offset), // from data control block
			   .ctrl_writedata(ctrl_writedata),     // from data control, read modified write writedata block
			   .uif_logical_ch_addr(uif_logical_ch_addr), // from uif block
			   .ctrl_readdata(ctrl_readdata),              // readdata to data control for read modify writes
			   .ctrl_phreaddata(ctrl_phreaddata),  // this is i/p data coming from cif for read modify writes			   
			   .ctrl_illegal_phy_ch(ctrl_illegal_phy_ch), // illegal phy ch for data control logic
			   .ctrl_waitrequest(ctrl_waitrequest), // waitrequest from fsm to data control logic 
						    
			   // base reconfig interface						    
			   .reconfig_address_base(analog_reconfig_address_base),
			   .reconfig_writedata_base(analog_reconfig_writedata_base),
			   .reconfig_write_base(analog_reconfig_write_base),
			   .reconfig_read_base(analog_reconfig_read_base),
			   .reconfig_readdata_base(analog_reconfig_readdata_base),
			   .reconfig_irq_from_base(analog_reconfig_irq_from_base),
			   .reconfig_waitrequest_from_base(analog_reconfig_waitrequest_from_base),
			   .arb_grant(arb_grant),
			   .arb_req(arb_req)
			   );




endmodule
			     
			     
   

			   
			   
			   
