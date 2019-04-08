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


`timescale 1ps/1ps

module av_pma #(
  //PARAM_LIST_START
    parameter rx_enable         = 1,                // (1,0) Enable or disable reciever PMA
    parameter tx_enable         = 1,                // (1,0) Enable or disable transmitter PMA
    parameter bonded_lanes      = 1,                // Number of bonded lanes
    parameter bonding_master_ch = 0,                // Indicates which channel is master
    parameter pma_bonding_master= "0",              // (List i.e. "0,3,..."), Indicates which channels is master
    parameter bonding_master_only= "-1",            // Indicates bonding_master_channel is MASTER_ONLY
    parameter channel_number    = 0,                //  
    parameter plls              = 1,                // (1+) Number of high-speed serial clocks from TX plls (tx_ser_clk)
    parameter pll_sel           = 0,                // (0 - plls-1) // Which PLL clock to use
    parameter pma_prot_mode     = "basic",          // (basic,cpri,cpri_rx_tx,disabled_prot_mode,gige, pipe_g1,pipe_g2,srio_2p1,test,xaui)
    parameter pma_mode          = 8,                // (8,10,16,20,32,40,64,80) Serialization factor
	parameter base_data_rate    = "1250000000 bps", // Base data rate for CGB
    parameter pma_data_rate     = "1250000000 bps", // Serial data rate in bits-per-second
    parameter cdr_reconfig      = 0,                // 1-Enable CDR reconfiguration, 0-Disable CDR reconfiguration
    parameter cdr_reference_clock_frequency = "100 Mhz",
    parameter cdr_refclk_cnt    = 1,                // # of CDR reference clocks
    parameter cdr_refclk_sel    = 0,                // Initial CDR reference clock selection
    parameter deser_enable_bit_slip   = "false",
    parameter auto_negotiation  = "<auto_single>",   // ("true","false") PCIe Auto-Negotiation (Gen1,2,3)
    parameter tx_clk_div        = 1,                // (1,2,4,8)
    parameter pcie_rst          = "normal_reset",
    parameter fref_vco_bypass   = "NORMAL_OPERATION",
    parameter sd_on             = 16,
    parameter pdb_sd            = "true", 
    parameter pma_bonding_mode  = "x1", // valid value "x1", "xN"
    parameter external_master_cgb = 0, 
    // CvP IOCSR control - cvp_update
    parameter cvp_en_iocsr      = "false" // valid values = "true", "false"
  //PARAM_LIST_END
) (
  //PORT_LIST_START
  // TX/RX ports
  input   wire  			              calclk,         // Calibration clock (to aux block)
  input   wire  [bonded_lanes - 1: 0]     seriallpbken,   // 1 = enable serial loopback
  input   wire  [bonded_lanes-1: 0]     pciesw,         // PCIe generation select

  // RX ports
  input   wire  [bonded_lanes - 1 : 0]    rx_rstn,        // Active low digital reset for (deserializer, CDR, RX buf)
  input   wire  [bonded_lanes - 1 : 0]    rx_crurstn,     // CDR analog reset (active low)
  input   wire  [bonded_lanes - 1 : 0]    rx_datain,      // RX serial data input
  input   wire  [bonded_lanes - 1 : 0]    rx_bslip,       // PMA bitslip. Slips one clock cycle (2 UI of data)
  input   wire  [bonded_lanes*cdr_refclk_cnt-1:0]    rx_cdr_ref_clk, // Reference clock for CDR
  input   wire  [bonded_lanes - 1 : 0]    rx_ltr,         // Force lock-to_reference clock
  input   wire  [bonded_lanes - 1 : 0]    rx_ltd,         // Force lock-to-data stream
  input   wire  [bonded_lanes - 1 : 0]    rx_freqlock,    // frequency lock detector input (external PPM detector)
  input   wire  [bonded_lanes - 1 : 0]    rx_earlyeios,   // Early electricle idle ordered sequence
  input   wire  [bonded_lanes - 1 : 0]    rx_hardoccalen, // Enable Offset cancellation
  output  wire  [bonded_lanes - 1 : 0]    rx_clkdivrx,    // RX parallel clock output
  output  wire  [((pma_prot_mode == "pma direct") ? (bonded_lanes*80) : (bonded_lanes*20))-1: 0]    rx_dataout,     // RX parallel data output
  output  wire  [bonded_lanes - 1 : 0]    rx_sd,          // RX signal detect
  output  wire  [bonded_lanes - 1 : 0]    rx_clklow,      // RX low frequency recovered clock
  output  wire  [bonded_lanes - 1 : 0]    rx_fref,        // RX PFD reference clock (rx_cdr_refclk after divider)
  output  wire  [bonded_lanes - 1 : 0]    rx_is_lockedtodata, // Indicates lock to incoming data rate
  output  wire  [bonded_lanes - 1 : 0]    rx_is_lockedtoref,  // Indicates lock to reference clock
  output  wire  [bonded_lanes - 1 : 0]    out_pcs_signal_ok,
  output  wire  [bonded_lanes - 1 : 0]    out_pcs_rx_pll_phase_lock_out,
  
  // TX ports
  //input port for buf
  input   wire  [((pma_prot_mode == "pma direct") ? (bonded_lanes*80) : (bonded_lanes*20))-1: 0]    tx_datain,      // TX parallel data input
  input   wire  [bonded_lanes - 1 : 0]    tx_txelecidl,   // TX force electricle idle
  input   wire                            tx_rxdetclk,    // Clock for detection of downstream receiver (125MHz ?)
  input   wire  [bonded_lanes - 1 : 0]    tx_txdetrx,     // 1 = enable downstream receiver detection
  //output port for buf
  output  wire  [bonded_lanes - 1 : 0]    tx_dataout,     // TX serial data output
  output  wire  [bonded_lanes - 1 : 0]    tx_rxdetectvalid, // Indicates corresponding tx_rxfound signal contains valid data
  output  wire  [bonded_lanes - 1 : 0]    tx_rxfound,     // Indicates downnstream receiver is detected (qualify with tx_rxdetectvalid)
  //input ports for ser
  input   wire                            tx_rstn,        // TODO - Examine resets
  //output ports for ser
  output  wire  [bonded_lanes - 1 : 0]    tx_clkdivtx,    // TX parallel clock output
  //input ports for cgb
  input   wire  [bonded_lanes*plls-1:0]   tx_ser_clk,     // High-speed serial clock(s) from PLL
  input   wire                            tx_pcsrstn,
  input   wire                            tx_fref,
  input   wire  [bonded_lanes*plls-1:0]   tx_rstn_cgb_master,
  input   wire  [bonded_lanes - 1 : 0]    tx_cpulsein,
  input   wire  [bonded_lanes - 1 : 0]    tx_hclkin,
  input   wire  [bonded_lanes - 1 : 0]    tx_lfclkin,
  input   wire  [bonded_lanes*3-1 : 0]    tx_pclkin,  
  //output ports for cgb
  output  wire  [bonded_lanes -1 : 0]  tx_pcieswdone,   // Inidicates PMA has accepted value on pciesw input.
  
    // AVMM ports
  input   wire  [bonded_lanes-1:0 ]       pma_avmmrstn,             // one for each lane
  input   wire  [bonded_lanes-1:0 ]       pma_avmmclk,              // one for each lane
  input   wire  [bonded_lanes-1:0 ]       pma_avmmwrite,            // one for each lane
  input   wire  [bonded_lanes-1:0 ]       pma_avmmread,             // one for each lane
  input   wire  [(bonded_lanes*2)-1:0 ]   pma_avmmbyteen,           // two for each lane
  input   wire  [(bonded_lanes*11)-1:0 ]  pma_avmmaddress,          // 11 for each lane
  input   wire  [(bonded_lanes*16)-1:0 ]  pma_avmmwritedata,        // 16 for each lane

  output  wire  [(bonded_lanes*16)-1:0 ]  pma_avmmreaddata_tx_cgb,  // TX AVMM CGB readdata (16 for each lane)
  output  wire  [(bonded_lanes*16)-1:0 ]  pma_avmmreaddata_tx_ser,  // TX AVMM SER readdata (16 for each lane)
  output  wire  [(bonded_lanes*16)-1:0 ]  pma_avmmreaddata_tx_buf,  // TX AVMM BUF readdata (16 for each lane)
  output  wire  [(bonded_lanes*16)-1:0 ]  pma_avmmreaddata_rx_ser,  // RX AVMM SER readdata (16 for each lane)
  output  wire  [(bonded_lanes*16)-1:0 ]  pma_avmmreaddata_rx_buf,  // RX AVMM BUF readdata (16 for each lane)
  output  wire  [(bonded_lanes*16)-1:0 ]  pma_avmmreaddata_rx_cdr,  // RX AVMM CDR readdata (16 for each lane)
  output  wire  [(bonded_lanes*16)-1:0 ]  pma_avmmreaddata_rx_mux,  // RX AVMM CDR MUX readdata (16 for each lane)
  output  wire  [bonded_lanes-1:0 ]       pma_blockselect_tx_cgb,   // TX AVMM CGB blockselect (1 for each lane)
  output  wire  [bonded_lanes-1:0 ]       pma_blockselect_tx_ser,   // TX AVMM SER blockselect (1 for each lane)
  output  wire  [bonded_lanes-1:0 ]       pma_blockselect_tx_buf,   // TX AVMM BUF blockselect (1 for each lane)
  output  wire  [bonded_lanes-1:0 ]       pma_blockselect_rx_ser,   // RX AVMM SER blockselect (1 for each lane)
  output  wire  [bonded_lanes-1:0 ]       pma_blockselect_rx_buf,   // RX AVMM BUF blockselect (1 for each lane)
  output  wire  [bonded_lanes-1:0 ]       pma_blockselect_rx_cdr,   // RX AVMM SER blockselect (1 for each lane)
  output  wire  [bonded_lanes-1:0 ]       pma_blockselect_rx_mux,    // RX AVMM BUF blockselect (1 for each lane)
  output  wire  [bonded_lanes-1:0 ]       pll_aux_atb_comp_out     // Voltage comparator output for DCD (1 for each lane)

  //PORT_LIST_END
  );

import altera_xcvr_functions::*;  // Useful functions (primarily for rule-checking)

localparam  rbc_all_prot_mode = "(basic,cpri,cpri_rx_tx,disabled_prot_mode,gige,pipe_g1,pipe_g2,srio_2p1,test,xaui,pma direct)";
localparam  rbc_any_prot_mode = "basic";
localparam  fnl_prot_mode     = (pma_prot_mode == "<auto_any>" || pma_prot_mode == "<auto_single>") ? rbc_any_prot_mode : pma_prot_mode;
localparam  pipe_mode = (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2") ? 1 : 0;

localparam  rbc_all_auto_negotiation  = (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2") ? "(true,false)" : "false";
localparam  rbc_any_auto_negotiation  = "false";
localparam  fnl_auto_negotiation      = (auto_negotiation == "<auto_any>" || auto_negotiation == "<auto_single>") ? rbc_any_auto_negotiation : auto_negotiation;
        
// Internal parameters
localparam  INT_DATA_RATE             = str2hz(pma_data_rate);  // TODO - may fail due to 32-bit param
localparam  INT_CDR_OUT_CLOCK_FREQ    = INT_DATA_RATE / 2;
localparam  INT_CDR_OUT_CLOCK_FREQ_STR= hz2str(INT_CDR_OUT_CLOCK_FREQ);
localparam  pma_width                 = (pma_prot_mode == "pma direct") ? 80 : 20;

localparam FIR_COEFF_CTRL_SEL = (pipe_mode == 1)? "dynamic_ctl" : "ram_ctl";
// Parameter legality checking
initial begin
  if (!is_in_legal_set(pma_prot_mode, rbc_all_prot_mode)) begin
    $display("Critical Warning: pma_prot_mode value, '%s', not in legal set: '%s'", pma_prot_mode, rbc_all_prot_mode);
  end
  
  if (!is_in_legal_set(auto_negotiation, rbc_all_auto_negotiation)) begin
    $display("Critical Warning: auto_negotiation value, '%s', not in legal set: '%s'", auto_negotiation, rbc_all_auto_negotiation);
  end
  
end


// Internal signals
wire  [bonded_lanes - 1: 0] loopback_data;
wire  [bonded_lanes -1: 0] int_pciesw;     // PCIe generation select
wire  [bonded_lanes-1: 0] int_pcieswdone; // Inidicates PMA has accepted value on pciesw input.

wire  [bonded_lanes - 1: 0] reverse_loopback_data_p;
wire  [bonded_lanes - 1: 0] reverse_loopback_data_n;
wire  [bonded_lanes - 1: 0] seriallpbken_n;

assign  int_pciesw    = (fnl_auto_negotiation == "true") ? pciesw : {bonded_lanes{1'b0}};
assign  tx_pcieswdone = (fnl_auto_negotiation == "true" || tx_enable == 0) ? int_pcieswdone : {bonded_lanes{1'b0}};

assign  out_pcs_signal_ok             = rx_is_lockedtodata;
assign  out_pcs_rx_pll_phase_lock_out = rx_is_lockedtodata;
// We only drive seriallpbken in duplex mode.
assign  seriallpbken_n = ((rx_enable == 1) && (tx_enable == 1)) ? ~seriallpbken : {bonded_lanes{1'b1}};


//*********************************************************************
//************************ Receiver PMA *******************************
generate if(rx_enable == 1) begin
av_rx_pma #(
      .bonded_lanes                 (bonded_lanes                 ),
      .bonding_master_ch_num        (pma_bonding_master            ),
      .bonding_master_only          (bonding_master_only          ),
      .mode                         (pma_mode                     ),
      //.serial_loopback              ("lpbkp_dis"                  ),
      .sdclk_enable                 ("true"                       ),  // TODO Hard-code for now
      .channel_number               (channel_number               ),
      .deser_enable_bit_slip        (deser_enable_bit_slip        ),
      .auto_negotiation             (fnl_auto_negotiation         ),
		.cdr_refclk_sel               (cdr_refclk_sel               ),
      .cdr_reconfig                 (cdr_reconfig                 ),
      .cdr_reference_clock_frequency(cdr_reference_clock_frequency),
      .cdr_refclk_cnt               (cdr_refclk_cnt               ),
      .cdr_output_clock_frequency   (INT_CDR_OUT_CLOCK_FREQ_STR   ),
      .rxpll_pd_bw_ctrl             ("300"                        ),  // TODO Hard-code for now
      .sd_on                        (sd_on                        ),
      .pdb_sd                       (pdb_sd                       ),
      .pma_width                    (pma_width                    ),
      .pma_direct                   ((pma_prot_mode == "pma direct")? "true" : "false"),
      .cvp_en_iocsr                 (cvp_en_iocsr                 )    //Only PCIe CvP designs override this 
) av_rx_pma( 
  .rstn               (rx_rstn                ),
  .crurstn            (rx_crurstn             ),
  
  .calclk             ({bonded_lanes{calclk}} ),
  .datain             (rx_datain              ),
  .seriallpbkin       (loopback_data          ),
  .seriallpbken       (seriallpbken_n         ),
  .bslip              (rx_bslip               ),
  //.adaptcapture       (rx_adaptcapture        ),
  //.adcestandby        (rx_adcestandby         ),
  .hardoccalen        (rx_hardoccalen         ),
  //.eyemonitor         (rx_eyemonitor          ),
  //.adaptdone          (rx_adaptdone           ),
  //.hardoccaldone      (rx_hardoccaldone       ),
  
  .cdr_ref_clk        (rx_cdr_ref_clk         ),
  
  .pciesw             (int_pciesw             ),
  
  .ltr                (rx_ltr                 ),
  .ltd                (rx_ltd                 ),
  .freqlock           (rx_freqlock            ),
  
  .earlyeios          (rx_earlyeios           ),
  
  .clkdivrx           (rx_clkdivrx            ),
  .dout               (rx_dataout             ),
  .sd                 (rx_sd                  ),
  
  .clklow             (rx_clklow              ),
  .fref               (rx_fref                ),
  
  .rx_is_lockedtodata (rx_is_lockedtodata     ),
  .rx_is_lockedtoref  (rx_is_lockedtoref      ),

  .avmmrstn           (pma_avmmrstn           ),
  .avmmclk            (pma_avmmclk            ),
  .avmmwrite          (pma_avmmwrite          ),
  .avmmread           (pma_avmmread           ),
  .avmmbyteen         (pma_avmmbyteen         ),
  .avmmaddress        (pma_avmmaddress        ),
  .avmmwritedata      (pma_avmmwritedata      ),
  .avmmreaddata_ser   (pma_avmmreaddata_rx_ser), // SER readdata
  .avmmreaddata_buf   (pma_avmmreaddata_rx_buf), // BUF readdata
  .avmmreaddata_cdr   (pma_avmmreaddata_rx_cdr), // CDR readdata
  .avmmreaddata_mux   (pma_avmmreaddata_rx_mux), // CDR MUX readdata
  .blockselect_ser    (pma_blockselect_rx_ser ), // SER blockselect
  .blockselect_buf    (pma_blockselect_rx_buf ), // BUF blockselect
  .blockselect_cdr    (pma_blockselect_rx_cdr ), // CDR blockselect
  .blockselect_mux    (pma_blockselect_rx_mux ), // CDR MUX blockselect
  
  .rdlpbkp            (reverse_loopback_data_p)
  //.rdlpbkn            (reverse_loopback_data_n)

);

end else begin
  // Default unused outputs
  assign  rx_clkdivrx                   = {bonded_lanes{1'b0}};
  assign  rx_dataout                    = {(bonded_lanes*pma_width){1'b0}};
  assign  rx_sd                         = {bonded_lanes{1'b0}};
  assign  rx_clklow                     = {bonded_lanes{1'b0}};
  assign  rx_fref                       = {bonded_lanes{1'b0}};
  assign  rx_is_lockedtodata            = {bonded_lanes{1'b0}};
  assign  rx_is_lockedtoref             = {bonded_lanes{1'b0}};
  //assign  rx_adaptdone                  = {bonded_lanes{1'b0}};
  //assign  rx_hardoccaldone              = {bonded_lanes{1'b0}};
  
  assign  pma_avmmreaddata_rx_ser       = {bonded_lanes*16{1'b0}};
  assign  pma_avmmreaddata_rx_buf       = {bonded_lanes*16{1'b0}};
  assign  pma_avmmreaddata_rx_cdr       = {bonded_lanes*16{1'b0}};
  assign  pma_avmmreaddata_rx_mux       = {bonded_lanes*16{1'b0}};
  assign  pma_blockselect_rx_ser        = {bonded_lanes{1'b0}};
  assign  pma_blockselect_rx_buf        = {bonded_lanes{1'b0}};
  assign  pma_blockselect_rx_cdr        = {bonded_lanes{1'b0}};
  assign  pma_blockselect_rx_mux        = {bonded_lanes{1'b0}};
  assign  reverse_loopback_data_p       = {bonded_lanes{1'b0}};
end
endgenerate
//********************** End Receiver PMA *****************************
//*********************************************************************


//*********************************************************************
//********************** Transmitter PMA ******************************
generate if(tx_enable == 1) begin
av_tx_pma #(
      .bonded_lanes           (bonded_lanes           ),
      .bonding_master_ch_num  (pma_bonding_master      ),
      .bonding_master_only    (bonding_master_only    ),
	  .base_data_rate         (base_data_rate         ),
      .data_rate              (pma_data_rate          ), // TODO
      .mode                   (pma_mode               ),
      .plls                   (plls                   ),
      .pll_sel                (pll_sel                ),
      .channel_number         (channel_number         ),
      .ser_loopback           ("false"                ),
      .auto_negotiation       (fnl_auto_negotiation   ),
      .ht_delay_sel           ("false"                ),
      .rx_det_pdb             ("false"                ),
      .tx_clk_div             (tx_clk_div             ),
      .pcie_rst               (pcie_rst               ),
      .fref_vco_bypass        (fref_vco_bypass        ),
	    .pma_width              (pma_width              ),
	    .pma_bonding_mode       (pma_bonding_mode       ),
      .fir_coeff_ctrl_sel     (FIR_COEFF_CTRL_SEL     ),
	    .pma_direct             ((pma_prot_mode == "pma direct")? "true" : "false"),
      .external_master_cgb    (external_master_cgb   )
) av_tx_pma( 
  //input port for aux
  .calclk             ({bonded_lanes{calclk}} ),
  //input port for buf
  .datain             (tx_datain              ),
  .txelecidl          (tx_txelecidl           ),
  .rxdetclk           (tx_rxdetclk            ),
  .txdetrx            (tx_txdetrx             ),
  
  //output port for buf
  .dataout            (tx_dataout             ),
  .rxdetectvalid      (tx_rxdetectvalid       ),
  .rxfound            (tx_rxfound             ),
  
  //input ports for ser
  .rstn               (tx_rstn                ),
  .seriallpbken       (seriallpbken_n         ),
  
  //output ports for ser
  .clkdivtx           (tx_clkdivtx            ),  
  .seriallpbkout      (loopback_data          ),

  //input ports for cgb
  .clk                (tx_ser_clk             ),
  .pcsrstn            (tx_pcsrstn             ),
  .fref               (tx_fref                ),
  .rstn_cgb_master    (tx_rstn_cgb_master     ),
  .pciesw             (int_pciesw[bonding_master_ch]),
  .cpulsein           (tx_cpulsein                   ),
  .hclkin             (tx_hclkin                     ),
  .lfclkin            (tx_lfclkin                    ),
  .pclkin             (tx_pclkin                     ),

  //output ports for cgb
  .pcieswdone         (int_pcieswdone         ),

  .avmmrstn           (pma_avmmrstn           ),
  .avmmclk            (pma_avmmclk            ),
  .avmmwrite          (pma_avmmwrite          ),
  .avmmread           (pma_avmmread           ),
  .avmmbyteen         (pma_avmmbyteen         ),
  .avmmaddress        (pma_avmmaddress        ),
  .avmmwritedata      (pma_avmmwritedata      ),
  .avmmreaddata_cgb   (pma_avmmreaddata_tx_cgb),  // CGB readdata
  .avmmreaddata_ser   (pma_avmmreaddata_tx_ser),  // SER readdata
  .avmmreaddata_buf   (pma_avmmreaddata_tx_buf),  // BUF readdata
  .blockselect_cgb    (pma_blockselect_tx_cgb ),  // CGB blockselect
  .blockselect_ser    (pma_blockselect_tx_ser ),  // SER blockselect
  .blockselect_buf    (pma_blockselect_tx_buf ),   // BUF blockselect
  .atb_comp_out       (pll_aux_atb_comp_out   ),   // pll aux voltage comparator output

  .vrlpbkp            (reverse_loopback_data_p),
  .vrlpbkn            ({bonded_lanes{1'b0}})
);

end else begin
  // Default the outputs
  assign  tx_dataout              = {bonded_lanes{1'b0}};
  assign  tx_rxdetectvalid        = {bonded_lanes{1'b0}};
  assign  tx_rxfound              = {bonded_lanes{1'b0}};
  assign  tx_clkdivtx             = {bonded_lanes{1'b0}};
  assign  int_pcieswdone          = {bonded_lanes{1'b0}};
  assign  pma_avmmreaddata_tx_cgb = {bonded_lanes*16{1'b0}};
  assign  pma_avmmreaddata_tx_ser = {bonded_lanes*16{1'b0}};
  assign  pma_avmmreaddata_tx_buf = {bonded_lanes*16{1'b0}};
  assign  pma_blockselect_tx_cgb  = {bonded_lanes{1'b0}};
  assign  pma_blockselect_tx_ser  = {bonded_lanes{1'b0}};
  assign  pma_blockselect_tx_buf  = {bonded_lanes{1'b0}};
  assign  pll_aux_atb_comp_out    = {bonded_lanes{1'b0}};
  assign  loopback_data           = {bonded_lanes{1'b0}};
end
endgenerate
//******************** End Transmitter PMA ****************************
//*********************************************************************

endmodule
