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
// Reset controller for Stratix IV transceivers with RX CDR in auto-lock mode. 
//
// Uses alt_reset_ctrl_lego to handle each reset stage, with 3 required for the overall sequence.
// Parameter defaults for pll-powerdown and lock-to-data-auto timers assume 50 MHz system clock
//
//      $Header$
//

`timescale 1 ns / 1 ns

(* altera_attribute = "-name MERGE_TX_PLL_DRIVEN_BY_REGISTERS_WITH_SAME_CLEAR ON -to \"alt_reset_ctrl_lego:lego_pll_powerdown|zspulse\" " *)
module  alt_reset_ctrl_tgx_cdrauto
#(
        parameter       sys_clk_in_mhz = 50     // needed for 1us and 4us delay timers
)
(
        // User inputs and outputs
        input   wire    clock,
        input   wire    reset_all,
        input   tri0    reset_tx_digital,
        input   tri0    reset_rx_digital,
        input   wire    powerdown_all,
        output  wire    tx_ready,
        output  wire    rx_ready,
        
        // I/O to Stratix IV transceiver control & status
        output  wire    pll_powerdown,          // reset TX PLL
        output  wire    tx_digitalreset,        // reset TX PCS
        output  wire    rx_analogreset,         // reset RX PMA
        output  wire    rx_digitalreset,        // reset RX PCS
        output  wire    gxb_powerdown,          // powerdown whole quad
        input   wire    pll_is_locked,          // TX PLL is locked status
        input   tri0    tx_cal_busy,            // TX channel calibration status
        input   tri0    rx_cal_busy,            // RX channel calibration status
        input   tri0    rx_is_lockedtodata,     // RX CDR PLL is locked to data status
        input   tri0    manual_mode             // 0=Automatically reset RX after loss of rx_is_lockedtodata
);

localparam clk_in_mhz =
`ifdef QUARTUS__SIMGEN
        2;  // simulation-only value
`elsif ALTERA_RESERVED_QIS
        sys_clk_in_mhz; // use real counter lengths for normal Quartus synthesis
`else
        2;  // simulation-only value
