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


// Transceiver Reconfiguration Module
//
// Includes many function-specific sub-modules, such as:
//  - analog reconfig (alt_xcvr_reconfig_analog)
//  - offset cancellation (alt_xcvr_reconfig_offset_cancellation)
//  - ...
// TODO - Add support to read configuration (enabled options)

// $Header$

`timescale 1 ns / 1 ns

module alt_xcvr_reconfig #(
  parameter device_family = "Stratix V",

  // reconfig blocks to enable or disable
  parameter enable_offset = 1,  // always need offset cancellation to calibrate buffers
  parameter enable_lc     = 1,  // LC Tuning
  parameter enable_dcd    = 0,  // DCD
  parameter enable_dcd_power_up = 1, // 0: manual trigger; 1: manual trigger + auto run upon power up
  parameter enable_analog = 0,  // manual tuning of buffer analog parameters
  parameter enable_eyemon = 0,  // EyeQ
  parameter enable_ber    = 0, //Enables the BER Counter
  parameter enable_dfe    = 0,  // DFE
  parameter enable_adce   = 0,  // ADCE
  parameter enable_mif    = 0,  // MIF streaming
  parameter enable_pll    = 0,  // PLL reconfig
  parameter enable_direct = 1,  // Direct Basic access

  // number of physical reconfig interfaces
  parameter number_of_reconfig_interfaces = 1
) (
  input  wire        mgmt_clk_clk,
  input  wire        mgmt_rst_reset,

  // user reconfiguration management interface
  input  wire [6:0]  reconfig_mgmt_address,
  output wire        reconfig_mgmt_waitrequest,
  input  wire        reconfig_mgmt_read,
  output wire [31:0] reconfig_mgmt_readdata,
  input  wire        reconfig_mgmt_write,
  input  wire [31:0] reconfig_mgmt_writedata,
  output wire        reconfig_busy,

  // calibration port
  input  wire        cal_busy_in,
  output wire        tx_cal_busy,
  output wire        rx_cal_busy,
  
  //MIF storage interface
  output wire [31:0] reconfig_mif_address,   
  output wire        reconfig_mif_read,
  input wire         reconfig_mif_waitrequest, 
  input wire [15:0]  reconfig_mif_readdata,

  // bundled reconfig buses
  output wire [altera_xcvr_functions::get_reconfig_to_width(device_family,number_of_reconfig_interfaces) -1:0] reconfig_to_xcvr,  // all native xcvr reconfig sinks
  input  wire [altera_xcvr_functions::get_reconfig_from_width(device_family,number_of_reconfig_interfaces)-1:0] reconfig_from_xcvr // all native xcvr reconfig sources
);

  // Enable CMU kickstart IP for Arria V and Cyclone V ES.
  localparam  l_enable_lc = 
  `ifdef ALTERA_RESERVED_QIS_ES
    `ifndef ALTERA_RESERVED_XCVR_DISABLE_CMU_KICKSTART
      (altera_xcvr_functions::has_a5_style_hssi(device_family) || altera_xcvr_functions::has_c5_style_hssi(device_family)) ? 1 :
    `endif
  `endif
    enable_lc;

  import alt_xcvr_reconfig_h::*;

  // count of the total number of sub-components that can act
  // as slaves to the mgmt interface, and masters to the 'basic' block
  localparam arb_count  = INDEX_XR_END;
  // Use CPU for various features
  localparam  enable_soc_offset = enable_offset ? ((altera_xcvr_functions::has_s5_style_hssi(device_family)) ? 1 : 0) : 0;  // use SOC for OC, but only for Stratix V
  localparam  enable_soc_dcd    = enable_dcd    ? 0 : 0;  // use SOC for DCD
  localparam  enable_soc_lc     = l_enable_lc   ? 1 : 0;  // use SOC for LC Tuning and CMU kickstart
  localparam  enable_soc_analog = enable_analog ? 0 : 0;  // use SOC for manual tuning of buffer analog parameters
  localparam  enable_soc_eyemon = enable_eyemon ? 0 : 0;  // use SOC for EyeQ
  localparam  enable_soc_dfe    = enable_dfe    ? 0 : 0;  // use SOC for DFE
  localparam  enable_soc_adce   = enable_adce   ? 0 : 0;  // use SOC for ADCE
  localparam  enable_soc_mif    = enable_mif    ? 0 : 0;  // use SOC for MIF streaming
  localparam  enable_soc_pll    = enable_pll    ? 0 : 0;  // use SOC for PLL reconfig
  localparam  enable_soc_direct = enable_direct ? 0 : 0;  // use SOC for Direct Basic access

  // Conditions for enabling the reconfig CPU
  localparam  [arb_count-1:0] enable_soc_mask
      = (enable_soc_offset[arb_count-1:0]  << INDEX_XR_OFFSET  )
      | (enable_soc_dcd   [arb_count-1:0]  << INDEX_XR_DCD     )
      | (enable_soc_lc    [arb_count-1:0]  << INDEX_XR_LC      )
      | (enable_soc_analog[arb_count-1:0]  << INDEX_XR_ANALOG  )
      | (enable_soc_eyemon[arb_count-1:0]  << INDEX_XR_EYEMON  )
      | (enable_soc_dfe   [arb_count-1:0]  << INDEX_XR_DFE     )
      | (enable_soc_adce  [arb_count-1:0]  << INDEX_XR_ADCE    )
      | (enable_soc_mif   [arb_count-1:0]  << INDEX_XR_MIF     )
      | (enable_soc_pll   [arb_count-1:0]  << INDEX_XR_PLL     )
      | (enable_soc_direct[arb_count-1:0]  << INDEX_XR_DIRECT  );


  localparam width_awa  = W_XR_FEATURE_LADDR;  // word address width of interface to analog reconfig block
  localparam width_bwa  = W_XR_FEATURE_LADDR;  // word address width of interface to basic reconfig block
  // decoder block index, for 8-word address blocks
  localparam arb_offset = INDEX_XR_OFFSET;
  localparam arb_analog = INDEX_XR_ANALOG;
  localparam arb_eyemon = INDEX_XR_EYEMON;
  localparam arb_dfe    = INDEX_XR_DFE;
  localparam arb_direct = INDEX_XR_DIRECT;
  localparam arb_adce   = INDEX_XR_ADCE;
  localparam arb_lc     = INDEX_XR_LC;
  localparam arb_mif    = INDEX_XR_MIF;
  localparam arb_dcd    = INDEX_XR_DCD;
  localparam arb_pll    = INDEX_XR_PLL;


  ///////////////////////////////////////////////////////////////////////
  // Connections between sub-components and the basic interface (switch)
  ///////////////////////////////////////////////////////////////////////

  // Decoded slave block output ports, mgmt facing
  wire [31:0]          blk2mgmt_readdata    [arb_count-1:0];
  wire                 blk2mgmt_waitrequest [arb_count-1:0];

  // CPU -> MGMT connections
  wire  [31:0]          cpu_mgmt_readdata;
  wire                  cpu_mgmt_waitrequest;
  wire  [arb_count-1:0] cpu_busy;

  // Decoded slave block output ports, basic facing (from CPU)
  wire                  cpu_basic_read;
  wire                  cpu_basic_write;
  wire  [width_bwa-1:0] cpu_basic_address;
  wire  [31:0]          cpu_basic_writedata;
  wire  [arb_count-1:0] cpu_basic_req;

  // Decoded slave block output ports, basic facing
  wire                 blk2basic_read      [arb_count-1:0];
  wire                 blk2basic_write     [arb_count-1:0];
  wire [width_bwa-1:0] blk2basic_address   [arb_count-1:0];
  wire [31:0]          blk2basic_writedata [arb_count-1:0];

  // master interface to basic reconfiguration block that interfaces to the transceiver channel
  wire  [width_bwa-1:0] basic_address;
  wire                  basic_waitrequest;
  wire                  basic_irq;
  wire                  basic_read;
  wire  [31:0]          basic_readdata;
  wire                  basic_write;
  wire  [31:0]          basic_writedata;

  // native testbus interfaces: to logical interface:
  wire [7:0]  lch_testbus;  // testbus from native reconfig, for selected channel, from basic block
  wire [23:0] pch_testbus; // triplet testbus
  wire        lch_atbout;

  // gate soft-IPs from running by holding off logical mutex until interface select is done
  wire ifsel_notdone;
  reg ifsel_notdone_resync;
  wire reconfig_subblock_reset;

  ///////////////////////////////////////////////////////////////////////
  // Decoder for multiple slaves of reconfig_mgmt interface
  ///////////////////////////////////////////////////////////////////////
  wire [arb_count-1:0] r_decode;

  // intermediate wires for mgmt readdata and waitrequest muxes
  wire [31:0] wmgmt_readdata    [arb_count-1:0];
  wire        wmgmt_waitrequest [arb_count-1:0];

  // intermediate wires for basic read, write, address, and writedata OR's
  wire [width_bwa-1:0] wbasic_address     [arb_count-1:0]; //   basic.address
  wire                 wbasic_read        [arb_count-1:0]; //        .read
  wire                 wbasic_write       [arb_count-1:0]; //        .write
  wire [31:0]          wbasic_writedata   [arb_count-1:0]; //        .writedata

  // interconnection between PLL and MIF IP
  wire        pll_mif_busy;
  wire        pll_mif_err;
  wire        mif_pll_go;
  wire        mif_pll_type;
  wire [9:0]  mif_pll_lch;
  wire [3:0]  mif_pll_data;
  wire        mif_pll_pll_type;

  // Busy and done signals for each feature IP
  wire  [arb_count-1:0] busy;
  wire  [arb_count-1:0] done;
  wire  [arb_count-1:0] hold;

  wire  oc_cal_busy;
  wire  cpu_unused; //dummy wire for warning reduction
  // prevent warnings
  assign  cpu_unused            = & {1'b0,cpu_basic_address,cpu_mgmt_readdata,cpu_mgmt_waitrequest,cpu_basic_read,
                                     cpu_basic_writedata,cpu_basic_write,cpu_busy,cpu_basic_req};
  wire  r_mgmt_rst_reset;
  
  //////////////////////////////////////////////////////////////////////////////////////
  // Synchronize the reset
  // This is a data synchronizer; ensures synchronous assertion and deassertion 
  // NOTE: This is different from reset synchronizer; reset synchronizer only ensures 
  //       synchronous deassertion. 
  //////////////////////////////////////////////////////////////////////////////////////
  
  alt_xcvr_resync #(
    .INIT_VALUE (1)
  ) inst_reconfig_reset_sync (
    .clk    (mgmt_clk_clk       ),
    .reset  (1'd0               ),
    .d      (mgmt_rst_reset     ),
    .q      (r_mgmt_rst_reset   )
  ); 

  genvar i;
  generate for (i=0; i<arb_count; i = i+1) begin: dec
    // a synthesizable decoder, with a parameterized number of outputs
    assign r_decode[i] = (reconfig_mgmt_address[6:width_awa] == i);

    // reconfig_mgmt output generation is muxing of decoded slave output
    // basic block input generation is OR-ing of blk2basic outputs
    if (i == 0) begin
      assign wmgmt_readdata[0] = blk2mgmt_readdata[0] & {32{r_decode[0]}};
      assign wmgmt_waitrequest[0] = blk2mgmt_waitrequest[0] & r_decode[0];
      assign wbasic_address[i]     = blk2basic_address[i];
      assign wbasic_read[i]        = blk2basic_read[i];
      assign wbasic_write[i]       = blk2basic_write[i];
      assign wbasic_writedata[i]   = blk2basic_writedata[i];
    end
    else begin
      assign wmgmt_readdata[i]    = wmgmt_readdata[i-1] | blk2mgmt_readdata[i] & {32{r_decode[i]}};
      assign wmgmt_waitrequest[i] = wmgmt_waitrequest[i-1] | blk2mgmt_waitrequest[i] & r_decode[i];
      assign wbasic_address[i]     = wbasic_address[i-1]     | blk2basic_address[i];
      assign wbasic_read[i]        = wbasic_read[i-1]        | blk2basic_read[i];
      assign wbasic_write[i]       = wbasic_write[i-1]       | blk2basic_write[i];
      assign wbasic_writedata[i]   = wbasic_writedata[i-1]   | blk2basic_writedata[i];
    end
  end
  endgenerate

  
  //use bit 8 as the combined busy bit for the user
  assign reconfig_mgmt_readdata    = (reconfig_mgmt_address[width_awa-1:0] == XR_STATUS_OFST) ?
                                      wmgmt_readdata[arb_count-1] | (reconfig_busy << XR_STATUS_OFST_COMB_BUSY) : 
                                      wmgmt_readdata[arb_count-1];
  
  //assign reconfig_mgmt_readdata    = wmgmt_readdata[arb_count-1];
  assign reconfig_mgmt_waitrequest = wmgmt_waitrequest[arb_count-1];
  assign basic_address     = wbasic_address[arb_count-1];
  assign basic_read        = wbasic_read[arb_count-1];
  assign basic_write       = wbasic_write[arb_count-1];
  assign basic_writedata   = wbasic_writedata[arb_count-1];


  ///////////////////////////////////////////////////////////////////////
  // Arbiter for multiple masters accessing 'basic' reconfig slave port
  ///////////////////////////////////////////////////////////////////////
  wire [arb_count-1:0] req; // req[0] is highest priority when current grantee is done
  wire [arb_count-1:0] temp_grant;
  wire [arb_count-1:0] grant;
  reg  [arb_count-1:0] reg_grant_last;
  wire lif_is_active; // indicates at least 1 request & grant pair present.  Must go low 1 cycle on grant change

  // -ifsel_done indicates that serial shift load is completed and interface_select has be switched over to enable DPRIO access
  // -if serial shift load is not done, then grant should remain '0'
  assign grant = temp_grant;

  // generate lif_is_active low when no request, or in cycle after grant change
  assign lif_is_active = ( | req) & (grant == reg_grant_last);

  alt_xcvr_arbiter #(
    .width(arb_count) // count total number of sub-components that act as masters to 'basic'
  ) arbiter (
    .clock(mgmt_clk_clk),
    .req(req),
    .grant(temp_grant)
  );
  
  // grant last state, for change detection
  always @(posedge mgmt_clk_clk or posedge r_mgmt_rst_reset) begin
    if (r_mgmt_rst_reset == 1)
      reg_grant_last <= {arb_count{1'b0}};
    else
      reg_grant_last <= grant | cpu_unused; // cpu_unused is always 1'b0, but is used as warning reduction
  end


  ///////////////////////////////////////////
  // Sub-component: offset cancellation
  // word address offset: +0 (0x00 in bytes)
  ///////////////////////////////////////////
  generate if (enable_offset && !enable_soc_offset) begin:offset

    assign  busy[arb_offset]  = ~done[arb_offset];

    alt_xcvr_reconfig_offset_cancellation #(
      .number_of_reconfig_interfaces(number_of_reconfig_interfaces),
      .device_family(device_family)
    ) sc_offset (
      .reconfig_clk(mgmt_clk_clk),
      .reset(reconfig_subblock_reset),
      // external mgmt interface facing
      .offset_cancellation_address    (reconfig_mgmt_address[2:0]),
      .offset_cancellation_writedata  (reconfig_mgmt_writedata),
      .offset_cancellation_write      (reconfig_mgmt_write & r_decode[arb_offset]),
      .offset_cancellation_read       (reconfig_mgmt_read & r_decode[arb_offset]),
      .offset_cancellation_readdata   (blk2mgmt_readdata[arb_offset]),
      .offset_cancellation_waitrequest(blk2mgmt_waitrequest[arb_offset]),
      .offset_cancellation_done       (done[arb_offset]),
      .testbus_data                   ({number_of_reconfig_interfaces{16'd0}} | lch_testbus[7:0]),
      // master-to-slave fabric facing, to basic reconfig
      .offset_cancellation_irq_from_base(),
      .offset_cancellation_waitrequest_from_base(basic_waitrequest),
      .offset_cancellation_readdata_base        (basic_readdata),
      .offset_cancellation_address_base         (blk2basic_address  [arb_offset]),
      .offset_cancellation_writedata_base       (blk2basic_writedata[arb_offset]),
      .offset_cancellation_write_base           (blk2basic_write    [arb_offset]),
      .offset_cancellation_read_base            (blk2basic_read     [arb_offset]),
      // fabric acquisition for basic block access
      .arb_req  (req[arb_offset]),
      .arb_grant(grant[arb_offset])
    );
  end else if (enable_offset && enable_soc_offset) begin:soc_offset 
    // Use soft offset cancellation block
    // CPU <-> MGMT connections
    assign  blk2mgmt_readdata   [arb_offset] = cpu_mgmt_readdata;
    assign  blk2mgmt_waitrequest[arb_offset] = cpu_mgmt_waitrequest;
    // CPU <-> Basic connections
    assign  blk2basic_address   [arb_offset] = cpu_basic_address;
    assign  blk2basic_writedata [arb_offset] = cpu_basic_writedata;
    assign  blk2basic_write     [arb_offset] = cpu_basic_write;
    assign  blk2basic_read      [arb_offset] = cpu_basic_read;
    assign  req                 [arb_offset] = cpu_basic_req[arb_offset];
    assign  busy                [arb_offset] = cpu_busy[arb_offset];
    assign  done                [arb_offset] = ~busy[arb_offset];
  end else begin:no_offset
    // plceholders for missing block
    assign blk2mgmt_readdata    [arb_offset] = 32'd0;
    assign blk2mgmt_waitrequest [arb_offset] = 1'b0;
    assign blk2basic_address    [arb_offset] = {width_bwa{1'b0}};
    assign blk2basic_writedata  [arb_offset] = 32'd0;
    assign blk2basic_write      [arb_offset] = 1'b0;
    assign blk2basic_read       [arb_offset] = 1'b0;
    assign req  [arb_offset] = 1'b0;
    assign busy [arb_offset] = 1'b0;
    assign done [arb_offset] = ~busy[arb_offset];
  end
  endgenerate

  ////////////////////////////////////
  // Sub-component: analog controls
  // word address offset: +8
  ////////////////////////////////////
  generate if (enable_analog && !enable_soc_analog) begin:analog
    // Use hard analog block
    assign  busy[arb_analog]  = ~done[arb_analog];

    alt_xcvr_reconfig_analog #(
      .device_family(device_family)
    ) sc_analog (
      .reconfig_clk(mgmt_clk_clk),
      .reset(reconfig_subblock_reset),
      // external mgmt interface facing
      .analog_reconfig_address    (reconfig_mgmt_address[width_awa-1:0]),
      .analog_reconfig_writedata  (reconfig_mgmt_writedata),
      .analog_reconfig_write      (reconfig_mgmt_write & r_decode[arb_analog]),
      .analog_reconfig_read       (reconfig_mgmt_read & r_decode[arb_analog]),
      .analog_reconfig_readdata   (blk2mgmt_readdata[arb_analog]),
      .analog_reconfig_waitrequest(blk2mgmt_waitrequest[arb_analog]),
      .analog_reconfig_done       (done[arb_analog]),
      // master-to-slave fabric facing, to basic reconfig
      .analog_reconfig_irq_from_base(),
      .analog_reconfig_waitrequest_from_base(basic_waitrequest),
      .analog_reconfig_readdata_base        (basic_readdata),
      .analog_reconfig_address_base         (blk2basic_address  [arb_analog]),
      .analog_reconfig_writedata_base       (blk2basic_writedata[arb_analog]),
      .analog_reconfig_write_base           (blk2basic_write    [arb_analog]),
      .analog_reconfig_read_base            (blk2basic_read     [arb_analog]),
      // fabric acquisition for basic block access
      .arb_req  (req[arb_analog]),
      .arb_grant(grant[arb_analog])
    );
  end else if(enable_analog && enable_soc_analog) begin:soc_analog
    // Use soft analog block
    // CPU <-> MGMT connections
    assign  blk2mgmt_readdata   [arb_analog] = cpu_mgmt_readdata;
    assign  blk2mgmt_waitrequest[arb_analog] = cpu_mgmt_waitrequest;
    // CPU <-> Basic connections
    assign  blk2basic_address   [arb_analog] = cpu_basic_address;
    assign  blk2basic_writedata [arb_analog] = cpu_basic_writedata;
    assign  blk2basic_write     [arb_analog] = cpu_basic_write;
    assign  blk2basic_read      [arb_analog] = cpu_basic_read;
    assign  req                 [arb_analog] = cpu_basic_req[arb_analog];
    assign  busy                [arb_analog] = cpu_busy[arb_analog];
    assign  done                [arb_analog] = ~busy[arb_analog];
  end else begin:no_analog
    // Disable analog block
    assign blk2mgmt_readdata    [arb_analog] = 32'd0;
    assign blk2mgmt_waitrequest [arb_analog] = 1'b0;
    assign blk2basic_address    [arb_analog] = {width_bwa{1'b0}};
    assign blk2basic_writedata  [arb_analog] = 32'd0;
    assign blk2basic_write      [arb_analog] = 1'b0;
    assign blk2basic_read       [arb_analog] = 1'b0;
    assign req                  [arb_analog] = 1'b0;
    assign busy                 [arb_analog] = 1'b0; 
    assign done                 [arb_analog] = ~busy[arb_analog];
  end
  endgenerate



  ///////////////////////////////////////////
  // Sub-component: "EyeQ" eye monitor
  // word address offset: +16
  ///////////////////////////////////////////
  generate if (enable_eyemon) begin:eyemon

    assign busy[arb_eyemon] = ~done[arb_eyemon];

    alt_xcvr_reconfig_eyemon #(
      .number_of_reconfig_interfaces          (number_of_reconfig_interfaces),
      .enable_ber_counter                     (enable_ber),
      .device_family                          (device_family)
    ) sc_eyemon (
      .reconfig_clk                           (mgmt_clk_clk),
      .reset                                  (reconfig_subblock_reset),
      // external mgmt interface facing
      .eyemon_address                         (reconfig_mgmt_address[2:0]),
      .eyemon_writedata                       (reconfig_mgmt_writedata),
      .eyemon_write                           (reconfig_mgmt_write & r_decode[arb_eyemon]),
      .eyemon_read                            (reconfig_mgmt_read & r_decode[arb_eyemon]),
      .eyemon_readdata                        (blk2mgmt_readdata[arb_eyemon]),
      .eyemon_waitrequest                     (blk2mgmt_waitrequest[arb_eyemon]),
      .eyemon_done                            (done[arb_eyemon]),
      // master-to-slave fabric facing, to basic reconfig
      .eyemon_waitrequest_from_base           (basic_waitrequest),
      .eyemon_readdata_base                   (basic_readdata),
      .eyemon_address_base                    (blk2basic_address  [arb_eyemon]),
      .eyemon_writedata_base                  (blk2basic_writedata[arb_eyemon]),
      .eyemon_write_base                      (blk2basic_write    [arb_eyemon]),
      .eyemon_read_base                       (blk2basic_read     [arb_eyemon]),
      .eyemon_irq_from_base                   (),
      // fabric acquisition for basic block access
      .arb_req                                (req[arb_eyemon]),
      .arb_grant                              (grant[arb_eyemon]),
      //testbus
      .eyemon_testbus                         (lch_testbus)
    );
  end
  else begin:no_eyemon
    // placeholders for missing block
    assign blk2mgmt_readdata   [arb_eyemon] = 32'd0;
    assign blk2mgmt_waitrequest[arb_eyemon] = 1'b0;
    assign blk2basic_address  [arb_eyemon] = {width_bwa{1'b0}};
    assign blk2basic_writedata[arb_eyemon] = 32'd0;
    assign blk2basic_write    [arb_eyemon] = 1'b0;
    assign blk2basic_read     [arb_eyemon] = 1'b0;
    assign req  [arb_eyemon] = 1'b0;
    assign busy [arb_eyemon] = 1'b0;
    assign done [arb_eyemon] = ~busy[arb_eyemon];
  end
  endgenerate


  ///////////////////////////////////////////
  // Sub-component: DFE
  // word address offset: +24
  ///////////////////////////////////////////

  // DFE controls 'done' signal, mainly for S4 legacy
  generate if (enable_dfe) begin:dfe

    assign busy[arb_dfe] = ~done[arb_dfe];

    alt_xcvr_reconfig_dfe #(
      .number_of_reconfig_interfaces    (number_of_reconfig_interfaces),
      .device_family                    (device_family)
    ) sc_dfe (
      .reconfig_clk                     (mgmt_clk_clk),
      .reset                            (reconfig_subblock_reset),
      .hold                             (hold[arb_dfe]),

      // external mgmt interface facing
      .dfe_address                      (reconfig_mgmt_address[2:0]),
      .dfe_writedata                    (reconfig_mgmt_writedata),
      .dfe_write                        (reconfig_mgmt_write & r_decode[arb_dfe]),
      .dfe_read                         (reconfig_mgmt_read & r_decode[arb_dfe]),
      .dfe_readdata                     (blk2mgmt_readdata[arb_dfe]),
      .dfe_waitrequest                  (blk2mgmt_waitrequest[arb_dfe]),
      .dfe_done                   (done[arb_dfe]),
      // master-to-slave fabric facing, to basic reconfig
      .dfe_waitrequest_from_base        (basic_waitrequest),
      .dfe_readdata_base                (basic_readdata),
      .dfe_address_base                 (blk2basic_address  [arb_dfe]),
      .dfe_writedata_base               (blk2basic_writedata[arb_dfe]),
      .dfe_write_base                   (blk2basic_write    [arb_dfe]),
      .dfe_read_base                    (blk2basic_read     [arb_dfe]),
      .dfe_irq_from_base(),
      // fabric acquisition for basic block access
      .arb_req                          (req[arb_dfe]),
      .arb_grant                        (grant[arb_dfe]),
      // testbus
      .dfe_testbus                      (lch_testbus)
    );
  end
  else begin:no_dfe
    // placeholders for missing block
    assign blk2mgmt_readdata   [arb_dfe] = 32'd0;
    assign blk2mgmt_waitrequest[arb_dfe] = 1'b0;
    assign blk2basic_address  [arb_dfe] = {width_bwa{1'b0}};
    assign blk2basic_writedata[arb_dfe] = 32'd0;
    assign blk2basic_write    [arb_dfe] = 1'b0;
    assign blk2basic_read     [arb_dfe] = 1'b0;
    assign req  [arb_dfe] = 1'b0;
    assign busy [arb_dfe] = 1'b0;
    assign done [arb_dfe] = ~busy[arb_dfe];
  end
  endgenerate

  ///////////////////////////////////////////
  // Sub-component: direct access
  // word address offset: +32
  ///////////////////////////////////////////

  assign  busy[arb_direct]  = 1'b0;
  assign  done[arb_direct]  = ~busy[arb_direct];

  generate
  if (enable_direct) begin:direct
    alt_xcvr_reconfig_direct #(
      .device_family(device_family)
    ) sc_direct (
      .clk(mgmt_clk_clk),
      .reset(reconfig_subblock_reset),
      // external mgmt interface facing
      .address    (reconfig_mgmt_address[2:0]),
      .writedata  (reconfig_mgmt_writedata),
      .write      (reconfig_mgmt_write & r_decode[arb_direct]),
      .read       (reconfig_mgmt_read & r_decode[arb_direct]),
      .readdata   (blk2mgmt_readdata[arb_direct]),
      .waitrequest(blk2mgmt_waitrequest[arb_direct]),
      // master-to-slave fabric facing, to basic reconfig
      .basic_waitrequest(basic_waitrequest),
      .basic_readdata   (basic_readdata),
      .basic_address    (blk2basic_address  [arb_direct]),
      .basic_writedata  (blk2basic_writedata[arb_direct]),
      .basic_write      (blk2basic_write    [arb_direct]),
      .basic_read       (blk2basic_read     [arb_direct]),
      // fabric acquisition for basic block access
      .arb_req  (req[arb_direct]),
      .arb_grant(grant[arb_direct])
    );
  end
  else begin:no_direct
    // placeholders for missing block
    assign req[arb_direct] = 1'b0;
    assign blk2mgmt_readdata   [arb_direct] = 32'd0;
    assign blk2mgmt_waitrequest[arb_direct] = 1'b0;
    assign blk2basic_address  [arb_direct] = {width_bwa{1'b0}};
    assign blk2basic_writedata[arb_direct] = 32'd0;
    assign blk2basic_write    [arb_direct] = 1'b0;
    assign blk2basic_read     [arb_direct] = 1'b0;
  end
  endgenerate


   ///////////////////////////////////////////
   // Sub-component: ADCE
   // word address offset: +40 (0x28)
   ///////////////////////////////////////////

   
   generate
      if (enable_adce) begin:adce
         
         assign busy[arb_adce]= ~done[arb_adce];

         alt_xcvr_reconfig_adce 
         #(
           .number_of_reconfig_interfaces ( number_of_reconfig_interfaces ),
           .device_family                 ( device_family                 )
           ) sc_adce 
         (
          .reconfig_clk                  ( mgmt_clk_clk                               ),
          .reset                         ( reconfig_subblock_reset                           ),
          .hold                          ( hold[arb_adce]                             ),
          // external mgmt interface facing
          .adce_address                  ( reconfig_mgmt_address[ 2:0 ]               ),
          .adce_writedata                ( reconfig_mgmt_writedata),
          .adce_write                    ( reconfig_mgmt_write & r_decode[ arb_adce ] ),
          .adce_read                     ( reconfig_mgmt_read  & r_decode[ arb_adce ] ),
          .adce_readdata                 ( blk2mgmt_readdata   [ arb_adce ]           ),
          .adce_waitrequest              ( blk2mgmt_waitrequest[ arb_adce ]           ),
          .adce_done                     ( done[arb_adce]                              ),
          // master-to-slave fabric facing, to basic reconfig
          .adce_b_waitrequest            ( basic_waitrequest                          ),
          .adce_b_readdata               ( basic_readdata                             ),
          .adce_b_address                ( blk2basic_address  [ arb_adce ]            ),
          .adce_b_writedata              ( blk2basic_writedata[ arb_adce ]            ),
          .adce_b_write                  ( blk2basic_write    [ arb_adce ]            ),
          .adce_b_read                   ( blk2basic_read     [ arb_adce ]            ),
          .adce_b_irq                    (                                            ),
          // fabric acquisition for basic block access
          .adce_b_arb_req                ( req[ arb_adce ]                            ),
          .adce_b_arb_grant              ( grant[ arb_adce ]                          ),
          // testbus
          .adce_testbus                  ( lch_testbus                                )
          );
      end else begin:no_adce
         // placeholders for missing block
         assign blk2mgmt_readdata    [arb_adce] = 32'd0;
         assign blk2mgmt_waitrequest [arb_adce] = 1'b0;
         assign blk2basic_address    [arb_adce] = {width_bwa{1'b0}};
         assign blk2basic_writedata  [arb_adce] = 32'd0;
         assign blk2basic_write      [arb_adce] = 1'b0;
         assign blk2basic_read       [arb_adce] = 1'b0;
         assign req                  [arb_adce] = 1'b0;
         assign busy                 [arb_adce] = 1'b0; 
         assign done                 [arb_adce] = ~busy[arb_adce];
      end
   endgenerate


 ///////////////////////////////////////////
  // Sub-component: DCD
  // word address offset: +72
  ///////////////////////////////////////////
  generate if (enable_dcd) begin:dcd

    assign busy[arb_dcd] = ~done[arb_dcd];

    alt_xcvr_reconfig_dcd #(
      .number_of_reconfig_interfaces (number_of_reconfig_interfaces),
      .enable_dcd_power_up(enable_dcd_power_up),
      .device_family (device_family)
    ) sc_dcd (
      .reconfig_clk        (mgmt_clk_clk),
      .reset               (reconfig_subblock_reset),
      .hold                (hold[arb_dcd]),  
      // ATB comparator output for Arria V
      .lch_atbout          (lch_atbout),
      // external mgmt interface facing
      .dcd_address         (reconfig_mgmt_address[2:0]),
      .dcd_writedata       (reconfig_mgmt_writedata),
      .dcd_write           (reconfig_mgmt_write & r_decode[arb_dcd]),
      .dcd_read            (reconfig_mgmt_read  & r_decode[arb_dcd]),
      .dcd_readdata        (blk2mgmt_readdata[arb_dcd]),
      .dcd_waitrequest     (blk2mgmt_waitrequest[arb_dcd]),
      .dcd_done            (done[arb_dcd]),
      // master-to-slave fabric facing, to basic reconfig
      .dcd_waitrequest_from_base (basic_waitrequest),
      .dcd_readdata_base   (basic_readdata),
      .dcd_address_base    (blk2basic_address  [arb_dcd]),
      .dcd_writedata_base  (blk2basic_writedata[arb_dcd]),
      .dcd_write_base      (blk2basic_write    [arb_dcd]),
      .dcd_read_base       (blk2basic_read     [arb_dcd]),
      .dcd_irq_from_base(),
      // fabric acquisition for basic block access
      .arb_req             (req[arb_dcd]),
      .arb_grant           (grant[arb_dcd])
    );
  end
  else begin:no_dcd
    // placeholders for missing block
    assign blk2mgmt_readdata   [arb_dcd] = 32'd0;
    assign blk2mgmt_waitrequest[arb_dcd] = 1'b0;
    assign blk2basic_address  [arb_dcd] = {width_bwa{1'b0}};
    assign blk2basic_writedata[arb_dcd] = 32'd0;
    assign blk2basic_write    [arb_dcd] = 1'b0;
    assign blk2basic_read     [arb_dcd] = 1'b0;
    assign req  [arb_dcd] = 1'b0;
    assign busy [arb_dcd] = 1'b0;
    assign done [arb_dcd] = ~busy[arb_dcd];
  end
  endgenerate  


  //*************************************************************************
  //***************************** LC PLL Tuning *****************************
  assign  done[arb_lc]  = ~busy[arb_lc];
  generate if(l_enable_lc == 1) begin:lc
    // CPU <-> MGMT connections
    assign  blk2mgmt_readdata   [arb_lc]  = cpu_mgmt_readdata;
    assign  blk2mgmt_waitrequest[arb_lc]  = cpu_mgmt_waitrequest;
    // CPU <-> Basic connections
    assign  blk2basic_address   [arb_lc]  = cpu_basic_address;
    assign  blk2basic_writedata [arb_lc]  = cpu_basic_writedata;
    assign  blk2basic_write     [arb_lc]  = cpu_basic_write;
    assign  blk2basic_read      [arb_lc]  = cpu_basic_read;
    assign  req                 [arb_lc]  = cpu_basic_req[arb_lc];
    assign  busy                [arb_lc]  = cpu_busy[arb_lc];
  end else begin:no_lc
    assign blk2mgmt_readdata    [arb_lc]  = 32'd0;
    assign blk2mgmt_waitrequest [arb_lc]  = 1'b0;
    assign blk2basic_address    [arb_lc]  = {width_bwa{1'b0}};
    assign blk2basic_writedata  [arb_lc]  = 32'd0;
    assign blk2basic_write      [arb_lc]  = 1'b0;
    assign blk2basic_read       [arb_lc]  = 1'b0;
    assign req                  [arb_lc]  = 1'b0;
    assign busy                 [arb_lc]  = 1'b0;
  end
  endgenerate
  //*************************** End LC PLL Tuning ***************************
  //*************************************************************************


  //*************************************************************************
  //***************************** MIF Streamer ******************************
  generate if(enable_mif == 1) begin:mif

    assign busy[arb_mif] = ~done[arb_mif];

    alt_xcvr_reconfig_mif #(
        .device_family                 ( device_family ),
        .enable_mif                    ( enable_mif    )
    ) sc_mif (

      //User interface
      .reconfig_clk               ( mgmt_clk_clk                            ),        
      .reset                      ( reconfig_subblock_reset                 ),
      .mif_reconfig_address       ( reconfig_mgmt_address[2:0]              ),             
      .mif_reconfig_writedata     ( reconfig_mgmt_writedata                 ),
      .mif_reconfig_write         ( reconfig_mgmt_write & r_decode[arb_mif] ),
      .mif_reconfig_read          ( reconfig_mgmt_read & r_decode[arb_mif]  ),
      .mif_reconfig_readdata      ( blk2mgmt_readdata[arb_mif]              ),      
      .mif_reconfig_waitrequest   ( blk2mgmt_waitrequest[arb_mif]           ),
      .mif_reconfig_done          ( done[arb_mif]                           ),

      //PLL reconfig interface
      .mif_pll_busy               ( pll_mif_busy    ),
      .mif_pll_err                ( pll_mif_err     ),
      .mif_pll_go                 ( mif_pll_go      ),
      .mif_pll_type               ( mif_pll_type    ),
      .mif_pll_lch                ( mif_pll_lch     ),
      .mif_pll_data               ( mif_pll_data    ),
      .mif_pll_pll_type           ( mif_pll_pll_type),

      //MIF storage interface
      .mif_stream_address         ( reconfig_mif_address     ),   
      .mif_stream_read            ( reconfig_mif_read        ),
      .mif_stream_waitrequest     ( reconfig_mif_waitrequest ), 
      .mif_stream_readdata        ( reconfig_mif_readdata    ),  
              
      //Basic interface         
      .mif_base_address           ( blk2basic_address[arb_mif]   ),   
      .mif_base_writedata         ( blk2basic_writedata[arb_mif] ),  
      .mif_base_write             ( blk2basic_write[arb_mif]     ),                         
      .mif_base_read              ( blk2basic_read[arb_mif]      ),                          
      .mif_base_readdata          ( basic_readdata               ),         
      .mif_base_waitrequest       ( basic_waitrequest            ), 
      .mif_base_irq               ( 1'd0                         ),  //unused
      
        //arbiter 
      .arb_req                    (req[arb_mif]   ),
      .arb_grant                  (grant[arb_mif] )
    );  
  end else begin:no_mif
    wire mif_unused;

    assign blk2mgmt_readdata    [arb_mif] = 32'd0;
    assign blk2mgmt_waitrequest [arb_mif] = 1'b0;
    assign blk2basic_address    [arb_mif] = {width_bwa{1'b0}};
    assign blk2basic_writedata  [arb_mif] = 32'd0;
    assign blk2basic_write      [arb_mif] = 1'b0;
    assign blk2basic_read       [arb_mif] = 1'b0;
    assign req                  [arb_mif] = 1'b0;
    assign busy                 [arb_mif] = 1'b0 | mif_unused; 
    assign done                 [arb_mif] = ~busy[arb_mif];

    assign reconfig_mif_read       = 1'b0;
    assign reconfig_mif_address    = 32'd0;

    assign mif_pll_go       = 1'b0;
    assign mif_pll_type     = 1'b0;
    assign mif_pll_lch      = 10'd0;
    assign mif_pll_data     = 4'd0;
    assign mif_pll_pll_type = 1'b0;
    // prevent warnings
    assign mif_unused     = & {1'b0,mif_pll_pll_type,mif_pll_data,mif_pll_lch,mif_pll_type,mif_pll_go};

  end
  endgenerate
  //*************************** End MIF Streamer ****************************
  //*************************************************************************


  //*************************************************************************
  //***************************** PLL Reconfig ******************************
 generate if(enable_pll == 1 || enable_mif == 1) begin:pll

    assign busy[arb_pll] = ~done[arb_pll];

    alt_xcvr_reconfig_pll #(
        .device_family                 ( device_family )
    ) sc_pll (

      //User interface
      .reconfig_clk               ( mgmt_clk_clk                            ),        
      .reset                      ( reconfig_subblock_reset                 ),
      .pll_reconfig_address       ( reconfig_mgmt_address[2:0]              ),             
      .pll_reconfig_writedata     ( reconfig_mgmt_writedata                 ),
      .pll_reconfig_write         ( reconfig_mgmt_write & r_decode[arb_pll] ),
      .pll_reconfig_read          ( reconfig_mgmt_read & r_decode[arb_pll]  ),
      .pll_reconfig_readdata      ( blk2mgmt_readdata[arb_pll]              ),      
      .pll_reconfig_waitrequest   ( blk2mgmt_waitrequest[arb_pll]           ),
      .pll_reconfig_done          ( done[arb_pll]                           ),

      //MIF interface
      .pll_mif_busy               ( pll_mif_busy    ),
      .pll_mif_err                ( pll_mif_err     ),
      .pll_mif_go                 ( mif_pll_go      ),
      .pll_mif_type               ( mif_pll_type    ),
      .pll_mif_lch                ( mif_pll_lch     ),
      .pll_mif_data               ( mif_pll_data    ),
      .pll_mif_pll_type           ( mif_pll_pll_type),

      //Basic interface         
      .pll_base_address           ( blk2basic_address[arb_pll]   ),   
      .pll_base_writedata         ( blk2basic_writedata[arb_pll] ),  
      .pll_base_write             ( blk2basic_write[arb_pll]     ),                         
      .pll_base_read              ( blk2basic_read[arb_pll]      ),                          
      .pll_base_readdata          ( basic_readdata               ),         
      .pll_base_waitrequest       ( basic_waitrequest            ), 
     // .pll_base_irq               ( 1'd0                         ),  //unused
      
        //arbiter 
      .arb_req                    (req[arb_pll]   ),
      .arb_grant                  (grant[arb_pll] )
    );  
  end else begin:no_pll
    wire  pll_unused;
    assign blk2mgmt_readdata    [arb_pll] = 32'd0;
    assign blk2mgmt_waitrequest [arb_pll] = 1'b0;
    assign blk2basic_address    [arb_pll] = {width_bwa{1'b0}};
    assign blk2basic_writedata  [arb_pll] = 32'd0;
    assign blk2basic_write      [arb_pll] = 1'b0;
    assign blk2basic_read       [arb_pll] = 1'b0;
    assign req                  [arb_pll] = 1'b0;
    assign busy                 [arb_pll] = 1'b0 | pll_unused; 
    assign done                 [arb_pll] = ~busy[arb_pll];

    assign pll_mif_busy                   = 1'b0;
    assign pll_mif_err                    = 1'b0;
    // prevent warnings
    assign pll_unused                     = & {1'b0,pll_mif_err,pll_mif_busy};
  end
  endgenerate

  //*************************** End PLL Reconfig ****************************
  //*************************************************************************

  //*************************************************************************
  //**************************** Reconfig CPU *******************************
  generate if(enable_soc_mask != 0) begin:soc
    wire  [arb_count-1:0] cpu_decode;

    assign  cpu_decode  = r_decode & enable_soc_mask;

    alt_xcvr_reconfig_soc #(
        .device_family  (device_family),
        .arb_count      (arb_count    ),
        .width_awa      (width_awa    ),
        .width_bwa      (width_bwa    ),
        .number_of_reconfig_interfaces(number_of_reconfig_interfaces),
        .enable_soc_mask(enable_soc_mask)
    ) sc_soc(
      // user reconfiguration management interface
      .mgmt_clk         (mgmt_clk_clk           ),
      .mgmt_rst         (reconfig_subblock_reset),
      .mgmt_address     (reconfig_mgmt_address  ),
      .mgmt_read        (reconfig_mgmt_read     ),
      .mgmt_write       (reconfig_mgmt_write    ),
      .mgmt_writedata   (reconfig_mgmt_writedata),
      .mgmt_readdata    (cpu_mgmt_readdata      ),
      .mgmt_waitrequest (cpu_mgmt_waitrequest   ),
      .mgmt_decode      (cpu_decode             ),
      .hold             (hold                   ),
      .busy             (cpu_busy               ),
      .hard_busy        (busy                   ),
    
      // CPU <-> Basic interface
      .basic_address    (cpu_basic_address      ),
      .basic_writedata  (cpu_basic_writedata    ),
      .basic_write      (cpu_basic_write        ),
      .basic_read       (cpu_basic_read         ),
      .basic_readdata   (basic_readdata         ),
      .basic_waitrequest(basic_waitrequest      ),
      .basic_req        (cpu_basic_req          ),  // request access to B block
      .basic_grant      (grant                  ),  // granted access to B block

      // Testbus
      .lch_testbus      (lch_testbus            ),
      .pch_testbus      (pch_testbus            )
    );
  end else begin:no_soc // No CPU

    assign  cpu_mgmt_readdata     = 32'd0;
    assign  cpu_mgmt_waitrequest  = 1'b0;
    assign  cpu_basic_read        = 1'b0;
    assign  cpu_basic_write       = 1'b0;
    assign  cpu_basic_address     = {width_bwa{1'b0}};
    assign  cpu_basic_writedata   = 32'd0;
    assign  cpu_basic_req         = {arb_count{1'b0}};
    assign  cpu_busy              = {arb_count{1'b0}};
  end
  endgenerate
  //**************************** Reconfig CPU *******************************
  //*************************************************************************


  ////////////////////////////////////////////////////////////////////
  // Calibration Start-up sequencing control and coordination 
  ////////////////////////////////////////////////////////////////////
  alt_xcvr_reconfig_cal_seq  #(
        .arb_count(arb_count)
)
cal_seq (
  .reconfig_clk         (mgmt_clk_clk),
  .reset                (reconfig_subblock_reset),
  .busy                 (busy   ),
  .cal_busy_in          (cal_busy_in),

  // user reconfiguration management interface
  .hold                 (hold   ),
  .reconfig_busy        (reconfig_busy ),
  .tx_cal_busy          (tx_cal_busy    ),
  .rx_cal_busy          (rx_cal_busy    ),
  .oc_cal_busy          (oc_cal_busy    )
  );

  ////////////////////////////////////////////////////////////////////
  // The basic block is a switch and interface to the native reconfig
  ////////////////////////////////////////////////////////////////////
  alt_xcvr_reconfig_basic #(
    .basic_ifs(1),
    .native_ifs(number_of_reconfig_interfaces),
    .device_family(device_family)
  ) basic (
    .reconfig_clk(mgmt_clk_clk),
    .reset(r_mgmt_rst_reset),
    .lif_is_active(lif_is_active),

    .oc_cal_busy(oc_cal_busy),
    .tx_cal_busy(tx_cal_busy),
    .rx_cal_busy(rx_cal_busy),
    .reconfig_to_xcvr(reconfig_to_xcvr),
    .reconfig_from_xcvr(reconfig_from_xcvr),

    .basic_reconfig_write(basic_write),
    .basic_reconfig_read(basic_read),
    .basic_reconfig_writedata(basic_writedata),
    .basic_reconfig_address(basic_address),
    .basic_reconfig_readdata(basic_readdata),
    .basic_reconfig_waitrequest(basic_waitrequest),
    .ifsel_notdone(ifsel_notdone),
    .lch_testbus(lch_testbus),
    .pch_testbus(pch_testbus),
    .lch_atbout(lch_atbout)
    //.basic_reconfig_irq(basic_reconfig_irq)
  );


  ///////////////////////////////////////////
  // Status to external mgmt interface
  ///////////////////////////////////////////
 // assign reconfig_busy = |busy;
 
    
  //////////////////////////////////////////////////////////////////////////////////////
  // Synchronize the ifsel_notdone into each Reconfig IP block
  //////////////////////////////////////////////////////////////////////////////////////
  always @(posedge mgmt_clk_clk or posedge r_mgmt_rst_reset) begin
    if (r_mgmt_rst_reset == 1)
      ifsel_notdone_resync <= 1'b1;
    else
      ifsel_notdone_resync <= ifsel_notdone;
    end

    
    assign reconfig_subblock_reset = ifsel_notdone_resync;


endmodule
