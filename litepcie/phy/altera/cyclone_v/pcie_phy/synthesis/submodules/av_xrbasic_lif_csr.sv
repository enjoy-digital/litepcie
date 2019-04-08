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


//
// Control and status register for logical-side interface of transceiver reconfig 'basic' block
//
// $Header$
//

`timescale 1 ns / 1 ns

(* ALTERA_ATTRIBUTE = {"ALLOW_ANY_ROM_SIZE_FOR_RECOGNITION=ON;AUTO_ROM_RECOGNITION=ON;ALLOW_ANY_RAM_SIZE_FOR_RECOGNITION=ON;AUTO_RAM_RECOGNITION=ON"} *)
module av_xrbasic_lif_csr #(
  parameter logical_interface = 0,  // which single logical interface is this?
  parameter native_ifs = 1, // number of native reconfig interfaces
  parameter w_lch = 5,  // bits needed to represent logical channels and logical or physical interfaces
  parameter w_pif = 5,  // bits needed to represent physical interfaces
  parameter w_pch = 3,  // 8 physical channels numbers are enough to represent: 3 real channels, 1 LC PLL, and 1 virtual PLL
  parameter w_paddr = 12, // width of physical avalon reconfig address
  parameter w_rom = 32,
  parameter four_word_rom = 1,
  parameter physical_channel_mapping = ""
) (
  // avalon clock interface, and arbiter activity indicator
  input wire reconfig_clk,
  input wire reset,
  input wire lif_is_active,
  
  // avalon MM, "basic" interface
  input wire        basic_reconfig_write,
  input wire        basic_reconfig_read,
  input wire [31:0] basic_reconfig_writedata,
  input wire [ 2:0] basic_reconfig_address,     // address to MM described below
  
  output reg [31:0] basic_reconfig_readdata,
  output wire       basic_reconfig_waitrequest,

  // control outputs of CSR block
  output reg  [w_lch -1:0] lif_number,    // current logical channel
  output wire [w_pif -1:0] pif_number,    // physical interface number for current logical channel
  output wire [w_pch -1:0] pch_number,    // phys channel number (within a phys interface) for the current logical channel
  output reg  [32    -1:0] reg_rwdata,    // storage for indirect read/write data
  output wire              plock_get,     // attempt to lock physical interface, persistent value (stays until cleared)
  input  wire              plock_granted, // indicates current channel pif lock request is granted

  // Testbus control outputs
  output reg [ 3:0] testbus_sel,

  // FSM outputs, reconfig results
  output wire              reco_read, // read control for physical interface
  output reg               reco_write,  // write control for physical interface
  output reg [w_paddr-1:0] reco_addr, // address for physical (reconfig) reads & writes
  input wire [16     -1:0] reco_rdata // readdata from native reconfig
);



  // Memory Map for register indirection
  // word addr            wr/rd                description
  //    ------------------------------------------------------
  //      0               wr/rd               reserved
  //      1               wr/rd               logical_ch_addr (can be up to 10 bits)
  //      2                rd                 physical_chnl_map
  //      3               rd/wr               status/control -- see op-code definitions
  //      4               wr/rd               DPRIO addr_offset
  //      5               wr/rd               DPRIO data
  //      6                --                 reserved
  //      7                --                 reserved
  import alt_xcvr_reconfig_h::*;

  (* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
  reg   [w_lch  -1:0] reg_lch;  // storage for logical channel
  reg   [w_paddr-1:0] reg_addr; // storage for indirect address (for logical or physical reads & writes, and table lookup)
  wire  [1:0]         loc_addr; // address for local registers
  wire  [3:0]         opcode; // opcode from basic_reconfig_writedata
  
  // address auto-increment mode (set via ctrl op-code)
  (* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
  reg  reg_write_incr;  // when set, write to data register triggers a write, and increments address regs
  wire w_write_incr;    // indicates increment should happen on next rising edge  
  (* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
  reg  reg_is_phys_addr;  // when set, interpret RECO addr_offset as absolute address
  (* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
  reg  reg_plock; // attempt to lock physical interface, persistent value (stays until cleared)
  reg  lif_is_active_last = 0; // last state of lif_is_active input, for edge detection

  // From mapping tables
  wire [w_paddr-1:0] l2p_addr;  // physical addr calculated as logical offset addr + phys ch start addr

  wire [w_rom-1:0]  l2p_rom_word;
  wire [1:0]        l2p_word_sel;

  // waitrequest generation
  reg       lif_inwait; // captures state of lif_waitrequest in previous cycle, for edge detection
  reg       lif_wrwait; // additional waitrequest for logical ch write
  wire      lif_waitrequest;  // waitrequest to basic interface

  // native reconfig read/write FSM logic
  reg [2:0] reco_read_length_cntr;  // Av native reconfig reads have fixed latency of 3 cycles, and 'B' adds 2 more
  localparam RECO_READ_START_COUNT = 3'd6;  // assert native reconfig read when 6, 5, 4, 3
  localparam RECO_READ_CAPTURE_COUNT = 3'd2;  // capture native reconfig readdata when count is this value
  reg [1:0] reco_addr_load_cntr;  // count propagation delays through ctrl logic, to time when ready to load new reco_addr value
  localparam RECO_ADDR_LOAD_LCH_CHANGE = 2'd3; // cycles needed after logical ch change
  localparam RECO_ADDR_LOAD_OFFSET_CHANGE = 2'd2; // cycles needed after native addr offset change
  localparam RECO_ADDR_LOAD_IS_PHYS_CHANGE = 2'd1; // cycles needed after is_phys_addr bit change

  //XR_DIRECT_CONTROL_TABLE_READ    ROM table lookup, especially for PLL and clock mux remapping

  initial begin
    // output register
    basic_reconfig_readdata = 0;
    reg_lch = 0;  // storage for logical channel
    reg_addr = 0; // storage for indirect address (for logical or physical reads & writes, and table lookup)
    reg_rwdata = 0; // storage for indirect write data

    // mgmt interface FSM outputs
    reg_plock = 0;  // phys interface lock request
    reg_write_incr = 0; // auto-write-and-address-increment-on-data-write mode
    reg_is_phys_addr = 0; // when set, interpret RECO addr_offset as absolute address
    lif_inwait = 0; // capture last waitrequest state for edge detection
    lif_wrwait = 0; // additional waitrequest for logical ch write
    
    // native reconfig control registers
    reco_addr_load_cntr = 0;
    reco_addr = 0;
    reco_read_length_cntr = 0;
    reco_write = 0;
  end

  assign plock_get  = reg_plock;
  assign opcode     = basic_reconfig_writedata[3:0];  //opcode use should always be qualified basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_CONTROL

  ////////////////////////////////////////////
  // Memory-mapped register write interface
  ////////////////////////////////////////////

  // logical channel register
  always @(posedge reconfig_clk or posedge reset) begin
    if (reset == 1) begin
      reg_lch <= 0;
    end
    else if (basic_reconfig_write && basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL) begin
      // write from mgmt interface is only way to modify value
      reg_lch <= basic_reconfig_writedata[w_lch-1:0];
    end
  end

  // native reconfig address register, can be interpretted as channel offset address, or physical address
  always @(posedge reconfig_clk or posedge reset) begin
    if (reset == 1) begin
      reg_addr <= 0;
    end
    else if (basic_reconfig_write && basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR) begin
      reg_addr <= basic_reconfig_writedata[w_paddr-1:0];  // write from mgmt interface
    end
    else if (w_write_incr) begin
      reg_addr <= reg_addr + 1'b1;  // auto-increment write in progress
    end
  end

  // native reconfig data register, can be used to write data, or to get read data value after a read
  always @(posedge reconfig_clk or posedge reset) begin
    if (reset == 1) begin
      reg_rwdata <= 0;
    end
    else if (basic_reconfig_write && (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_DATA )) begin
      reg_rwdata <= basic_reconfig_writedata; // write from mgmt interface
    end
    //Look for CONTROL_TABLE_READ opcode and save L2P ROM content for a subsequent read from the Data register
    //use reg_addr as pointer
    else if (basic_reconfig_write && (opcode == XR_DIRECT_CONTROL_TABLE_READ) && (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_CONTROL)) begin
      reg_rwdata <= l2p_rom_word; //capture ROM L2P information
    end
    else if (reco_read_length_cntr == RECO_READ_CAPTURE_COUNT) begin
      reg_rwdata <= {16'd0,reco_rdata}; // output of native reconfig readdata for current phys interface
    end
    //else if (basic_reconfig_write & ~lif_inwait
    //    & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_CONTROL)
    //    & (opcode == CONTROL_INTERNAL_READ)
    //    & (reg_addr[0] == XR_DIRECT_OFFSET_TESTBUS_SEL)) begin
    //  reg_rwdata <= 32'd0 | testbus_sel;  // read testbus_sel value
    //end
  end

  // Control modes, set/cleared via control word opcodes, set/cleared on lif_is_active arbiter activity
  always @(posedge reconfig_clk or posedge reset) begin
    if (reset == 1) begin
      reg_plock <= 1'b0;
      reg_write_incr <= 1'b0;
      reg_is_phys_addr <= 1'b0;
    end
    else if (basic_reconfig_write && basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_CONTROL) begin
      // Request to set or clear phys interface lock
      if (opcode == XR_DIRECT_CONTROL_PHYS_LOCK_CLEAR)
        reg_plock <= 1'b0;
      else if (opcode == XR_DIRECT_CONTROL_PHYS_LOCK_SET)
        reg_plock <= 1'b1;

      // Request to set or clear auto-address-increment on data write
      if (opcode == XR_DIRECT_CONTROL_ADDR_AUTO_INCR_CLEAR)
        reg_write_incr <= 1'b0;
      else if (opcode == XR_DIRECT_CONTROL_ADDR_AUTO_INCR_SET)
        reg_write_incr <= 1'b1;

      // Request to set or clear physical address bit, to interpret RECO_ADDR as absolute addr
      if (opcode == XR_DIRECT_CONTROL_LADDR_SET)
        reg_is_phys_addr <= 1'b0;
      else if (opcode == XR_DIRECT_CONTROL_PADDR_SET)
        reg_is_phys_addr <= 1'b1;
    end
    else if (lif_is_active_last == 0) begin // reset state when B lock released
      reg_plock <= lif_is_active; // auto-set pif lock bit when B is acquired, clear when released
      reg_write_incr <= 1'b0;
      reg_is_phys_addr <= 1'b0;
    end
  end

  // save last state of lif_is_active, to detect changes
  always @(posedge reconfig_clk)
    lif_is_active_last <= lif_is_active;

  // write increment: logic to detect address regs should increment
  assign w_write_incr = reg_write_incr & basic_reconfig_write & ~lif_inwait
             & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_DATA);



  ////////////////////////////////////////////
  // Memory-mapped register read interface
  ////////////////////////////////////////////

  always @(posedge reconfig_clk or posedge reset) begin
    if (reset == 1) begin
      basic_reconfig_readdata <= 0;

      // variable logical interface waitrequest generation
      lif_wrwait <= 0;  // extra wait states for writes that take multiple cycles for data to propagate through internal logic
      lif_inwait <= 0;  // capture last waitrequest state for edge detection
    end
    else begin
      lif_inwait <= lif_waitrequest;  // capture last waitrequest state for edge detection
      lif_wrwait <= ~lif_inwait & basic_reconfig_write
        & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL); // logical ch write needs 2 cycles to propagate through FSM

      // decode readdata output for each supported address
      // writes are decoded separately, since most registers can be written both
      // through internal FSM paths, as well as through the mgmt interface

      case (basic_reconfig_address)
      // logical channel number
      ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL:   basic_reconfig_readdata <= (32'd0 | reg_lch);
      // physical channel mapping for current logical channel
      ADDR_XCVR_RECONFIG_BASIC_PHYSICAL_CHANNEL:  basic_reconfig_readdata <= (32'd0 | {pif_number, 3'd0 | pch_number});
      // status word
      //   on read, 0: phys.lock.granted - no native reconfig reads or writes get through while plock_granted is 0
      ADDR_XCVR_RECONFIG_BASIC_CONTROL:           basic_reconfig_readdata <= (32'd0
                              | {32{plock_granted}}    & XR_DIRECT_STATUS_BITMASK_PHYS_LOCK_GRANTED
                              | {32{reg_plock}}        & XR_DIRECT_STATUS_BITMASK_PHYS_LOCK_REQUESTED
                              | {32{reg_is_phys_addr}} & XR_DIRECT_STATUS_BITMASK_USING_PHYS_ADDR
                              | {32{reg_write_incr}}   & XR_DIRECT_STATUS_BITMASK_USING_ADDR_AUTO_INCR);
      // indirect address register
      ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR:  basic_reconfig_readdata <= (32'd0 | reg_addr);
      // indirect data register
      ADDR_XCVR_RECONFIG_BASIC_DATA:         basic_reconfig_readdata <= (32'd0 | reg_rwdata);
      default:                               basic_reconfig_readdata <= ~ 32'd0;  // use too many LEs?
      endcase
    end
  end

  // generate waitrequest for all reads, and for select writes
  assign lif_waitrequest = 
    // 2 cycles for write to logical channel
    // 2 cycles for write to native reconfig offset address
    // 1 cycle  for write to is_phys_addr bit
    // 0 cycles for other writes
        basic_reconfig_write & (~lif_inwait | lif_wrwait) & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL)
      | basic_reconfig_write & ~lif_inwait & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR)
    // 1 cycle  for all reads, except
    // (variable) for read of native reconfig data after issuing a READ opcode
      | basic_reconfig_read & ~lif_inwait
      | basic_reconfig_read & (reco_read_length_cntr != 3'd0) & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_DATA);

  assign basic_reconfig_waitrequest = lif_waitrequest;  // show wait on basic (logical) interface


  ////////////////////////////////////////////
  // Internal register write interface,
  // mainly for testbus control
  ////////////////////////////////////////////
  // Local control registers
  initial begin
    // Testbus control registers
    testbus_sel           = 4'd0;
  end

  assign  loc_addr  = reg_addr[1:0];
  // testbus_sel control
  always @(posedge reconfig_clk or posedge reset) begin
    if (reset == 1)
      testbus_sel           <= 4'd0;
    else if (basic_reconfig_write & ~lif_inwait
          & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_CONTROL)
          & (opcode == XR_DIRECT_CONTROL_INTERNAL_WRITE)
          & (loc_addr == XR_DIRECT_OFFSET_TESTBUS_SEL) )
            testbus_sel           <= reg_rwdata[3:0]; // set testbus_sel output from data reg
  end



  //////////////////////////////////////////
  // native reconfig read/write FSM logic
  //////////////////////////////////////////

  // native reconfig write control
  always @(posedge reconfig_clk or posedge reset) begin
    if (reset == 1)
      reco_write <= 0;
    else if (basic_reconfig_write & ~lif_inwait
        & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_CONTROL)
        & (opcode == XR_DIRECT_CONTROL_RECONF_WRITE)) begin
      reco_write <= 1'b1; // from control opcode for logical or physical write
    end
    else if (w_write_incr)
      reco_write <= 1'b1; // from native reconfig data auto-write-and-increment mode
    else
      reco_write <= 0;  // clear all other cycles
  end

  // native reconfig read control (sequence counter)
  always @(posedge reconfig_clk or posedge reset) begin
    if (reset == 1)
      reco_read_length_cntr <= 0;
    else if (basic_reconfig_write & ~lif_inwait
        & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_CONTROL)
        & (opcode == XR_DIRECT_CONTROL_RECONF_READ)) begin
      reco_read_length_cntr <= RECO_READ_START_COUNT; // from control opcode for logical or physical read
    end
    else if (reco_read_length_cntr != 0)
      // decrement reco_read_length_cntr until it reaches 0, ending a read cycle
      reco_read_length_cntr <= reco_read_length_cntr - 3'b1;
  end


  // native reconfig read control to native interface
  assign reco_read  = ( reco_read_length_cntr > RECO_READ_CAPTURE_COUNT); // read control for physical interface

  // native reconfig address load counter, triggers update after an input change
  always @(posedge reconfig_clk or posedge reset) begin
    if (reset == 1)
      reco_addr_load_cntr <= 0;
    else if (basic_reconfig_write & ~lif_inwait
        & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL)) begin
      reco_addr_load_cntr <= RECO_ADDR_LOAD_LCH_CHANGE; // cycles needed after logical ch change
    end
    else if (basic_reconfig_write & ~lif_inwait
        & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR)) begin
      reco_addr_load_cntr <= RECO_ADDR_LOAD_OFFSET_CHANGE; // cycles needed after native addr offset change
    end
    else if (basic_reconfig_write & ~lif_inwait
        & (basic_reconfig_address == ADDR_XCVR_RECONFIG_BASIC_CONTROL)
        & (   opcode == XR_DIRECT_CONTROL_LADDR_SET
           || opcode == XR_DIRECT_CONTROL_PADDR_SET)) begin
      reco_addr_load_cntr <= RECO_ADDR_LOAD_IS_PHYS_CHANGE; // cycles needed after is_phys_addr bit change
    end
    else if (reco_addr_load_cntr != 0)
      // decrement reco_addr_load_cntr until it reaches 0, ending a reco_addr refresh
      reco_addr_load_cntr <= reco_addr_load_cntr - 2'b1;
  end

  // native reconfig address
  always @(posedge reconfig_clk or posedge reset) begin
    if (reset == 1)
      reco_addr <= 0;
    else if (reco_addr_load_cntr == 2'd1 & (reg_is_phys_addr | reg_addr[w_paddr-1]))
      reco_addr <= reg_addr;  // physical read or write opcode, use address reg without offset
    else if (reco_addr_load_cntr == 2'd1 & ~reg_is_phys_addr)
      reco_addr <= l2p_addr;  // logical read or write opcode, use address with ch start offset
    else if (reg_write_incr & reco_write)
      reco_addr <= reco_addr + 1'b1; // from native reconfig data auto-write-and-increment mode
  end


  //////////////////////////////////////////////////////
  // Look-up tables for channel and address translation
  //////////////////////////////////////////////////////

  // Logical to logical mapping
  always @(posedge reconfig_clk or posedge reset)
    if(reset == 1)
      lif_number <= {w_lch{1'b0}};
    else
      lif_number <= reg_lch;


  assign l2p_word_sel = reg_addr[1:0];

  // Logical channel mapping to physical interface number and channel number
generate if(four_word_rom == 1) begin
  //New four word/channel ROM structure
  av_xrbasic_l2p_rom #(
    .logical_interface(logical_interface),  // which logical interface is the mapping for?
    .native_ifs(native_ifs),
    .w_word(2),
    .w_rom(w_rom),
    .w_lch(w_lch),  // bits needed to represent logical channel numbers
    .w_pif(w_pif),  // bits needed to represent physical interface numbers
    .w_pch(w_pch),  // bits needed to represent physical channel numbers (within a phys interface)
    .physical_channel_mapping(physical_channel_mapping) // string notation to define logical-to-physical channel mapping
  ) l2pch (
    .clk(reconfig_clk),
    .logical_ch(reg_lch), // logical channel input
    .l2p_word_sel(l2p_word_sel),
    .l2p_rom_data(l2p_rom_word),
    .physical_if(pif_number), // physical interface output
    .physical_ch(pch_number)  // physical channel output (offset within a physical interface)
  );
end 
else begin
  //old ROM stucture
  av_xrbasic_l2p_ch #(
    .logical_interface(logical_interface),  // which logical interface is the mapping for?
    .native_ifs(native_ifs),
    .w_lch(w_lch),  // bits needed to represent logical channel numbers
    .w_pif(w_pif),  // bits needed to represent physical interface numbers
    .w_pch(w_pch),  // bits needed to represent physical channel numbers (within a phys interface)
    .physical_channel_mapping(physical_channel_mapping) // string notation to define logical-to-physical channel mapping
  ) l2pch (
    .clk(reconfig_clk),
    .logical_ch(reg_lch), // logical channel input
    .physical_if(pif_number), // physical interface output
    .physical_ch(pch_number)  // physical channel output (offset within a physical interface)
  );

  assign l2p_rom_word = 32'd0;
end
endgenerate


  // Logical address offset mapping to physical address
  av_xrbasic_l2p_addr #(
    .w_pch(w_pch),  // bits needed to represent physical channel numbers (within a phys interface)
    .w_paddr(w_paddr) // bits needed to represent physical addresses
  ) l2paddr (
    .clk(reconfig_clk),
    .offset_addr(reg_addr), // logical channel offset address input
    .physical_ch(pch_number),   // physical channel input
    .physical_addr(l2p_addr)  // physical address output
  );

endmodule
