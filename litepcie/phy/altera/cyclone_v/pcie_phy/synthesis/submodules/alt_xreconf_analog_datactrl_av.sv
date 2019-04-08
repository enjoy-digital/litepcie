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


// Analog Data control Interface Block
// This Block talks with common uif (alt_xreconf_uif) and cif (alt_xreconf_cif) interface
//
// $Header$

`timescale 1 ns / 1 ps

module alt_xreconf_analog_datactrl_av
  #(
    parameter RECONFIG_USER_ADDR_WIDTH = 3,
    parameter RECONFIG_USER_DATA_WIDTH = 32,
    parameter RECONFIG_USER_OFFSET_WIDTH=6,
    parameter RECONFIG_BASIC_OFFSET_ADDR_WIDTH=11
    ) (
       // Inputs
    input wire clk,
    input wire reset,
       // from/to uif module
    input wire [RECONFIG_USER_OFFSET_WIDTH-1:0] uif_addr_offset,
    input wire 					uif_go,
    input wire [2:0] 				uif_mode,
    input wire [RECONFIG_USER_DATA_WIDTH-1:0] 	uif_writedata,

    output wire 				uif_busy ,
    output reg 					uif_illegal_pch_error = 1'b0,
    output reg 					uif_illegal_offset_error = 1'b0,       
    output reg [RECONFIG_USER_DATA_WIDTH-1:0] 	uif_readdata = 32'd0,


       // from/to cif module

    output wire 				ctrl_go,
    output wire [2:0] 				ctrl_opcode,
    output wire 				ctrl_lock,

    input wire 					ctrl_wait,   // connect this to waitrequest from cif block

    input wire 					ctrl_illegal_phy_ch,
    input wire [RECONFIG_USER_DATA_WIDTH-1:0] 	ctrl_readdata,	// readadata from cif block
    output wire [RECONFIG_USER_DATA_WIDTH-1:0] 				ctrl_writedata, // this is read modified data from rmw block
    output reg [RECONFIG_BASIC_OFFSET_ADDR_WIDTH-1:0] ctrl_addr_offset, // ch_offset_addr

    input wire 					       waitrequest_from_base
       );


   reg [4:0] 					       analog_offset = 5'b00000;
   reg [4:0] 					       analog_length = 5'b00000;




   import alt_xcvr_reconfig_h::*; //alt_xcvr_reconfig/alt_xcvr_reconfig/alt_xcvr_reconfig_h.sv
   import av_xcvr_h::*; //altera_xcvr_generic/av/av_xcvr_h.sv

   // Preempashsis pretap and Posttap2 Implementation

    // RX DCGAIN implemnatation is similar to SIVGX
    //////////////////////////////////////////////////
    //Port              |       DRIO CRAM bit value
    //2..0              |       10..7
    //////////////////////////////////////////////////
    //000               |       0000
    //001               |       0001
    //010               |       0011
    //011               |       0111
    //100               |       1111
    //Others            |       Assume to be 1's   


   // bit offsets and bit length for all features
   
   localparam [4:0] TX_VOD_BIT_OFFSET = 6;
   localparam [4:0] TX_VOD_BIT_LENGTH = 6;

// pretap, 1st posttap and 2nd psoattap all backened address is same ch_reg_3

   localparam [4:0] TX_PRETAP_INV_BIT_OFFSET = 1;
   localparam [4:0] TX_PRETAP_INV_LENGTH = 1;
   localparam [4:0] TX_PRETAP_BIT_OFFSET = 12;
   localparam [4:0] TX_PRETAP_LENGTH = 4;

   localparam [4:0] TX_POSTTAP1_BIT_OFFSET = 2;
   localparam [4:0] TX_POSTTAP1_LENGTH = 5;

   localparam [4:0] TX_POSTTAP_2INV_BIT_OFFSET = 0;
   localparam [4:0] TX_POSTTAP_2INV_LENGTH = 1;
   localparam [4:0] TX_POSTTAP2_BIT_OFFSET = 8;
   localparam [4:0] TX_POSTTAP2_LENGTH = 4;

   localparam [4:0] RX_DCGAIN_BIT_OFFSET = 2;
   localparam [4:0] RX_DCGAIN_LENGTH = 1;
   
   localparam [4:0] RX_EQASET_BIT_OFFSET = 14;
   localparam [4:0] RX_EQASET_LENGTH = 2;

   localparam [4:0] RX_EQVSET_BIT_OFFSET = 0;
   localparam [4:0] RX_EQVSET_LENGTH = 2;

   // For Loopback need to do 2 cosecutive writes
   // First write to CRAM rrevlb_sw (1 for postcdr and 0 for precdr)
   // Then write to cram rrx_dlpbk for pre-cdr and rcru_rlpbk for postcdr
   localparam [4:0] RCRU_RLBK_BIT_OFFSET = 14;
   localparam [4:0] RCRU_RLBK_BIT_LENGTH = 1;

   localparam [4:0] RREVLB_SW_BIT_OFFSET = 10;
   localparam [4:0] RREVLB_SW_BIT_LENGTH = 1;

   localparam [4:0] RRX_DLPBK_BIT_OFFSET = 3;
   localparam [4:0] RRX_DLPBK_BIT_LENGTH = 1;      
   

   
   
   // user modes
   localparam [2:0] UIF_MODE_RD    = 3'b000;
   localparam [2:0] UIF_MODE_WR    = 3'b001;
   localparam [2:0] UIF_MODE_PHYS  = 3'b010;





   
   reg [31:0] 					       datain_rmw = 32'h00000000;
   wire [31:0] 					       analog_rddata;
   

   integer 					       i =0;
					       
   reg 						       rxdcgain_f = 1'b0;
   reg 						       lpbk_lock = 1'b0;
   wire 					       lpbk_lock_ack;
   reg 						       lpbk_go = 1'b0;
   reg 						       lpbk_done = 1'b0;
   reg  					       lpbk_precdr_reg = 1'b0;
   reg  					       lpbk_postcdr_reg = 1'b0;
   reg 						       precdr_lpbk_f = 1'b0;
   reg 						       postcdr_lpbk_f = 1'b0;
   reg 						       eqctrl_f = 1'b0;
   reg 						       illegal_offset_f = 1'b0;
   
   
   
   
   
   
   
// This block decodes the uif_addr_offset and assigns proper bit_offset, bit_length and
// write data for read modify write (rmw) module
// It also assigns the ctrl_addr_offset for CIF function
// uif_addr_offset is from UIF block when address is offset address and write is enabled

   always @(*)
     begin
	rxdcgain_f = 1'b0;
	precdr_lpbk_f = 1'b0;
	postcdr_lpbk_f = 1'b0;
	eqctrl_f = 1'b0;

	illegal_offset_f = 1'b0;	
	case (uif_addr_offset)
	  XR_ANALOG_OFFSET_VOD:
	    begin
	       analog_offset= TX_VOD_BIT_OFFSET;
	       analog_length = TX_VOD_BIT_LENGTH;
	       ctrl_addr_offset = RECONFIG_PMA_CH0_VOD;
	       datain_rmw = uif_writedata;
	    end

	  XR_ANALOG_OFFSET_PREEMPH1T:
	    begin
	       analog_offset =  TX_POSTTAP1_BIT_OFFSET;
	       analog_length = TX_POSTTAP1_LENGTH;
	       ctrl_addr_offset = RECONFIG_PMA_CH0_POSTTAP1;
	       datain_rmw = uif_writedata;
	    end

	  XR_ANALOG_OFFSET_RXDCGAIN:
	    begin
	       analog_offset = RX_DCGAIN_BIT_OFFSET;
	       analog_length = RX_DCGAIN_LENGTH;
	       ctrl_addr_offset = RECONFIG_PMA_CH0_RX_EQDCGAIN;	       
	       rxdcgain_f = 1'b1;
	       datain_rmw [31:1] = 31'd0;
	       if (uif_writedata[0] == 1'b0)
				datain_rmw[0] = 1'b0;
	       else if (uif_writedata[0] == 1'b1)
				datain_rmw[0] = 1'b1;
	       else
				datain_rmw[0] = 1'b1;		 
	    end // case: XR_ANALOG_OFFSET_RXDCGAIN

	  // For PRECDR Loopback need to do 2 cosecutive writes
	  // First write to CRAM rrevlb_sw 0 for precdr
	  // Then write to cram rrx_dlpbk to 1"	  
	  XR_ANALOG_OFFSET_PRECDRLPBK:
	    begin
	       precdr_lpbk_f = 1'b1;
	       if (!lpbk_lock_ack & !lpbk_done)
		 begin
		    datain_rmw = {{31{1'b0}}, 1'b0};   // First write 0 to rrevlb_sw
		    analog_offset = RREVLB_SW_BIT_OFFSET;
		    analog_length = RREVLB_SW_BIT_LENGTH;
		    ctrl_addr_offset = RECONFIG_PMA_CH0_RREVLB_SW;
		 end
	       else
		 begin
		    datain_rmw = {{31{1'b0}}, uif_writedata[0]};   // Now write user entered data[0] to cram rrx_dlpbk
		    analog_offset = RRX_DLPBK_BIT_OFFSET;
		    analog_length = RRX_DLPBK_BIT_LENGTH;
		    ctrl_addr_offset = RECONFIG_PMA_CH0_RRX_DLPBK;
		 end // else: !if(!lpbk_lock_ack)
	    end // case: XR_ANALOG_OFFSET_PRECDRLPBK

	  // For POSTCDR Loopback need to do 2 cosecutive writes
	  // First write to CRAM rrevlb_sw 1 for precdr
	  // Then write to cram rcru_rlpbk to 1"	  
	  XR_ANALOG_OFFSET_POSTCDRLPBK:
	    begin
	       postcdr_lpbk_f = 1'b1;	       
	       if (!lpbk_lock_ack & !lpbk_done)
		 begin
		    datain_rmw = {{31{1'b0}}, 1'b1};   // First write 1 to rrevlb_sw
		    analog_offset = RREVLB_SW_BIT_OFFSET;
		    analog_length = RREVLB_SW_BIT_LENGTH;
		    ctrl_addr_offset = RECONFIG_PMA_CH0_RREVLB_SW;
		 end
	       else
		 begin
		    datain_rmw = {{31{1'b0}}, uif_writedata[0]};   // Now write user entered data[0] to cram rcru_rlbk
		    analog_offset = RCRU_RLBK_BIT_OFFSET;
		    analog_length = RCRU_RLBK_BIT_LENGTH;
		    ctrl_addr_offset = RECONFIG_PMA_CH0_RCRU_RLBK;
		 end // else: !if(!lpbk_lock_ack)
	    end // case: XR_ANALOG_OFFSET_PRECDRLPBK

      // For EQCTRL need to do 2 cosecutive writes (eqa & eqv registers)
	  // EQCTRL 
	  XR_ANALOG_OFFSET_RXEQCTRL:
	    begin
			//debug add code here
			eqctrl_f = 1'b1;	       
			if (!lpbk_lock_ack & !lpbk_done)
			begin
				analog_offset = RX_EQASET_BIT_OFFSET;
				analog_length = RX_EQASET_LENGTH;
				ctrl_addr_offset = RECONFIG_PMA_CH0_RX_EQA;
				
				// First write 2 bits to rrx_eqa_set
				datain_rmw [31:2] = 30'd0;
				case (uif_writedata[1:0])
					2'b00:	//L0
					begin
						datain_rmw[1:0] = 2'b00;  //eqa
					end
					2'b01:	//L1
					begin
						datain_rmw[1:0] = 2'b10;  //eqa
					end				
					2'b10:	//L2
					begin
						datain_rmw[1:0] = 2'b11;  //eqa
					end								
					default:
					begin
						datain_rmw[1:0] = 2'b11;  //eqa
					end					
				endcase // case (uif_writedata[1:0])
			end
			else
			begin
				//datain_rmw = {{30{1'b0}}, uif_writedata[1:0]};   
				analog_offset = RX_EQVSET_BIT_OFFSET;
				analog_length = RX_EQVSET_LENGTH;
				ctrl_addr_offset = RECONFIG_PMA_CH0_RX_EQV;
				
				// First write 2 bits to rrx_eqv_set
				datain_rmw [31:2] = 30'd0;
				case (uif_writedata[1:0])
					2'b00:	//L0
					begin
						datain_rmw[1:0] = 2'b00;  //eqv
					end
					2'b01:	//L1
					begin
						datain_rmw[1:0] = 2'b00;  //eqv
					end				
					2'b10:	//L2
					begin
						datain_rmw[1:0] = 2'b11;  //eqv
					end								
					default:
					begin
						datain_rmw[1:0] = 2'b11;  //eqv
					end					
				endcase // case (uif_writedata[1:0])				
			end // else: !if(!lpbk_lock_ack)			
		
	    end // case: XR_ANALOG_OFFSET_RXEQCTRL
	  
	  default:
	    begin
	       analog_offset= 5'b00000;
	       analog_length = 5'b00000;
	       ctrl_addr_offset = 11'd0;
	       datain_rmw = 32'd0;
	       illegal_offset_f = 1'b1;
	    end
	endcase // case (add_offset)
     end // always @ (*)


   

   // assert lpbk_lock only if PRECDR or POSTCDR loopback offset or eq control is enabled (which requires 2 writes to seperate registers)
   always @(posedge clk or posedge reset)
     begin
	if (reset)
	  lpbk_lock <= 1'b0;
	else
	  begin
	     if ((uif_addr_offset == XR_ANALOG_OFFSET_PRECDRLPBK || uif_addr_offset == XR_ANALOG_OFFSET_POSTCDRLPBK)  & !lpbk_lock_ack)
	       begin
			if (analog_offset == RREVLB_SW_BIT_OFFSET)
				lpbk_lock <= 1'b1;
			else
				lpbk_lock <= 1'b0;
			end
	     else if ((uif_addr_offset == XR_ANALOG_OFFSET_RXEQCTRL)  & !lpbk_lock_ack)
	       begin
			if (analog_offset == RX_EQASET_BIT_OFFSET)
				lpbk_lock <= 1'b1;
			else
				lpbk_lock <= 1'b0;
			end
	     else
	       lpbk_lock <= 1'b0;		    	       
	  end // else: !if(reset)
     end // always @ (posedge clk or posedge reset)
   


   // Following block asserts the lpbk_go signal for control state machien which controls the ctrl_lock, ctrl_go
   // and ctrl_opcode for CIF block
   
   always @(posedge clk or posedge reset)
     begin
	if (reset)
	  begin
	     lpbk_go <= 1'b0;
	  end	     
	
	else
	  begin
	     if (uif_addr_offset == XR_ANALOG_OFFSET_PRECDRLPBK || uif_addr_offset == XR_ANALOG_OFFSET_POSTCDRLPBK || uif_addr_offset == XR_ANALOG_OFFSET_RXEQCTRL)
	       begin
		  if (lpbk_lock_ack)
		    begin
		       lpbk_go <= 1'b1;
		    end		       
		  else
		    lpbk_go <= 1'b0;
	       end
	     else
	       begin
		  lpbk_go <= 1'b0;
	       end		  
	  end // always @ (posedge clk or posedge reset)
     end // always @ (posedge clk or posedge reset)

   always @(posedge clk or posedge reset)
     begin
	if (reset)
	  lpbk_done <= 1'b0;	     
	else
	  begin
	     if (uif_addr_offset == XR_ANALOG_OFFSET_PRECDRLPBK || uif_addr_offset == XR_ANALOG_OFFSET_POSTCDRLPBK  || uif_addr_offset == XR_ANALOG_OFFSET_RXEQCTRL)
	       begin
		  if (lpbk_lock_ack)
		       lpbk_done <= 1'b1;
		  else
		    if (lpbk_done & !lpbk_go & !uif_busy)
		      begin
			 lpbk_done <= 1'b0;
		      end
	       end
	     else
	       lpbk_done <= 1'b0;
	  end // else: !if(reset)
     end // always @ (posedge clk or posedge reset)


   

   // Store precdr and postcdr Loopback values in internal register for reading purpose
   
   always @(posedge clk or posedge reset)
     begin
	if (reset)
	  begin
	     lpbk_precdr_reg <= 1'b0;
	     lpbk_postcdr_reg <= 1'b0;	     
	  end
	else
	  begin
	     if (uif_addr_offset == XR_ANALOG_OFFSET_PRECDRLPBK && uif_mode == UIF_MODE_WR)
	       lpbk_precdr_reg <= uif_writedata[0];
	     else if (uif_addr_offset == XR_ANALOG_OFFSET_POSTCDRLPBK && uif_mode == UIF_MODE_WR)
	       lpbk_postcdr_reg <= uif_writedata[0];	       
	  end // else: !if(reset)
     end // always @ (posedge clk or posedge reset)

   




   // Assert uif_illegal_pch_error

   always @(posedge clk or posedge reset)
     begin
	if (reset)
	  uif_illegal_pch_error <= 1'b0;
	else
	  begin
	     if (ctrl_illegal_phy_ch)
	       uif_illegal_pch_error <= 1'b1;
	     else
	       uif_illegal_pch_error <= 1'b0;	       
	  end
     end

   // Assert uif_illegal_offset_error

   always @(posedge clk or posedge reset)
     begin
	if (reset)
	  uif_illegal_offset_error <= 1'b0;
	else
	  begin
	     if (illegal_offset_f)
	       uif_illegal_offset_error <= 1'b1;
	     else
	       uif_illegal_offset_error <= 1'b0;	       
	  end
     end



   
   // Control state machine which reads uif and lpbk go signal
   // and gives ctrl_go, ctrl_opcode and ctrl_lock to ths cif block
   // this state machine looks for the lpbk_lock signal and does 2 consecutive writes
   // at the end of first write aserted the lpbk_ack signal for 1 clock cycle
   
   alt_xreconf_analog_ctrlsm
     inst_analog_ctrlsm (
      .clk(clk),
      .reset(reset),
      .uif_go(uif_go | lpbk_go),
      .uif_mode(uif_mode),
      .uif_busy(uif_busy),
      .ctrl_go(ctrl_go),
      .ctrl_opcode(ctrl_opcode),
      .ctrl_lock(ctrl_lock),
      .ctrl_wait(ctrl_wait),
      .lpbk_lock(lpbk_lock),
      .lpbk_lock_ack(lpbk_lock_ack),
      .illegal_offset_f(illegal_offset_f),
      .illegal_ph_ch(ctrl_illegal_phy_ch)
      );


   // Read modify write module - Takes in the writedata from user and readdata from control block (cif block)
   // and does masking and shifting and returns the modified data for Basic
   
   alt_xreconf_analog_rmw_av #(
			    .DATA_WIDTH(32)
			    ) inst_rmw_sm (
					   .clk(clk),
					   .reset(reset),
					   .offset(analog_offset),
					   .length(analog_length),
					   .waitrequest_from_base(waitrequest_from_base),
					   .uif_mode(uif_mode),
					   .writedata(datain_rmw),
					   .readdata(ctrl_readdata),
					   .outdata(ctrl_writedata)
					   );


   //right shift the read data from control block (basic block) with offset to align it to lsb
   assign analog_rddata = ctrl_readdata >> analog_offset;


   // Read logic, assign uf_readdata with proper value when mode is UIF_MODE_RD
   always @(*)
     begin
	i = 0;
	if (uif_mode == UIF_MODE_RD)
	  begin
	     if (rxdcgain_f)
	      begin
			uif_readdata[31:1] = 31'd0;
			if (analog_rddata[0] == 1'b0)
				uif_readdata[0] = 1'b0;
			else if (analog_rddata[0] == 1'b1)
				uif_readdata[0] = 1'b1;
			else
				uif_readdata[0] = 1'b0;		    
	       end // if (rxdcgain_f)
	     else if (precdr_lpbk_f)
	       begin
		  uif_readdata[31:1] = 31'd0;	       
		  uif_readdata[0] = lpbk_precdr_reg;
	       end
	     else if (postcdr_lpbk_f)
	       begin
		  uif_readdata[31:1] = 31'd0;	       		  
		  uif_readdata[0] = lpbk_postcdr_reg;
	       end
	     else if (eqctrl_f)
	       begin
		  uif_readdata[31:2] = 30'd0;
			if (analog_rddata[1:0] == 2'b00) //read from eqa - 00(L0), 10(L1), 11(L2)
				uif_readdata[1:0] = 2'b00;	//EQ ctrl L0				
			else if (analog_rddata[1:0] == 2'b10)
				uif_readdata[1:0] = 2'b01;	//EQ ctrl L1				
			else if (analog_rddata[1:0] == 2'b11)
				uif_readdata[1:0] = 2'b10;	//EQ ctrl L2				
			else
				uif_readdata[1:0] = 2'b00;
	       end
	     
	     else
	       begin
		  for (i = 0; i<= 31; i=i+1)
		    begin
		       if (i >= analog_length)
			 uif_readdata[i] = 1'b0;
		       else
			 uif_readdata[i] = analog_rddata[i];
		    end
	       end // else: !if(posttap2_f)
	  end // if (uif_mode == UIF_MODE_RD)
	else
	  uif_readdata = analog_rddata;
	
     end // always @ (*)
   
  


endmodule // alt_xreconf_analog_datactrl_av




