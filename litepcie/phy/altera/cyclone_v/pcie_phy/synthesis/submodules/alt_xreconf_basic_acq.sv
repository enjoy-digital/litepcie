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


////////////////////////////////////////////////////////
// Reconfig BASIC Acquistion block Code
//
////////////////////////////////////////////////////////
// Reconfig IP and Reconfig basic State machine
////////////////////////////////////////////////////////
//
// The minimum steps to read & write a reconfiguration word are the following:
//  Step 1  - Check for mutex grant
//  Step 2  - write logical channel number to ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL = 1
//  Step 3  - acquire channel lock
//       3a - request channel lock (write XR_DIRECT_CONTROL_PHYS_LOCK_SET to ADDR_XCVR_RECONFIG_BASIC_CONTROL = 3)
//       3b - confirm channel lock (read ADDR_XCVR_RECONFIG_BASIC_CONTROL, mask with XR_DIRECT_STATUS_BITMASK_PHYS_LOCK_GRANTED)
//          -- repeat step 3b until result after applying mask is 1
//  Step 4  - write channel offset address to ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR
//  Step 5  - read existing value from reconfig space, modify, then write back
//       5a (read cycle part 1)  - write XR_DIRECT_CONTROL_RECONF_READ to ADDR_XCVR_RECONFIG_BASIC_CONTROL = 3;
//       5b (read cycle part 2)  - read data from ADDR_XCVR_RECONFIG_BASIC_DATA = 5;
//       5c (write cycle part 1) - write modified value to ADDR_XCVR_RECONFIG_BASIC_DATA = 5;
//       5d (write cycle part 2) - write XR_DIRECT_CONTROL_RECONF_WRITE to ADDR_XCVR_RECONFIG_BASIC_CONTROL
//          -- addtional read-modify-write cycles, repeat from step 2 or 4 (can skip step 3)
//  Step 6  - release channel lock (write XR_DIRECT_CONTROL_PHYS_LOCK_CLEAR to ADDR_XCVR_RECONFIG_BASIC_CONTROL)
//  Step 7  - release mutex_request
//
// For read cycle
// Update step5 as
//        5a (read cycle part 1)  - write XR_DIRECT_CONTROL_RECONF_READ to ADDR_XCVR_RECONFIG_BASIC_CONTROL = 3;
//       5b (read cycle part 2)  - read data from ADDR_XCVR_RECONFIG_BASIC_DATA = 5;
//       5c read cycle part 3)   - read and shift the data read from master_readdata

// $Header$

