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


// (C) 2001-2013 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// DCD implementation
//
// Perform DCD calibration by force serializer output into clock pattern (101010...)
//
// Check the voltage comparator output (from PLL AUX) and sets rser_dc_tune accordingly. Algorithm as below:
//
// 1. Sets reser_dc_tune to default value.
// 2. Check comparator logic level.
// 3. Comparator output = 1, rser_dc_tune[2:0] need to be swept from default value to 000.
// 4. Comparator output = 0, rser_dc_tune[2:0] need to be swept from default value to 111.
// 5. Once the change of comparator output logic state is detected, rser_dc_tune[2:0] should be set to the 
//    value before the logic state change happen.
// 6. If comparator never change state, sets rser_dc_tune to max/min depending on level of comparator output.

// $Header$

`timescale 1 ns / 1 ps

module alt_xcvr_reconfig_dcd_control_av (
  input  wire        clk,
  input  wire        reset,
  input  wire        hold,  // stops after current channel while asserted
  input  wire        dcd_start,
  output reg         dcd_done,
  
  // comparator output
  input  wire        lch_atbout,
    
  // Basic Block control
  output reg         ctrl_go,
  output reg         ctrl_lock,
  input  wire        ctrl_done,
  output reg  [9:0]  ctrl_chan,
  input  wire        ctrl_chan_err,
  output reg  [11:0] ctrl_addr,
  output reg  [2:0]  ctrl_opcode,
  output reg  [15:0] ctrl_wdata,
  input  wire [15:0] ctrl_rdata,
  output reg         user_busy
  );

  parameter  [6:0] NUM_OF_CHANNELS = 36;  
  parameter  enable_dcd_power_up = 1; 

  //states
  localparam [4:0] STATE_IDLE               = 5'h00;
  localparam [4:0] STATE_RD_PHY_REQ         = 5'h01;
  localparam [4:0] STATE_RD_PHY_ID          = 5'h02;
  localparam [4:0] STATE_RD_PHY_FIN         = 5'h12; // (201074)
  localparam [4:0] STATE_RD_RSER_CLKMON     = 5'h03;
  localparam [4:0] STATE_WR_RSER_CLKMON     = 5'h04; // Force ser to clock output
  localparam [4:0] STATE_RD_RTX_LST         = 5'h05;
  localparam [4:0] STATE_WR_RTX_LST         = 5'h06; // Sets ATB network to LPF mode
  localparam [4:0] STATE_RD_DEFAULT_DCTUNE  = 5'h07;
  localparam [4:0] STATE_RESET_DCTUNE       = 5'h08; // Sets rser_dc_tune to default value
  localparam [4:0] STATE_RD_CMP_OUT         = 5'h09; // Reads voltage comparator output logic level
  localparam [4:0] STATE_INC_DCTUNE         = 5'h0a;
  localparam [4:0] STATE_DEC_DCTUNE         = 5'h0b;
  localparam [4:0] STATE_RD_CMP_TOGGLE      = 5'h0c;
  localparam [4:0] STATE_SET_DCTUNE         = 5'h0d;
  localparam [4:0] STATE_RD_DCTUNE          = 5'h0e;
  localparam [4:0] STATE_RESET_RSER_CLKMON  = 5'h0f;
  localparam [4:0] STATE_RESET_RTX_LST      = 5'h10;
  localparam [4:0] STATE_DONE               = 5'h11;

  localparam MANUAL_IDLE = 2'b00;
  localparam MANUAL_ASSERT = 2'b01;
  localparam MANUAL_DEASSERT = 2'b10;
  // register addresses
  import av_xcvr_h::*;

  // register bits values
  localparam       REQUEST_DCD       = 1'b1;   // PHY RX present
  localparam       PHY_TX_ID         = 1'b1;   // PHY TX present
  localparam       RSER_CLK_MON_ON   = 1'b1;   
  localparam       RTX_LST_ON        = 4'b1100; 
  localparam       RTX_LST_OFF       = 4'b0000; 
  localparam       DC_TUNE_DEFAULT   = 3'b011;

  // Commands
  localparam [2:0] OPCODE_READ  = 3'h0; 
  localparam [2:0] OPCODE_WRITE = 3'h1;
  
  // waiting time for comparator
  localparam MAX_CNT = 11'h4E3;    
  
  reg       cmp_wait_cnt = 1'b0;
  reg       cmp_wait_cnt_reg = 1'b0;
  reg [10:0] count = {11{1'b0}};
  reg       cal_done = 1'b0;
  wire      count_lim;

  reg        [1:0]  hold_ff;
  reg        [1:0]  dcd_start_ff;
  wire              hold_sync;
  wire              dcd_start_sync;
  reg        [5:0]  state = 6'b000000;
  reg        [1:0]  manual_state = 2'b00;
  wire              phy_req;
  wire              phy_id;
  wire              ctrl_chan_tc;
  reg               ctrl_go_ff; 
  reg        [2:0]  dc_tune_value;
  reg        [2:0]  dc_tune_inc;
  reg        [2:0]  dc_tune_dec;
  reg        [2:0]  dc_tune_prev;

  reg               cmp_out_reg;
  reg               cmp_out_prev;
  reg               cmp_toggle;
  reg               dctune_max;
  reg               dctune_min;
  reg        [1:0]  rdata_done;
  
  reg               reset_rser_clkmon;
  reg               reset_rtx_lst;
  reg               dcd_start_sync_reg = 1'b0;
  

  assign dcd_done = cal_done;
  
  // synchronize signals
  always @(posedge clk)
  begin
    hold_ff <= {hold_ff[0], hold};
  end
 
  assign hold_sync = hold_ff[1];


  always @ (posedge clk)
  begin
    case(manual_state)
      MANUAL_IDLE: begin
        dcd_start_sync_reg <= 1'b0;
        if (dcd_start)
          manual_state <= MANUAL_ASSERT;
        else
          manual_state <= MANUAL_IDLE;
      end
      MANUAL_ASSERT: begin
        dcd_start_sync_reg <= 1'b1;
        if (dcd_start)
          manual_state <= MANUAL_DEASSERT;
        else
          manual_state <= MANUAL_IDLE;
      end
      MANUAL_DEASSERT: begin
        dcd_start_sync_reg <= 1'b0;
        if (dcd_start)
          manual_state <= MANUAL_DEASSERT;
        else
          manual_state <= MANUAL_IDLE; 
      end
    endcase
  end
  
  
  // State transfer
  always @(posedge clk)
  begin 
    if (reset || dcd_start_sync_reg) begin
	    state <=  STATE_IDLE;
	    ctrl_addr <= 12'h000;
	    reset_rser_clkmon <= 1'b0;
	    reset_rtx_lst <= 1'b0;
    end
    else  
      case (state)
      STATE_IDLE:                 if (!hold_sync & !cal_done & !dcd_start) begin
      							  	if (enable_dcd_power_up)
      							  	begin
                                    	state <= STATE_RD_PHY_REQ;
                    ctrl_addr <= AV_XR_ABS_ADDR_REQUEST;                  	
                  end
                                    else begin
                                    	state <= STATE_DONE;
                    ctrl_addr <= 12'h000;
                  end
                  end 
                                  else if (!hold_sync & dcd_start) begin
                                  		state <= STATE_RD_PHY_REQ;
                    cal_done <= 1'b0;
				    ctrl_addr <= AV_XR_ABS_ADDR_REQUEST;
				  end
									 
	  // check phy channel and request
      STATE_RD_PHY_REQ:          if ((ctrl_done && ctrl_chan_tc && ctrl_chan_err) ||
                                      (ctrl_done && ctrl_chan_tc && !phy_req)) begin
                                    // state <= STATE_DONE; // (201074) Reroute to new finish state
                                    state <= STATE_RD_PHY_FIN;
				    ctrl_addr <= 12'h000;
				  end
                                  else if ((ctrl_done && !ctrl_chan_tc && ctrl_chan_err) ||
                                           (ctrl_done && !ctrl_chan_tc && !phy_req)) begin
                                    state <= STATE_IDLE;
				    ctrl_addr <= 12'h000;
				  end
                                  else if (ctrl_done ) begin
                                    state <= STATE_RD_PHY_ID;    
				    ctrl_addr <= AV_XR_ABS_ADDR_ID;
				  end
			
	  // check phy channel and channel ID
      STATE_RD_PHY_ID:            if (ctrl_done && ctrl_chan_tc && !phy_id) begin
                                    // state <= STATE_DONE; // (201074) Reroute to new finish state
                                    state <= STATE_RD_PHY_FIN;
				    ctrl_addr <= 12'h000;
				  end
                                  else if (ctrl_done && !ctrl_chan_tc && !phy_id) begin
                                    state <= STATE_IDLE;
				    ctrl_addr <= 12'h000;
				  end
                                  else if (ctrl_done ) begin
                                    state <= STATE_RD_RSER_CLKMON; 
				    ctrl_addr <= RECONFIG_PMA_CH0_DCD_RSER_CLK_MON;
				  end
			
          // (201074): added this state to release the channel lock after aborting DCD	  
      STATE_RD_PHY_FIN:
				if (ctrl_done) begin
					state <= STATE_DONE;
					ctrl_addr <= 12'h000;
				end

      STATE_RD_RSER_CLKMON:       if (ctrl_done) begin
                                    ctrl_addr <= RECONFIG_PMA_CH0_DCD_RSER_CLK_MON;
                                    if(!reset_rser_clkmon)
                                      state <= STATE_WR_RSER_CLKMON; 
				    else begin
				      state <= STATE_RESET_RSER_CLKMON;
				      reset_rser_clkmon <= 1'b0;
				    end
				  end
			
      STATE_WR_RSER_CLKMON:       if(ctrl_done) begin
                                    state <= STATE_RD_RTX_LST;	
                                    ctrl_addr <= RECONFIG_PMA_CH0_DCD_RTX_LST;
				  end
				  
      STATE_RD_RTX_LST:           if(ctrl_done) begin
                                    ctrl_addr <= RECONFIG_PMA_CH0_DCD_RTX_LST;
                                    if (!reset_rtx_lst)
				      state <= STATE_WR_RTX_LST;				      
				    else begin
				      state <= STATE_RESET_RTX_LST;
				      reset_rtx_lst <= 1'b0;
				    end				    
				  end
									 
      STATE_WR_RTX_LST:           if(ctrl_done) begin
	                            state <= STATE_RD_DEFAULT_DCTUNE;
				    ctrl_addr <= RECONFIG_PMA_CH0_DCD_DC_TUNE;
				  end
				  
	  STATE_RD_DEFAULT_DCTUNE:    if(ctrl_done) begin
	                            state <= STATE_RESET_DCTUNE;
				  end
			 
      STATE_RESET_DCTUNE:         if(ctrl_done) begin
	                                // wait 10us after reset dc tune
	                                if (!(cmp_wait_cnt_reg))
									  state <= STATE_RESET_DCTUNE;
									else
	                                  state <= STATE_RD_CMP_OUT;
				                  end
									 
      STATE_RD_CMP_OUT:           begin
                                    ctrl_addr <= RECONFIG_PMA_CH0_DCD_DC_TUNE;

				    if (cmp_out_reg && (!(cmp_toggle))) 
			              state <= STATE_DEC_DCTUNE;
			            else if (!(cmp_toggle))
				      state <= STATE_INC_DCTUNE;
				    else 
				      state <= STATE_SET_DCTUNE;
				  end
										
      STATE_DEC_DCTUNE:           if(ctrl_done) begin
                                    state <= STATE_RD_CMP_TOGGLE;
				    ctrl_addr <= 12'h000;
				  end
									  
      STATE_INC_DCTUNE:           if(ctrl_done) begin
                                    state <= STATE_RD_CMP_TOGGLE;
				    ctrl_addr <= 12'h000;
				  end
									  
      STATE_RD_CMP_TOGGLE:        begin
				                    ctrl_addr <= RECONFIG_PMA_CH0_DCD_DC_TUNE;
					                if (!(cmp_wait_cnt_reg))
					                  state <= STATE_RD_CMP_TOGGLE;
				                    else if (cmp_toggle)
	        	                      state <= STATE_SET_DCTUNE;
				                    else 
				                      state <= STATE_RD_DCTUNE;
				                  end
										 
      STATE_RD_DCTUNE:        begin
                         	  if (rdata_done != 2'b11) 
	                            state <= STATE_RD_DCTUNE;
	                          else if (dctune_max || dctune_min) begin
				                if(ctrl_done)
                                  state <= STATE_SET_DCTUNE;
				                else 
				                  state <= STATE_RD_DCTUNE;
				              end
				              else 
				                if(ctrl_done) begin
	     			             state <= STATE_RD_CMP_OUT;
				                 ctrl_addr <= 12'h000;
				                end
				                else
				                  state <= STATE_RD_DCTUNE;
				              end
			
      STATE_SET_DCTUNE:           if(ctrl_done) begin
	                            state <= STATE_RD_RSER_CLKMON;
				    ctrl_addr <= RECONFIG_PMA_CH0_DCD_RSER_CLK_MON;
				    reset_rser_clkmon <= 1'b1;
				  end
									  
      STATE_RESET_RSER_CLKMON:    if(ctrl_done) begin
                                    state <= STATE_RD_RTX_LST;
				    ctrl_addr <= RECONFIG_PMA_CH0_DCD_RTX_LST;
				    reset_rtx_lst <= 1'b1;
				  end
			
      STATE_RESET_RTX_LST:        if(ctrl_done) begin
                                    state <= STATE_DONE; 
				    ctrl_addr <= 12'h000;
				  end
                                      										  
	  // done            
      STATE_DONE:                 if(ctrl_chan_tc || cal_done || !enable_dcd_power_up) begin
                                    state <= STATE_DONE;
				    cal_done <= 1'b1;
				  end
				  else
                                    state <= STATE_IDLE; 
            
      default:                    state <= STATE_IDLE; 
    endcase
  end
    
  // PHY_ID
  assign phy_req = (ctrl_rdata[AV_XR_REQUEST_DCD_OFST]   == REQUEST_DCD);

  assign phy_id  = (ctrl_rdata[AV_XR_ID_TX_CHANNEL_OFST] == PHY_TX_ID);  
	
  // channel counter
  always @(posedge clk)
  begin
    if (reset || dcd_start_sync_reg)
        ctrl_chan <= 10'h000;
    else if (((state == STATE_RD_PHY_REQ)    &&  ctrl_done && ctrl_chan_err) ||
           ((state == STATE_RD_PHY_REQ)    &&  ctrl_done && !phy_req && !ctrl_chan_tc) ||
           ((state == STATE_RD_PHY_ID)     &&  ctrl_done && !phy_id && !ctrl_chan_tc) ||
           (state == STATE_RESET_RTX_LST && ctrl_done))                 
      ctrl_chan <= ctrl_chan + 1'b1;
  end

  assign ctrl_chan_tc = ((enable_dcd_power_up || cal_done == 1'b0) && !dcd_start) ? (ctrl_chan == NUM_OF_CHANNELS -1) : (ctrl_chan == 1) ;
  // ctrl_opcode 
  always @(posedge clk)
  begin
    case (state)
      STATE_IDLE:               ctrl_opcode <= 3'h0;
      STATE_RD_PHY_REQ:         ctrl_opcode <= OPCODE_READ;
      STATE_RD_PHY_ID:          ctrl_opcode <= OPCODE_READ;
      STATE_RD_PHY_FIN:         ctrl_opcode <= OPCODE_READ; // (201074) New state to release arbiter lock properly
      STATE_RD_RSER_CLKMON:     ctrl_opcode <= OPCODE_READ;
      STATE_WR_RSER_CLKMON:     ctrl_opcode <= OPCODE_WRITE;
      STATE_RD_RTX_LST:         ctrl_opcode <= OPCODE_READ;
      STATE_WR_RTX_LST:         ctrl_opcode <= OPCODE_WRITE;
	  STATE_RD_DEFAULT_DCTUNE:  ctrl_opcode <= OPCODE_READ;
      STATE_RESET_DCTUNE:       ctrl_opcode <= OPCODE_WRITE;
      STATE_RD_CMP_OUT:         ctrl_opcode <= 3'h0;
      STATE_INC_DCTUNE:         ctrl_opcode <= OPCODE_WRITE;
      STATE_DEC_DCTUNE:         ctrl_opcode <= OPCODE_WRITE;
      STATE_RD_CMP_TOGGLE:      ctrl_opcode <= 3'h0;
      STATE_SET_DCTUNE:         ctrl_opcode <= OPCODE_WRITE;
      STATE_RD_DCTUNE:          ctrl_opcode <= OPCODE_READ;
      STATE_RESET_RSER_CLKMON:  ctrl_opcode <= OPCODE_WRITE;
      STATE_RESET_RTX_LST:      ctrl_opcode <= OPCODE_WRITE;
      STATE_DONE:               ctrl_opcode <= 3'h0;
	  default:                  ctrl_opcode <= 3'h0;
    endcase
  end       
  
  // ctrl_addr 
  // always @(posedge clk)
  // begin
    // case (state)
      // STATE_IDLE:               ctrl_addr <= 12'h000;
      // STATE_RD_PHY_REQ:         ctrl_addr <= AV_XR_ABS_ADDR_REQUEST;
      // STATE_RD_PHY_ID:          ctrl_addr <= AV_XR_ABS_ADDR_ID;
      // STATE_WR_RSER_CLKMON:     ctrl_addr <= RECONFIG_PMA_CH0_DCD_RSER_CLK_MON;
      // STATE_WR_RTX_LST:         ctrl_addr <= RECONFIG_PMA_CH0_DCD_RTX_LST;
      // STATE_RESET_DCTUNE:       ctrl_addr <= RECONFIG_PMA_CH0_DCD_DC_TUNE;
      // STATE_RD_CMP_OUT:         ctrl_addr <= 12'h000;
      // STATE_INC_DCTUNE:         ctrl_addr <= RECONFIG_PMA_CH0_DCD_DC_TUNE;
      // STATE_DEC_DCTUNE:         ctrl_addr <= RECONFIG_PMA_CH0_DCD_DC_TUNE;
      // STATE_RD_CMP_TOGGLE:      ctrl_addr <= 12'h000;
      // STATE_SET_DCTUNE:         ctrl_addr <= RECONFIG_PMA_CH0_DCD_DC_TUNE;
      // STATE_RD_DCTUNE:          ctrl_addr <= RECONFIG_PMA_CH0_DCD_DC_TUNE;
      // STATE_RESET_RSER_CLKMON:  ctrl_addr <= RECONFIG_PMA_CH0_DCD_RSER_CLK_MON;
      // STATE_RESET_RTX_LST:      ctrl_addr <= RECONFIG_PMA_CH0_DCD_RTX_LST;
      // STATE_DONE:               ctrl_addr <= 12'h000;
	  // default:                  ctrl_addr <= 12'h000;
    // endcase
  // end  

  // ctrl_wdata 
  always @(posedge clk)
  begin
    ctrl_wdata <= ctrl_rdata;
    case (state)
        STATE_WR_RSER_CLKMON :      ctrl_wdata[RSER_CLK_MON_OFST]
		                                  <= RSER_CLK_MON_ON;
                         
        STATE_WR_RTX_LST:           begin     
                           		      //ctrl_wdata               <=  dcd_rdata;
                                      ctrl_wdata[RTX_LST_3_OFST : RTX_LST_0_OFST]
                                                             <=  RTX_LST_ON;
                                    end
                                                          
        STATE_RESET_DCTUNE:         begin
                                      //ctrl_wdata               <=  dcd_rdata;
                                      ctrl_wdata[RSER_DC_TUNE_2_OFST : RSER_DC_TUNE_0_OFST] 
                                                             <=  DC_TUNE_DEFAULT;							
                                    end
                                  
        STATE_INC_DCTUNE:           ctrl_wdata[RSER_DC_TUNE_2_OFST : RSER_DC_TUNE_0_OFST] 
                                                             <= dc_tune_inc;
           
        STATE_DEC_DCTUNE:           ctrl_wdata[RSER_DC_TUNE_2_OFST : RSER_DC_TUNE_0_OFST] 
                                                        	 <= dc_tune_dec;
							   
	STATE_SET_DCTUNE:           ctrl_wdata[RSER_DC_TUNE_2_OFST : RSER_DC_TUNE_0_OFST] 
		                                                     <= dc_tune_value;
															 
        STATE_RESET_RSER_CLKMON:    ctrl_wdata[RSER_CLK_MON_OFST]
		                                  <= ~RSER_CLK_MON_ON;
										
	STATE_RESET_RTX_LST:        ctrl_wdata[RTX_LST_3_OFST : RTX_LST_0_OFST]
                                                             <=  RTX_LST_OFF;
										
        default:             ctrl_wdata                      <=  16'h0000;
    endcase
  end

  // Read rser_dc_tune value
  always @(posedge clk)
  begin
    if ((state == STATE_IDLE) || (state == STATE_RD_CMP_OUT))
	begin
	  rdata_done   <= 2'b00;
	  dctune_min   <= 1'b0;
	  dctune_max   <= 1'b0;
	end
	  
    if (state == STATE_RD_DCTUNE)
	begin
	  
	  if (dc_tune_value == 3'b000)
	  begin
	    dctune_min <= 1'b1;
		rdata_done <= 2'b11;
      end
	  else if (dc_tune_value == 3'b111)
	  begin
	    dctune_max <= 1'b1;
		rdata_done <= 2'b11;
	  end
	  else
	    if (rdata_done != 2'b11)
	      rdata_done <= rdata_done + 1'b1;
	end
	
  end 
  
  // read ATB output
  assign count_lim = (count == MAX_CNT);
  
  always @(posedge clk)
  begin
    if (reset || dcd_start_sync_reg) begin
      cmp_out_reg <= 1'b0;
      cmp_out_prev <= cmp_out_reg;
      cmp_toggle <= 1'b0;
    end
    begin
      
      cmp_out_reg <= lch_atbout;
      
      if (state == STATE_RD_CMP_TOGGLE || state == STATE_RESET_DCTUNE) begin
	    if (~count_lim) begin
	      cmp_wait_cnt <= 1'b0;
	      count <= count + 1'b1;
	    end
	    else begin
	      cmp_wait_cnt <= 1'b1;
	    end
	  
	    cmp_wait_cnt_reg <= cmp_wait_cnt;
	  end
	  
      if (state == STATE_RD_CMP_TOGGLE) begin
	    if (cmp_out_reg != cmp_out_prev)
	      cmp_toggle <= 1'b1;
        end
      end
      
	  // reset reg when in idle state
      if (state == STATE_IDLE) 
      begin
        cmp_toggle   <= 1'b0;
      end
      
	  if (state == STATE_RD_DCTUNE || state == STATE_SET_DCTUNE || state == STATE_RD_CMP_OUT) begin
	    cmp_wait_cnt <= 1'b0;
		cmp_wait_cnt_reg <= 1'b0;
		count <= 0;
	  end
	  
      if ((state != STATE_SET_DCTUNE) && (state != STATE_INC_DCTUNE) && (state != STATE_DEC_DCTUNE))
        cmp_out_prev <= cmp_out_reg;
    
  end

  // set dc_tune value
  always @(posedge clk)
  begin
    if (reset || dcd_start_sync_reg) 
      dc_tune_value              <= DC_TUNE_DEFAULT;
    else if (state == STATE_WR_RSER_CLKMON)                // Set to default value everytime the algorithm start over
      dc_tune_value              <= DC_TUNE_DEFAULT;
    else if ((state == STATE_SET_DCTUNE) && (cmp_toggle == 1'b1))            // Set to previous value before comparator toggle
      dc_tune_value              <= dc_tune_prev;
    else if (state == STATE_INC_DCTUNE)            // Set to previous value before comparator toggle
      dc_tune_value              <= dc_tune_inc;
    else if (state == STATE_DEC_DCTUNE)            // Set to previous value before comparator toggle
      dc_tune_value              <= dc_tune_dec;
    else if (state == STATE_RD_DCTUNE && ctrl_done)
      dc_tune_value              <= ctrl_rdata[RSER_DC_TUNE_2_OFST : RSER_DC_TUNE_0_OFST];
  end

  // Ready with both up sweeping and down sweeping value for rser_dc_tune
  always @(posedge clk)
  begin
    if (reset || dcd_start_sync_reg) begin
      dc_tune_prev             <= DC_TUNE_DEFAULT;
      dc_tune_inc              <= DC_TUNE_DEFAULT;
      dc_tune_dec              <= DC_TUNE_DEFAULT;
    end
    else if (state == STATE_RD_CMP_OUT)
    begin
      if (!(cmp_toggle))
        dc_tune_prev             <= dc_tune_value;
      if (!(dc_tune_value == 3'b111))
        dc_tune_inc              <= dc_tune_value + 3'b001;
      if (!(dc_tune_value == 3'b000))
        dc_tune_dec              <= dc_tune_value - 3'b001;		
    end
  end

  // ctrl_lock
  always @(posedge clk or posedge reset)
  begin
    if (reset)
	  ctrl_lock    <= 1'b0;
	else 
      ctrl_lock <= ~((state == STATE_IDLE) |
                    // (state == STATE_RD_PHY_REQ)  | // (201074) lock should be asserted in an intermediate state
                    (state == STATE_RD_PHY_FIN)  | // (201074) release arbiter lock in this finished state
                    (state == STATE_RESET_RTX_LST) |
                    (state == STATE_DONE));
  end 
  
  // ctrl_go 
  always @(posedge clk)
  begin
    if (reset || dcd_start_sync_reg)
      begin
        ctrl_go_ff <= 1'b0; 
      end
    else 
      case (state)
        STATE_IDLE:              ctrl_go_ff <=  ~hold_sync;
        // (201074) changed to always kick off an extra access to release the arbiter lock - ctrl_lock
        // STATE_RD_PHY_REQ:        ctrl_go_ff <=  ctrl_done & ~ctrl_chan_err & phy_req;
        // STATE_RD_PHY_ID:         ctrl_go_ff <=  ctrl_done &  phy_id;
        STATE_RD_PHY_REQ:        ctrl_go_ff <=  ctrl_done & (ctrl_chan_tc | phy_req);
        STATE_RD_PHY_ID:         ctrl_go_ff <=  ctrl_done & (ctrl_chan_tc | phy_id);
	STATE_RD_RSER_CLKMON:    ctrl_go_ff <=  ctrl_done;
        STATE_WR_RSER_CLKMON:    ctrl_go_ff <=  ctrl_done;
	STATE_RD_RTX_LST:        ctrl_go_ff <=  ctrl_done;
        STATE_WR_RTX_LST:        ctrl_go_ff <=  ctrl_done;
		STATE_RD_DEFAULT_DCTUNE:        ctrl_go_ff <=  ctrl_done;
        STATE_RESET_DCTUNE:      ctrl_go_ff <=  ctrl_done;
	STATE_INC_DCTUNE:        ctrl_go_ff <=  ctrl_done;
	STATE_DEC_DCTUNE:        ctrl_go_ff <=  ctrl_done;
	STATE_SET_DCTUNE:        ctrl_go_ff <=  ctrl_done;
	STATE_RD_CMP_TOGGLE:     ctrl_go_ff <=  cmp_wait_cnt;
	STATE_RD_DCTUNE:         ctrl_go_ff <=  ctrl_done & rdata_done[0] & rdata_done[1];
	STATE_RESET_RSER_CLKMON: ctrl_go_ff <=  ctrl_done;
	STATE_RESET_RTX_LST:     ctrl_go_ff <=  1'b0;
        default:              ctrl_go_ff <=  1'b0;
      endcase
  end     
  
  // delay GO to match write data 
  always @(posedge clk)
  begin
    if (reset || dcd_start_sync_reg)
      begin
        ctrl_go    <= 1'b0;
      end    
    else
      begin
        ctrl_go    <= ctrl_go_ff; 
      end 
  end

  // user busy    
  always @(posedge clk)
  begin
  if (reset & !cal_done)
    user_busy <= 1'b1;
  else
    user_busy <= !cal_done;       
  end      

endmodule 
