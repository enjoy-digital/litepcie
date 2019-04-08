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
module av_xcvr_reconfig_mif
#(
    parameter MIF_ADDR_WIDTH  = 8,
    parameter MIF_DATA_WIDTH  = 16,
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
output wire         mif_pll_type,
output wire [9:0]   mif_pll_lch,
output wire [3:0]   mif_pll_data,

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

//internal wires
wire [31:0] uif_writedata;
wire [31:0] uif_readdata;
wire [11:0] uif_addr_offset;
wire [9:0]  uif_logical_ch_addr;
wire [2:0]  uif_mode;
wire [1:0]  uif_mif_mode;
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
wire        ctrl_waitrequest;
wire        ctrl_go;             
wire [2:0]  ctrl_opcode;         
wire        ctrl_lock;
wire [31:0] mif_base_addr;
wire        ctrl_av_go;
wire        ctrl_op_done;
wire        av_addr_burst;
wire [9:0]  ctrl_lch;
wire [10:0] av_mif_addr;
wire [15:0] av_mif_data;
wire        av_ctrl_req;
wire        av_done;
wire        av_opcode_err;
wire        ctrl_op_err;
wire        av_mif_type_err;
wire [1:0]  av_mif_type;
wire        av_mif_type_valid;
wire        mif_addr_mode;
wire        av_pll_err;
wire        uif_chan_err;
wire        uif_addr_err;


// MIF User interface
alt_xreconf_uif
  #(
    .RECONFIG_USER_ADDR_WIDTH(3),
    .RECONFIG_USER_DATA_WIDTH(32),
    .RECONFIG_USER_ENABLE_CTRL(1),
    .RECONFIG_USER_OFFSET_WIDTH(12)
 ) 
inst_xreconf_uif (
    .reconfig_clk(reconfig_clk),
    .reset(reset),
    .user_reconfig_address(mif_reconfig_address),
    .user_reconfig_writedata(mif_reconfig_writedata),
    .user_reconfig_write(mif_reconfig_write),
    .user_reconfig_read(mif_reconfig_read),
    .user_reconfig_readdata(mif_reconfig_readdata),
    .user_reconfig_waitrequest(mif_reconfig_waitrequest),
    .user_reconfig_done(mif_reconfig_done),

    // to /from data control logic
    .uif_writedata(uif_writedata),  // to data control logic
    .uif_addr_offset(uif_addr_offset), // to data control logic/rmw block
    .uif_mode(uif_mode),  // to data control logic
    .uif_ctrl(uif_mif_mode),
    .uif_logical_ch_addr(uif_logical_ch_addr), // to data
    .uif_go(uif_go), // to data control logic
    .uif_readdata(uif_readdata),// from data control logic
    .uif_phreaddata(ctrl_phreaddata),// from cif logic             
    .uif_illegal_pch_error(uif_chan_err), // from data control logic
    .uif_illegal_offset_error(uif_addr_err), // from data control logic               
    .uif_busy(uif_busy)   // from data control logic
    );


// MIF control unit
av_xcvr_reconfig_mif_ctrl  #(
    .UIF_ADDR_WIDTH  (12),
    .UIF_DATA_WIDTH  (32),
    .CTRL_ADDR_WIDTH (12),
    .CTRL_DATA_WIDTH (32),
    .MIF_ADDR_WIDTH  (32),
    .MIF_DATA_WIDTH  (16) 
)
inst_mif_ctrl (
    .clk           (reconfig_clk),
    .reset         (reset),
    
     // user interface
    .uif_go                 (uif_go),              // start user cycle  
    .uif_mode               (uif_mode),            // 0=read; 1=write;
    .uif_mif_mode           (uif_mif_mode),
    .uif_busy               (uif_busy),            // transfer in process
    .uif_addr               (uif_addr_offset),     // address offset
    .uif_wdata              (uif_writedata), // data in
    .uif_rdata              (uif_readdata),  // data out
    .ctrl_chan_err          (ctrl_illegal_phy_ch),
    .uif_chan_err           (uif_chan_err), // illegal channel
    .uif_addr_err           (uif_addr_err),           // illegal address
    .uif_logical_ch_addr    (uif_logical_ch_addr),

    // Avalon Master interface
    .mif_base_addr      (mif_base_addr),
    .ctrl_av_go         (ctrl_av_go),
    .ctrl_op_done       (ctrl_op_done),
    .ctrl_op_err        (ctrl_op_err),
    .ctrl_lch           (ctrl_lch),
    .mif_addr_mode      (mif_addr_mode),

    .av_mif_addr        (av_mif_addr),
    .av_mif_data        (av_mif_data),
    .av_ctrl_req        (av_ctrl_req),
    .av_addr_burst      (av_addr_burst),

    .av_done            (av_done),
    .av_opcode_err      (av_opcode_err),
    .av_mif_type_err    (av_mif_type_err),
    .av_mif_type        (av_mif_type),
    .av_mif_type_valid  (av_mif_type_valid),
    .av_pll_err         (av_pll_err),
     
    // basic block interface
    .ctrl_go       (ctrl_go),             // start basic block cycle
    .ctrl_opcode   (ctrl_opcode),         // 0=read; 1=write;
    .ctrl_lock     (ctrl_lock),           // multicycle lock 
    .ctrl_wait     (ctrl_waitrequest),    // transfer in process
    .ctrl_addr     (ctrl_addr_offset),    // address
    .ctrl_rdata    (ctrl_readdata[31:0]), // data in
    .ctrl_wdata    (ctrl_writedata[31:0]) // data out
    );

