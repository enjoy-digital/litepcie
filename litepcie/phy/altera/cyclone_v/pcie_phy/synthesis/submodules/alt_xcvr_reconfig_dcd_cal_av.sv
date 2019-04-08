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


// DCD calibration
//
// DCD calibration top module.
// 
// dcd_control.sv controls calibration 
// dcd_pll_reset.sv sequences pll resets

module alt_xcvr_reconfig_dcd_cal_av (
    input  wire        clk,
    input  wire        reset,
    input  wire        hold,
    input  wire        dcd_start,
    output wire        dcd_done,
	
	input  wire        lch_atbout,
    
    output wire        ctrl_go,
    output wire        ctrl_lock,
    input  wire        ctrl_wait,
    output wire [9:0]  ctrl_chan,
    input  wire        ctrl_chan_err,
    output wire [11:0] ctrl_addr,
    output wire [2:0]  ctrl_opcode,
    output wire [15:0] ctrl_wdata,
    input  wire [15:0] ctrl_rdata,
    
    output wire        user_busy
    );  

parameter  [6:0] NUM_OF_CHANNELS = 66;  
parameter  enable_dcd_power_up = 1;

// done state machine
localparam [1:0] STATE_DONE0  = 2'b00;
localparam [1:0] STATE_DONE1  = 2'b01;
localparam [1:0] STATE_DONE2  = 2'b10;

// declarations
wire        ctrl_done;
reg  [1:0]  state_done;
reg  [6:0]  reset_ff;
wire        reset_sync1;

// control   
alt_xcvr_reconfig_dcd_control_av #(
    .NUM_OF_CHANNELS  (NUM_OF_CHANNELS),
    .enable_dcd_power_up (enable_dcd_power_up)
)
inst_alt_xcvr_reconfig_dcd_control (
    .clk            (clk),
    .reset          (reset_sync1),
    .hold           (hold),
    .dcd_start      (dcd_start),
    .dcd_done       (dcd_done),
	
	.lch_atbout     (lch_atbout),
    
    .ctrl_go        (ctrl_go),
    .ctrl_lock      (ctrl_lock),
    .ctrl_done      (ctrl_done),
    .ctrl_chan      (ctrl_chan),
    .ctrl_chan_err  (ctrl_chan_err),
    .ctrl_addr      (ctrl_addr),
    .ctrl_opcode    (ctrl_opcode),
    .ctrl_wdata     (ctrl_wdata),
    .ctrl_rdata     (ctrl_rdata),
    .user_busy      (user_busy)
    );  

// creating CTRL_DONE from CTRL_WAIT
always @(posedge clk)
begin
  if (reset_sync1)
    state_done <= STATE_DONE0;
  else
    case (state_done)
      // wait for ctrl_go
      STATE_DONE0:    if (ctrl_go)   
                        state_done <= STATE_DONE1;
       
      // wait ctrl_to negate     
      STATE_DONE1:    if (!ctrl_wait)   
                        state_done <= STATE_DONE2;
                           
      // generate ctrl_done for 1 clock period
      STATE_DONE2:    state_done <= STATE_DONE0;       
    endcase
end

assign ctrl_done = (state_done == STATE_DONE2);

// synchronize reset
always @(posedge clk or posedge reset)
begin   
    if (reset)
       reset_ff <= 7'h00;
    else
       reset_ff <= {reset_ff[5:0], 1'b1};    
end

assign reset_sync1 = ~reset_ff[6];


endmodule
