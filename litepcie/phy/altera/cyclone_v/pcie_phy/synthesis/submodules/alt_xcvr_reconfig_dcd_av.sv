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


// dcd calibration for Arria 5
//
// This module instantiates the user Avalon Bus interface,
// the DCD calibration module and the Basic Block interface code.

// The user interface is for user_busy only.

// $Header$

`timescale 1 ns / 1 ps

module alt_xcvr_reconfig_dcd_av #(
    parameter number_of_reconfig_interfaces = 1,
    parameter enable_dcd_power_up = 1
)
   (
    input  wire        reconfig_clk,
    input  wire        reset,
    input  wire        hold,
	
	input  wire        lch_atbout,

   // avalon MM slave
    input  wire [2:0]  dcd_address,
    input  wire [31:0] dcd_writedata,
    input  wire        dcd_write,
    input  wire        dcd_read,
    output reg  [31:0] dcd_readdata,     
    output reg         dcd_waitrequest,
    output wire        dcd_irq,

    // base_reconfig
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
   
   localparam device_family = "ArriaV";
   import alt_xcvr_reconfig_h::*; //alt_xcvr_reconfig/alt_xcvr_reconfig/alt_xcvr_reconfig_h.sv
	
   wire        dcd_done;
   wire        ctrl_go;
   wire [2:0]  ctrl_opcode;
   wire        ctrl_lock;
   wire [11:0] ctrl_addr;
   wire [31:0] ctrl_wdata;
   wire [31:0] ctrl_rdata;
   wire [9:0]  ctrl_chan;
   wire [9:0]  dcd_logical_address;
   wire [9:0]  cif_logical_ch_addr;
   wire        ctrl_chan_err;
   wire        ctrl_wait;
   wire        uif_busy;
	
   wire [31:0] uif_writedata; 
   wire [11:0] uif_addr_offset;
   wire        uif_mode;
   wire [6:0]  uif_logical_ch_addr;
   wire        uif_go;
   wire [31:0] uif_readdata;
   wire        uif_illegal_pch_error;
   wire        uif_illegal_offset_error;
	
// user interface
alt_xreconf_uif #(
   .RECONFIG_USER_ADDR_WIDTH    (3),
   .RECONFIG_USER_DATA_WIDTH    (32),
   .RECONFIG_USER_OFFSET_WIDTH  (6)
)
inst_alt_xreconf_uif  (
   .reconfig_clk              (reconfig_clk),
   .reset                     (reset),

   // User ports
   .user_reconfig_address     (dcd_address),
   .user_reconfig_writedata   (dcd_writedata),
   .user_reconfig_write       (dcd_write),
   .user_reconfig_read        (dcd_read),
   .user_reconfig_readdata    (dcd_readdata),
   .user_reconfig_waitrequest (dcd_waitrequest),
   .user_reconfig_done        (dcd_irq),

   // data control signals
   .uif_writedata             (uif_writedata),              //(uif_writedata), 
   .uif_addr_offset           (),              //(uif_addr_offset), 
   .uif_mode                  (),              //(uif_mode), 
   .uif_logical_ch_addr       (dcd_logical_address), //(uif_logical_ch_addr), 
   .uif_go                    (),              //(uif_go), 
   .uif_readdata              (32'h0000_0000), //(uif_readdata),
   .uif_phreaddata            (32'h0000_0000), //(ctrl_phread_data), 
   .uif_illegal_pch_error     (1'b0),          //(ctrl_illegal_phy_ch),
   .uif_illegal_offset_error  (1'b0),          //(uif_error),
   .uif_busy                  (uif_busy)       //(uif_busy)
);


// dcd cal
alt_xcvr_reconfig_dcd_cal_av  #(
    .NUM_OF_CHANNELS     (number_of_reconfig_interfaces),
    .enable_dcd_power_up   (enable_dcd_power_up)
) 
inst_alt_xcvr_reconfig_dcd_cal (
    .clk           (reconfig_clk),
    .reset         (reset),
    .hold          (hold),
    .dcd_start     (uif_writedata[0]),
    .dcd_done      (dcd_done),
        
    .lch_atbout    (lch_atbout),
	
     // user interface
//  .uif_go        (uif_go),                 // start user cycle  
//  .uif_mode      (uif_mode),               // transfer type
//  .uif_busy      (uif_reg_busy),           // transfer in process
//  .uif_addr      (uif_addr_offset),        // address offset
//  .uif_wdata     (uif_writedata[15:0]),    // data in
//  .uif_rdata     (uif_readdata[15:0]),     // data out
//  .uif_chan_err  (ctrl_illegal_phy_ch),    // illegal channel
//  .uif_addr_err  (uif_error),              // illegal address

    // basic block interface
    .ctrl_go       (ctrl_go),                // start basic block cycle
    .ctrl_lock     (ctrl_lock),              // multicycle lock 
    .ctrl_wait     (ctrl_wait),              // transfer in process
    .ctrl_chan     (ctrl_chan),              // channel
    .ctrl_chan_err (ctrl_chan_err),          // channel error
    .ctrl_addr     (ctrl_addr),              // address
    .ctrl_opcode   (ctrl_opcode),            // 0=read; 1=write;
    .ctrl_wdata    (ctrl_wdata[15:0]),       // data out
    .ctrl_rdata    (ctrl_rdata[15:0]),       // data in
    
    .user_busy     (uif_busy) 
);

// unused signals
//assign uif_writedata[31:16]  = 16'h0000;
assign ctrl_wdata[31:16]     = 16'h0000;
assign cif_logical_ch_addr = ((enable_dcd_power_up || dcd_done == 1'b0) && !uif_writedata[0]) ? ctrl_chan : dcd_logical_address ;

// Basic Block interface 
alt_xreconf_cif  #(
    .CIF_RECONFIG_ADDR_WIDTH      (3),
    .CIF_RECONFIG_DATA_WIDTH      (32),
    .CIF_OFFSET_ADDR_WIDTH        (12),
    .CIF_MASTER_ADDR_WIDTH        (3),
    .CIF_RECONFIG_OFFSET_WIDTH    (6)
)
inst_alt_xreconf_cif (
   .reconfig_clk                   (reconfig_clk),
   .reset                          (reset),

   // data control signals
   .ctrl_go                        (ctrl_go),  
   .ctrl_opcode                    (ctrl_opcode),
   .ctrl_lock                      (ctrl_lock), 
   .ctrl_addr_offset               (ctrl_addr), 
   .ctrl_writedata                 (ctrl_wdata),
   .uif_logical_ch_addr            (cif_logical_ch_addr), 
   .ctrl_readdata                  (ctrl_rdata), 
   .ctrl_phreaddata                (),  
   .ctrl_illegal_phy_ch            (ctrl_chan_err), 
   .ctrl_waitrequest               (ctrl_wait), 

   // basic block ports                    
   .reconfig_address_base          (dcd_address_base),
   .reconfig_writedata_base        (dcd_writedata_base),
   .reconfig_write_base            (dcd_write_base),
   .reconfig_read_base             (dcd_read_base),
   .reconfig_readdata_base         (dcd_readdata_base),
   .reconfig_irq_from_base         (dcd_irq_from_base),
   .reconfig_waitrequest_from_base (dcd_waitrequest_from_base),
   .arb_grant                      (arb_grant),
   .arb_req                        (arb_req)
);
  
endmodule
          