`timescale 1 ns / 1 ps


module alt_xreconf_basic_acq
  #(
    parameter OFFSET_ADDR_WIDTH = 11,
    parameter MASTER_ADDR_WIDTH = 3
    ) (
    input wire clk,
    input wire reset,

       // to/from data control logic which handles, opcode generation and rmw, data control logic
    input wire ctrl_go,  // go from data control_logic, which tells go and start the operation and acquire mutex
    input wire ctrl_lock,  // lock from data control_logic indicates want to do more operations
    input wire [2:0] opcode,
    input wire [31:0] ctrl_writedata,  // read modified writedata from rmw block
    output reg        illegal_phy_ch = 1'b0,
    output reg        waitrequest_to_ctrl = 1'b0,



       // to/from uif block
    input wire [9:0]  logical_ch_addr,
    input wire [OFFSET_ADDR_WIDTH-1:0] ch_offset_addr,      // same as backend address
    input wire                 waitrequest_from_basic,
    output reg [31:0]                  readdata_for_user = 32'h00000000,   // Actual readdaa
    output reg [31:0]                  ph_readdata = 32'h00000000,   // Actual readdaa       


       // From/to mutex_acq
    input wire [31:0]                 master_readdata,
    input wire                        mutex_grant,
    output reg                        mutex_req = 1'b0,

       // Following outputs to mutex_acq block
    output reg                        master_read = 1'b0,
    output reg                        master_write = 1'b0,
    output reg [31:0]                 master_writedata = 32'h00000000,
    output reg [MASTER_ADDR_WIDTH-1:0] master_address = {MASTER_ADDR_WIDTH{1'b0}}

       );

   // Opcode encoding
   localparam READ_CH_ADD             = 3'b000;
   localparam WRITE_CH_ADD            = 3'b001;
   localparam READ_PHY_CH             = 3'b010;
   localparam WRITE_INTERNAL_REGISTER = 3'b011;
   localparam READ_INTERNAL_ROM_TABLE = 3'b100; 
   localparam READ_PHY_ADD            = 3'b101;
   localparam WRITE_PHY_ADD           = 3'b110;


   // Memory Map for reconfig basic
   // word addr            wr/rd                description
   //    ------------------------------------------------------
   //      0               wr/rd               mutex : bit[0]
   //      1               wr/rd               logical_ch_addr (10 bits)
   //      2                rd                 physical_chnl_map
   //      3               rd/wr               status/control  -- bit 0 busy/bit 1 read, bit 2 write, bit 3 = absolute addressing
   //      4               wr/rd               DPRIO addr_offset
   //      5               wr/rd               DPRIO data
   //      6                --                 reserved
   //      7                --                 reserved
   ////////////////////////////////////////////////////////
   // Basic block addresses (internal, private addresses)
   ////////////////////////////////////////////////////////
   // The 'basic' interface block is the switch that routes requests to
   // an appropriate physical reconfiguration interface.  A logical channel
   // number acts as a channel ID, which allows the basic block to find
   // the corresponding physical reconfiguration interface, and a physical
   // channel index within a physical interface.
   //
   // The Basic (B) block features are also available via the direct access block.
   // All users of the basic block, including the direct access block, must
   // acquire appropriate semaphores before using an interface, and release
   // the semaphores when done, to avoid locking out other feature blocks.
   //   localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_MUTEX = 0;
   //   localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL = 1;
   //   localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_PHYSICAL_CHANNEL = 2;
   //   localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_CONTROL = 3;
   //   localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR = 4;
   //   localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_DATA = 5;

   import alt_xcvr_reconfig_h::*; //alt_xcvr_reconfig/alt_xcvr_reconfig/alt_xcvr_reconfig_h.sv

   localparam ST_IDLE = 4'h0,
     ST_REQ_MUTEX = 4'h1,
     ST_WRITE_RECONFIG_BASIC_LCH = 4'h2,
     ST_READ_PHY_ADDRESS = 4'h3,
     ST_CHECK_PHY_ADD_LEGAL = 4'h4,
     //ST_REQ_RECONFIG_BASIC_CH_LOCK = 4'h5,
     ST_SET_RECONFIG_BASIC_PADDR_MODE = 4'h5,
     ST_CONFIRM_RECONFIG_BASIC_CH_LOCK = 4'h6,
     ST_ACCESS_RECONFIG_BASIC_OFFSET_REG = 4'h7,
     ST_WRITE_DATA_TO_RECONFIG_BASIC = 4'h8,
     ST_SET_RECONFIG_BASIC_WRITE = 4'h9,
     ST_SET_RECONFIG_BASIC_READ = 4'ha,
     ST_READ_RECONFIG_BASIC_DATA = 4'hb,
     ST_CHECK_CTRLLOCK =4'hc,
     ST_START_AGAIN = 4'hd,
     ST_RELEASE_REQ = 4'he,
     ST_CLR_RECONFIG_BASIC_PADDR_MODE = 4'hf;

   reg [3:0]  state = 4'b0000;
   reg [3:0]  next_state = 4'b0000;

   reg        lch_legal; //save logical channel legality check is the same LCH is continuously used
   reg [9:0]  lch_dly;
   reg        phy_addr_is_set;
   wire       lch_changed;

  always @(posedge clk or posedge reset)
     begin
        if (reset)
          lch_dly <= 10'd0;
        else
          lch_dly <= logical_ch_addr;
     end

  // detect a change in the logical channel to determine if we need to re-check legality
  assign lch_changed = lch_dly != logical_ch_addr;
  
  always @(posedge clk or posedge reset)
  begin
    if (reset)
      lch_legal <= 1'd0;
    else begin
      if(lch_changed || opcode == READ_PHY_CH)
        lch_legal <= 1'd0;
      else if(state == ST_CHECK_PHY_ADD_LEGAL && next_state == ST_CONFIRM_RECONFIG_BASIC_CH_LOCK)
        lch_legal <= 1'b1;
    end
  end

  // create a flag to track whether physicall addressing is set.
  // we switch back to logical addressing after each physical read/write request.
  always @(posedge clk or posedge reset)
  begin
    if (reset)
      phy_addr_is_set <= 1'd0;
    else begin
      if(next_state == ST_CLR_RECONFIG_BASIC_PADDR_MODE )
        phy_addr_is_set <= 1'd0;
      else if(next_state == ST_SET_RECONFIG_BASIC_PADDR_MODE)
        phy_addr_is_set <= 1'b1;
    end
  end

   localparam ILLEGAL_PHYSICAL_CHNL = 3'b111;


   // State machine which controls the communication with basic B block
   // Using three always blocks - registered outputs style



   // state
   always @(posedge clk or posedge reset)
     begin
        if (reset)
          state <= ST_IDLE;
        else
          state <= next_state;
     end

   // Following state machine reads the go siganl and opcode from UIF block and generates the RD, WR for basic B block
   // Typical flow for CH Address WR
   // 1) Read LCH, 2) Read PCH from basic 3) Check PCH is legal 4) Acquire lock 5) Confirm basic lock
   // 6) if write opcode then write data reg 7) set basic wr bit "1" 8) check lock input, if no lock then release req
   //  9) if ctrl_go then repeat step 6
   //
   // For Read Cycle
   // 1) Read LCH, 2) Read PCH from basic 3) Check PCH is legal 4) Acquire lock 5) Confirm basic lock
   // 6) if read opcode then set basic rd bit "1" 7) Read data from basic 8) check lock input, if no lock then release req 
   //  9) if ctrl_go then repeat step 6   
   
   
   // next_state
   always @(*)
     begin
        next_state = state;
        case (state)
          ST_IDLE:
            begin
               if (ctrl_go)
                 begin
                    if (opcode == WRITE_CH_ADD || opcode == READ_CH_ADD ||
                        opcode == WRITE_PHY_ADD || opcode == READ_PHY_ADD || 
                        opcode == READ_PHY_CH || opcode == WRITE_INTERNAL_REGISTER || 
                        opcode == READ_INTERNAL_ROM_TABLE)
                      next_state = ST_REQ_MUTEX;
                    else
                      next_state = ST_IDLE;
                 end
               else
                 next_state = ST_IDLE;
            end // case: ST_IDLE

          ST_REQ_MUTEX:
            begin
               if (mutex_grant)
                 next_state = ST_WRITE_RECONFIG_BASIC_LCH;
               else
                 next_state = ST_REQ_MUTEX;
            end


          ST_WRITE_RECONFIG_BASIC_LCH: // send logical channel address  // step 2
          begin
             if (!waitrequest_from_basic && !lch_legal)
               begin
                  next_state = ST_READ_PHY_ADDRESS;
               end
            //new
             else if (!waitrequest_from_basic && lch_legal)
               begin
                  next_state = ST_CONFIRM_RECONFIG_BASIC_CH_LOCK;
               end
          end

          ST_READ_PHY_ADDRESS:
            begin
               if (!waitrequest_from_basic)
                 next_state = ST_CHECK_PHY_ADD_LEGAL;
            end

          ST_CHECK_PHY_ADD_LEGAL:
            begin
               if (master_readdata[2:0] == ILLEGAL_PHYSICAL_CHNL)
                 begin
                    //synopsys translate_off
                    $display ("Illegal physical address: 10'h%h", master_readdata);
                    $display ("Time: %0t  Instance: %m", $time);
                    // synopsys translate_on
                    next_state = ST_IDLE;
                 end
               else
                 begin
                    if (!waitrequest_from_basic)
                      begin
                         if (opcode == READ_PHY_CH)    // if cmd phy ch read then read phy ch and check for ctrl_lock
                           next_state = ST_CHECK_CTRLLOCK;
                         else
                           //next_state = ST_REQ_RECONFIG_BASIC_CH_LOCK;
                          next_state = ST_CONFIRM_RECONFIG_BASIC_CH_LOCK; //Basic lock is automatically aquired by logical interface
                      end
                 end // else: !if(master_readdata[2:0] = ILLEGAL_PHYSICAL_CHNL)
            end // case: ST_CHECK_PHY_ADD_LEGAL

/*
          ST_REQ_RECONFIG_BASIC_CH_LOCK:                        // step 3a
            begin
               if (!waitrequest_from_basic)
                 next_state = ST_CONFIRM_RECONFIG_BASIC_CH_LOCK;
            end
*/
          ST_CONFIRM_RECONFIG_BASIC_CH_LOCK:                      // step 3b
            begin
               if (!waitrequest_from_basic)
                 begin
                    if (master_readdata & XR_DIRECT_STATUS_BITMASK_PHYS_LOCK_GRANTED) // that means the LOCK is granted
                      next_state = ST_ACCESS_RECONFIG_BASIC_OFFSET_REG;
                    else
                      next_state = ST_CONFIRM_RECONFIG_BASIC_CH_LOCK;
                 end
            end

          ST_ACCESS_RECONFIG_BASIC_OFFSET_REG: // step 4 : Write backend address to reconfig basic's offset register, aslo check for opcode and decide whether its read or write operation
            begin
               if (!waitrequest_from_basic)
                 begin
                    if ((opcode == READ_PHY_ADD) || (opcode == WRITE_PHY_ADD))
                      next_state = ST_SET_RECONFIG_BASIC_PADDR_MODE;
                    else if ((opcode == WRITE_CH_ADD) || (opcode == WRITE_INTERNAL_REGISTER))
                      next_state = ST_WRITE_DATA_TO_RECONFIG_BASIC;
                    else if ((opcode == READ_CH_ADD) || (opcode == READ_INTERNAL_ROM_TABLE) )
                      next_state = ST_SET_RECONFIG_BASIC_READ;
                 end
            end

          ST_SET_RECONFIG_BASIC_PADDR_MODE:                        
            begin
               if (!waitrequest_from_basic) begin
                 if (opcode == WRITE_PHY_ADD)
                   next_state = ST_WRITE_DATA_TO_RECONFIG_BASIC;
                 else if(opcode == READ_PHY_ADD)
                   next_state = ST_SET_RECONFIG_BASIC_READ;
               end
            end

          ST_WRITE_DATA_TO_RECONFIG_BASIC:
            begin
               if (!waitrequest_from_basic)
                 next_state = ST_SET_RECONFIG_BASIC_WRITE;
            end

          ST_SET_RECONFIG_BASIC_WRITE:
            begin
               if(phy_addr_is_set && !waitrequest_from_basic)
                 next_state = ST_CLR_RECONFIG_BASIC_PADDR_MODE; 
               else if (!waitrequest_from_basic)
                 next_state = ST_CHECK_CTRLLOCK;
            end


          ST_SET_RECONFIG_BASIC_READ: // write reconfig read to basic's control reg, set rd = 1
            begin
               if (!waitrequest_from_basic)
                 next_state = ST_READ_RECONFIG_BASIC_DATA;
            end

          ST_READ_RECONFIG_BASIC_DATA:
            begin
               if(phy_addr_is_set && !waitrequest_from_basic)
                 next_state = ST_CLR_RECONFIG_BASIC_PADDR_MODE;
               else if (!waitrequest_from_basic)
                 next_state = ST_CHECK_CTRLLOCK;
            end
          
          ST_CLR_RECONFIG_BASIC_PADDR_MODE:
            begin
               if (!waitrequest_from_basic)
                 next_state = ST_CHECK_CTRLLOCK;
            end
          
          ST_CHECK_CTRLLOCK:
            begin
               if (ctrl_lock)
                 next_state = ST_START_AGAIN;
               else
                 next_state = ST_RELEASE_REQ;
            end

          ST_START_AGAIN:    // if lock "1" then wait for go signal and go back and check for opcode again
            begin
               //contnue to monitor ctrl_lock to allow arbiter req release
          //     if(!ctrl_lock)
          //       next_state = ST_RELEASE_REQ;
               if (ctrl_go)
                 next_state = ST_ACCESS_RECONFIG_BASIC_OFFSET_REG;
               else
                 next_state = ST_START_AGAIN;
            end

          ST_RELEASE_REQ:  //Step 6
            begin
               if (!waitrequest_from_basic)
                 next_state = ST_IDLE;
            end
          default:
            next_state = ST_IDLE;
        endcase // case (state)
     end // always @ (*)


   // Assign outputs (registered outputs), these are the outputs to the master reconfig_basic
   always @(posedge clk or posedge reset)
     begin
        if (reset)
          begin
             master_address <= {MASTER_ADDR_WIDTH{1'b0}};
             master_write  <= 1'b0;
             master_read <= 1'b0;
             illegal_phy_ch <= 1'b0;
             mutex_req <= 1'b0;
             master_writedata <= 32'd0;
             readdata_for_user <= 32'd0;
             ph_readdata <= 32'd0;
             waitrequest_to_ctrl <= 1'b0;
          end
        else
          begin
             master_address <= {MASTER_ADDR_WIDTH{1'b0}};
             master_write  <= 1'b0;
             master_read <= 1'b0;
             master_writedata <= 32'd0;
             case (next_state)
               ST_IDLE:
                 begin
                    master_address <= {MASTER_ADDR_WIDTH{1'b0}};
                    master_write  <= 1'b0;
                    master_read <= 1'b0;
                    waitrequest_to_ctrl <= 1'b0;
                    master_writedata <= 32'd0;
                    mutex_req <= 1'b0;
                    waitrequest_to_ctrl <= 1'b0;
                 end // case: ST_IDLE

               ST_REQ_MUTEX:
                 begin
                    mutex_req <= 1'b1;
                    waitrequest_to_ctrl <= 1'b1;
                 end

               ST_WRITE_RECONFIG_BASIC_LCH:
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL; //1
                    master_writedata <= (32'd0 | logical_ch_addr);
                    master_write <= 1'b1;
                    master_read <= 1'b0;
                    // ST_WRITE_RECONFIG_BASIC_LCH is always a first state of any opcode operation so need to set waitrequest here to tell adta control logic that FSM is running and don't give other request till waitrequest goes "0"
                    waitrequest_to_ctrl <= 1'b1;

                 end
               ST_READ_PHY_ADDRESS:
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_PHYSICAL_CHANNEL;
                    master_write <= 1'b0;
                    master_read <= 1'b1;
                    waitrequest_to_ctrl <= 1'b1;
                 end
               ST_CHECK_PHY_ADD_LEGAL:
                 begin
                    ph_readdata <= master_readdata;                 
                    waitrequest_to_ctrl <= 1'b1;
                    if (master_readdata[2:0]== ILLEGAL_PHYSICAL_CHNL)
                      illegal_phy_ch <= 1'b1;
                    else
                      illegal_phy_ch <= 1'b0;
                 end
/*
              //Basic Lock automatically aquired. This state is redundant.
               ST_REQ_RECONFIG_BASIC_CH_LOCK:
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL; // 3
                    master_writedata <= XR_DIRECT_CONTROL_PHYS_LOCK_SET; // opcode <= 32'b0101, set lock request for current channel
                    master_write <= 1'b1;
                    master_read <= 1'b0;
                    waitrequest_to_ctrl <= 1'b1;
                 end
*/
               ST_CONFIRM_RECONFIG_BASIC_CH_LOCK:
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL; // 3
                    master_write <= 1'b0;
                    master_read <= 1'b1;
                    waitrequest_to_ctrl <= 1'b1;
                 end
               ST_ACCESS_RECONFIG_BASIC_OFFSET_REG: // Write backend address to reconfig basic's offset register
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR; // 4
                    //         master_writedata <= {{20{1'b0}, backend_add};
                    master_writedata <= (32'd0 | ch_offset_addr);
                    master_write <= 1'b1;
                    master_read <= 1'b0;
                    waitrequest_to_ctrl <= 1'b1;
                 end

              ST_SET_RECONFIG_BASIC_PADDR_MODE: //set Physical addressing mode
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL; // 4
                    master_writedata <= XR_DIRECT_CONTROL_PADDR_SET;
                    master_write <= 1'b1;
                    master_read <= 1'b0;
                    waitrequest_to_ctrl <= 1'b1;
                 end

               ST_WRITE_DATA_TO_RECONFIG_BASIC:
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_DATA; //5
                    master_writedata <= ctrl_writedata; // this is from data control block
                    master_write <= 1'b1;
                    master_read <= 1'b0;
                    waitrequest_to_ctrl <= 1'b1;
                 end

               ST_SET_RECONFIG_BASIC_WRITE:
                 begin
                    master_address <=  ADDR_XCVR_RECONFIG_BASIC_CONTROL; // 3
                    if (opcode == WRITE_INTERNAL_REGISTER)
                      master_writedata <= XR_DIRECT_CONTROL_INTERNAL_WRITE;
                    else
                      master_writedata <= XR_DIRECT_CONTROL_RECONF_WRITE;
                    master_write <= 1'b1;
                    master_read <= 1'b0;
                    waitrequest_to_ctrl <= 1'b1;
                 end

               ST_SET_RECONFIG_BASIC_READ: // write reconfig read to basic's control reg, set rd <= 1
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL; // 3
                    master_write <= 1'b1;
                    master_read <= 1'b0;
                    if(opcode == READ_INTERNAL_ROM_TABLE)
                      master_writedata <= XR_DIRECT_CONTROL_TABLE_READ; 
                    else
                      master_writedata <= XR_DIRECT_CONTROL_RECONF_READ; //XR_DIRECT_CONTROL_RECONF_READ  <= 32'b0001;  reconfig space: read from OFFSET_ADDR, save result in DATA
                    waitrequest_to_ctrl <= 1'b1;
                 end
               ST_READ_RECONFIG_BASIC_DATA:
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_DATA; //5
                    master_read <= 1'b1;
                    master_write <= 1'b0;
//                  readdata_for_user <= master_readdata;
                    waitrequest_to_ctrl <= 1'b1;
                 end

               ST_CLR_RECONFIG_BASIC_PADDR_MODE: //clear Physical addressing mode
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL; // 4
                    master_writedata <= XR_DIRECT_CONTROL_LADDR_SET;
                    master_write <= 1'b1;
                    master_read <= 1'b0;
                    waitrequest_to_ctrl <= 1'b1;
                 end

               ST_CHECK_CTRLLOCK:
                 begin
                    if (state == ST_READ_RECONFIG_BASIC_DATA || state == ST_CHECK_PHY_ADD_LEGAL || state == ST_CLR_RECONFIG_BASIC_PADDR_MODE)
                      begin
                         master_read <= 1'b0;
                         if (state == ST_READ_RECONFIG_BASIC_DATA || state == ST_CLR_RECONFIG_BASIC_PADDR_MODE)
                           readdata_for_user <= master_readdata;
                         if (state == ST_CHECK_PHY_ADD_LEGAL)
                           begin
                              ph_readdata <= master_readdata;
                              if (master_readdata[2:0]== ILLEGAL_PHYSICAL_CHNL)
                                illegal_phy_ch <= 1'b1;
                              else
                                illegal_phy_ch <= 1'b0;
                           end
                      end // if (state == ST_READ_RECONFIG_BASIC_DATA || state == ST_CHECK_PHY_ADD_LEGAL)
                    
                    if (ctrl_lock)
                      waitrequest_to_ctrl <= 1'b0;
                    else
                      waitrequest_to_ctrl <= 1'b1;
                 end

               ST_START_AGAIN:
                 begin
                    if (ctrl_go)
                      waitrequest_to_ctrl <= 1'b1;
                    else
                      waitrequest_to_ctrl <= 1'b1;
                 end

               ST_RELEASE_REQ:
                 begin
                    master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL; // 3
                    master_writedata <= XR_DIRECT_CONTROL_PHYS_LOCK_CLEAR;
                    master_write <= 1'b1;
                    master_read <= 1'b0;
                    waitrequest_to_ctrl <= 1'b1;
                    mutex_req <= 1'b0;
                 end
             endcase // case (next_state)
          end // else: !if(reset)
     end // always @ (posedge clk or posedge reset)


endmodule
