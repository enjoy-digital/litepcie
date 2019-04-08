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


// (C) 2001-2011 Altera Corporation. All rights reserved.
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


`timescale 1 ps / 1 ps
// need to review the interface - figure out if anything needs to be added, or if anything can be removed - fix me!
module alt_xcvr_reconfig_offset_cancellation_av #(
  parameter device_family = "Arria V",
  parameter number_of_reconfig_interfaces = 1
)
(
  input wire reconfig_clk,        // this will be the reconfig clk
  input wire reset,

  //avalon MM slave
  input wire [2:0]  offset_cancellation_address,       // MM address
  input wire [31:0] offset_cancellation_writedata,
  input wire offset_cancellation_write,
  input wire offset_cancellation_read,

  //output MM slave
  output reg [31:0] offset_cancellation_readdata,      // from MM

  output wire offset_cancellation_done, 

  // input from base_reconfig
  input wire offset_cancellation_irq_from_base,
  input wire offset_cancellation_waitrequest_from_base,

  output wire offset_cancellation_waitrequest,

  // output to base_reconfig
  // Avalon MM Master
  output wire [2:0] offset_cancellation_address_base,   // 3 bit MM
  output wire [31:0] offset_cancellation_writedata_base,
  output wire offset_cancellation_write_base,                         // start write to GXB
  output wire offset_cancellation_read_base,                          // start read from GXB

  // input from base reconfig
  input wire [31:0] offset_cancellation_readdata_base,         // data from read command

  // Avalon ST
  input wire [7 : 0] testbus_data, // testbus data is now provided on a per-channel basis from the 'B'

	// external connect to switch fabric: request basic access from arbiter
  output wire arb_req,
  input  wire arb_grant
);

import alt_xcvr_reconfig_h::*;
import av_xcvr_h::*;
///////////////////////////////////////////////////////////////////
// Memory map   | wr/rd     |       Description
//----------------------------------------------------------------
// 0           | wr/rd     |   [31:10] Reserved
//              |           |   [9] Error
//              |           |   [8] Busy
//              |           |   [7:1] Reserved
//              |           |   [0] Start (hidden for QII 9.1)
///////////////////////////////////////////////////////////////////

//local parameters
//state
localparam IDLE_STATE             = 6'b000000;
localparam LOGICAL_ADDRESS_STATE  = 6'b000001;
localparam WRITE_DATA_STATE       = 6'b000010;
localparam CONTROL_STATE          = 6'b000011;
localparam BUSY_STATE             = 6'b000100;
localparam READ_PHY_ADDR_STATE    = 6'b000101;
localparam CHECK_PHY_ADDR_STATE   = 6'b000110;
localparam SET_ADDR_OFFSET_REQ_STATE = 6'b000111; 
localparam REQUEST_CONTROL_STATE  = 6'b001000;
localparam READ_REQ_DATA_STATE    = 6'b001001;
localparam CHECK_REQ_DATA_STATE   = 6'b001010;
localparam ADDRESS_OFFSET_STATE   = 6'b001011;
localparam BASE_BUSY_STATE        = 6'b001100;
localparam READ_DATA_STATE        = 6'b001101;
localparam WRITE_DONE_STATE       = 6'b001110;
localparam ACQUIRE_PMUTEX_STATE   = 6'b001111;
localparam READ_PMUTEX_STATE      = 6'b010000;
localparam CHECK_PMUTEX_STATE     = 6'b010001;
localparam RELEASE_PMUTEX_STATE   = 6'b010010;
localparam WAIT_FOR_NEXT_STATE    = 6'b010011;
localparam GET_TESTBUS_ADDR_STATE = 6'b010100;
localparam GET_TESTBUS_DATA_STATE = 6'b010101;
localparam SET_OC_CALEN_ADDR_STATE = 6'b010110;
localparam SET_OC_CALEN_DATA_STATE = 6'b010111;
localparam START_OC_CALEN_STATE    = 6'b011000;
localparam RELEASE_OC_CALEN_DATA_STATE  = 6'b011001;
localparam RELEASE_OC_CALEN_START_STATE = 6'b011010;
localparam RELEASE_OC_CALEN_DONE_STATE  = 6'b011011;
localparam SET_PHY_RESET_OVERRIDE_ADDR_STATE = 6'b011100;
localparam SET_PHY_RESET_OVERRIDE_DATA_STATE = 6'b011101;
localparam SET_PHY_RESET_OVERRIDE_START_STATE = 6'b011110;
localparam RELEASE_PHY_RESET_OVERRIDE_ADDR_STATE = 6'b11111;
localparam RELEASE_PHY_RESET_OVERRIDE_DATA_STATE = 6'b100000;
localparam RELEASE_PHY_RESET_OVERRIDE_START_STATE = 6'b100001;

localparam ILLEGAL_PHYSICAL_CHNL  = 3'b111; // lower 3 bits of the physical address will be all 1 - the channel index within the triplet

wire mutex_grant; // don't need to check if we check waitrequest - waitrequest from the arbiter_acq module is gated by grant
wire [31:0] master_read_data;
wire mutex_waitrequest_from_base;
reg [5:0] state = 0;
reg write_read_control = 0;
reg master_write = 0;
reg master_read = 0;
reg [31:0] master_write_data = 0;
reg [15:0] prev_logical_channel = 0;
reg [W_XR_FEATURE_LADDR-1:0] master_address = 0;
reg req_and_use_mutex = 0;

//alt_cal instantiation
wire alt_cal_busy;
wire [15:0] alt_cal_dprio_dataout;
wire alt_cal_dprio_wren;
wire alt_cal_dprio_rden;

wire [15:0] alt_cal_dprio_addr;
wire [8:0] alt_cal_quad_addr;
reg [11:0] alt_cal_remap_addr = 0;
reg alt_cal_dprio_busy = 0;
reg [15:0] alt_cal_dprio_datain = 0;

reg oc_started = 1'b0;
reg pmutex_acquired = 1'b0;
reg start, start0q;
wire start_trigger;

assign start_trigger =  start & ~start0q; // rising edge of start

function integer CLogB2;
input integer Depth;
integer i;
begin
i = Depth;
for(CLogB2 = 0; i > 0; CLogB2 = CLogB2 + 1)
i = i >> 1;
end
endfunction

// Implement waitrequest to match previous implementation
altera_wait_generate wait_gen(
    .rst(reset),
    .clk(reconfig_clk),
    .launch_signal(offset_cancellation_read),
    .wait_req(offset_cancellation_waitrequest)
);

// synopsys translate_off
initial begin
    state = 5'b0;
    alt_cal_remap_addr = 12'h000;
    req_and_use_mutex = 1'b0;
    alt_cal_dprio_datain = 16'h0000;
    alt_cal_dprio_busy = 1'b0;

    master_write = 1'b0;
    master_read = 1'b0;
    master_write_data = {32{1'b0}};
    prev_logical_channel = {16{1'b0}};
    master_address = 3'h0;

    write_read_control = 1'b0; // 1 for write, 0 for read

    oc_started = 1'b0;
    pmutex_acquired = 1'b0;

end
// synopsys translate_on


// offset_cancellation_done starts at 0
// -once alt_cal_busy goes high, then we are allowed to change OC done
// -once alt_cal_busy has gone high once, then oc_done is equal to ~oc_busy
// -oc_started should not be in the reset block - oc only needs to run once at initial powerup
// -we also need to make sure state is IDLE, since the mutex release state occurs after alt_cal is no longer busy
assign offset_cancellation_done = oc_started ? (~alt_cal_busy && (state == IDLE_STATE)) : 1'b0;

integer count;

always @ (posedge reconfig_clk) begin
  // starts as 0, and is asserted to 1 the first time alt_cal goes busy.  Do not unset this flag for subsequent runs, as OC should only run once at initial powerup
  if (oc_started == 1'b1) begin
    oc_started <= 1'b1;
  end else begin
    oc_started <= alt_cal_busy;
  end
end

always @(posedge reconfig_clk or posedge reset)
begin
  if (reset) begin
    master_write <= 1'b0;
    master_read <= 1'b0;
    master_write_data <= {32{1'b0}};
    prev_logical_channel <= {16{1'b0}};
    master_address <= 3'h0;
    write_read_control <= 1'b0; // 1 for write, 0 for read
    state <= IDLE_STATE;
    offset_cancellation_readdata[31:0] <= {32{1'b0}};
    req_and_use_mutex <= 1'b0;
    pmutex_acquired <= 1'b0;
    start <= 1'b0;
    start0q <= 1'b0;
    alt_cal_remap_addr <= 12'h000;
    alt_cal_dprio_datain <= 16'h0000;
    alt_cal_dprio_busy <= 1'b0;
  end else begin
    if(offset_cancellation_read == 1'b1) begin
      if(offset_cancellation_address == 3'h2) begin // SPR 377710 - change the address to register 0x2 to be consistent with other reconfig interfaces
        offset_cancellation_readdata <= {{23{1'b0}}, alt_cal_busy , {8{1'b0}}};
      end
    end else if (offset_cancellation_write == 1'b1) begin // read and write can not be asserted at the same time
      if (offset_cancellation_address == 3'h2) begin // SPR 377710 - change the address to register 0x2 to be consistent with other reconfig interfaces
        start   <= offset_cancellation_writedata[0]; // differs slightly from other reconfig interfaces - only the write itself triggers a restart of offset cancellation
        start0q <= start;
      end
    end else begin
      start   <= 1'b0;
      start0q <= start;
    end

    if(alt_cal_busy == 1'b0 && (state == IDLE_STATE)) // make sure we have released the physical mutex before releasing request
      req_and_use_mutex <= 1'b0;
    else
      req_and_use_mutex <= 1'b1;

    case (state)
      IDLE_STATE: begin
        //reset the signal
        master_write <= 1'b0;
        master_read <= 1'b0;
        alt_cal_remap_addr <= 12'h000;

        //alt_cal will not assert wren and rden at the same time
        if((alt_cal_dprio_wren == 1'b1) || (alt_cal_dprio_rden == 1'b1)) begin
          if(alt_cal_dprio_wren == 1'b1) begin
            write_read_control <= 1'b1; // 1 for write
          end else begin
            write_read_control <= 1'b0; // 0 for read
          end
          state <= LOGICAL_ADDRESS_STATE; // need to change to request arbiter lock
          master_write <= 1'b1; // next step is to send address to alt_dprio
          master_address <= ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL;
          master_write_data <= {{21{1'b0}}, alt_cal_quad_addr, alt_cal_dprio_addr[13:12]}; // the logical channel is just sent as is - we can revise alt_cal_sv.v to account for this, but leave it for now - fix me!
          prev_logical_channel <= {5'b0, alt_cal_quad_addr, alt_cal_dprio_addr[13:12]}; // store the previous logical channel
        end else begin
          state <= IDLE_STATE;
        end
      end
      LOGICAL_ADDRESS_STATE: begin //sending channel and quad address
        if (~mutex_waitrequest_from_base) begin
          master_write <= 1'b0;
          master_read <= 1'b1; // do a read operation
          master_address <= ADDR_XCVR_RECONFIG_BASIC_PHYSICAL_CHANNEL;
          state <= READ_PHY_ADDR_STATE;
        end else begin
          state <= LOGICAL_ADDRESS_STATE;
        end
      end
      READ_PHY_ADDR_STATE: begin //read phsical address
        if (~mutex_waitrequest_from_base) begin
          master_read <= 1'b0; 
          master_write <= 1'b0;
          state <= CHECK_PHY_ADDR_STATE;
        end else begin // waitrequest is asserted - keep control signals constant
          state <= READ_PHY_ADDR_STATE;
        end
      end
      CHECK_PHY_ADDR_STATE: begin //check physical address correct or not
        master_read <= 1'b0;
        master_write <= 1'b0;
        if (master_read_data[2:0] == ILLEGAL_PHYSICAL_CHNL) begin
          // synopsys translate_off
            $display ("Illegal physical address: 10'h%h", master_read_data);
            $display ("Time: %0t  Instance: %m", $time);
          // synopsys translate_on
          alt_cal_remap_addr <= 12'hfff;
          state <= IDLE_STATE;
        end else begin
          alt_cal_remap_addr <= master_read_data[11:0];
          // if we already have the physical mutex, we are guaranteed it until we are done
          state <= SET_ADDR_OFFSET_REQ_STATE; // get the physical mutex if we haven't yet
        end
      end
      SET_ADDR_OFFSET_REQ_STATE: begin  // send address request to alt_dprio
        if (~mutex_waitrequest_from_base) begin
          master_address <= ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR;
          master_write_data <= AV_XR_ABS_ADDR_REQUEST;
          master_write <= 1'b1;
          master_read <= 1'b0;
          state <= REQUEST_CONTROL_STATE;
        end else begin 
          state <= SET_ADDR_OFFSET_REQ_STATE;
        end
      end
      REQUEST_CONTROL_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL; // get ready to send control command to alt_dprio
          master_write_data <= XR_DIRECT_CONTROL_RECONF_READ; // set control to read
          master_write <= 1'b1;
          master_read <= 1'b0;
          state <= READ_REQ_DATA_STATE;
	    end else begin
	      state <= REQUEST_CONTROL_STATE;
	    end
      end
      READ_REQ_DATA_STATE: begin // read offset request bit
	    if (master_read && ~mutex_waitrequest_from_base) begin // irq is deprecated - the basic now blocks (using waitrequest) until the operation is done
	      master_read <= 1'b0;
	      state <= CHECK_REQ_DATA_STATE;
	    end else if (master_write && ~mutex_waitrequest_from_base) begin // we just came from ACQUIRE_PMUTEX_STATE
	      master_read <= 1'b1; 
	      master_write <= 1'b0; 
	      master_address <= ADDR_XCVR_RECONFIG_BASIC_DATA; // get the addr request data from the DPRIO result register
	      state <= READ_REQ_DATA_STATE; // need to stall for one more cycle
	    end else begin // waitrequested
	      state <= READ_REQ_DATA_STATE;
	     end
      end
      CHECK_REQ_DATA_STATE: begin //check logical if whether offset cancellation is required
        master_read <= 1'b0;
        master_write <= 1'b0;
        if (master_read_data[2] == 1'b0) begin
          // synopsys translate_off
            $display ("Offset cancellation is not required");
            $display ("Time: %0t  Instance: %m", $time);
          // synopsys translate_on
          alt_cal_remap_addr <= 12'hfff;
          state <= IDLE_STATE;
        end else begin
          // if we already have the physical mutex, we are guaranteed it until we are done
          state <= pmutex_acquired ? ADDRESS_OFFSET_STATE : ACQUIRE_PMUTEX_STATE; // get the physical mutex if we haven't yet
	    end
      end
      ACQUIRE_PMUTEX_STATE: begin
        master_read <= 1'b0;
        master_write <= 1'b1;
        master_address <= 3'h3; // status and control word
        master_write_data <= XR_DIRECT_CONTROL_PHYS_LOCK_SET; // write to request physical mutex
        state <= READ_PMUTEX_STATE;
      end
      READ_PMUTEX_STATE: begin // read the mutex state back to see if we got it
        if (master_read && ~mutex_waitrequest_from_base) begin // we just read the mutex state
          master_read <= 1'b0;
          state <= CHECK_PMUTEX_STATE;
        end else if (master_write && ~mutex_waitrequest_from_base) begin // we just came from ACQUIRE_PMUTEX_STATE
          master_read <= 1'b1; 
          master_write <= 1'b0; 
          master_address <= 3'h3; // status and control word to read back the pmutex state
          state <= READ_PMUTEX_STATE; // need to stall for one more cycle
        end else begin // waitrequested
          state <= READ_PMUTEX_STATE;
        end
      end
      CHECK_PMUTEX_STATE: begin
        if (master_read_data[0]) begin // we got the mutex
          pmutex_acquired <= 1'b1;
          master_read <= 1'b0;
          master_write <= 1'b1;
          master_address <= ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR;
          master_write_data <= AV_XR_LOCAL_OFFSET + AV_XR_ADDR_RSTCTL; // phy reset override control
          state <= SET_PHY_RESET_OVERRIDE_ADDR_STATE; // get the testbus
        end else begin // we didn't get the mutex - try again
          state <= ACQUIRE_PMUTEX_STATE;
        end
      end
      SET_PHY_RESET_OVERRIDE_ADDR_STATE: begin // override the PHY reset via the soft-CSR
        if (~mutex_waitrequest_from_base) begin
          master_read <= 1'b0;
          master_write <= 1'b1;
          master_address <= ADDR_XCVR_RECONFIG_BASIC_DATA; 
          master_write_data <= (1 << AV_XR_RSTCTL_RX_RST_OVR_OFST) | (1 << AV_XR_RSTCTL_RX_ANALOG_RST_N_VAL_OFST); // override the rx analog reset - active low
          state <= SET_PHY_RESET_OVERRIDE_DATA_STATE;
        end else begin // wait until waitrequest clears
          state <= SET_PHY_RESET_OVERRIDE_ADDR_STATE;
        end
      end
      SET_PHY_RESET_OVERRIDE_DATA_STATE: begin // override the PHY reset via the soft-CSR
        if (~mutex_waitrequest_from_base) begin
          master_read <= 1'b0;
          master_write <= 1'b1;
          master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL;
          master_write_data <= XR_DIRECT_CONTROL_RECONF_WRITE;
          state <= SET_PHY_RESET_OVERRIDE_START_STATE; 
        end else begin // wait until waitrequest clears
          state <= SET_PHY_RESET_OVERRIDE_DATA_STATE;
        end
      end
      SET_PHY_RESET_OVERRIDE_START_STATE: begin // override the PHY reset via the soft-CSR
        if (~mutex_waitrequest_from_base) begin
          master_read <= 1'b0;
          master_write <= 1'b1;
          master_address <= ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR; // status and control word
          master_write_data <= XR_DIRECT_OFFSET_TESTBUS_SEL; // write to get testbus
          state <= GET_TESTBUS_ADDR_STATE; 
        end else begin // wait until waitrequest clears
          state <= SET_PHY_RESET_OVERRIDE_START_STATE;
        end
      end
      GET_TESTBUS_ADDR_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          master_address <= ADDR_XCVR_RECONFIG_BASIC_DATA;
          master_write_data <= 16'b110; // set testbus to 4'b0110 for offset cancellation
          master_write <= 1'b1; // send address to alt_dprio
          master_read <= 1'b0;
          state <= GET_TESTBUS_DATA_STATE;
        end else begin // wait until waitrequest clears
          state <= GET_TESTBUS_ADDR_STATE;
        end
      end
      GET_TESTBUS_DATA_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL;
          master_write_data <= XR_DIRECT_CONTROL_INTERNAL_WRITE;
          master_write <= 1'b1; // send address to alt_dprio
          master_read <= 1'b0;
          state <= SET_OC_CALEN_ADDR_STATE;
        end else begin // wait until waitrequest clears
          state <= GET_TESTBUS_DATA_STATE;
        end
      end

      SET_OC_CALEN_ADDR_STATE: begin // set address to hardoc_calen internal register
        if (~mutex_waitrequest_from_base) begin
          master_read <= 1'b0;
          master_write <= 1'b1;
          master_address <= ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR; // status and control word
          master_write_data <= AV_XR_LOCAL_OFFSET + AV_XR_ADDR_OC;// write to get hardoc_calen register
          state <= SET_OC_CALEN_DATA_STATE;
        end else begin
          state <= SET_OC_CALEN_ADDR_STATE;
        end
      end 
      SET_OC_CALEN_DATA_STATE: begin // prepare data to enable oc_calen
        if (~mutex_waitrequest_from_base) begin
          master_address <= ADDR_XCVR_RECONFIG_BASIC_DATA;
          master_write_data <= AV_XR_OC_CALEN_MASK; //set the lowest bit to 1'b1 to enable oc_calen
          master_write <= 1'b1; // send address to alt_dprio
          master_read <= 1'b0;
          state <= START_OC_CALEN_STATE;
        end else begin // wait until waitrequest clears
          state <= SET_OC_CALEN_DATA_STATE;
        end
      end
      START_OC_CALEN_STATE: begin // kick off indirect operation
        if (~mutex_waitrequest_from_base) begin
          master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL;
          master_write_data <= XR_DIRECT_CONTROL_RECONF_WRITE;
          master_write <= 1'b1; // send address to alt_dprio
          master_read <= 1'b0;
          state <= ADDRESS_OFFSET_STATE;
        end else begin // wait until waitrequest clears
          state <= START_OC_CALEN_STATE;
        end
      end
      ADDRESS_OFFSET_STATE: begin // send address offset to alt_dprio
        if (~mutex_waitrequest_from_base) begin
          master_address <= ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR;
          master_write_data <= {{17{1'b0}}, alt_cal_dprio_addr[14:0]};
          master_write <= 1'b1;
          master_read <= 1'b0;
          if(write_read_control == 1'b1) begin
            state <= WRITE_DATA_STATE;
          end else begin
            state <= CONTROL_STATE;
          end
        end else begin
          state <= ADDRESS_OFFSET_STATE;
        end
      end
      WRITE_DATA_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          master_address <= ADDR_XCVR_RECONFIG_BASIC_DATA;
          master_write_data <= {{16{1'b0}}, alt_cal_dprio_dataout};
          master_write <= 1'b1; // send address to alt_dprio
          master_read <= 1'b0;
          state <= CONTROL_STATE;
        end else begin // wait until waitrequest clears
          state <= WRITE_DATA_STATE; 
        end
      end
      CONTROL_STATE: begin // sending write/read command
        if (~mutex_waitrequest_from_base) begin
            master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL; // get ready to send control command to alt_dprio
            master_write_data <= write_read_control ? XR_DIRECT_CONTROL_RECONF_WRITE : XR_DIRECT_CONTROL_RECONF_READ; // write_read_control == 0 is a read
            master_write <= 1'b1;
            master_read <= 1'b0;
            state <= BUSY_STATE;
        end else begin
          state <= CONTROL_STATE;
        end
      end

      BUSY_STATE: begin // wait for write done
        if(~mutex_waitrequest_from_base) begin // irq is deprecated - the basic now blocks (using waitrequest) until the operation is done
          alt_cal_dprio_busy <= 1'b1;
          if(write_read_control == 1'b0) begin //read
            master_address <= ADDR_XCVR_RECONFIG_BASIC_DATA; // get the data from the DPRIO result register
            master_write <= 1'b0;
            master_read <= 1'b1;
            alt_cal_dprio_busy <= 1'b1;
            state <= READ_DATA_STATE;
          end else begin
            master_write <= 1'b0;
            master_read <= 1'b0;
            state <= WRITE_DONE_STATE; // nothing to clean up for write state
          end
        end else begin
          alt_cal_dprio_busy <= 1'b1;
          state <= BUSY_STATE;
        end
      end
      WRITE_DONE_STATE: begin
        alt_cal_dprio_busy <= 1'b0; // clear the dprio operation
        master_read <= 1'b0;
        master_write <= 1'b0;
        master_address <= 3'h0; 
        master_write_data <= 32'b0;
        state <= WAIT_FOR_NEXT_STATE;
      end
      READ_DATA_STATE: begin
        if (~mutex_waitrequest_from_base) begin // make sure read was accepted
          alt_cal_dprio_datain <= master_read_data[15:0];
          alt_cal_dprio_busy <= 1'b0;
          master_read <= 1'b0;
          master_write <= 1'b0;
          master_address <= 3'h0; 
          master_write_data <= 32'b0; // write to clear physical mutex
          state <= WAIT_FOR_NEXT_STATE;
        end else begin
          state <= READ_DATA_STATE;
        end
      end
      WAIT_FOR_NEXT_STATE: begin // wait here for next operation, or else wait for busy to drop and then release the physical mutex
        if (~alt_cal_busy) begin // oc is done - clear the mutex
          master_read <= 1'b0;
          master_write <= 1'b1;
          master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL; // status and control word
          master_write_data <= XR_DIRECT_CONTROL_PHYS_LOCK_CLEAR; // write to clear physical mutex
          state <= RELEASE_PMUTEX_STATE; // release the physical mutex
        end else begin 
          if((alt_cal_dprio_wren == 1'b1) || (alt_cal_dprio_rden == 1'b1)) begin
            if(alt_cal_dprio_wren == 1'b1) begin
              write_read_control <= 1'b1; // 1 for write
            end else begin
              write_read_control <= 1'b0; // 0 for read
            end
            if ({alt_cal_quad_addr, alt_cal_dprio_addr[13:12]} != prev_logical_channel[10:0]) begin // different channel - we need to release the mutex and unset offset cancellation mode
              master_read <= 1'b0;
              master_write <= 1'b1;
              master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL; // status and control word
              master_write_data <= XR_DIRECT_CONTROL_PHYS_LOCK_CLEAR; // write to clear physical mutex
              state <= RELEASE_PMUTEX_STATE; // release the physical mutex
            end else begin // same channel - continue 
              state <= LOGICAL_ADDRESS_STATE; // need to change to request arbiter lock
              master_write <= 1'b1; // next step is to send address to alt_dprio
              master_address <= ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL;
              master_write_data <= {{21{1'b0}}, alt_cal_quad_addr, alt_cal_dprio_addr[13:12]}; // the logical channel is just sent as is - we can revise alt_cal_sv.v to account for this, but leave it for now - fix me!
            end
          end else begin
            state <= WAIT_FOR_NEXT_STATE;
          end
        end
      end
      RELEASE_PMUTEX_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          pmutex_acquired <= 1'b0; // clear the mutex flag
          master_read <= 1'b0;
          master_write <= 1'b1;
          master_address <= ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR;
          master_write_data <= AV_XR_LOCAL_OFFSET + AV_XR_ADDR_RSTCTL; // phy reset override control
          state <= RELEASE_PHY_RESET_OVERRIDE_ADDR_STATE;
        end else begin
          state <= RELEASE_PMUTEX_STATE;
        end
      end 

      RELEASE_PHY_RESET_OVERRIDE_ADDR_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          master_read <= 1'b0;
          master_write <= 1'b1;
          master_address <= ADDR_XCVR_RECONFIG_BASIC_DATA;
          master_write_data <= (0 << AV_XR_RSTCTL_RX_RST_OVR_OFST) | (0 << AV_XR_RSTCTL_RX_ANALOG_RST_N_VAL_OFST); // release reset override
          state <= RELEASE_PHY_RESET_OVERRIDE_DATA_STATE;
        end else begin
          state <= RELEASE_PHY_RESET_OVERRIDE_ADDR_STATE;
        end
      end
      RELEASE_PHY_RESET_OVERRIDE_DATA_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          master_read <= 1'b0;
          master_write <= 1'b1;
          master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL;
          master_write_data <= XR_DIRECT_CONTROL_RECONF_WRITE;
          state <= RELEASE_PHY_RESET_OVERRIDE_START_STATE;
        end else begin
          state <= RELEASE_PHY_RESET_OVERRIDE_DATA_STATE;
        end
      end
      RELEASE_PHY_RESET_OVERRIDE_START_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          master_read <= 1'b0;
          master_write <= 1'b1;
          master_address <= ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR; // status and control word
          master_write_data <= AV_XR_LOCAL_OFFSET + AV_XR_ADDR_OC; // write to get hardoc_calen register
          state <= RELEASE_OC_CALEN_DATA_STATE;
        end else begin
          state <= RELEASE_PHY_RESET_OVERRIDE_START_STATE;
        end
      end
      RELEASE_OC_CALEN_DATA_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          master_address <= ADDR_XCVR_RECONFIG_BASIC_DATA;
          master_write_data <= 16'b0; //set the lowest bit to 1'b0 to disable oc_calen
          master_write <= 1'b1; // send address to alt_dprio
          master_read <= 1'b0;
          state <= RELEASE_OC_CALEN_START_STATE;
        end else begin // wait until waitrequest clears
          state <= RELEASE_OC_CALEN_DATA_STATE;
        end
      end
      RELEASE_OC_CALEN_START_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          master_address <= ADDR_XCVR_RECONFIG_BASIC_CONTROL;
          master_write_data <= XR_DIRECT_CONTROL_RECONF_WRITE;
          master_write <= 1'b1; // send address to alt_dprio
          master_read <= 1'b0;
          state <= RELEASE_OC_CALEN_DONE_STATE; 
        end else begin // wait until waitrequest clears
          state <= RELEASE_OC_CALEN_START_STATE;
        end
      end
      RELEASE_OC_CALEN_DONE_STATE: begin
        if (~mutex_waitrequest_from_base) begin
          master_write <= 1'b0; // send address to alt_dprio
          master_read <= 1'b0;
          state <= IDLE_STATE; 
        end else begin // wait until waitrequest clears
          state <= RELEASE_OC_CALEN_DONE_STATE;
        end
      end

// need to add a state to release the reset override here

      default: begin
        state <= IDLE_STATE;
      end
    endcase
  end
end


  alt_cal_av #(
    .number_of_channels (number_of_reconfig_interfaces), // updated for AV - one reconfig interface is one channel
    .channel_address_width (CLogB2(number_of_reconfig_interfaces)),
    .pma_base_address (0) // for now it's 0 - we can override if it changes later
  )alt_cal_inst
  (
  .clock(reconfig_clk),
  .reset(reset),
  .start(start_trigger), // start bit written - rising edge triggers start (note - no effect if OC already running)
  .busy(alt_cal_busy),
  .dprio_addr(alt_cal_dprio_addr), // only extract the logical channel address
  .quad_addr(alt_cal_quad_addr),
  .dprio_dataout(alt_cal_dprio_dataout),
  .dprio_datain(alt_cal_dprio_datain),
  .dprio_wren(alt_cal_dprio_wren),
  .dprio_rden(alt_cal_dprio_rden),
  .dprio_busy(alt_cal_dprio_busy),
  .remap_addr(alt_cal_remap_addr),
  .testbuses(testbus_data)
  );


alt_arbiter_acq #(
  .addr_width(3),
  .data_width(32)
)
mutex_inst (
  .clk(reconfig_clk),
  .reset(reset),
// inputs to the base that should be routed through the mutex
  .address(master_address),
  .writedata(master_write_data),
  .write(master_write),
  .read(master_read),
// output from the mutex which is processed form of output from base
  .waitrequest(mutex_waitrequest_from_base),
  .readdata(master_read_data),

// outputs from mutex to be routed to the base
  .master_address(offset_cancellation_address_base),
  .master_writedata(offset_cancellation_writedata_base),
  .master_write(offset_cancellation_write_base),
  .master_read(offset_cancellation_read_base),

// these ports are from the base routed to the mutex
  .master_waitrequest(offset_cancellation_waitrequest_from_base),
  .master_readdata(offset_cancellation_readdata_base),      // from MM

//request signal to the mutex    should be kept high as long as the mutex is being used
  .mutex_req(req_and_use_mutex),
// output from mutex indicates whether you have mutex or not
  .mutex_grant(mutex_grant),
// external arbiter connections for fabric access
  .arb_req(arb_req),
  .arb_grant(arb_grant)
);

endmodule

