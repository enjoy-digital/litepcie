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


// analog data control
//
//
// This state machine receives commands from the user interface 
// and controls the basic block. 
//
// User writes are read modify write to the basic block.
// User read data and user read physical channel requests are a single basic read.
// 
// User to basic block address mapping in not part of this module.
// Modification of the read data for RMW cycles is also outside this module.
//
// $Header$

`timescale 1 ns / 1 ps


module alt_xreconf_analog_ctrlsm (
    input  wire        clk,
    input  wire        reset,

			 // user interface
    input  wire        uif_go,     // start user cycle  
    input  wire [2:0]  uif_mode,   // 000=read; 001=write; 010=read physical channel
    output reg         uif_busy = 1'b0,   // transfer in process

			 // basic block control interface
    output reg         ctrl_go = 1'b0,     // start basic block cycle
    output reg [2:0]   ctrl_opcode = 1'b0, // 00=read; 01=write; 10=rd phy channel; 11=testbus
    output reg         ctrl_lock = 1'b0,   // multicycle lock 
    input  wire        ctrl_wait,    // transfer in process
    input wire 	       illegal_offset_f,
    input wire 	       illegal_ph_ch,	       				  

    input wire 	       lpbk_lock,
    output reg 	       lpbk_lock_ack = 1'b0
			 );

   // state assignments
   localparam [3:0] STATE_IDLE     = 4'b0000;
   localparam [3:0] STATE_GO       = 4'b0001;
   localparam [3:0] STATE_READ     = 4'b0010;
   localparam [3:0] STATE_RMW_GO   = 4'b0011;
   localparam [3:0] STATE_RMW_RD   = 4'b0100;
   localparam [3:0] STATE_RMW_WAIT = 4'b0101;
   localparam [3:0] STATE_RMW_GO2  = 4'b0110;
   localparam [3:0] STATE_RMW_WR   = 4'b0111;
   localparam [3:0] STATE_LOCK_CHK = 4'b1000;
   localparam [3:0] STATE_GO_WRAGAIN = 4'b1001;
   

   // user modes
   localparam [2:0] UIF_MODE_RD    = 3'b000;
   localparam [2:0] UIF_MODE_WR    = 3'b001;
   localparam [2:0] UIF_MODE_PHYS  = 3'b010;

   // basic control commands
   localparam [2:0] CTRL_OP_RD     = 3'b000;
   localparam [2:0] CTRL_OP_WR     = 3'b001;
   localparam [2:0] CTRL_OP_PHYS   = 3'b010;

   // declarations
   reg [3:0] 	       next_state; 
   reg [3:0] 	       state;
   

   // next state
   always @(*)
     begin
	case (state)
	  STATE_IDLE :    if (uif_go && uif_mode == UIF_MODE_WR && !illegal_offset_f)	 
	    next_state = STATE_RMW_GO;
	  else if (uif_go && !illegal_offset_f)		
	    next_state = STATE_GO;
	  else 
	    next_state = STATE_IDLE;
	  
	  // GO to basic block for a read	
	  STATE_GO:        next_state = STATE_READ;

	  // read cycle
	  STATE_READ:     if (!ctrl_wait)
	    next_state = STATE_IDLE;
	  else
	    next_state = STATE_READ;
	  
	  // GO for read part of read-modify-write
	  STATE_RMW_GO:   next_state = STATE_RMW_RD;
	  
	  // read cycle of read-modify-write
	  STATE_RMW_RD:   
	    if (!ctrl_wait && !illegal_ph_ch)
	      next_state = STATE_RMW_WAIT;
	    else if (!ctrl_wait && illegal_ph_ch)
	      next_state = STATE_IDLE;
	    else
	      next_state = STATE_RMW_RD;
	  
	  // delay to modify data		
	  STATE_RMW_WAIT:  next_state = STATE_RMW_GO2; 
	  
	  //  GO for write cycle of read-modify-write
	  STATE_RMW_GO2 :  next_state = STATE_RMW_WR;
	  
	  // write cycle of read-modify-write		
	  STATE_RMW_WR:   if (!ctrl_wait)
//	    next_state = STATE_IDLE;
	    next_state = STATE_LOCK_CHK;
	  else
	    next_state = STATE_RMW_WR;

	  // check lock from data control logic
	  // do read modify write again if lock
	  STATE_LOCK_CHK:
	    begin
	       if (!lpbk_lock)
		 next_state = STATE_IDLE;
	       else
		 next_state = STATE_GO_WRAGAIN;
	    end
	  
	  STATE_GO_WRAGAIN:
	    begin
	       if (!uif_go)
		 next_state = STATE_GO_WRAGAIN;
	       else
		 next_state = STATE_RMW_GO;
	    end
	  
	  
	  default:        next_state = STATE_IDLE;
	endcase		 
     end

   // present state
   always @(posedge clk or posedge reset)
     begin
	if (reset)
	  state <= STATE_IDLE;
	else
	  state <= next_state;
     end

   // outputs
   always @(posedge clk or posedge reset)
     begin
	if (reset)
	  begin
	     uif_busy    <= 1'b0;
             ctrl_go     <= 1'b0;
	     ctrl_lock   <= 1'b0;
	     ctrl_opcode <= 3'b000;
	     lpbk_lock_ack <= 1'b0;
	  end
	else
	  begin
	     // busy to user  
	     uif_busy <= (next_state != STATE_IDLE); 
	     
	     // go to basic					
             ctrl_go  <= (next_state == STATE_GO) |
			 (next_state == STATE_RMW_GO) |
			 (next_state == STATE_RMW_GO2);			
	     
             // lock to basic
	     if (!lpbk_lock)
	       begin
		  ctrl_lock <= (next_state == STATE_RMW_GO) |
		  	       (next_state == STATE_RMW_RD);			  
	       end
	     else
	       begin
		  ctrl_lock <= (next_state == STATE_RMW_GO) |
		  	       (next_state == STATE_RMW_RD) |
		  	       (next_state == STATE_RMW_WAIT) |
		  	       (next_state == STATE_RMW_GO2) |
		  	       (next_state == STATE_RMW_WR) |
		  	       (next_state == STATE_LOCK_CHK) |
		  	       (next_state == STATE_GO_WRAGAIN);
	       end

	     lpbk_lock_ack <= (next_state == STATE_GO_WRAGAIN);
	     
	     // opcode to basic
	     if ((next_state == STATE_IDLE) || (next_state == STATE_GO_WRAGAIN))
               ctrl_opcode <= CTRL_OP_RD;
	     else if ((next_state == STATE_GO) && (uif_mode == UIF_MODE_PHYS))
               ctrl_opcode <= CTRL_OP_PHYS;
	     else if (next_state == STATE_RMW_GO2)	 
	       ctrl_opcode <= CTRL_OP_WR;
             
	  end
     end

endmodule