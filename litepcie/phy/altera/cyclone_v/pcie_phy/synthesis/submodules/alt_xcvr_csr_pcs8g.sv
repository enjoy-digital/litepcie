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
// Common control & status register map for transceiver PHY IP
// Applies to Stratix V-generation basic PHY components
//
// $Header$
//

`timescale 1 ns / 1 ns

module alt_xcvr_csr_pcs8g #(
  parameter lanes = 1,
  parameter words = 2,   // for status bits that are per-word, like 8B10B status
  parameter boundary_width = 5
)
(
  // user data (avalon-MM formatted) 
  input   wire          clk,
  input   tri0          reset,
  input   wire  [7:0]   address,
  input   tri0          read,
  output  reg   [31:0]  readdata = 0,
  input   tri0          write,
  input   wire  [31:0]  writedata,

  input   wire          rx_clk, // to synchronize rx control outputs
  input   wire          tx_clk, // to synchronize tx control outputs

  // transceiver status inputs to this CSR
  input wire [lanes*words - 1 : 0]  rx_patterndetect,
  input wire [lanes*words - 1 : 0]  rx_syncstatus,
  input wire [lanes*words - 1 : 0]  rx_errdetect,
  input wire [lanes*words - 1 : 0]  rx_disperr,
  input wire [lanes - 1 : 0]        rx_phase_comp_fifo_error,
  input wire [lanes - 1 : 0]        tx_phase_comp_fifo_error,
  input wire [lanes*boundary_width - 1: 0]       rx_bitslipboundaryselectout,
  input wire [lanes - 1 : 0]        rlv,
  input wire [lanes*words - 1 : 0]  rx_a1a2sizeout,
  
  // read/write control outputs
  // PCS controls
  output  wire [lanes - 1 : 0]    csr_tx_invpolarity,
  output  wire [lanes*boundary_width - 1 : 0]  csr_tx_bitslipboundaryselect,
  output  wire [lanes - 1 : 0]    csr_rx_invpolarity,
  output  wire [lanes - 1 : 0]    csr_rx_enapatternalign,
  output  wire [lanes - 1 : 0]    csr_rx_bitreversalenable,
  output  wire [lanes - 1 : 0]    csr_rx_bytereversalenable,
  output  wire [lanes - 1 : 0]    csr_rx_bitslip,
  output  wire [lanes - 1 : 0]    csr_rx_a1a2size
);
  import alt_xcvr_csr_common_h::*;
  import alt_xcvr_csr_pcs8g_h::*;
  
  localparam sync_stages = 2; // number of sync stages for transceiver status signals
  localparam sync_stages_str  = sync_stages[7:0] + 8'd48; // number of sync stages specified as string (for timing constraints)
  localparam LANE_REGW = 5;

  // Parameter strings for embedded timing constraints
  localparam  SYNC_RX_CONSTRAINT = {"-name SDC_STATEMENT \"set regs [get_registers -nowarn *alt_xcvr_csr_pcs8g*sync_rx_*[",sync_stages_str,"]*]; if {[llength [query_collection -report -all $regs]] > 0} {set_false_path -to $regs}\""};
  localparam  SYNC_TX_CONSTRAINT = {"-name SDC_STATEMENT \"set regs [get_registers -nowarn *alt_xcvr_csr_pcs8g*sync_tx_*[",sync_stages_str,"]*]; if {[llength [query_collection -report -all $regs]] > 0} {set_false_path -to $regs}\""};
  localparam  CSR_REG_CONSTRAINT = {"-name SDC_STATEMENT \"set regs [get_registers -nowarn *alt_xcvr_csr_pcs8g*csr_indexed_read_only_reg*sreg[",sync_stages_str,"]*]; if {[llength [query_collection -report -all $regs]] > 0} {set_false_path -to $regs}\""};
  localparam  SDC_CONSTRAINTS = {SYNC_RX_CONSTRAINT,";",SYNC_TX_CONSTRAINT,";",CSR_REG_CONSTRAINT};

  // internal registers
  reg  [LANE_REGW-1:0] reg_lane_number = 0; // lane or group number for indirection

  ////////////////////////////////////////////////////////
  // Read/Write CSR registers with lane indirection 
  ////////////////////////////////////////////////////////
  // Apply false path timing constraints to synchronization registers. (It does not matter as to which node these are applied).
  (* altera_attribute = SDC_CONSTRAINTS *)
  reg  [lanes - 1 : 0] reg_tx_invpolarity = 0;
  reg  [lanes - 1 : 0] sync_tx_invpolarity [sync_stages:1]; // synchronize to tx_clk
  wire [lanes - 1 : 0] write_tx_invpolarity;  // indexed write group muxed in
  wire [0 : 0] lane_tx_invpolarity; // selected group indexed for output
  csr_indexed_write_mux #(.groups(lanes), .grp_size(1), .sel_size(LANE_REGW), .init_value(0))
    wmux_tx_invpolarity(.in_narrow(writedata[0]), 
      .in_wide(reg_tx_invpolarity), .sel(reg_lane_number),
      .out_narrow(lane_tx_invpolarity), .out_wide(write_tx_invpolarity));
      
  reg  [lanes*boundary_width - 1 : 0] reg_tx_bitslipboundaryselect = 0;
  reg  [lanes*boundary_width - 1 : 0] sync_tx_bitslipboundaryselect [sync_stages:1]; //synchronize to tx_clk
  wire [lanes*boundary_width - 1 : 0] write_tx_bitslipboundaryselect; //indexed write group muxed in
  wire [boundary_width-1:0] lane_tx_bitslipboundaryselect; //selected group indexed for output
  csr_indexed_write_mux #(.groups(lanes), .grp_size(boundary_width), .sel_size(LANE_REGW), .init_value(0))
    wmux_tx_bitslipboundaryselect(.in_narrow(writedata[boundary_width:1]), 
      .in_wide(reg_tx_bitslipboundaryselect), .sel(reg_lane_number),
      .out_narrow(lane_tx_bitslipboundaryselect), .out_wide(write_tx_bitslipboundaryselect));

  reg  [lanes - 1 : 0] reg_rx_invpolarity = 0;
  reg  [lanes - 1 : 0] sync_rx_invpolarity [sync_stages:1]; // synchronize to rx_clk
  wire [lanes - 1 : 0] write_rx_invpolarity;  // indexed write group muxed in
  wire [0 : 0] lane_rx_invpolarity; // selected group indexed for output
  csr_indexed_write_mux #(.groups(lanes), .grp_size(1), .sel_size(LANE_REGW), .init_value(0))
    wmux_rx_invpolarity(.in_narrow(writedata[0]), 
      .in_wide(reg_rx_invpolarity), .sel(reg_lane_number),
      .out_narrow(lane_rx_invpolarity), .out_wide(write_rx_invpolarity));
    
  reg  [lanes - 1 : 0] reg_rx_enapatternalign = 0;
  reg  [lanes - 1 : 0] sync_rx_enapatternalign [sync_stages:1]; // synchronize to rx_clk
  wire [lanes - 1 : 0] write_rx_enapatternalign;  // indexed write group muxed in
  wire [0 : 0] lane_rx_enapatternalign; // selected group indexed for output
  csr_indexed_write_mux #(.groups(lanes), .grp_size(1), .sel_size(LANE_REGW), .init_value(0))
    wmux_rx_enapatternalign(.in_narrow(writedata[0]), 
      .in_wide(reg_rx_enapatternalign), .sel(reg_lane_number),
      .out_narrow(lane_rx_enapatternalign), .out_wide(write_rx_enapatternalign));
      
  reg  [lanes - 1 : 0] reg_rx_bitreversalenable = 0;
  reg  [lanes - 1 : 0] sync_rx_bitreversalenable [sync_stages:1]; // synchronize to rx_clk
  wire [lanes - 1 : 0] write_rx_bitreversalenable;  // indexed write group muxed in
  wire [0 : 0] lane_rx_bitreversalenable; // selected group indexed for output
  csr_indexed_write_mux #(.groups(lanes), .grp_size(1), .sel_size(LANE_REGW), .init_value(0))
    wmux_rx_bitreversalenable(.in_narrow(writedata[1]), 
      .in_wide(reg_rx_bitreversalenable), .sel(reg_lane_number),
      .out_narrow(lane_rx_bitreversalenable), .out_wide(write_rx_bitreversalenable));
  
  reg  [lanes - 1 : 0] reg_rx_bytereversalenable = 0;
  reg  [lanes - 1 : 0] sync_rx_bytereversalenable [sync_stages:1]; // synchronize to rx_clk
  wire [lanes - 1 : 0] write_rx_bytereversalenable; // indexed write group muxed in
  wire [0 : 0] lane_rx_bytereversalenable;  // selected group indexed for output
  csr_indexed_write_mux #(.groups(lanes), .grp_size(1), .sel_size(LANE_REGW), .init_value(0))
    wmux_rx_bytereversalenable(.in_narrow(writedata[2]), 
      .in_wide(reg_rx_bytereversalenable), .sel(reg_lane_number),
      .out_narrow(lane_rx_bytereversalenable), .out_wide(write_rx_bytereversalenable));
      
  reg  [lanes - 1 : 0] reg_rx_bitslip = 0;
  reg  [lanes - 1 : 0] sync_rx_bitslip [sync_stages:1]; // synchronize to rx_clk
  wire [lanes - 1 : 0] write_rx_bitslip;  // indexed write group muxed in
  wire [0 : 0] lane_rx_bitslip; // selected group indexed for output
  csr_indexed_write_mux #(.groups(lanes), .grp_size(1), .sel_size(LANE_REGW), .init_value(0))
    wmux_rx_bitslip(.in_narrow(writedata[3]), 
      .in_wide(reg_rx_bitslip), .sel(reg_lane_number),
      .out_narrow(lane_rx_bitslip), .out_wide(write_rx_bitslip));
      
  reg  [lanes - 1 : 0] reg_rx_a1a2size = 0;
  reg  [lanes - 1 : 0] sync_rx_a1a2size [sync_stages:1]; // synchronize to rx_clk
  wire [lanes - 1 : 0] write_rx_a1a2size; // indexed write group muxed in
  wire [0 : 0] lane_rx_a1a2size;  // selected group indexed for output
  csr_indexed_write_mux #(.groups(lanes), .grp_size(1), .sel_size(LANE_REGW), .init_value(0))
    wmux_rx_a1a2size(.in_narrow(writedata[3]), 
      .in_wide(reg_rx_a1a2size), .sel(reg_lane_number),
      .out_narrow(lane_rx_a1a2size), .out_wide(write_rx_a1a2size));

  ////////////////////////////////////////////////////////
  // Read-only CSR registers with lane indirection
  ////////////////////////////////////////////////////////
  // read-only status registers are synchronized forms of transceiver status signals
  // async inputs go to reg [sync_stages], and come out synchronized at reg [1]
  ////////////////////////////////////////////////////////
  // read selectors (muxes) that index using the indirect lane (group) number
  wire [words-1 : 0]  lane_rx_patterndetect;
  csr_indexed_read_only_reg #(.groups(lanes), .grp_size(words), .sel_size(LANE_REGW), .sync_stages(sync_stages))
    mux_rx_patterndetect(.clk(clk), .async_in_wide(rx_patterndetect),
      .sel(reg_lane_number), .out_narrow(lane_rx_patterndetect));

  wire [words-1 : 0]  lane_rx_syncstatus;
  csr_indexed_read_only_reg #(.groups(lanes), .grp_size(words), .sel_size(LANE_REGW), .sync_stages(sync_stages))
    mux_rx_syncstatus(.clk(clk), .async_in_wide(rx_syncstatus),
      .sel(reg_lane_number), .out_narrow(lane_rx_syncstatus));

  wire [words-1 : 0]  lane_rx_errdetect;
  csr_indexed_read_only_reg #(.groups(lanes), .grp_size(words), .sel_size(LANE_REGW), .sync_stages(sync_stages))
    mux_rx_errdetect(.clk(clk), .async_in_wide(rx_errdetect),
      .sel(reg_lane_number), .out_narrow(lane_rx_errdetect));

  wire [words-1 : 0]  lane_rx_disperr;
  csr_indexed_read_only_reg #(.groups(lanes), .grp_size(words), .sel_size(LANE_REGW), .sync_stages(sync_stages))
    mux_rx_disperr(.clk(clk), .async_in_wide(rx_disperr),
      .sel(reg_lane_number), .out_narrow(lane_rx_disperr));

  wire [words-1 : 0]  lane_rx_a1a2sizeout;
  csr_indexed_read_only_reg #(.groups(lanes), .grp_size(words), .sel_size(LANE_REGW), .sync_stages(sync_stages))
    mux_rx_a1a2sizeout(.clk(clk), .async_in_wide(rx_a1a2sizeout),
      .sel(reg_lane_number), .out_narrow(lane_rx_a1a2sizeout));
  
  wire [0 : 0]  lane_rx_phase_comp_fifo_error;
  csr_indexed_read_only_reg #(.groups(lanes), .grp_size(1), .sel_size(LANE_REGW), .sync_stages(sync_stages))
    mux_rx_phase_comp_fifo_error(.clk(clk), .async_in_wide(rx_phase_comp_fifo_error),
      .sel(reg_lane_number), .out_narrow(lane_rx_phase_comp_fifo_error));
      
  wire [boundary_width-1 : 0]  lane_rx_bitslipboundaryselectout;
  csr_indexed_read_only_reg #(.groups(lanes), .grp_size(boundary_width), .sel_size(LANE_REGW), .sync_stages(sync_stages))
    mux_rx_bitslipboundaryselectout(.clk(clk), .async_in_wide(rx_bitslipboundaryselectout),
      .sel(reg_lane_number), .out_narrow(lane_rx_bitslipboundaryselectout));
      
  wire [0 : 0]  lane_tx_phase_comp_fifo_error;
  csr_indexed_read_only_reg #(.groups(lanes), .grp_size(1), .sel_size(LANE_REGW), .sync_stages(sync_stages))
    mux_tx_phase_comp_fifo_error(.clk(clk), .async_in_wide(tx_phase_comp_fifo_error),
      .sel(reg_lane_number), .out_narrow(lane_tx_phase_comp_fifo_error));
      
  wire [0 : 0]  lane_rlv;
  csr_indexed_read_only_reg #(.groups(lanes), .grp_size(1), .sel_size(LANE_REGW), .sync_stages(sync_stages))
    mux_rlv(.clk(clk), .async_in_wide(rlv),
      .sel(reg_lane_number), .out_narrow(lane_rlv));  


  always @(posedge clk or posedge reset) begin
    if (reset == 1) begin
      readdata <= 0;
      reg_lane_number <= 0;
      reg_tx_invpolarity <= 0;
      reg_tx_bitslipboundaryselect <= 0;
      reg_rx_invpolarity <= 0;
      reg_rx_enapatternalign <= 0;
      reg_rx_bitreversalenable <= 0;
      reg_rx_bytereversalenable <= 0;
      reg_rx_bitslip <= 0;
      reg_rx_a1a2size <= 0;
      
      // no need to clear synchronization registers, since they do not store state
    end
    else begin
      // decode read & write for each supported address
      case (address)
      // lane or group number for indirection
      ADDR_PCS_LANE_GROUP: begin
        readdata <= (32'd0 | reg_lane_number);
        if (write) reg_lane_number <= writedata[LANE_REGW-1:0];
      end
      
      // offset + 1, read-only RX status bits
      // bit 0, rx_phase_comp_fifo_error
      // bit boundary_width:1, rx_bitslipboundaryselectout
      ADDR_PCS8G_RX_STATUS: begin
        readdata <= (32'd0 |
          {lane_rx_bitslipboundaryselectout, //bit boundary_width-1
          lane_rx_phase_comp_fifo_error}); // bit 0
      end

      // offset + 2, read-only TX status bits
      // bit 0, tx_phase_comp_fifo_error
      ADDR_PCS8G_TX_STATUS: begin
        readdata <= (32'd0 | lane_tx_phase_comp_fifo_error); // bit 0
      end

      // offset + 3, read/write TX control bits
      // bit 0, tx_invpolarity
      // bit boundary_width:1, tx_bitslipboundaryselect
      ADDR_PCS8G_TX_CONTROL: begin
        readdata <= (32'd0 | {lane_tx_bitslipboundaryselect, lane_tx_invpolarity});
        if (write) 
        begin 
          reg_tx_invpolarity <= write_tx_invpolarity;
          reg_tx_bitslipboundaryselect <= write_tx_bitslipboundaryselect;
        end
      end

      // offset + 4, read/write RX control bits
      // bit 0, rx_invpolarity
      ADDR_PCS8G_RX_CONTROL: begin
        readdata <= (32'd0 | lane_rx_invpolarity);
        if (write) reg_rx_invpolarity <= write_rx_invpolarity;
      end
      
      // offset + 5, read/write RX WA control bits
      // bit 0, rx_enapatternalign
      // bit 1, rx_bitreversalenable
      // bit 2, rx_bytereversalenable
      // bit 3, rx_bitslip
      // bit 4, rx_a1a2size
      ADDR_PCS8G_RX_WA_CONTROL: begin
        readdata <= (32'd0 | { lane_rx_a1a2size, // bit 4
              lane_rx_bitslip, // bit 3
              lane_rx_bytereversalenable, // bit 2
              lane_rx_bitreversalenable, // bit 1
              lane_rx_enapatternalign}); // bit 0
        if (write) 
        begin
          reg_rx_enapatternalign <= write_rx_enapatternalign;
          reg_rx_bitreversalenable <= write_rx_bitreversalenable;
          reg_rx_bytereversalenable <= write_rx_bytereversalenable;
          reg_rx_bitslip <= write_rx_bitslip;
          reg_rx_a1a2size <= write_rx_a1a2size;
        end
      end
      
      // offset + 5, read RX WA status bits
      // bit 3:0, rx_errdetect
      // bit 7:4, rx_syncstatus
      // bit 11:8, rx_disperr
      // bit 15:12, rx_patterndetect
      // bit 16, rlv
      // bit 23:20, rx_a1a2sizeout
      ADDR_PCS8G_RX_WA_STATUS: begin
        readdata <= (32'd0 | {(4'b0 | lane_rx_a1a2sizeout), // bit 23:20
              (4'b0 | lane_rlv), // bit 16
              (4'b0 | lane_rx_patterndetect), // bit 15:12
              (4'b0 | lane_rx_disperr), // bit 11:8
              (4'b0 | lane_rx_syncstatus), // bit 7:4
              (4'b0 | lane_rx_errdetect)}); // bit 3:0
      end
      
      default:  readdata <= ~ 32'd0;  // use too many LEs?
      endcase
    end
  end

  // synchronize TX controls to tx_clk before generating output
  // sysclk-sync'ed input enters at [sync_stages], and tx_clk-sync'ed output exist at [1]
  integer stage;
  always @(posedge tx_clk) begin
    sync_tx_invpolarity[sync_stages] <= reg_tx_invpolarity;
    sync_tx_bitslipboundaryselect[sync_stages] <= reg_tx_bitslipboundaryselect;
    for (stage=2; stage <= sync_stages; stage = stage + 1) begin
      // additional sync stages
      sync_tx_invpolarity[stage-1] <= sync_tx_invpolarity[stage];
      sync_tx_bitslipboundaryselect[stage-1] <= sync_tx_bitslipboundaryselect[stage];
    end
  end
  assign csr_tx_invpolarity = sync_tx_invpolarity[1];
  assign csr_tx_bitslipboundaryselect = sync_tx_bitslipboundaryselect[1];

  // synchronize RX controls to rx_clk before generating output
  // sysclk-sync'ed input enters at [sync_stages], and rx_clk-sync'ed output exist at [1]
  always @(posedge rx_clk) begin
    sync_rx_invpolarity[sync_stages] <= reg_rx_invpolarity;
    sync_rx_enapatternalign[sync_stages] <= reg_rx_enapatternalign;
    sync_rx_bitreversalenable[sync_stages] <= reg_rx_bitreversalenable;
    sync_rx_bytereversalenable[sync_stages] <= reg_rx_bytereversalenable;
    sync_rx_bitslip[sync_stages] <= reg_rx_bitslip;
    sync_rx_a1a2size[sync_stages] <= reg_rx_a1a2size;
    for (stage=2; stage <= sync_stages; stage = stage + 1) begin
      // additional sync stages
      sync_rx_invpolarity[stage-1] <= sync_rx_invpolarity[stage];
      sync_rx_enapatternalign[stage-1] <= sync_rx_enapatternalign[stage];
      sync_rx_bitreversalenable[stage-1] <= sync_rx_bitreversalenable[stage];
      sync_rx_bytereversalenable[stage-1] <= sync_rx_bytereversalenable[stage];
      sync_rx_bitslip[stage-1] <= sync_rx_bitslip[stage];
      sync_rx_a1a2size[stage-1] <= sync_rx_a1a2size[stage];
    end
  end
  assign csr_rx_invpolarity = sync_rx_invpolarity[1];
  assign csr_rx_enapatternalign = sync_rx_enapatternalign[1];
  assign csr_rx_bitreversalenable = sync_rx_bitreversalenable[1];
  assign csr_rx_bytereversalenable = sync_rx_bytereversalenable[1];
  assign csr_rx_bitslip = sync_rx_bitslip[1];
  assign csr_rx_a1a2size = sync_rx_a1a2size[1];

endmodule
