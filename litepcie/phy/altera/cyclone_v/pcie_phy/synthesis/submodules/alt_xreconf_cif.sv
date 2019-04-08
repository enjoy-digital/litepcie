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


// Common framework for many reconfig blocks
//
// $Header$

`timescale 1 ns / 1 ps

module alt_xreconf_cif
  #(
    parameter CIF_RECONFIG_ADDR_WIDTH = 3,
    parameter CIF_RECONFIG_DATA_WIDTH = 32,
    parameter CIF_RECONFIG_OFFSET_WIDTH = 5,
    parameter CIF_OFFSET_ADDR_WIDTH = 11,
    parameter CIF_MASTER_ADDR_WIDTH = 3
    )
   (

    input wire reconfig_clk,
    input wire reset,

    // to/From user inteface, data control control logic:
    input wire ctrl_go,
    input wire [2:0] ctrl_opcode,
    input wire 	     ctrl_lock,
    input [CIF_OFFSET_ADDR_WIDTH-1:0] ctrl_addr_offset,  //offset address for reconfig_basic same as ch_offset_addr
    input wire [CIF_RECONFIG_DATA_WIDTH-1:0] ctrl_writedata,  // read odified write writedata from data control block
    input wire [9:0] 			     uif_logical_ch_addr,

    output wire [CIF_RECONFIG_DATA_WIDTH-1:0] ctrl_readdata,  //readdata for user, this will go to the uif block
    output wire [CIF_RECONFIG_DATA_WIDTH-1:0] ctrl_phreaddata,  //readdata for user, this will go to the uif block    
    output wire 			      ctrl_illegal_phy_ch,//to data control
    output wire 			      ctrl_waitrequest, // to data control

 // output to base_reconfig
 // outputs from mutex to be routed to the base
 // Avalon MM Master
    output wire [CIF_RECONFIG_ADDR_WIDTH-1:0]  reconfig_address_base,   // 3 bit MM
    output wire [CIF_RECONFIG_DATA_WIDTH-1:0] reconfig_writedata_base,
    output wire 			      reconfig_write_base,
    output wire 			      reconfig_read_base,

 // input from base reconfig
    input wire [CIF_RECONFIG_DATA_WIDTH-1:0]  reconfig_readdata_base,         // data from read command
    input wire 				      reconfig_irq_from_base,
    input wire 				      reconfig_waitrequest_from_base,


    input wire 				      arb_grant,
    output wire 			      arb_req

 );


   // Following wire definitions for FSM connection
   wire 				      mutex_req;
   wire 				      mutex_grant;
   wire 				      master_read;
   wire 				      master_write;
   wire [31:0] 				      master_writedata;
   wire [CIF_MASTER_ADDR_WIDTH-1:0] 	      master_address;
   wire [31:0] 				      master_readdata;



// State machine which talks with Reconfig basic B block

   alt_xreconf_basic_acq
     #(
       .OFFSET_ADDR_WIDTH(CIF_OFFSET_ADDR_WIDTH),
       .MASTER_ADDR_WIDTH(CIF_MASTER_ADDR_WIDTH)
       ) inst_basic_acq (

			 .clk(reconfig_clk),
			 .reset(reset),
			 .ctrl_go(ctrl_go),
			 .ctrl_lock(ctrl_lock),
			 .opcode(ctrl_opcode),
			 .ctrl_writedata(ctrl_writedata),
			 .illegal_phy_ch(ctrl_illegal_phy_ch),
			 .waitrequest_to_ctrl(ctrl_waitrequest),

			 // to/from uif block
			 .logical_ch_addr(uif_logical_ch_addr),
			 .ch_offset_addr(ctrl_addr_offset),
			 .waitrequest_from_basic(reconfig_waitrequest_from_base),
			 .readdata_for_user(ctrl_readdata),
			 .ph_readdata(ctrl_phreaddata),

			 //arb_acq block interface
			 .mutex_grant(mutex_grant),
			 .mutex_req(mutex_req),
			 .master_read(master_read),
			 .master_write(master_write),
			 .master_writedata(master_writedata),
			 .master_address(master_address),
			 .master_readdata(master_readdata)

			 );

   // Arbiter acq block which talks with basic and generates request and reads grant from basic

   alt_arbiter_acq #(
		     .addr_width(CIF_RECONFIG_ADDR_WIDTH),
		     .data_width(CIF_RECONFIG_DATA_WIDTH)
		     )
   mutex_inst (
	       .clk(reconfig_clk),
	       .reset(reset),
	       // inputs to the base that should be routed through the mutex
	       .address(master_address),
	       .writedata(master_writedata),
	       .write(master_write),
	       .read(master_read),
	       // output from the mutex which is processed form of output from base
	       .waitrequest(),
	       .readdata(master_readdata),

	       // outputs from mutex to be routed to the base
	       .master_address(reconfig_address_base),
	       .master_writedata(reconfig_writedata_base),
	       .master_write(reconfig_write_base),
	       .master_read(reconfig_read_base),

	       // these ports are from the base routed to the mutex
	       .master_waitrequest(reconfig_waitrequest_from_base),
	       .master_readdata(reconfig_readdata_base),      // from MM

	       //request signal to the mutex    should be kept high as long as the mutex is being used
	       .mutex_req(mutex_req),
	       // output from mutex indicates whether you have mutex or not
	       .mutex_grant(mutex_grant),

	       .arb_req(arb_req),
	       .arb_grant(arb_grant)
	       );

endmodule
