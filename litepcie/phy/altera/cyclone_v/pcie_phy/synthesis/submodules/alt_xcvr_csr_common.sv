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

`timescale 1 ps / 1 ps

module alt_xcvr_csr_common #(
    parameter lanes   = 1,
    parameter plls    = 1,
    parameter rpc     = 0   // reset per channel
)
(
    // user data (avalon-MM formatted) 
    input   wire        clk,
    input   tri0        reset,
    input   wire [7:0]  address,
    input   tri0        read,
    output  reg  [31:0] readdata = 0,
    input   tri0        write,
    input   wire [31:0] writedata,

    // transceiver status inputs to this CSR
    input   wire [plls - 1 : 0]     pll_locked,
    input   wire [lanes - 1 : 0]    rx_is_lockedtoref,
    input   wire [lanes - 1 : 0]    rx_is_lockedtodata,
    input   wire [lanes - 1 : 0]    rx_signaldetect,
    
    // reset controller outputs
    input   wire                    reset_controller_tx_ready,
    input   wire                    reset_controller_rx_ready,
    input   wire                    reset_controller_pll_powerdown,
    input   wire [(rpc?lanes:1)-1:0]reset_controller_tx_digitalreset,
    input   wire [(rpc?lanes:1)-1:0]reset_controller_rx_analogreset,
    input   wire [(rpc?lanes:1)-1:0]reset_controller_rx_digitalreset,

    // read/write control registers
    // to reset controller
    output  reg                     csr_reset_tx_digital = 0,
    output  reg                     csr_reset_rx_digital = 0,
    output  reg                     csr_reset_all = 1,      // power-up to 1 to trigger auto-init sequence
    // to PMA and PCS reset inputs
    output  wire                    csr_pll_powerdown,      // reset controller or manual
    output  wire [lanes - 1 : 0]    csr_tx_digitalreset,    // reset controller or manual
    output  wire [lanes - 1 : 0]    csr_rx_analogreset,     // reset controller or manual
    output  wire [lanes - 1 : 0]    csr_rx_digitalreset,    // reset controller or manual
    // common PMA controls
    output  reg  [lanes - 1 : 0]    csr_phy_loopback_serial = 0,
    output  reg  [lanes - 1 : 0]    csr_rx_set_locktoref = 0,
    output  reg  [lanes - 1 : 0]    csr_rx_set_locktodata = 0
);
    import alt_xcvr_csr_common_h::*;
    
    localparam sync_stages = 2; // number of sync stages for transceiver status signals
    localparam sync_stages_str  = sync_stages[7:0] + 8'd48; // number of sync stages specified as string (for timing constraints)

    integer stage;

    // Parameter strings for embedded timing constraints
    localparam  CSR_PLLLOCKED_CONSTRAINT    = {"-name SDC_STATEMENT \"set regs [get_registers -nowarn *alt_xcvr_csr_common*csr_pll_locked*[",sync_stages_str,"]*]; if {[llength [query_collection -report -all $regs]] > 0} {set_false_path -to $regs}\""};
    localparam  CSR_RXISLOCKED_CONSTRAINT   = {"-name SDC_STATEMENT \"set regs [get_registers -nowarn *alt_xcvr_csr_common*csr_rx_is_locked*[",sync_stages_str,"]*]; if {[llength [query_collection -report -all $regs]] > 0} {set_false_path -to $regs}\""};
    localparam  CSR_RXSIGNALDET_CONSTRAINT  = {"-name SDC_STATEMENT \"set regs [get_registers -nowarn *alt_xcvr_csr_common*csr_rx_signaldetect*[",sync_stages_str,"]*]; if {[llength [query_collection -report -all $regs]] > 0} {set_false_path -to $regs}\""};
    localparam  SDC_CONSTRAINTS = {CSR_PLLLOCKED_CONSTRAINT,";",CSR_RXISLOCKED_CONSTRAINT,";",CSR_RXSIGNALDET_CONSTRAINT};
  
    // internal control registers
    reg  [lanes - 1 : 0]    csr_interrupt_ch_bitmask = {lanes{1'b1}};
    // fine reset control.  'OR' with reset controller equivalent signals
    reg                     csr_reset_or_pll_powerdown = 0;     // fine reset control
    reg                     csr_reset_or_reset_tx_digital = 0;  // fine reset control
    reg                     csr_reset_or_reset_rx_analog = 0;   // fine reset control
    reg                     csr_reset_or_reset_rx_digital = 0;  // fine reset control
    reg  [lanes - 1 : 0]    csr_reset_ch_bitmask = {lanes{1'b1}};
    reg  [1:0]              csr_reset_tx_digital_r;
    reg  [1:0]              csr_reset_rx_digital_r;
    
    // read-only status registers
    // These are synchronized forms of transceiver status signals
    // async inputs go to reg [sync_stages], and come out synchronized at reg [1]
    (* altera_attribute = SDC_CONSTRAINTS *)  // Apply timing constraints (does not matter which node)
    reg [plls - 1 : 0]  csr_pll_locked [sync_stages:1];
    reg [lanes - 1 : 0] csr_rx_is_lockedtoref [sync_stages:1];
    reg [lanes - 1 : 0] csr_rx_is_lockedtodata [sync_stages:1];
    reg [lanes - 1 : 0] csr_rx_signaldetect [sync_stages:1];

    // Internal expansion of reset controller inputs
    wire [lanes-1:0]  w_reset_controller_tx_digitalreset;
    wire [lanes-1:0]  w_reset_controller_rx_analogreset;
    wire [lanes-1:0]  w_reset_controller_rx_digitalreset;
    // Internal expansion of reset override registers
    wire [lanes-1:0]  w_csr_reset_or_reset_tx_digital;  // fine reset control
    wire [lanes-1:0]  w_csr_reset_or_reset_rx_analog;   // fine reset control
    wire [lanes-1:0]  w_csr_reset_or_reset_rx_digital;  // fine reset control

    // Synchronization registers
    always @(posedge clk) begin
      // synchronization registers for status signals from transceivers
      csr_pll_locked        [sync_stages] <= pll_locked;  // input from transceiver
      csr_rx_is_lockedtoref [sync_stages] <= rx_is_lockedtoref;
      csr_rx_is_lockedtodata[sync_stages] <= rx_is_lockedtodata;
      csr_rx_signaldetect   [sync_stages] <= rx_signaldetect;
      for (stage=2; stage <= sync_stages; stage = stage + 1) begin
          // additional sync stages
          csr_pll_locked        [stage-1] <= csr_pll_locked         [stage]; 
          csr_rx_is_lockedtoref [stage-1] <= csr_rx_is_lockedtoref  [stage];
          csr_rx_is_lockedtodata[stage-1] <= csr_rx_is_lockedtodata [stage];
          csr_rx_signaldetect   [stage-1] <= csr_rx_signaldetect    [stage];
      end
    end

    always @(posedge clk or posedge reset) begin
        if (reset == 1) begin
            readdata <= 0;
            csr_interrupt_ch_bitmask <= {lanes{1'b1}};
            
            csr_reset_tx_digital <= 0;
            csr_reset_rx_digital <= 0;
            csr_reset_tx_digital_r  <= 2'b00;
            csr_reset_rx_digital_r  <= 2'b00;
            csr_reset_all <= 1;     // reset to 1 to trigger auto-init sequence
            csr_reset_ch_bitmask <= {lanes{1'b1}};
            csr_reset_or_pll_powerdown <= 0;    // fine reset control
            csr_reset_or_reset_tx_digital <= 0; // fine reset control
            csr_reset_or_reset_rx_analog <= 0;  // fine reset control
            csr_reset_or_reset_rx_digital <= 0; // fine reset control

            csr_phy_loopback_serial <= 0;
            csr_rx_set_locktoref <= 0;
            csr_rx_set_locktodata <= 0;
        end
        else begin
            // decode read & write for each supported address
            case (address)
            // interrupt control
            ADDR_INTERRUPT_CH_BITMASK: begin
                readdata <= (32'd0 | csr_interrupt_ch_bitmask);
                if (write) csr_interrupt_ch_bitmask <= writedata[lanes-1:0];
            end
            
            // reset control
            ADDR_RESET_CONTROL: begin
                // on read, returns two bits: bit0: TX ready, bit1: RX ready
                readdata <= (32'd0 | {reset_controller_rx_ready, reset_controller_tx_ready});
                // on write, bit0 is 'reset_tx_digital', bit1 is 'reset_rx_digital', bit2 is 'reset_all'
                //if (write) begin
                    // reset_all write side-effect: when write a '1', force all reset_ch_bitmask bits to '1'
                //  csr_reset_ch_bitmask <= csr_reset_ch_bitmask | {(lanes){writedata[2]}};
                //end
            end
            ADDR_RESET_CH_BITMASK: begin
                readdata <= (32'd0 | csr_reset_ch_bitmask);
                if (write) csr_reset_ch_bitmask <= writedata[lanes-1:0];
            end
            
            // loopback control
            ADDR_PHY_LOOPBACK_SERIAL,
            ADDR_PMA_LOOPBACK_SERIAL: begin
                readdata <= (32'd0 | csr_phy_loopback_serial);
                if (write) csr_phy_loopback_serial <= writedata[lanes-1:0];
            end
            
            // PMA control and status
            ADDR_PMA_RX_SET_LOCKTOREF: begin
                readdata <= (32'd0 | csr_rx_set_locktoref);
                if (write) csr_rx_set_locktoref <= writedata[lanes-1:0];
            end  
            ADDR_PMA_RX_SET_LOCKTODATA: begin
                readdata <= (32'd0 | csr_rx_set_locktodata);
                if (write) csr_rx_set_locktodata <= writedata[lanes-1:0];
            end
            // PMA status (read-only)
            ADDR_PMA_PLL_IS_LOCKED:        readdata <= (32'd0 | csr_pll_locked[1]);
            ADDR_PMA_RX_IS_LOCKEDTOREF:    readdata <= (32'd0 | csr_rx_is_lockedtoref[1]);
            ADDR_PMA_RX_IS_LOCKEDTODATA:   readdata <= (32'd0 | csr_rx_is_lockedtodata[1]);
            ADDR_PMA_RX_SIGNALDETECT:      readdata <= (32'd0 | csr_rx_signaldetect[1]);

            // Fine reset control - device dependent
            ADDR_RESET_FINE_CONTROL: begin
                // bit 0: 'pll_powerdown', 1: 'reset_tx_digital', 2: 'reset_rx_analog', 3: 'reset_rx_digital'

                readdata <= (32'd0 | {csr_reset_or_reset_rx_digital, csr_reset_or_reset_rx_analog,
                                      csr_reset_or_reset_tx_digital, csr_reset_or_pll_powerdown});
                if (write) begin
                    csr_reset_or_pll_powerdown <= writedata[0];     // fine reset control
                    csr_reset_or_reset_tx_digital <= writedata[1];  // fine reset control
                    csr_reset_or_reset_rx_analog <= writedata[2];   // fine reset control
                    csr_reset_or_reset_rx_digital <= writedata[3];  // fine reset control
                end
            end
            

            default:    readdata <= ~ 32'd0;  // use too many LEs?
            endcase
            
            // special handling for registers that must auto-clear on cycle after a write
            // reset control.  on write, bit0 is 'reset_tx_digital', bit1 is 'reset_rx_digital', bit2 is 'reset_all'
            {csr_reset_tx_digital,csr_reset_tx_digital_r} <= ((address == ADDR_RESET_CONTROL) & write & writedata[0])
                                                      ? 3'b111 : {csr_reset_tx_digital_r,1'b0};
            {csr_reset_rx_digital,csr_reset_rx_digital_r} <= ((address == ADDR_RESET_CONTROL) & write & writedata[1])
                                                      ? 3'b111 : {csr_reset_rx_digital_r,1'b0};
            csr_reset_all <= (address == ADDR_RESET_CONTROL) & write & writedata[2];

        end
    end

    // combine reset controller and CSR manual reset control settings
    assign  w_reset_controller_tx_digitalreset  = {(rpc?1:lanes){reset_controller_tx_digitalreset}};
    assign  w_reset_controller_rx_analogreset   = {(rpc?1:lanes){reset_controller_rx_analogreset}};
    assign  w_reset_controller_rx_digitalreset  = {(rpc?1:lanes){reset_controller_rx_digitalreset}};

    assign  w_csr_reset_or_reset_tx_digital = {lanes{csr_reset_or_reset_tx_digital}}; // fine reset control
    assign  w_csr_reset_or_reset_rx_analog  = {lanes{csr_reset_or_reset_rx_analog}};  // fine reset control
    assign  w_csr_reset_or_reset_rx_digital = {lanes{csr_reset_or_reset_rx_digital}}; // fine reset control

    assign csr_pll_powerdown = reset_controller_pll_powerdown;  // cut manual PLL reset path
                                // | csr_reset_or_pll_powerdown;
    assign csr_tx_digitalreset = csr_reset_ch_bitmask &
                                    (w_reset_controller_tx_digitalreset | w_csr_reset_or_reset_tx_digital);
    assign csr_rx_analogreset = csr_reset_ch_bitmask &
                                    (w_reset_controller_rx_analogreset | w_csr_reset_or_reset_rx_analog);
    assign csr_rx_digitalreset = csr_reset_ch_bitmask &
                                    (w_reset_controller_rx_digitalreset | w_csr_reset_or_reset_rx_digital);

endmodule
