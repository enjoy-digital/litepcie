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
// Transceiver reconfig 'basic' block for Stratix V & derivatives
//
// $Header$
//

`timescale 1 ns / 1 ns
import altera_xcvr_functions::*;
//  -The PMA testbus ends up clocking some registers that are being used for edge detection circuitry,
//  -Note that the frequency assignment is somewhat arbitrary (matching nominal reconfig_clk frequency), since the testbus is effectively asyncrhonous.

 module av_xcvr_reconfig_basic #(


  parameter basic_ifs = 1,  // post-merge, allow multiple basic interfaces
  parameter native_ifs = 1, // number of native reconfig interfaces
  parameter physical_channel_mapping = ""
) (
  // avalon clock interface
  input   wire reconfig_clk,
  input   wire reset,
  input   wire lif_is_active,

  // avalon MM, "basic" interface
  input   wire [basic_ifs   -1:0] basic_reconfig_write,
  input   wire [basic_ifs   -1:0] basic_reconfig_read,
  input   wire [basic_ifs*32-1:0] basic_reconfig_writedata,
  input   wire [basic_ifs*3 -1:0] basic_reconfig_address,     // address to MM described below
  
  output  reg  [basic_ifs*32-1:0] basic_reconfig_readdata,
  output  wire [basic_ifs   -1:0] basic_reconfig_waitrequest,
  //output reg [basic_ifs-1:0] basic_reconfig_irq,  // interrupt to Master

  // native testbus interfaces: to logical interface:
  // We only expose timing-critical signals here. Other signals accessible through the register interface
  output  wire [basic_ifs*8 -1:0]  lch_testbus,  // testbus from native reconfig, for selected channel
  output  wire [basic_ifs*24 -1:0] pch_testbus,  // full triplet testbus
  
  output  wire                     atbout,   // voltage comparator output from native reconfig, for selected channel
  
  // gate soft-IPs from running by holding off logical mutex until interface select is done
  output wire ifsel_notdone,

  // bundled reconfig buses
  //input   wire reconfig_busy, // input from reconfig master blocks, to forward through the bundles
  input  wire oc_cal_busy,
  input  wire tx_cal_busy,
  input  wire rx_cal_busy,
  output  wire [native_ifs*W_S5_RECONFIG_BUNDLE_TO_XCVR -1:0] reconfig_to_xcvr, // all inputs from reconfig block to native xcvr reconfig ports
  input   wire [native_ifs*W_S5_RECONFIG_BUNDLE_FROM_XCVR-1:0] reconfig_from_xcvr // all input s from native xcvr reconfig ports to reconfig block
);
  ////////////////////////////////////////////////////////
  // reconfiguration and testbus ports, in unbundled form
  ////////////////////////////////////////////////////////
  localparam w_paddr = 12;    // width of physical avalon reconfig address

  // native testbus interfaces: to physical interfaces:
  wire [native_ifs*12 -1:0] pif_testbus_sel;    // 4 bits per physical channel
  (* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=HIGH"} *)
  reg                       pif_interface_sel;  // Shared for all interfaces
  (* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=HIGH"} *)
  reg                       pif_ser_shift_load; // Shared for all interfaces

  // native testbus signals: from physical interfaces
  wire [native_ifs*3*8-1:0] pif_testbus;  // testbus from native reconfig, for all physical interfaces  

  // avalon MM native reconfiguration interfaces
  wire [native_ifs*16     -1:0] native_reconfig_readdata; // Avalon DPRIO readdata
  wire [native_ifs*16     -1:0] native_reconfig_writedata;// Avalon DPRIO writedata
  wire [native_ifs*w_paddr-1:0] native_reconfig_address;  // Avalon DPRIO address
  wire [native_ifs        -1:0] native_reconfig_write;    // Avalon DPRIO write
  wire [native_ifs        -1:0] native_reconfig_read;     // Avalon DPRIO read

  ////////////////////////////////////////////////////////
  // OR'ing logic to combine I/O from multiple logical ifs
  ////////////////////////////////////////////////////////

  // outputs of the logical interface blocks, to drive native interfaces
  wire [native_ifs*16     -1:0] native_wdata [basic_ifs-1:0];
  wire [native_ifs*w_paddr-1:0] native_addr  [basic_ifs-1:0];
  wire [native_ifs        -1:0] native_write [basic_ifs-1:0];
  wire [native_ifs        -1:0] native_read  [basic_ifs-1:0];
  
  wire [native_ifs*12     -1:0] tb_sel       [basic_ifs-1:0];

  // readdata return from native interfaces
  wire [native_ifs*16-1:0] native_rdata;

  // wires for OR gates that drive native interfaces
  wire [native_ifs*16     -1:0] or_wdata    [basic_ifs-1:0];
  wire [native_ifs*w_paddr-1:0] or_addr     [basic_ifs-1:0];
  wire [native_ifs        -1:0] or_write    [basic_ifs-1:0];
  wire [native_ifs        -1:0] or_read     [basic_ifs-1:0];
  wire [native_ifs*12     -1:0] or_tb_sel   [basic_ifs-1:0];

  // physical interface request/grant arbitration wires, grouped for connection to lif block
  wire [native_ifs-1:0] lif_grouping_req   [basic_ifs-1:0];
  wire [native_ifs-1:0] lif_grouping_grant [basic_ifs-1:0];

  // physical interface request/grant arbitration wires, grouped for connection to pif arbiter
  wire [basic_ifs-1:0] pif_arbiter_req   [native_ifs-1:0];
  wire [basic_ifs-1:0] pif_arbiter_grant [native_ifs-1:0];

  // generate logical interface blocks, and OR-mux the native reconfig outputs
  genvar i;
  generate
    for (i=0; i<basic_ifs; ++i) begin: lif
      av_xrbasic_lif #(
        .logical_interface(i),  // which single logical interface is this?
        .native_ifs(native_ifs), // number of native reconfig interfaces
        .w_paddr(w_paddr),  // width of physical channel address
        .physical_channel_mapping(physical_channel_mapping) // string notation to define logical-to-physical channel mapping
      ) logical_if (
        // avalon clock interface
        .reconfig_clk(reconfig_clk),
        .reset(reset),
        .lif_is_active(lif_is_active),

        // avalon MM, "basic" interface
        .basic_reconfig_write(basic_reconfig_write[i]),
        .basic_reconfig_read(basic_reconfig_read[i]),
        .basic_reconfig_writedata(basic_reconfig_writedata[32*i +:32]),
        .basic_reconfig_address(basic_reconfig_address[3*i +:3]), // address to MM described sv_xrbasic_lif.sv
        .basic_reconfig_readdata(basic_reconfig_readdata[32*i +:32]),
        .basic_reconfig_waitrequest(basic_reconfig_waitrequest[i]),
        //.basic_reconfig_irq(basic_reconfig_irq[i]), // interrupt to Master
        
        // avalon MM native reconfiguration interfaces
        .native_reconfig_readdata(native_reconfig_readdata), // Avalon DPRIO readdata, concatenation of readdata from all phys ifs
        .native_reconfig_writedata(native_wdata[i]), // Avalon DPRIO writedata
        .native_reconfig_address(native_addr[i]),  // Avalon DPRIO address
        .native_reconfig_write(native_write[i]),  // Avalon DPRIO write
        .native_reconfig_read(native_read[i]),  // Avalon DPRIO read

        // testbus outputs (to physical interfaces)
        .pif_testbus_sel(tb_sel[i]),
        // testbus inputs (from physical interfaces)
        .pif_testbus(pif_testbus),

        // Logical interface outputs (to basic block clients)
        .lch_testbus(lch_testbus[8*i+:8]),
        .pch_testbus(pch_testbus[24*i+:24]),
		  

        // physical interface arbiter connections
        .pif_arb_req(lif_grouping_req[i]),
        .pif_arb_grant(lif_grouping_grant[i])
      );
      
      // OR-mux for native interface drivers
      if (i == 0) begin
        assign or_wdata     [0] = native_wdata[0];
        assign or_addr      [0] = native_addr [0];
        assign or_write     [0] = native_write[0];
        assign or_read      [0] = native_read [0];
        assign or_tb_sel    [0] = tb_sel      [0];
      end else begin
        assign or_wdata     [i] = native_wdata  [i] | or_wdata    [i-1];
        assign or_addr      [i] = native_addr   [i] | or_addr     [i-1];
        assign or_write     [i] = native_write  [i] | or_write    [i-1];
        assign or_read      [i] = native_read   [i] | or_read     [i-1];
        assign or_tb_sel    [i] = tb_sel        [i] | or_tb_sel   [i-1];
      end
    end
  endgenerate

  // connect native reconfig interfaces
  assign native_reconfig_write     = or_write     [basic_ifs-1];  // Avalon DPRIO write
  assign native_reconfig_read      = or_read      [basic_ifs-1];  // Avalon DPRIO read
  assign native_reconfig_address   = or_addr      [basic_ifs-1];
  assign native_reconfig_writedata = or_wdata     [basic_ifs-1];
  assign pif_testbus_sel           = or_tb_sel    [basic_ifs-1];

  // Logic for each physical (native) interface
  genvar li;
  genvar pi;
  generate
    for (pi=0; pi<native_ifs; ++pi) begin: pif
      alt_xcvr_arbiter #(
        // parameters
        .width(basic_ifs) // each phys interface needs one req/grant pair per logical interface (a.k.a. basic interface)
      ) pif_arb (
        // ports
        .clock(reconfig_clk),
        .req(pif_arbiter_req[pi]),
        .grant(pif_arbiter_grant[pi])
      );
      
      // map wires from lif grouping to the pif grouping needed for this phys interface arbiter
      for (li=0; li < basic_ifs; ++li) begin: lif2pif
        assign pif_arbiter_req[pi][li] = lif_grouping_req[li][pi];
        assign lif_grouping_grant[li][pi] = pif_arbiter_grant[pi][li];
      end
    end
  endgenerate

// -for iTrack 80226 - the core is potentially active 2240ns before the periphery - we must gate the assertion of 
//  serial shift load for this time
// -worst case, the maximum clock frequency of reconfig_clk is 125MHz (8ns).  Therefore, we must wait a maximum of 
//   280 clock cycles before asserting the serial shift load.
// -also, serial shift load counter should be gated by reset, as customers may source reconfig_clk from a PLL and would
//   need to gate all logic in the reconfig controller until the PLL locks

// UPDATE - increase wait time by 8x due to default SSM clock divisor being increased by 8x
  localparam COUNTER_WIDTH = 12;
  localparam NUM_SSL_CYCLES = 6;
  localparam [COUNTER_WIDTH-1:0] SSL_WAIT_TIME = 12'd2240; // total number of cycles to wait before switching interface_sel

  // register to initialize pif_interface_sel and pif_ser_shift_load
  (* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
  reg [COUNTER_WIDTH-1:0] reg_init = 0; 
  (* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=LOW"} *)
  reg init_done = 0; // only do the serial shift load and ifsel once
  
  assign ifsel_notdone = (reg_init < SSL_WAIT_TIME);

// -IC design also recommended that serial shift load be asserted for 4 clock cycles of the avalon clock (reconfig_clk)
  always @ (posedge reconfig_clk) begin
    init_done <= init_done;
    reg_init  <= reg_init;
    pif_interface_sel  <= ifsel_notdone; // active low - toggle from '1' to '0' on the last clock cycle
    pif_ser_shift_load <= ~((reg_init < (SSL_WAIT_TIME - 1)) && (reg_init > (SSL_WAIT_TIME-NUM_SSL_CYCLES))); // negative pulse for 4 cycles from SSL_WAIT_TIME-NUM_SSL_CYCLES to SSL_WAIT_TIME-1

    if (reset && ~init_done) begin // only reset the counter if we haven't already completed the init sequence
        reg_init <= {COUNTER_WIDTH{1'b0}};
    end else begin
      if (ifsel_notdone) begin // count to SSL_WAIT_TIME cycles (280 + 4 cycles for serial shift load assertion, and 1 cycle for interface_sel)
        reg_init <= reg_init + 1'b1;
      end else begin // ifsel is done - assert init_done
        init_done <= 1'b1;
      end
    end
  end

  // un/bundle reconfig signals
  av_reconfig_bundle_to_basic #(
    .native_ifs(native_ifs)
  ) bundle (
    .reconfig_to_xcvr(reconfig_to_xcvr),
    .reconfig_from_xcvr(reconfig_from_xcvr),

    .native_reconfig_readdata(native_reconfig_readdata),
    .pif_testbus(pif_testbus),
	 
    .pif_atbout(atbout),
    .native_reconfig_clk({native_ifs{reconfig_clk}}),
    .native_reconfig_reset({native_ifs{reset}}),
    .native_reconfig_writedata(native_reconfig_writedata),
    .native_reconfig_address(native_reconfig_address),
    .native_reconfig_write(native_reconfig_write),
    .native_reconfig_read(native_reconfig_read),
    .pif_testbus_sel(pif_testbus_sel),
    .pif_interface_sel({native_ifs{pif_interface_sel}}),
    .pif_ser_shift_load({native_ifs{pif_ser_shift_load}}),
    .oc_cal_busy(oc_cal_busy),
    .tx_cal_busy(tx_cal_busy),
    .rx_cal_busy(rx_cal_busy)
  );

endmodule
