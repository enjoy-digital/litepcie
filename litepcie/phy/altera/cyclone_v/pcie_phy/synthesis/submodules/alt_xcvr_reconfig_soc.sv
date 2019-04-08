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


import altera_xcvr_functions::*;

`timescale 1 ns / 1 ns

module alt_xcvr_reconfig_soc #(
    parameter device_family = "Stratix V",
    parameter arb_count     = 6,  // Number of IPs
    parameter width_awa     = 3,  // Number of address bits per PHY IP (direct registers)
    parameter width_bwa     = 3,  // Number of address bits for basic block
    parameter number_of_reconfig_interfaces = 1, // Number of reconfig interfaces
    parameter [arb_count-1:0] enable_soc_mask = 0 // encoded bit field. Each bit acts as enable for respective IP
  ) (
  // user reconfiguration management interface
  input   wire                  mgmt_clk,
  input   wire                  mgmt_rst,
  input   wire  [6:0]           mgmt_address,
  output  wire                  mgmt_waitrequest,
  input   wire                  mgmt_read,
  output  wire  [31:0]          mgmt_readdata,
  input   wire                  mgmt_write,
  input   wire  [31:0]          mgmt_writedata,
  input   wire  [arb_count-1:0] mgmt_decode,

  input   wire  [arb_count-1:0] hold,       // Hold signal for IP sequencing
  output  wire  [arb_count-1:0] busy,       // Busy status per IP
  input   wire  [arb_count-1:0] hard_busy,  // Busy status input from other IP

  // CPU <-> Basic interface
  output  wire  [width_bwa-1:0] basic_address,
  output  wire  [31:0]          basic_writedata,
  output  wire                  basic_write,
  output  wire                  basic_read,
  input   wire  [31:0]          basic_readdata,
  input   wire                  basic_waitrequest,
  output  wire  [arb_count-1:0] basic_req,  // request access to B block
  input   wire  [arb_count-1:0] basic_grant,// granted access to B block

  // Testbus
  input   wire  [7:0]           lch_testbus,
  input   wire  [23:0]          pch_testbus
);

`ifdef ALTERA_RESERVED_QIS
  // Enable full model for synthesis. Fast model for sim
  `define ALTERA_RESERVED_XCVR_FULL_RECONFIG_SOC
`endif // ifdef ALTERA_RESERVED_QIS

