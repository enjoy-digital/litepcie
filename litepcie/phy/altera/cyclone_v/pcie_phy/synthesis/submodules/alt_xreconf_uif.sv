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


// Modification of Common register interface for many reconfig blocks
// Added a mode filed in the control register
// $Header$

`timescale 1 ns / 1 ps

module alt_xreconf_uif
  #(
    parameter RECONFIG_USER_ADDR_WIDTH    = 3,
    parameter RECONFIG_USER_DATA_WIDTH    = 32,
    parameter RECONFIG_USER_CTRL_WIDTH    = 2,
    parameter RECONFIG_USER_ENABLE_CTRL   = 0,
    parameter RECONFIG_USER_MODE_WIDTH    = 3,
    parameter RECONFIG_USER_OFFSET_WIDTH  = 5
    )
   (
    input wire reconfig_clk,
    input wire reset,

    //avalon MM slave
    input wire [RECONFIG_USER_ADDR_WIDTH-1:0] user_reconfig_address,             // MM address
    input wire [RECONFIG_USER_DATA_WIDTH-1:0] user_reconfig_writedata,
    input wire                    user_reconfig_write,
    input wire                    user_reconfig_read,
    output reg [RECONFIG_USER_DATA_WIDTH-1:0] user_reconfig_readdata,      // from MM
    output wire                   user_reconfig_waitrequest,
    output wire                   user_reconfig_done,

    // to/from data control logic
    output reg [RECONFIG_USER_DATA_WIDTH-1:0]   uif_writedata,   // user data for data control module
    output reg [RECONFIG_USER_OFFSET_WIDTH-1:0] uif_addr_offset, // offset address for data control module
    output reg [RECONFIG_USER_MODE_WIDTH-1:0]   uif_mode,       // rd, write or physical rd mode of operation
    output reg [RECONFIG_USER_CTRL_WIDTH-1:0]   uif_ctrl,       //spare control register bits
    output reg [9:0]                            uif_logical_ch_addr, // Logical channel address for data control module
    output reg                                  uif_go,          // go signal for data control logic to start the operation
    input wire [RECONFIG_USER_DATA_WIDTH-1:0]   uif_readdata,   // readdata from data control logic/basic
    input wire [RECONFIG_USER_DATA_WIDTH-1:0]   uif_phreaddata,   // readdata from data control logic/basic    
    input wire                                  uif_illegal_pch_error, //illegal physical error signal from control block
    input wire                  uif_illegal_offset_error, // illegal offset error from control block
    input wire                  uif_busy                 // busy from control block
    );


    
   // Parameters for reconfig address
   localparam LADDR_XR_LCH    = 0;
   localparam LADDR_XR_PCH    = 1;
   localparam LADDR_XR_STATUS = 2;
   localparam LADDR_XR_OFFSET = 3;
   localparam LADDR_XR_DATA   = 4;


   // different modes of operation
   localparam READ_CH_ADD = 3'b000;
   localparam WRITE_CH_ADD = 3'b001;
   localparam READ_PHY_CH = 3'b010;

   localparam MODE_OPCODE_LEN = 3;

   //register declaration

   wire                                 int_status_error;
   reg                                  illegal_addr_error= 1'b0;
   wire [1:0]                           status_reg;
   wire                                 mode_done;
   wire [RECONFIG_USER_CTRL_WIDTH-1:0]  uif_ctrl_rd;

   
   assign int_status_error = illegal_addr_error | uif_illegal_pch_error | uif_illegal_offset_error;
   assign status_reg = {int_status_error,uif_busy};
   assign user_reconfig_done = !uif_busy;


   // Memory mapped Write Interface
   always @(posedge reconfig_clk or posedge reset)
     begin
    if (reset)
          begin
            illegal_addr_error <= 1'b0;
            uif_addr_offset <= {RECONFIG_USER_OFFSET_WIDTH{1'b0}};
            uif_writedata <= {RECONFIG_USER_DATA_WIDTH{1'b0}};
            uif_logical_ch_addr <= 10'b0000000000;
            uif_go <= 1'b0;
            uif_mode <= {RECONFIG_USER_MODE_WIDTH{1'b0}};
            uif_ctrl <= {RECONFIG_USER_CTRL_WIDTH{1'b0}};
      end
    else
      begin
         // decode reconfig_address and take an action accordingly
         // generae uif_mode and uif_go pulse to start the operation
         case (user_reconfig_address)
           LADDR_XR_LCH :  // write logical ch address
         begin
            uif_go <= 1'b0;
            illegal_addr_error <= 1'b0;         
            if (user_reconfig_write && !uif_busy)
              begin
                 uif_logical_ch_addr <= user_reconfig_writedata[9:0];  // write logical ch address
              end
         end

           LADDR_XR_OFFSET:  // write offset register
         begin
            uif_go <= 1'b0;
            illegal_addr_error <= 1'b0;         
            if (user_reconfig_write && !uif_busy)
              uif_addr_offset <= user_reconfig_writedata[RECONFIG_USER_OFFSET_WIDTH-1:0];// if add offset then write txrx offset to offset_reg
         end

           LADDR_XR_DATA:    // write into data register
         begin
            uif_go <= 1'b0;
            illegal_addr_error <= 1'b0;         
            begin
            if (user_reconfig_write && !uif_busy)
              uif_writedata <= user_reconfig_writedata;  // write data to register
            end
         end
           LADDR_XR_STATUS:  // bit[0] = wr, bit[1]= rd, bit[8] = busy
         begin
            illegal_addr_error <= 1'b0;
            if (user_reconfig_write && !uif_busy)
              begin
             if (user_reconfig_writedata[0] == 1'b1) // check for wr bit is 1, if yes then enable go for data_control logic
               begin
                  uif_go <= 1'b1;   // give go to data control logic to start the operation
                  uif_mode[MODE_OPCODE_LEN-1:0] <= WRITE_CH_ADD;
                  uif_ctrl <= (RECONFIG_USER_ENABLE_CTRL == 1) ?  user_reconfig_writedata[3:2] : {RECONFIG_USER_CTRL_WIDTH{1'b0}};
               end
             else if (user_reconfig_writedata[1] == 1'b1) // check for rd bit is 1, if yes then enable go for data_control logic
               begin
                  uif_go <= 1'b1;   // give go to data control logic to start the operation
                  uif_mode[MODE_OPCODE_LEN-1:0] <= READ_CH_ADD;
                  uif_ctrl <= (RECONFIG_USER_ENABLE_CTRL == 1) ?  user_reconfig_writedata[3:2] : {RECONFIG_USER_CTRL_WIDTH{1'b0}};
               end
             else 
                begin
                  uif_go <= 1'b0;
                  uif_ctrl <= (RECONFIG_USER_ENABLE_CTRL == 1) ?  user_reconfig_writedata[3:2] : {RECONFIG_USER_CTRL_WIDTH{1'b0}};
                end
              end // if (user_reconfig_write && !status_busy_reg)
            else
              uif_go <= 1'b0;
         end // case: LADDR_XR_STATUS

           LADDR_XR_PCH:  // physical channel read
         begin
            illegal_addr_error <= 1'b0;         
            if (user_reconfig_read && !uif_busy)
              begin
             uif_go <= 1'b1;
             uif_mode[MODE_OPCODE_LEN-1:0] <= READ_PHY_CH;
              end
            else
              uif_go <= 1'b0;
         end
           default:  
         begin
            uif_go <= 1'b0;
            if (user_reconfig_write | user_reconfig_read)
              begin
		 illegal_addr_error <= 1'b1; // assert the error if address is other than, lch, offset, control/status pch and data 
		 
             // synopsys translate_off
             $display ("Illegal operation to reserved address %h", user_reconfig_address);
             $display ("Time: %0t  Instance: %m", $time);
             // synopsys translate_on
              end
         end // case: default
         endcase // case (user_reconfig_address)
      end // else: !if(reset)
     end // always @ (posedge reconfig_clk or posedge reset)




// Memory Mapped Read Interface - READ logic
 //------------------------------------------------------------------
   // Address reg     | read is allowed
   //-----------------|--------------------------------------------------------
   //   LCH           |   YES, always
   //   PCH           |   YES, only when busy is low
   //   control/status|  YES, only Status bits
   //   offset        |  YES, Always
   //   data          |  YES, only when busy is low


   assign uif_ctrl_rd = (RECONFIG_USER_ENABLE_CTRL == 1) ? uif_ctrl : {RECONFIG_USER_CTRL_WIDTH{1'b0}};
   always @(posedge reconfig_clk or posedge reset)
     begin
    if (reset)
      begin
         user_reconfig_readdata <= {RECONFIG_USER_DATA_WIDTH{1'b0}};
      end
    else
      begin
         if (user_reconfig_read == 1'b1)
           begin
          case (user_reconfig_address)
            LADDR_XR_LCH:
                      user_reconfig_readdata <= (32'd0 | uif_logical_ch_addr);
            LADDR_XR_PCH:
              begin
             if (!uif_busy)
               user_reconfig_readdata <= uif_phreaddata;
              end
            LADDR_XR_STATUS:
              begin
                   user_reconfig_readdata <= {{22{1'b0}}, status_reg, {4{1'b0}},uif_ctrl_rd, {2{1'b0}}};
                   //user_reconfig_readdata <= {{22{1'b0}}, status_reg, {8{1'b0}}};
              end
            LADDR_XR_OFFSET:
                      user_reconfig_readdata <= (32'd0 | uif_addr_offset);
            LADDR_XR_DATA:
              if (!uif_busy)
            begin
               if (uif_mode[MODE_OPCODE_LEN-1:0] == WRITE_CH_ADD)
                 user_reconfig_readdata <= (32'd0 | uif_writedata);
               else if ((uif_mode[MODE_OPCODE_LEN-1:0] == READ_CH_ADD) || (uif_mode[MODE_OPCODE_LEN-1:0] == READ_PHY_CH) )
                 user_reconfig_readdata <= uif_readdata;
            end
            default:
                      user_reconfig_readdata <= {32{1'b0}};
          endcase // case (reconfig_address)
               end // if (reconfig_read == 1'b1)
      end // else: !if(reset)
     end // always @ (posedge reconfig_clk or posedge reset)

// Implement 1-cycle waitrequest to match previous implementation
altera_wait_generate wait_gen(
    .rst(reset),
    .clk(reconfig_clk),
    .launch_signal(user_reconfig_read),
    .wait_req(user_reconfig_waitrequest)
);

endmodule // altera_xcvr_reconfig_common_user_if