generate if(enable_mif ==1) begin
//Only generate the AVMM interface if User specifies MIF streaming

av_xcvr_reconfig_mif_avmm  #(
    .MIF_ADDR_LEN    (11),
    .MIF_ADDR_WIDTH  (32),
    .MIF_DATA_WIDTH  (16) 
)
inst_mif_avmm (
    .clk           (reconfig_clk),
    .reset         (reset),
    
    //PLL reconfig interface
    .pll_busy               (mif_pll_busy), 
    .pll_err                (mif_pll_err),
    .pll_go                 (mif_pll_go),
    .pll_type               (mif_pll_type),
    .pll_lch                (mif_pll_lch[9:0]),
    .pll_data               (mif_pll_data[3:0]),

    // Avalon Master streaming interface
    .stream_address     (mif_stream_address),   
    .stream_read        (mif_stream_read),
    .stream_waitrequest (mif_stream_waitrequest), 
    .stream_readdata    (mif_stream_readdata),
     
    // MIF control interface
    .mif_base_addr      (mif_base_addr),
    .ctrl_av_go         (ctrl_av_go),
    .ctrl_op_done       (ctrl_op_done),
    .ctrl_op_err        (ctrl_op_err),
    .ctrl_lch           (ctrl_lch),
    .mif_addr_mode      (mif_addr_mode),

    .av_mif_addr        (av_mif_addr),
    .av_mif_data        (av_mif_data),
    .av_ctrl_req        (av_ctrl_req),
    .av_addr_burst      (av_addr_burst),
    .av_opcode_err      (av_opcode_err),
    .av_mif_type_err    (av_mif_type_err),
    .av_mif_type        (av_mif_type),
    .av_mif_type_valid  (av_mif_type_valid),
    .av_pll_err         (av_pll_err),
    .av_done            (av_done)
    );
end
else begin

  assign mif_pll_go         = 1'd0;
  assign mif_pll_type       = 1'd0;
  assign mif_pll_lch        = 10'd0;
  assign mif_pll_data       = 4'd0;

  assign mif_stream_address = 32'd0;
  assign mif_stream_read    = 1'd0;

  assign av_mif_addr        = 11'd0;
  assign av_mif_data        = 16'd0;
  assign av_ctrl_req        = 1'd0;
  assign av_pll_err         = 1'b0;
  assign av_opcode_err      = 1'd0;
  assign av_mif_type_err    = 1'b0;
  assign av_mif_type        = 2'd0;
  assign av_mif_type_valid  = 1'b0;
  assign av_done            = 1'b1;
  assign av_addr_burst      = 1'b0;

end
endgenerate
    
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
   .uif_logical_ch_addr            (uif_logical_ch_addr), 
   .ctrl_readdata                  (ctrl_readdata), 
   .ctrl_phreaddata                (ctrl_phreaddata),  
   .ctrl_illegal_phy_ch            (ctrl_illegal_phy_ch), 
   .ctrl_waitrequest               (ctrl_waitrequest), 

   // basic block ports                    
   .reconfig_address_base          (mif_base_address),
   .reconfig_writedata_base        (mif_base_writedata),
   .reconfig_write_base            (mif_base_write),
   .reconfig_read_base             (mif_base_read),
   .reconfig_readdata_base         (mif_base_readdata),
   .reconfig_irq_from_base         (mif_base_irq),
   .reconfig_waitrequest_from_base (mif_base_waitrequest),
   .arb_grant                      (arb_grant),
   .arb_req                        (arb_req)
    );
        

endmodule