`ifdef ALTERA_RESERVED_XCVR_FULL_RECONFIG_SOC
  // Addresses for local registers
  localparam  [3:0] ADDR_RAM_OFFSET     = 0, 
                    ADDR_HOLD           = 1,
                    ADDR_BUSY_SET       = 2,
                    ADDR_BUSY_CLR       = 3,
                    ADDR_BASIC_REQ_SET  = 4,
                    ADDR_BASIC_REQ_CLR  = 5,
                    ADDR_BASIC_GRANT    = 6,
                    ADDR_LCH_TESTBUS    = 7,
                    ADDR_PCH_TESTBUS0   = 8,
                    ADDR_PCH_TESTBUS1   = 9,
                    ADDR_PCH_TESTBUS2   = 10,
                    ADDR_IF_COUNT       = 11,
                    ADDR_CONFIG         = 12;

  localparam  RAM_SIZE_IN_BYTES = 4096;
  localparam  RAM_DEPTH = RAM_SIZE_IN_BYTES / 4;
  localparam  RAM_BITS = clogb2(RAM_DEPTH-1);
										

  // CPU <-> RAM connections
  wire  [RAM_BITS-1:0]  cpu_ram_address;
  wire  [ 3:0]          cpu_ram_byteenable;
  wire                  cpu_ram_write;
  wire  [31:0]          cpu_ram_writedata;
  wire  [31:0]          cpu_ram_readdata;
  // CPU <-> control connections
  wire                  ctrl_reset;
  wire  [4:0]           ctrl_address;
  wire                  ctrl_read; 
  wire                  ctrl_write;
  wire  [31:0]          ctrl_writedata;
  wire  [31:0]          ctrl_readdata;
  wire                  ctrl_basic_sel; // 1 = CPU addressing basic block,
                                        // 0 = CPU addressing local config registers
  wire                  ctrl_local_sel; // 1 = CPU addressing local config registers
                                        // 0 = CPU addressing basic block
  wire                  ctrl_waitrequest;
  // CPU <-> Local register signals
  wire  [3:0]           ctrl_local_address;
  wire  [31:0]          ctrl_local_readdata;
  wire                  ctrl_local_read;
  wire                  ctrl_local_write;
  wire  [31:0]          ctrl_local_writedata;

  // Busy controls
  reg   [arb_count-1:0] r_busy;
  wire                  ctrl_local_busy_set;
  wire                  ctrl_local_busy_clr;
  wire                  mgmt_busy_set;

  // MGMT <-> RAM connections
  wire  [RAM_BITS-1:0]  mgmt_ram_address;
  wire  [31:0]          mgmt_ram_readdata;
  reg   [RAM_BITS-1:0]  mgmt_ram_offset;  // Stores address offset of mgmt interface in RAM
  wire                  mgmt_ram_write;   // Gated mgmt_ram_write

  // Basic arbitration
  reg   [arb_count-1:0] r_basic_req;  // request access to B block
  wire                  granted;      // request & grant

  // Configuration
  wire                  is_es;  // 1 - if compiled for ES, 0 otherwise
  reg                   oc_done = 0; // 1 if OC has completed its first run, otherwise 0
  
  wire                  cpu_reset_req;

  // Static assignments
  `ifdef ALTERA_RESERVED_QIS_ES
    assign  is_es = 1'b1;
  `else
    assign  is_es = 1'b0;
  `endif

  // Initial register values
  initial begin
    r_busy          = enable_soc_mask;
    r_basic_req     = {arb_count{1'b0}};
    mgmt_ram_offset = {RAM_BITS{1'b0}};
  end

  //***************************************************************************
  //*********************** Basic / Local Arbitration *************************
  // Decode avalon signals between CPU and basic
  assign  ctrl_basic_sel    = ctrl_address[4];
  assign  ctrl_local_sel    = ~ctrl_basic_sel;
  assign  ctrl_readdata     = ctrl_basic_sel ? basic_readdata : (ctrl_local_readdata & {32{ctrl_local_read}});
  assign  ctrl_waitrequest  = ctrl_basic_sel ? basic_waitrequest : 1'b0;

  // CPU -> Basic connections
  assign  basic_req         = r_basic_req;
  assign  granted           = |(r_basic_req & basic_grant);
  assign  basic_address     = ctrl_address[width_bwa-1:0] & {width_bwa{granted}};
  assign  basic_writedata   = ctrl_writedata              & {32{granted}};
  assign  basic_write       = ctrl_write & ctrl_basic_sel & granted;
  assign  basic_read        = ctrl_read  & ctrl_basic_sel & granted;

  // CPU -> Local registers connection
  assign  ctrl_local_address    = ctrl_address[3:0];
  assign  ctrl_local_writedata  = ctrl_writedata; 
  assign  ctrl_local_write      = ctrl_write & ctrl_local_sel;
  assign  ctrl_local_read       = ctrl_read & ctrl_local_sel;
  //********************* End Basic / Local Arbitration ***********************
  //***************************************************************************


  //*************************************************************************
  //*************************** Local Registers *****************************
  // Local registers write decoder
  always @(posedge mgmt_clk or posedge ctrl_reset)
    if(ctrl_reset) begin
        r_basic_req <=  {arb_count{1'b0}};  // TODO (reset levels)
        mgmt_ram_offset <= {RAM_BITS{1'b0}};
    end else if(ctrl_local_write) begin
      if(ctrl_local_address == ADDR_RAM_OFFSET) begin
        mgmt_ram_offset <= ctrl_writedata[RAM_BITS-1:0];
      end
      if(ctrl_local_address == ADDR_BASIC_REQ_SET)
        r_basic_req <= r_basic_req | ctrl_local_writedata[arb_count-1:0];
      if(ctrl_local_address == ADDR_BASIC_REQ_CLR) 
        r_basic_req <= r_basic_req & ~ctrl_local_writedata[arb_count-1:0];
      
    end
    
  always @(posedge mgmt_clk)
  begin
    if(ctrl_local_write) begin
      if (ctrl_local_address == ADDR_CONFIG) begin // only allow bit [30] to be writeable
        oc_done <= ctrl_local_writedata[30];
      end
    end
  end

  // Local registers readback data
  // We are intentionally leaving out reading certain registers to save logic
  assign  ctrl_local_readdata =
    (ctrl_local_address == ADDR_HOLD        ) ? {{32-arb_count{1'b0}},hold        } :
    (ctrl_local_address == ADDR_BUSY_SET    ) ? {{32-arb_count{1'b0}},hard_busy   } :
    (ctrl_local_address == ADDR_BASIC_GRANT ) ? {{32-arb_count{1'b0}},basic_grant } :
    (ctrl_local_address == ADDR_LCH_TESTBUS ) ? {24'd0,lch_testbus} :
    (ctrl_local_address == ADDR_PCH_TESTBUS0) ? {24'd0,pch_testbus[ 7: 0]} :
    (ctrl_local_address == ADDR_PCH_TESTBUS1) ? {24'd0,pch_testbus[15: 8]} :
    (ctrl_local_address == ADDR_PCH_TESTBUS2) ? {24'd0,pch_testbus[23:16]} :
    (ctrl_local_address == ADDR_IF_COUNT    ) ? number_of_reconfig_interfaces[31:0] :
    (ctrl_local_address == ADDR_CONFIG      ) ? {is_es, oc_done, {30-arb_count{1'b0}},enable_soc_mask } :
    32'd0;
  //************************* End Local Registers ***************************
  //*************************************************************************


  //*************************************************************************
  //****************************** CPU System *******************************
  alt_xcvr_reconfig_cpu alt_xcvr_reconfig_cpu_inst(
    // Clocks and resets
    .reset_reset_n                  (~mgmt_rst          ),
    .clk_clk                        (mgmt_clk           ),
  
    // RAM
    .reconfig_mem_reset_reset       (/*unused*/         ),
    .reconfig_mem_reset_reset_req   (cpu_reset_req      ), // reset_req
    .reconfig_mem_mem_address       (cpu_ram_address    ),
    .reconfig_mem_mem_read          (/*unused*/         ),
    .reconfig_mem_mem_write         (cpu_ram_write      ),
    .reconfig_mem_mem_byteenable    (cpu_ram_byteenable ),
    .reconfig_mem_mem_readdata      (cpu_ram_readdata   ),
    .reconfig_mem_mem_writedata     (cpu_ram_writedata  ),
  
    // Control 
    .reconfig_ctrl_reset_reset      (ctrl_reset         ),
    .reconfig_ctrl_ctrl_write       (ctrl_write         ),
    .reconfig_ctrl_ctrl_address     (ctrl_address       ),
    .reconfig_ctrl_ctrl_waitrequest (ctrl_waitrequest   ),
    .reconfig_ctrl_ctrl_readdata    (ctrl_readdata      ),
    .reconfig_ctrl_ctrl_writedata   (ctrl_writedata     ),
    .reconfig_ctrl_ctrl_read        (ctrl_read          ),
    .reconfig_ctrl_ctrl_irq_irq     (1'b0       )
  );
  //**************************** End CPU System *****************************
  //*************************************************************************


  //*************************************************************************
  //**************************** Busy Registers *****************************
  // TODO - move these to alt_xcvr_reconfig_h.sv
  localparam  ADDR_XR_STATUS      = 2;
  localparam  XR_STATUS_OFST_BUSY = 8;

  //
  assign  mgmt_busy_set       = mgmt_ram_write   & (mgmt_address[width_awa-1:0] == ADDR_XR_STATUS);
  assign  ctrl_local_busy_set = ctrl_local_write & (ctrl_local_address == ADDR_BUSY_SET);
  assign  ctrl_local_busy_clr = ctrl_local_write & (ctrl_local_address == ADDR_BUSY_CLR);

  assign  busy = r_busy;

  genvar ig;
  generate begin
    for(ig=0;ig<arb_count;ig=ig+1) begin: busy_regs
      // Busy registers
      always @(posedge mgmt_clk or posedge mgmt_rst)
        if(mgmt_rst)  
                      r_busy[ig]  <= enable_soc_mask[ig];
        else if(mgmt_busy_set & mgmt_decode[ig])  // Set from mgmt interface
                      r_busy[ig]  <= 1'b1;
        else if(ctrl_local_busy_set)  // Set from CPU
                      r_busy[ig]  <= r_busy[ig] | ctrl_writedata[ig];
        else if(ctrl_local_busy_clr)  // Clear from CPU
                      r_busy[ig]  <= r_busy[ig] & ~ctrl_writedata[ig];
    end
  end
  endgenerate
  //************************** End Busy Registers ***************************
  //*************************************************************************


  //*************************************************************************
  //******************************* CPU RAM *********************************
  // Add offset to mgmt address to access ram
  assign  mgmt_ram_address    = mgmt_address + mgmt_ram_offset;
  // Gate write access with busy registers
  assign  mgmt_ram_write      = mgmt_write & |(mgmt_decode & ~r_busy);

  // Dual-port RAM block
  alt_xcvr_reconfig_cpu_ram #(
      .DEPTH(RAM_DEPTH)
  ) alt_xcvr_reconfig_cpu_ram_inst(
    // Clocks and resets
    .clk          (mgmt_clk           ),
  
    // Port A
    .a_address    (cpu_ram_address    ),
    .a_write      (cpu_ram_write      ),
    .a_byteenable (cpu_ram_byteenable ),
    .a_writedata  (cpu_ram_writedata  ),
    .a_readdata   (cpu_ram_readdata   ),
    
    // clock enable input of alt_sync_ram
    // cpu_reset_req goes HIGH when reset is asserted and is LOW when reset 
    // is deasserted. 
    // Clock enable has to be the opposite of cpu_reset_req 
    .ram_ce       (~cpu_reset_req     ),
    // Port B
    .b_address    (mgmt_ram_address   ),
    .b_write      (mgmt_ram_write     ),
    .b_byteenable (4'b1111            ),
    .b_writedata  (mgmt_writedata     ),
    .b_readdata   (mgmt_ram_readdata  )
  );
  //***************************** End CPU RAM *******************************
  //*************************************************************************


  //*************************************************************************
  //*************************** Avalon Interface ****************************

  // Modify readdata to include busy bit for appropriate addresses
  assign  mgmt_readdata = (mgmt_address[width_awa-1:0]  == ADDR_XR_STATUS)
                          ?  {mgmt_ram_readdata[31:(XR_STATUS_OFST_BUSY+1)],
                              r_busy[mgmt_address[6:width_awa]],
                              mgmt_ram_readdata[XR_STATUS_OFST_BUSY-1:0]}
                          : mgmt_ram_readdata;

  // Generate waitrequest signal for managment interface
  altera_wait_generate altera_wait_generate_inst(
    .rst          (mgmt_rst         ),
    .clk          (mgmt_clk         ),
    .launch_signal(mgmt_read        ),
    .wait_req     (mgmt_waitrequest )
  );
  //************************** End Avalon Interface *************************
  //*************************************************************************

`else   // ifdef ALTERA_RESERVED_XCVR_FULL_RECONFIG_SOC

  reg oc_busy;
  // No model. Drive outputs to 0. Use up all inputs to avoid warnings.
  // Assert waitrequest during reset to make simulation behavior consistent
  assign  mgmt_waitrequest  = mgmt_rst | &{1'b0,mgmt_clk, mgmt_rst, mgmt_address, mgmt_read,
                                mgmt_write, mgmt_writedata, hard_busy, basic_readdata,
                                basic_waitrequest, basic_grant, hold, lch_testbus,
                                pch_testbus}; // warning avoidance
  assign  mgmt_readdata     = 32'hdeadbeef;
  assign  busy              = {{arb_count-1{1'b0}}, oc_busy};
  assign  basic_address     = {width_bwa{1'b0}};
  assign  basic_writedata   = 32'd0;
  assign  basic_write       = 1'b0;
  assign  basic_read        = 1'b0;
  assign  basic_req         = {arb_count{1'b0}};

  initial begin
    $display("[alt_xcvr_reconfig_soc.v] Full model disabled");
    oc_busy = 1'b1; // fake out offset cancellation at the start - this edge is needed for the cal sequencer module
    repeat (100) @ (posedge mgmt_clk);
    oc_busy = 1'b0;
  end

`endif  // ifdef ALTERA_RESERVED_XCVR_FULL_RECONFIG_SOC

endmodule
