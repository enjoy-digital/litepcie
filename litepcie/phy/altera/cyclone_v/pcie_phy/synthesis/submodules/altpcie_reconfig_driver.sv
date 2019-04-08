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


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

module altpcie_reconfig_driver # (
      parameter number_of_reconfig_interfaces    = 10,
      parameter gen123_lane_rate_mode_hwtcl      = "Gen1 (2.5 Gbps)",
      parameter INTENDED_DEVICE_FAMILY           = "Stratix V"
      ) (
      input               pld_clk,
      // Reconfig GXB
      input               reconfig_xcvr_rst,
      output reg [6:0]    reconfig_mgmt_address,
      output reg          reconfig_mgmt_read,
      input [31:0]        reconfig_mgmt_readdata,
      input               reconfig_mgmt_waitrequest,
      output reg          reconfig_mgmt_write,
      output reg [31:0]   reconfig_mgmt_writedata,
      input               reconfig_xcvr_clk,
      input               reconfig_busy,
      output              cal_busy_in,

      // Input HIP Status signals
      input                derr_cor_ext_rcv_drv,
      input                derr_cor_ext_rpl_drv,
      input                derr_rpl_drv,
      input                dlup_drv,
      input                dlup_exit_drv,
      input                ev128ns_drv,
      input                ev1us_drv,
      input                hotrst_exit_drv,
      input [3 : 0]        int_status_drv,
      input                l2_exit_drv,
      input [3:0]          lane_act_drv,
      input [4 : 0]        ltssmstate_drv,
      input		   rx_par_err_drv,
      input [1:0]	   tx_par_err_drv,
      input		   cfg_par_err_drv,
      input [7:0]	   ko_cpl_spc_header_drv,
      input [11:0]	   ko_cpl_spc_data_drv,

      input [1:0]          currentspeed
      );

import alt_xcvr_reconfig_h::*;

assign reconfig_mgmt_read = 1'b0; // Not used
assign cal_busy_in        = 1'b0;

reg [1:0]     reconfig_xcvr_rst_r;
reg           mgmt_rst_reset;
reg [2:0]     reset_sync_pldclk_r;
wire          reset_sync_pldclk;

// To aviod holding up the ltssm when programming ADCE in simulation
wire reconfig_busy_int;
// synthesis translate_off
assign reconfig_busy_int = 1'b0;
// synthesis translate_on
//synthesis read_comments_as_HDL on
// assign reconfig_busy_int = reconfig_busy;
//synthesis read_comments_as_HDL off