`endif
localparam t_pll_powerdown = clk_in_mhz; // 1 us minimum
localparam t_ltd_auto = clk_in_mhz*4; // 4 us minimum


wire pll_is_locked_r;           // pll_is_locked resynchronized
wire tx_cal_busy_r;             // tx_cal_busy resynchronized
wire rx_cal_busy_r;             // rx_cal_busy resynchronized
wire rx_is_lockedtodata_r;      // rx_is_lockedtodata resynchronized

wire sdone_lego_pll_powerdown;  // 'sequence done' output of pll_powerdown lego
wire sdone_lego_tx_digitalreset;// 'sequence done' output of tx_digitalreset lego
wire sdone_lego_rx_digitalreset;// 'sequence done' output of rx_digitalreset lego
wire sdone_lego_rx_analogreset; // 'sequence done' output of rx_analogreset lego
wire wire_tx_digital_only_reset;// reset output for TX digital-only
wire wire_rx_digital_only_reset;// reset output for RX digital-only
wire wire_tx_digitalreset;      // TX digital full-reset source
wire wire_rx_digitalreset;      // RX digital full-reset source
wire wire_rx_digital_retrigger; // Trigger new RX digital sequence after main sequence completes, and lose lock-to-data

// Resynchronize input signals
alt_xcvr_resync #(
        .WIDTH(2)
 ) alt_xcvr_resync_inst_0 (
        .clk    (clock),
        .reset  (1'b0),
        .d      ({pll_is_locked  ,rx_is_lockedtodata  }),
        .q      ({pll_is_locked_r,rx_is_lockedtodata_r})
);

alt_xcvr_resync #(
        .WIDTH(2),
        .INIT_VALUE(1)
 ) alt_xcvr_resync_inst_1 (
        .clk    (clock),
        .reset  (1'b0),
        .d      ({rx_cal_busy,tx_cal_busy}),
        .q      ({rx_cal_busy_r,tx_cal_busy_r})
);

// First reset ctrl sequencer lego is for pll_powerdown generation
alt_reset_ctrl_lego #(
        .reset_hold_cycles(t_pll_powerdown) // hold pll_powerdown for 1us
 ) lego_pll_powerdown ( .clock(clock),
        .start(reset_all),      // Do not use resynched version of reset_all here
        .aclr(powerdown_all),
        .reset(pll_powerdown),
        .rdone(pll_is_locked_r),
        .sdone(sdone_lego_pll_powerdown));

// next reset ctrl sequencer lego is for tx_digitalreset generation
alt_reset_ctrl_lego #(
        .reset_hold_til_rdone(1)        // hold until rdone arrives for this test case
 ) lego_tx_digitalreset (       .clock(clock),
        .start(reset_all),
        .aclr(powerdown_all),
        .reset(wire_tx_digitalreset),
        .rdone(sdone_lego_pll_powerdown & ~tx_cal_busy_r), 
        .sdone(sdone_lego_tx_digitalreset));

// next reset ctrl sequencer lego is for rx_analogreset generation
alt_reset_ctrl_lego #(
        .reset_hold_til_rdone(1),       // hold until rdone arrives for this test case
        .sdone_delay_cycles(2)          // hold rx_analogreset 2 parallel_clock cycles after offset cancellation done
 ) lego_rx_analogreset (        .clock(clock),
        .start(reset_all),
        .aclr(powerdown_all),
        .reset(rx_analogreset),
        .rdone(sdone_lego_tx_digitalreset & ~rx_cal_busy_r), 
        .sdone(sdone_lego_rx_analogreset));

// last reset ctrl sequencer lego is for rx_digitalreset generation
alt_reset_ctrl_lego #(
        .reset_hold_til_rdone(1),       // hold until rdone arrives for this test case
        .sdone_delay_cycles(t_ltd_auto) // hold rx_digitalreset for 4us
 ) lego_rx_digitalreset (       .clock(clock),
        .start(~manual_mode & reset_all | wire_rx_digital_retrigger),
        .aclr(powerdown_all),
        .reset(wire_rx_digitalreset),
        .rdone(sdone_lego_rx_analogreset & rx_is_lockedtodata_r),
        .sdone(sdone_lego_rx_digitalreset));

//////////// digital-only reset ////////////
// separate reset ctrl sequencer lego for digital-only reset generation
alt_reset_ctrl_lego #(
        .reset_hold_cycles(3)   // hold 2 parallel clock cycles (assumes sysclk slower or same freq as parallel clock)
 ) lego_tx_digitalonly (        .clock(clock),
        .start(reset_tx_digital | reset_all),
        .aclr(powerdown_all),
        .reset(wire_tx_digital_only_reset),
        .rdone(sdone_lego_tx_digitalreset),
        .sdone(tx_ready));      // TX status indicator for user

alt_reset_ctrl_lego #(
        .reset_hold_cycles(3)   // hold 2 parallel clock cycles (assumes sysclk slower or same freq as parallel clock)
 ) lego_rx_digitalonly (        .clock(clock),
        .start(reset_rx_digital | (reset_all & ~manual_mode) | wire_rx_digital_retrigger),
        .aclr(powerdown_all),
        .reset(wire_rx_digital_only_reset),
        .rdone(sdone_lego_rx_digitalreset),
        .sdone(rx_ready));      // RX status indicator for user

// digital resets have 2 possible sources: full-reset or digital-only
assign tx_digitalreset = wire_tx_digitalreset | wire_tx_digital_only_reset;
assign rx_digitalreset = wire_rx_digitalreset | wire_rx_digital_only_reset;

// re-trigger RX digital sequence when main sequence is complete (indicated by sdone_lego_rx_digitalreset)
// not manual mode, and lose lock-to-data
assign wire_rx_digital_retrigger = ~manual_mode & sdone_lego_rx_digitalreset & ~rx_is_lockedtodata_r;

// Quad power-down
assign gxb_powerdown = powerdown_all;


////////////////////////
// general assertions
//synopsys translate_off
// vlog/vcs/ncverilog:  +define+ALTERA_XCVR_ASSERTIONS
`ifdef ALTERA_XCVR_ASSERTIONS
always @(posedge clock) begin
        // reset_all starts by triggering CMU PLL powerdown
        assert property ($rose(reset_all) |=> $rose(pll_powerdown));
  // While CMU PLL powerdown is asserted, all other resets must be asserted
  assert property (pll_powerdown |-> (tx_digitalreset & rx_analogreset & rx_digitalreset));
        // While rx_analogreset is asserted, rx_digitalreset must be asserted
        assert property (rx_analogreset |-> rx_digitalreset);
        // When pll_is_locked is asserted, tx_digitalreset must be deasserted
        assert property ($rose(pll_is_locked_r) |-> ##[0:2] !tx_digitalreset);
        // During a reset, rx_digitalreset should remain high for t_ltd_auto after rx_is_lockedtodata rising edge
        assert property ($rose(rx_is_lockedtodata_r) & ~manual_mode|-> rx_digitalreset [*(t_ltd_auto+1)] ##1 !rx_digitalreset);
        assert property ($rose(rx_is_lockedtodata_r) & manual_mode|->!rx_digitalreset);
        // reset_tx_digital results in only a brief pulse on tx_digitalreset
        assert property ($rose(reset_tx_digital) |=>    tx_digitalreset [*3] );
        assert property ($rose(reset_tx_digital) & tx_ready |=> tx_digitalreset [*3] ##1 ~tx_digitalreset ##1 $rose(tx_ready) );
        // reset_rx_digital results in only a brief pulse on rx_digitalreset
        assert property ($rose(reset_rx_digital) |=>    rx_digitalreset [*3] );
        assert property ($rose(reset_rx_digital) & rx_ready |=> rx_digitalreset [*3] ##1 ~rx_digitalreset ##1 $rose(rx_ready) );
end
`endif
//synopsys translate_on

endmodule
