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
module av_xcvr_reconfig_pll #(
    parameter device_family = "Stratix V"
)
(

input wire reconfig_clk,        
input wire reset,

////////////////////////////////
// User Avalon Slave interface
// User input MM slave
input wire [2:0]    pll_reconfig_address,             
input wire [31:0]   pll_reconfig_writedata,
input wire          pll_reconfig_write,
input wire          pll_reconfig_read,

// User output MM slave
output wire [31:0]  pll_reconfig_readdata,      
output wire         pll_reconfig_waitrequest,
output wire         pll_reconfig_done,
 
/////////////////////////////// 
// PLL reconfiguration interface
// input from PLL reconfig
output wire         pll_mif_busy,
output wire         pll_mif_err,

// output from PLL reconfig
input wire          pll_mif_go,
input wire          pll_mif_type,
input wire [3:0]    pll_mif_data,
input wire [9:0]    pll_mif_lch,

//////////////////////////////////
// Basic block interface 
// output to base_reconfig
output wire [2:0]   pll_base_address,   
output wire [31:0]  pll_base_writedata,  
output wire         pll_base_write,                         
output wire         pll_base_read,                          

// input from base reconfig
input wire [31:0]   pll_base_readdata,         
input wire          pll_base_waitrequest,         

//////////////////////////////////
// Arbiter interface
output wire arb_req,
input wire arb_grant
);


//internal wires
wire [31:0] uif_writedata;
wire [31:0] uif_readdata;
wire [2:0]  uif_addr_offset;
wire [9:0]  uif_logical_ch_addr;
wire [2:0]  uif_mode;
wire        uif_go;
wire        uif_busy;
wire        uif_error;
wire        uif_illegal_pch_error;
wire        uif_illegal_offset_error;

wire [31:0] ctrl_phreaddata;
wire [31:0] ctrl_writedata;
wire [31:0] ctrl_readdata;
wire [11:0] ctrl_addr_offset;
wire        ctrl_illegal_phy_ch;
wire        pll_base_irq;
wire        ctrl_go;            
wire        ctrl_waitrequest; 
wire [2:0]  ctrl_opcode;         
wire        ctrl_lock;
wire [9:0]  ctrl_lch;

    //MIF User interface
    alt_xreconf_uif
  #(
    .RECONFIG_USER_ADDR_WIDTH(3),
    .RECONFIG_USER_DATA_WIDTH(32),
    .RECONFIG_USER_OFFSET_WIDTH(3)
    ) inst_pll_uif (
        .reconfig_clk(reconfig_clk),
        .reset(reset),
        .user_reconfig_address(pll_reconfig_address),
        .user_reconfig_writedata(pll_reconfig_writedata),
        .user_reconfig_write(pll_reconfig_write),
        .user_reconfig_read(pll_reconfig_read),
        .user_reconfig_readdata(pll_reconfig_readdata),
        .user_reconfig_waitrequest(pll_reconfig_waitrequest),
        .user_reconfig_done(pll_reconfig_done),

        // to /from data control logic
        .uif_writedata(uif_writedata),  // to data control logic
        .uif_addr_offset(uif_addr_offset), // to data control logic/rmw block
        .uif_mode(uif_mode),  // to data control logic
        .uif_ctrl(), //unused
        .uif_logical_ch_addr(uif_logical_ch_addr), // to data
        .uif_go(uif_go), // to data control logic
        .uif_readdata(uif_readdata),// from data control logic
        .uif_phreaddata(ctrl_phreaddata),// from cif logic             
        .uif_illegal_pch_error(ctrl_illegal_phy_ch), // from data control logic
        .uif_illegal_offset_error(uif_error), // from data control logic            
        .uif_busy(uif_busy)   // from data control logic
        );


  av_xcvr_reconfig_pll_ctrl  #(
    .UIF_ADDR_WIDTH  (3),
    .UIF_DATA_WIDTH  (32),
    .CTRL_ADDR_WIDTH (12),
    .CTRL_DATA_WIDTH (32)
  ) inst_pll_ctrl (
    .clk           (reconfig_clk),
    .reset         (reset),
    
     // user interface
    .uif_go                 (uif_go),              // start user cycle  
    .uif_mode               (uif_mode),            // 0=read; 1=write;
    .uif_busy               (uif_busy),            // transfer in process
    .uif_addr               (uif_addr_offset),     // address offset
    .uif_wdata              (uif_writedata), // data in
    .uif_rdata              (uif_readdata),  // data out
    .uif_chan_err           (ctrl_illegal_phy_ch), // illegal channel
    .uif_addr_err           (uif_error),           // illegal address
    .uif_logical_ch_addr    (uif_logical_ch_addr),

    //MIF interface
    .pll_mif_busy           (pll_mif_busy), 
    .pll_mif_err            (pll_mif_err),
    .pll_mif_go             (pll_mif_go),
    .pll_mif_type           (pll_mif_type),
    .pll_mif_lch            (pll_mif_lch[9:0]),
    .pll_mif_data           (pll_mif_data[3:0]),
     
    // basic block interface
    .ctrl_go                (ctrl_go),             // start basic block cycle
    .ctrl_opcode            (ctrl_opcode),         // 0=read; 1=write;
    .ctrl_lock              (ctrl_lock),           // multicycle lock 
    .ctrl_wait              (ctrl_waitrequest),    // transfer in process
    .ctrl_addr              (ctrl_addr_offset),    // address
    .ctrl_lch               (ctrl_lch),
    .ctrl_rdata             (ctrl_readdata[31:0]), 
    .ctrl_wdata             (ctrl_writedata[31:0]) 
    );


  // Basic Block interface 
  alt_xreconf_cif  #(
    .CIF_RECONFIG_ADDR_WIDTH      (3),
    .CIF_RECONFIG_DATA_WIDTH      (32),
    .CIF_OFFSET_ADDR_WIDTH        (12),
    .CIF_MASTER_ADDR_WIDTH        (3),
    .CIF_RECONFIG_OFFSET_WIDTH    (5) //unused parameter
    )
    inst_xreconf_cif (
      .reconfig_clk                   (reconfig_clk),
      .reset                          (reset),

      // data control signals
      .ctrl_go                        (ctrl_go),  
      .ctrl_opcode                    (ctrl_opcode),
      .ctrl_lock                      (ctrl_lock), 
      .ctrl_addr_offset               (ctrl_addr_offset), 
      .ctrl_writedata                 (ctrl_writedata),
      .uif_logical_ch_addr            (ctrl_lch), 
      .ctrl_readdata                  (ctrl_readdata), 
      .ctrl_phreaddata                (ctrl_phreaddata),  
      .ctrl_illegal_phy_ch            (ctrl_illegal_phy_ch), 
      .ctrl_waitrequest               (ctrl_waitrequest), 

      // basic block ports                    
      .reconfig_address_base          (pll_base_address),
      .reconfig_writedata_base        (pll_base_writedata),
      .reconfig_write_base            (pll_base_write),
      .reconfig_read_base             (pll_base_read),
      .reconfig_readdata_base         (pll_base_readdata),
      .reconfig_irq_from_base         (pll_base_irq),
      .reconfig_waitrequest_from_base (pll_base_waitrequest),
      .arb_grant                      (arb_grant),
      .arb_req                        (arb_req)
      );


endmodule