always @(posedge pld_clk or posedge reconfig_xcvr_rst) begin
   if (reconfig_xcvr_rst == 1'b1) begin
      reset_sync_pldclk_r <= 3'b111;
   end
   else begin
      reset_sync_pldclk_r[0] <= 1'b0;
      reset_sync_pldclk_r[1] <= reset_sync_pldclk_r[0];
      reset_sync_pldclk_r[2] <= reset_sync_pldclk_r[1];
   end
end

assign reset_sync_pldclk = reset_sync_pldclk_r[2];

always @(posedge reconfig_xcvr_clk or posedge reconfig_xcvr_rst) begin
   if (reconfig_xcvr_rst == 1'b1) begin
      reconfig_xcvr_rst_r     <= 2'b11;
      mgmt_rst_reset          <= 1'b1;
   end
   else begin
      reconfig_xcvr_rst_r[0] <= 1'b0;
      reconfig_xcvr_rst_r[1] <= reconfig_xcvr_rst_r[0];
      mgmt_rst_reset         <= reconfig_xcvr_rst_r[1];
   end
end


generate begin : g_reconfig_ip
   if ((INTENDED_DEVICE_FAMILY == "Arria V") || (INTENDED_DEVICE_FAMILY == "Cyclone V")) begin

      // DCD Calibration IP needed for Arria V and Cyclone V

      reg [2:0]   dcd_sm_state;
      reg [3:0]   current_channel;

      reg [1:0]   current_speed_r;
      reg [1:0]   prev_speed_r;
      reg [4:0]   ltssm_state_drv_r;

      wire        go_bit;
      reg         go_bit_r;

      reg         go_rcfg_r;
      reg         go_rcfg_rr;

      reg         ack_bit_r;
      reg         ack_bit_rr;

      localparam  IDLE_STATE        = 3'h0,
                  ACK_STATE         = 3'h1,
                  DCD_LCH_STATE     = 3'h2,
                  DCD_OFFSET_STATE  = 3'h3,
                  DCD_DATA_STATE    = 3'h4,
                  PAUSE_STATE       = 3'h5,
                  WAIT_DCD_STATE    = 3'h6;

      assign go_bit = ((current_speed_r == 2'b10 && prev_speed_r == 2'b01 && ltssm_state_drv_r == 5'h1A) || (go_bit_r == 1'b1 && ack_bit_rr == 1'b0))? 1'b1 : 1'b0;

      always @(posedge pld_clk or posedge reset_sync_pldclk) begin
         if (reset_sync_pldclk == 1'b1) begin
            current_speed_r <= 2'b00;
            prev_speed_r <= 2'b00;
            ltssm_state_drv_r <= 5'h0;
            go_bit_r <= 1'b0;
            ack_bit_r <= 1'b0;
            ack_bit_rr <= 1'b0;
         end
         else begin
            current_speed_r <= currentspeed;
            prev_speed_r <= current_speed_r;
            ltssm_state_drv_r <= ltssmstate_drv;
            go_bit_r <= go_bit;
            ack_bit_r <= go_rcfg_rr;
            ack_bit_rr <= ack_bit_r;
         end
      end

      always @(posedge reconfig_xcvr_clk or posedge mgmt_rst_reset) begin
         if (mgmt_rst_reset == 1'b1) begin
            go_rcfg_r <= 1'b0;
            go_rcfg_rr <= 1'b0;
         end
         else begin
            go_rcfg_r <= go_bit_r;
            go_rcfg_rr <= go_rcfg_r;
         end
      end

      always @(posedge reconfig_xcvr_clk or posedge mgmt_rst_reset) begin
         if (mgmt_rst_reset ==1'b1) begin
            dcd_sm_state <= 3'h0;
            reconfig_mgmt_address <= 7'h0;
            reconfig_mgmt_write <= 1'b0;
            reconfig_mgmt_writedata <= 32'h0;
            current_channel <= 4'h0;
         end
         else begin
            case (dcd_sm_state)

               IDLE_STATE: begin
                  current_channel <= 4'h0;
                  reconfig_mgmt_write <= 1'b0;
                  reconfig_mgmt_writedata <= 32'h0;
                  reconfig_mgmt_address <= 7'h0;
                  if (reconfig_busy_int == 1'b1) begin
                     dcd_sm_state <= IDLE_STATE;
                     reconfig_mgmt_write <= 1'b0;
                  end
                  else if (go_rcfg_rr == 1'b1)
                     dcd_sm_state <= ACK_STATE;
                  else
                     dcd_sm_state <= IDLE_STATE;
               end

               ACK_STATE: begin
                  if (go_rcfg_rr == 1'b1 || reconfig_busy_int == 1'b1) begin
                     dcd_sm_state <= ACK_STATE;
                     reconfig_mgmt_write <= 1'b0;
                  end
                  else begin
                     dcd_sm_state <= DCD_LCH_STATE;
                  end
               end

               DCD_LCH_STATE: begin
                  if (reconfig_busy_int == 1'b1) begin
                     dcd_sm_state <= DCD_LCH_STATE;
                     reconfig_mgmt_write <= 1'b0;
                  end
                  else begin
                     reconfig_mgmt_address <= ADDR_XR_DCD_LCH;
                     reconfig_mgmt_writedata <= current_channel;
                     reconfig_mgmt_write <= 1'b1;
                     dcd_sm_state <= DCD_OFFSET_STATE;
                  end
               end

               DCD_OFFSET_STATE: begin
                  if (reconfig_busy_int == 1'b1) begin
                     dcd_sm_state <= DCD_OFFSET_STATE;
                     reconfig_mgmt_write <= 1'b0;
                  end
                  else begin
                     reconfig_mgmt_address <= ADDR_XR_DCD_OFFSET;
                     reconfig_mgmt_writedata <= 32'h0;
                     reconfig_mgmt_write <= 1'b1;
                     dcd_sm_state <= DCD_DATA_STATE;
                  end
               end

               DCD_DATA_STATE: begin
                  if (reconfig_busy_int == 1'b1) begin
                     dcd_sm_state <= DCD_DATA_STATE;
                     reconfig_mgmt_write <= 1'b0;
                  end
                  else if ((current_channel < (number_of_reconfig_interfaces - 1)) && (current_channel != 4'h4)) begin
                     reconfig_mgmt_address <= ADDR_XR_DCD_DATA;
                     reconfig_mgmt_writedata <= 32'h1;
                     reconfig_mgmt_write <= 1'b1;
                     current_channel <= current_channel + 4'h1;
                     dcd_sm_state <= PAUSE_STATE;
                  end
                  else if (current_channel == number_of_reconfig_interfaces - 1) begin
                     dcd_sm_state <= IDLE_STATE;
                  end
               end

               PAUSE_STATE: begin
                  reconfig_mgmt_write <= 1'b0;
                  if (reconfig_busy_int == 1'b1) begin
                     dcd_sm_state <= WAIT_DCD_STATE;
                  end
                  else begin
                     dcd_sm_state <= PAUSE_STATE;
                  end
               end

               WAIT_DCD_STATE: begin
                  if (reconfig_busy_int == 1'b1) begin
                     dcd_sm_state <= WAIT_DCD_STATE;
                  end
                  else begin
                     dcd_sm_state <= DCD_LCH_STATE;
                     reconfig_mgmt_address <= ADDR_XR_DCD_DATA;
                     reconfig_mgmt_writedata <= 32'h0;
                     reconfig_mgmt_write <= 1'b1;
                  end
               end

               default: begin
                  dcd_sm_state <= IDLE_STATE;
               end
            endcase
         end
      end

   end
   else if ( gen123_lane_rate_mode_hwtcl !="Gen3 (8.0 Gbps)" ) begin

      always @(posedge reconfig_xcvr_clk or posedge mgmt_rst_reset) begin
         if (mgmt_rst_reset ==1'b1) begin
            reconfig_mgmt_address <= 7'h0;
            reconfig_mgmt_write <= 1'b0;
            reconfig_mgmt_writedata <= 32'h0;
         end
         else begin
            reconfig_mgmt_address <= 7'h0;
            reconfig_mgmt_write <= 1'b0;
            reconfig_mgmt_writedata <= 32'h0;
         end
      end
   end
   else begin
   //ADCE CONTROL LOGIC

      localparam     IDLE_STATE = 3'h0,
                     CTL_REG_ADDR_WRITE = 3'h1,
                     CTL_MODE_SELECT = 3'h2,
                     CHANNEL_ADDR_WRITE = 3'h3,
                     CTL_GO = 3'h4,
                     AVMM_PAUSE = 3'h5,
                     ADCE_TRIG_DONE = 3'h6;

      localparam     IDLE = 2'h0,
                     CTLR_ON = 2'h1,
                     CTLR_POWERDOWN = 2'h2;

      localparam     EN_AEQ_IN_SPDCHG = 0; 

      reg            adce_on;
      reg  [1:0]     adce_mode;
      reg  [2:0]     adce_ctlr_state;
      reg  [3:0]     current_channel;
      wire [0:0]     adce_start;
      wire [0:0]     adce_off;
      reg  [2:0]     adce_start_r;
      reg  [1:0]     adce_on_ctlr;
      reg  [1:0]     pause_cnt;
      reg  [2:0]     adce_off_r;
      reg  [0:0]     adce_on_r;
      reg  [2:0]     adce_on_rr;
      wire           adce_on_strobe;
      wire           adce_off_strobe;
      reg  [19:0]    adce_cnt;
      reg            ev1us_r;
      reg  [4:0]     ltssmstate_drv_r;

      wire [1:0]   adce_mode_in = 2'b01;      // One time mode
      wire [11:0] adce_timer = 12'hFA0;       // To achive 4ms from ev1us

      // for EP turn on in Phase 2 i.e. state 1D, for RP turn on in Phase 3 i.e. state 1E
      assign adce_start = (ltssmstate_drv==5'h1D) ? 1'b1 : 1'b0;

      assign adce_off = (currentspeed!=2'b11);

      always @(posedge pld_clk or posedge reset_sync_pldclk) begin
         if (reset_sync_pldclk ==1'b1) begin
            adce_start_r <= 3'b0;
            ev1us_r <= 1'b0;
            ltssmstate_drv_r <= 5'b0;
         end
         else begin
            ltssmstate_drv_r <= ltssmstate_drv;
            ev1us_r <= ev1us_drv;
            adce_start_r[0] <= adce_start;
            adce_start_r[1] <= adce_start_r[0];
            adce_start_r[2] <= adce_start_r[1];
         end
      end

      always @(posedge pld_clk or posedge reset_sync_pldclk) begin
         if (reset_sync_pldclk == 1'b1) begin
            adce_cnt <= adce_timer;
            adce_on_r <= 1'b0;
         end
         else begin
            if((adce_start_r[1]==1'b1) && (adce_start_r[2]!=1'b1) && (ltssmstate_drv==5'h1D))
               adce_cnt <= 20'h0;
            else if (ev1us_r && (adce_cnt < adce_timer))
               adce_cnt <= adce_cnt + 20'b1;
      
            if (EN_AEQ_IN_SPDCHG == 1)
            begin
               if ((adce_cnt == (adce_timer - 1)) ||
                   (((ltssmstate_drv_r==5'h1A) && (ltssmstate_drv==5'h0C))&& (currentspeed == 2'b11)))
                  adce_on_r <= 1'b1;
               else if ((ltssmstate_drv!=5'h0C) && (ltssmstate_drv!=5'h1D))
                  adce_on_r<= 1'b0;
            end
            else
            begin
               if (adce_cnt == (adce_timer - 1)) 
                  adce_on_r <= 1'b1;
               else 
                  adce_on_r<= 1'b0;
            end
         end
      end

      always @(posedge reconfig_xcvr_clk or posedge mgmt_rst_reset) begin
         if (mgmt_rst_reset ==1'b1) begin
            adce_on_rr <= 3'b0;
            adce_off_r <= 3'b0;
         end
         else begin
            adce_on_rr[0] <= adce_on_r;
            adce_on_rr[1] <= adce_on_rr[0];
            adce_on_rr[2] <= adce_on_rr[1];
            adce_off_r[0] <= adce_off;
            adce_off_r[1] <= adce_off_r[0];
            adce_off_r[2] <= adce_off_r[1];
         end
      end

      assign adce_on_strobe = adce_on_rr[1] && !adce_on_rr[2];
      assign adce_off_strobe = adce_off_r[1] && !adce_off_r[2];

     always @(posedge reconfig_xcvr_clk or posedge mgmt_rst_reset) begin
         if (mgmt_rst_reset ==1'b1) begin
            adce_on_ctlr <= 2'h0;
            adce_on      <= 1'b0;
            adce_mode    <= 2'h0;
         end
         else begin
            case (adce_on_ctlr)
               IDLE: begin
                  adce_on <= 1'b0;
                  if (adce_on_strobe) begin
                     adce_on_ctlr <= CTLR_ON;
                  end
                  else if (adce_off_strobe) begin
                     adce_on_ctlr <= CTLR_POWERDOWN;
                  end
                  else begin
                     adce_on_ctlr <= IDLE;
                  end
               end
               CTLR_ON: begin
                  if (adce_off_strobe)  begin
                     adce_on_ctlr <= CTLR_POWERDOWN;
                  end
                  else begin
                     adce_on <= 1'b1;
                     adce_mode <= adce_mode_in;
                     adce_on_ctlr <= IDLE;
                  end
               end
               CTLR_POWERDOWN: begin
                  if (adce_on_strobe) begin
                     adce_on_ctlr <= CTLR_ON;
                  end
                  else begin
                     adce_on <= 1'b1;
                     adce_mode <= 2'b00;
                     if (reconfig_busy_int == 1'b1)
                        adce_on_ctlr <= CTLR_POWERDOWN;
                     else
                        adce_on_ctlr <= IDLE_STATE;
                  end
               end
               default: begin
                  adce_on_ctlr <= IDLE_STATE;
               end
            endcase
         end
      end


      always @(posedge reconfig_xcvr_clk or posedge mgmt_rst_reset) begin
         if (mgmt_rst_reset ==1'b1) begin
            adce_ctlr_state <= 3'h0;
            reconfig_mgmt_address <= 7'h0;
            reconfig_mgmt_write <= 1'b0;
            reconfig_mgmt_writedata <= 32'h0;
            current_channel <= 4'h0;
            pause_cnt <= 2'b00;
         end
         else begin
            case (adce_ctlr_state)
               IDLE_STATE: begin
                  current_channel <= 4'h0;
                  reconfig_mgmt_write <= 1'b0;
                  reconfig_mgmt_writedata <= 32'h0;
                  reconfig_mgmt_address <= 7'h0;
                  if (reconfig_busy_int == 1'b1) begin
                     adce_ctlr_state <= IDLE_STATE;
                     reconfig_mgmt_write <= 1'b0;
                  end
                  else if (adce_on==1'b1)
                     adce_ctlr_state <= CTL_REG_ADDR_WRITE;
                  else
                     adce_ctlr_state <= IDLE_STATE;
               end
               CTL_REG_ADDR_WRITE: begin
                  if (reconfig_busy_int == 1'b1) begin
                     adce_ctlr_state <= CTL_REG_ADDR_WRITE;
                     reconfig_mgmt_write <= 1'b0;
                  end
                  else begin
                     reconfig_mgmt_address <= ADDR_XR_ADCE_OFFSET;
                     reconfig_mgmt_writedata <= 32'h0;
                     reconfig_mgmt_write <= 1'b1;
                     adce_ctlr_state <= CTL_MODE_SELECT;
                  end
               end
               CTL_MODE_SELECT: begin
                  if ((reconfig_busy_int == 1'b1) || (reconfig_mgmt_waitrequest==1'b1)) begin
                     adce_ctlr_state <= CTL_MODE_SELECT;
                  end
                  else begin
                     reconfig_mgmt_address <= ADDR_XR_ADCE_DATA;
                     reconfig_mgmt_writedata <= {30'h0, adce_mode};
                     reconfig_mgmt_write <= 1'b1;
                     adce_ctlr_state <= CHANNEL_ADDR_WRITE;
                  end
               end
               CHANNEL_ADDR_WRITE: begin
                  pause_cnt <= 2'b00;
                  if ((reconfig_busy_int == 1'b1) || (reconfig_mgmt_waitrequest==1'b1)) begin
                     adce_ctlr_state <= CHANNEL_ADDR_WRITE;
                  end
                  else begin
                     reconfig_mgmt_address <= ADDR_XR_ADCE_LCH;
                     reconfig_mgmt_writedata <= {28'h0, current_channel};
                     reconfig_mgmt_write <= 1'b1;
                     adce_ctlr_state <= CTL_GO;
                  end
               end
               CTL_GO: begin
                  pause_cnt <= 2'b00;
                  if ((reconfig_busy_int == 1'b1) || (reconfig_mgmt_waitrequest==1'b1)) begin
                     adce_ctlr_state <= CTL_GO;
                  end
                  else if ((current_channel < (number_of_reconfig_interfaces - 1)) && (current_channel != 4'h4)) begin
                     reconfig_mgmt_address <= ADDR_XR_ADCE_STATUS;
                     reconfig_mgmt_writedata <= 32'h1;
                     reconfig_mgmt_write <= 1'b1;
                     current_channel <= current_channel + 4'h1;
                     adce_ctlr_state <= AVMM_PAUSE;
                  end
                  else if (current_channel==4'h4) begin
                     current_channel <= current_channel + 4'h1;
                     adce_ctlr_state <= CHANNEL_ADDR_WRITE;
                  end
                  else if (current_channel==number_of_reconfig_interfaces - 1) begin
                     adce_ctlr_state <= ADCE_TRIG_DONE;
                  end
               end
               AVMM_PAUSE: begin
                  reconfig_mgmt_write <= 1'b0;
                  if (pause_cnt == 2'b11) begin
                     pause_cnt <= pause_cnt;
                     if (reconfig_busy_int == 1'b1) 
                        adce_ctlr_state <= AVMM_PAUSE;
                     else begin
                        reconfig_mgmt_address <= ADDR_XR_ADCE_LCH;
                        reconfig_mgmt_writedata <= {28'h0, current_channel};
                        reconfig_mgmt_write <= 1'b1;
                        adce_ctlr_state <= CTL_GO;
                     end
                  end
                  else begin
                     adce_ctlr_state <= AVMM_PAUSE;
                     pause_cnt <= pause_cnt + 2'b01;
                  end
               end
               ADCE_TRIG_DONE: begin
                  adce_ctlr_state <= IDLE_STATE;
               end
               default: begin
                  adce_ctlr_state <= IDLE_STATE;
               end
            endcase
         end
      end
   end
end
endgenerate


endmodule


