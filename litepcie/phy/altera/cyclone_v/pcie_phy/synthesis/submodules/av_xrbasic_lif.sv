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
// Logical-side interface for transceiver reconfig 'basic' block
// Before merging, each 'basic' block will have only 1 logical-side interface
//
// $Header$
//

`timescale 1 ns / 1 ns

(* ALTERA_ATTRIBUTE = {"suppress_da_rule_internal=\"C101,C103,C104\""} *) module av_xrbasic_lif #(
  parameter logical_interface = 0,  // which single logical interface is this?
  parameter native_ifs = 1, // number of native reconfig interfaces
  parameter w_paddr = 12,   // width of physical avalon reconfig address (upper bit selects soft or hard dprio)
  parameter physical_channel_mapping = ""
) (
  // avalon clock interface
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
  //output reg  basic_reconfig_irq, // interrupt to Master

  // Testbus control and data outputs (to physical interface)
  output wire [native_ifs*12 -1:0] pif_testbus_sel, // 4 bits per physical channel
  // Testbus inputs (from physical interface)
  input  wire [native_ifs*3*8-1:0] pif_testbus, // testbus from native reconfig, for all physical interfaces
    
  // Logical interface outputs (to basic block clients)
  output wire [7:0]     lch_testbus,  // testbus from native reconfig, for selected channel
  output wire [3*8-1:0] pch_testbus,  // testbus from native reconfig, for all three channels
  
  
  // physical interface arbiter connections
  output wire [native_ifs        -1:0] pif_arb_req,
  input  wire [native_ifs        -1:0] pif_arb_grant,
  
  // avalon MM native reconfiguration interfaces
  input  wire [native_ifs*16     -1:0] native_reconfig_readdata, // Avalon DPRIO readdata
  output wire [native_ifs*16     -1:0] native_reconfig_writedata, // Avalon DPRIO writedata
  output wire [native_ifs*w_paddr-1:0] native_reconfig_address,  // Avalon DPRIO address
  output wire [native_ifs        -1:0] native_reconfig_write,  // Avalon DPRIO write
  output wire [native_ifs        -1:0] native_reconfig_read  // Avalon DPRIO read
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
  import altera_xcvr_functions::*;

  localparam logical_chs = (native_ifs > 32 ? native_ifs : 32); // number of logical channels that can be supported in one basic reconfig interface
  localparam w_lch = ceil_log2(logical_chs);  // bits needed to represent logical channels and logical or physical interfaces
  localparam w_pif = ceil_log2(native_ifs > 1 ? native_ifs : 2);  // bits needed to represent physical interfaces
  localparam w_pch = 3; // 8 physical channels numbers are enough to represent: 3 real channels, 1 LC PLL, and 1 virtual PLL
  localparam w_ptbus = 3*8; // 8 bits per physical channel, 3 phys ch per phys interface
    
  // ports of the logical interface CSR block
  wire               csr_plock;
  wire [32     -1:0] csr_rwdata;
  wire [16     -1:0] mux_csr_rwdata;
  reg                upper_16_sel /* synthesis keep */;
  wire [w_lch  -1:0] lif_number;  // Selected logical interface number
  wire [w_pif  -1:0] pif_number;  // physical interface number for current logical channel
  wire [w_pch  -1:0] pch_number;  // phys channel number (within a phys interface) for the current logical channel
  wire [16     -1:0] reco_rdata;
  wire               reco_read;
  wire               reco_write;
  wire [w_paddr-1:0] reco_addr;

  // CSR testbus controls
  wire [3:0] csr_testbus_sel;

  // Decode pif_number into individual pif enable signals
  reg  [native_ifs-1:0] pif_ena;
  reg  [native_ifs-1:0] lif_ena;
  wire [native_ifs-1:0] pif_ena_wire;
  reg  [native_ifs-1:0] lif_ena_wire;
  wire [native_ifs-1:0] pif_enabled_and_granted;
  wire [native_ifs-1:0] lif_enabled_and_granted;
  wire [native_ifs-1:0] sel_enabled_and_granted;

  // logical interface CSR block, includes channel and address remapping
  av_xrbasic_lif_csr #(
    .logical_interface(logical_interface),
    .native_ifs(native_ifs),
    .w_lch(w_lch),
    .w_pif(w_pif),
    .w_pch(w_pch),
    .w_paddr(w_paddr)
  ) lif_csr (
    .reconfig_clk(reconfig_clk),
    .reset(reset),
    .lif_is_active(lif_is_active),

    // basic reconfig, Avalon memory-mapped interface
    .basic_reconfig_write(basic_reconfig_write),
    .basic_reconfig_read(basic_reconfig_read),
    .basic_reconfig_writedata(basic_reconfig_writedata),
    .basic_reconfig_address(basic_reconfig_address),
    .basic_reconfig_readdata(basic_reconfig_readdata),
    .basic_reconfig_waitrequest(basic_reconfig_waitrequest),

    // data, address, and control needed by physical interfaces
    .lif_number(lif_number),
    .pif_number(pif_number),
    .pch_number(pch_number),
    .reg_rwdata(csr_rwdata),
    .plock_get(csr_plock),
    .plock_granted(|pif_enabled_and_granted), // 0 or 1 bits will be '1', indicating plock grant status
    // Control signals
    .testbus_sel(csr_testbus_sel),
    // reconfig interface signals
    .reco_rdata(reco_rdata),
    .reco_read(reco_read),
    .reco_write(reco_write),
    .reco_addr(reco_addr) 
  );

  //Create a dummy mux to allow fitter connectivity to all 32 L2P ROM bits
  always @(posedge reconfig_clk or posedge reset) begin
    if(reset)
      upper_16_sel <= 1'b0;
    else
      upper_16_sel <= 1'b0;
  end

  assign mux_csr_rwdata = upper_16_sel ? csr_rwdata[31:16] : csr_rwdata[15:0]; 


  /////////////////////////////////////////////////////////
  // Physical Interface Decoder
  //

  genvar pi;
  generate
    for (pi=0; pi < native_ifs; ++pi) begin: pifena
      assign pif_ena_wire[pi] = (pif_number == pi);
      assign lif_ena_wire[pi] = (lif_number == pi);
    end
  endgenerate
  
  // register pif decoder output
  initial begin
    pif_ena = 0;
    lif_ena = 0;
  end
  always @(posedge reconfig_clk) begin
    pif_ena <= pif_ena_wire;
    lif_ena <= lif_ena_wire;
  end

  // request signals for pif arbiters.  Request when phys.lock set in CSR, and pif selected for current logical ch
  assign pif_arb_req = (pif_ena & {native_ifs{csr_plock}});

  // pif is selected for current logical ch, and grant received from pif arbiter
  assign pif_enabled_and_granted = (pif_ena & pif_arb_grant);
  // Grant logical interface. If the physical is granted then assume logical is as well
  assign lif_enabled_and_granted = lif_ena;// & {native_ifs{|pif_enabled_and_granted}};
  // Upper most address bits select logical vs. physical interface for Avalon bus
  assign sel_enabled_and_granted = lif_enabled_and_granted & {native_ifs{reco_addr[w_paddr-1]}}
                                  | pif_enabled_and_granted & {native_ifs{~reco_addr[w_paddr-1]}};

  /////////////////////////////////////////////////////////
  // Native (Physical) Interface controls
  //
  // Gate read, write, address, and data with 'pif_enabled_and_granted'
  wire [15:0]         reco_rdata_groups   [native_ifs-1:0];
  wire [w_ptbus-1:0]  pif_testbus_groups  [native_ifs-1:0]; // testbus from native reconfig, for all physical interfaces 

  // Triplet specific controls
  assign native_reconfig_read   = (sel_enabled_and_granted & {native_ifs{reco_read}});
  assign native_reconfig_write  = (sel_enabled_and_granted & {native_ifs{reco_write}});

  // Native Av DPRIO address & data, and phys interface testbus muxing
  generate
    for (pi=0; pi < native_ifs; ++pi) begin: pifgate
      // Triplet specific controls
      assign native_reconfig_address[w_paddr*pi +: w_paddr] = ({w_paddr{sel_enabled_and_granted[pi]}} & reco_addr);
      assign native_reconfig_writedata[16*pi +: 16] = ({16{sel_enabled_and_granted[pi]}} & mux_csr_rwdata[15:0]);
      assign pif_testbus_sel          [12*pi +: 12] = ({12{pif_enabled_and_granted[pi]}} & {3{csr_testbus_sel}});
      
      // readdata gated to '0' for all pifs that are not selected and granted
      // pif_testbus (all 3 pif channels) gated to '0' for all pifs that are not selected and granted
      // then OR'ed together to form a decoded-select mux
      if (pi == 0) begin
        // Triplet specific status
        assign reco_rdata_groups    [0] = native_reconfig_readdata[15:0] & {16{sel_enabled_and_granted[0]}};
        assign pif_testbus_groups   [0] = pif_testbus[w_ptbus-1:0] & {w_ptbus{pif_enabled_and_granted[0]}};
		  
      end
      else begin
        // Triplet specific status
        assign reco_rdata_groups    [pi] = reco_rdata_groups    [pi-1]  | native_reconfig_readdata[pi*16 +: 16] & {16{sel_enabled_and_granted[pi]}};
        assign pif_testbus_groups   [pi] = pif_testbus_groups   [pi-1]  | pif_testbus[pi*w_ptbus +: w_ptbus] & {w_ptbus{pif_enabled_and_granted[pi]}};
      end
    end
  endgenerate
  // Multi-bit status signals (output selected logical channel)
  assign reco_rdata       = reco_rdata_groups   [native_ifs-1]; // output of readdata mux

  // instantiate mux for selection of a single-lane testbus output, out of the 3 testbus lanes per pif
  csr_mux #(
      .groups(3),
      .grp_size(w_ptbus/3),
      .sel_size(w_pch)
  ) pif_tbus_mux (
    .in_wide(pif_testbus_groups[native_ifs-1]),
    .sel(pch_number),
    .out_narrow(lch_testbus)  // testbus for a single channel (current logical ch)
  );

  // Provide the full triplet testbus based on which Physical interface is enabled
  // Needed for LC and ATT calibration IPs
  assign pch_testbus = pif_testbus_groups[native_ifs-1];
endmodule

