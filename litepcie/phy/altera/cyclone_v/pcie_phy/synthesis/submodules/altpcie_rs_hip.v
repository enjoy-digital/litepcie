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


// Complementary HIP reset logic (hiprst) used along with the
// HIP hard reset controller
//
// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on


module altpcie_rs_hip # (
      parameter HIPRST_USE_LOCAL_NPOR              = 0,
      parameter HIPRST_USE_LTSSM_HOTRESET          = 1,
      parameter HIPRST_USE_LTSSM_DISABLE           = 1,
      parameter HIPRST_USE_LTSSM_EXIT_DETECTQUIET  = 1,
      parameter HIPRST_USE_L2                      = 1,
      parameter HIPRST_USE_DLUP_EXIT               = 1
   )(
   input          pld_clk,
   input          dlup_exit,
   input          hotrst_exit,
   input          l2_exit,
   input          npor_core,
   input   [4: 0] ltssm,

   output reg     hiprst
);

localparam [4:0] LTSSM_POL          = 5'b00010;
localparam [4:0] LTSSM_CPL          = 5'b00011;
localparam [4:0] LTSSM_DET          = 5'b00000;
localparam [4:0] LTSSM_RCV          = 5'b01100;
localparam [4:0] LTSSM_DIS          = 5'b10000;
localparam [4:0] LTSSM_DETA         = 5'b00001;
localparam [4:0] LTSSM_DETQ         = 5'b00000;
localparam [23:0] RCV_TIMEOUT       = 24'd6000000;

`ifdef ALTERA_RESERVED_QIS_ES
   localparam SV_ES_DEVICE          =  1;
`else
   localparam SV_ES_DEVICE          =  0;
`endif

reg         hiprst_r;
reg [1:0]   npor_core_r ;
reg         npor_sync   ;
reg         dlup_exit_r;
reg         exits_r;
reg         hotrst_exit_r;
reg         l2_exit_r;
reg [4: 0]  rsnt_cntn;
reg [4: 0]  ltssm_r;
reg [4: 0]  ltssm_rr;
wire        recovery_rst;
wire        ext_dect_quiet;
reg         ltssm_disable;

   //reset Synchronizer
   always @(posedge pld_clk or negedge npor_core) begin
      if (npor_core == 1'b0) begin
         npor_core_r  <= 2'b00;
         npor_sync    <= 1'b0;
      end
      else begin
         npor_core_r  <= {npor_core_r[0],1'b1};
         npor_sync    <= npor_core_r[1];
      end
   end

  //Reset delay
   always @(posedge pld_clk or negedge npor_sync) begin
      if (npor_sync == 1'b0)
         rsnt_cntn <= 5'h0;
      else if (exits_r == 1'b1)
         rsnt_cntn <= 5'd10;
      else if (rsnt_cntn != 5'd20)
         rsnt_cntn <= rsnt_cntn + 5'h1;
   end


  //sync and config reset
   always @(posedge pld_clk or negedge npor_sync) begin
      if (npor_sync == 1'b0) begin
          hiprst_r <= (HIPRST_USE_LOCAL_NPOR==1)?1'b1:1'b0;
      end
      else if (exits_r == 1'b1) begin
          hiprst_r <= 1'b1;
      end
      else if (rsnt_cntn == 5'd20) begin
          hiprst_r <= 1'b0;
      end
   end

   generate begin : g_recovery_rst
      if (SV_ES_DEVICE==1) begin
         // Monitor if LTSSM is frozen in RECOVERY state
         // Issue reset if timeout RCV_TIMEOUT
         reg [23:0]  recovery_cnt;
         reg recovery_r_rst;
         always @(posedge pld_clk or negedge npor_sync) begin
            if (npor_sync == 1'b0) begin
               recovery_cnt <= {24{1'b0}};
               recovery_r_rst <= 1'b0;
            end
            else begin
               if (ltssm_r != LTSSM_RCV) begin
                  recovery_cnt <= {24{1'b0}};
               end
               else if (recovery_cnt == RCV_TIMEOUT) begin
                  recovery_cnt <= recovery_cnt;
               end
               else if (ltssm_r == LTSSM_RCV) begin
                  recovery_cnt <= recovery_cnt + 24'h1;
               end
               if (recovery_cnt == RCV_TIMEOUT) begin
                  recovery_r_rst <= 1'b1;
               end
               else if (ltssm_r != LTSSM_RCV) begin
                  recovery_r_rst <= 1'b0;
               end
            end
         end
         assign recovery_rst = recovery_r_rst;
      end
      else begin
         assign recovery_rst = 1'b0;
      end
   end
   endgenerate

   generate begin : g_exit_detectquiet
      if (HIPRST_USE_LTSSM_EXIT_DETECTQUIET==1) begin
         // Keep LTSSM in reset for 1us before transition from Detect.quiet to
         // Detect.active
         // Since the fastest pld_clk is 250Mhz (4ns) and the minimum wait is 1us,
         // the max_reset_cnt = 1024/4 = 256
         reg [7:0]   cnt_dect_quiet_low;
         reg         ext_dect_quiet_r;
         always @(posedge pld_clk or negedge npor_sync) begin
            if (npor_sync == 1'b0) begin
               cnt_dect_quiet_low   <= 8'hFF;
               ext_dect_quiet_r       <= 1'b0;
            end
            else  begin
               if ((ltssm_r == LTSSM_DETQ) && (ltssm_rr == LTSSM_DETA)) begin
                  cnt_dect_quiet_low   <= 8'h0;
                  ext_dect_quiet_r       <= 1'b1;
               end
               else begin
                  if (cnt_dect_quiet_low < 8'hFF ) begin
                     cnt_dect_quiet_low <= cnt_dect_quiet_low + 8'h1;
                  end
                  if (cnt_dect_quiet_low == 8'hFE ) begin
                     ext_dect_quiet_r <= 1'b0;
                  end
               end
            end
         end
         assign ext_dect_quiet = ext_dect_quiet_r;
      end
      else begin
         assign ext_dect_quiet = 1'b0;
      end
   end
   endgenerate


   always @(posedge pld_clk or negedge npor_sync) begin
      if (npor_sync == 1'b0) begin
         dlup_exit_r    <= 1'b1;
         hotrst_exit_r  <= 1'b1;
         l2_exit_r      <= 1'b1;
         exits_r        <= 1'b0;
         ltssm_disable  <= 1'b0;
         hiprst         <= (HIPRST_USE_LOCAL_NPOR==1)?1'b1:1'b0;
         ltssm_r        <= LTSSM_DETQ;
         ltssm_rr       <= LTSSM_DETQ;
      end
      else begin
         ltssm_r        <= ltssm;
         ltssm_rr       <= ltssm_r;
         hiprst         <= hiprst_r;
         dlup_exit_r    <= (HIPRST_USE_DLUP_EXIT==0)     ?1'b1:dlup_exit;
         hotrst_exit_r  <= (HIPRST_USE_LTSSM_HOTRESET==0)?1'b1:hotrst_exit;
         l2_exit_r      <= (HIPRST_USE_L2==0)            ?1'b1:l2_exit;
         ltssm_disable  <= (HIPRST_USE_LTSSM_DISABLE==0) ?1'b0:(ltssm_r == LTSSM_DIS)?1'b1:1'b0;
         exits_r <= ((l2_exit_r == 1'b0)||(hotrst_exit_r == 1'b0)||(dlup_exit_r == 1'b0)||(ltssm_disable == 1'b1)||(recovery_rst == 1'b1)||(ext_dect_quiet == 1'b1))?1'b1:1'b0;
      end
   end

endmodule
