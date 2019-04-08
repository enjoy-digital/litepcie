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


// This block instantiates a single channel or a number of bonded
// channels. The channel numbers are assigned sequentially starting from
// the channel_number specifical as a parameter
// 
// Key parameters:
// 
// bonded_lanes = specifies the number of lanes to produce. If bonded_lanes == 1,
//                only a single chann is produced of type "SINGLE_CHANNEL". 
//                If bonded_lanes > 1, then look at the value of the bonding_master_lane
//                and bonding_master_only parameters
//
//
// bonding_master_ch_number = uint, must be in the range [channel_number : channel_number + bonded_lanes - 1]
//                 Indicates that channel number that must be the master channel.
//                 All other lanes, with the exception of the master will be of SLAVE_CHANNEL type
//                 There are two scenarious possible:
//                 (1) If the bonding_master_only parameter is set to "true"; A master lane
//                     of type "MASTER_ONLY" will be instantiated.
//
//                 (2) If the bonding_master_only parameter is set to "false"; A master lane
//                     of type "MASTER_SINGLE_CHANNEL" will be instantiated.
//
// bonding_master_only = "true","false", Indicates the lane indicated by bonding_master_ch_number
//                  should by of type "MASTER_ONLY" ("true"), or of type "MASTER_SINGLE_CHANNEL" ("false").
//
// channel_number = uint, starting channel number. This module will instantiate channels and will label them
//                  consequitively from (channel_number) to (channnel_number + bonded_lanes - 1)
//


`timescale 1ps/1ps
module av_tx_pma #(
  parameter bonded_lanes = 1,
  parameter bonding_master_ch_num = "0",
  parameter bonding_master_only = "-1",

  parameter base_data_rate = "0 ps",
  parameter data_rate = "0 ps",

  parameter mode = 8,
  parameter channel_number = 0,
  parameter ser_loopback = "false",
  parameter auto_negotiation = "false",
  parameter plls = 1,
  parameter pll_sel = 0,
  parameter pclksel = "local_pclk",
  parameter ht_delay_sel = "false",
  parameter rx_det_pdb = "false",
  parameter tx_clk_div        = 1,                // (1,2,4,8)
  parameter pcie_rst          = "normal_reset",
  parameter fref_vco_bypass   = "NORMAL_OPERATION",
  parameter pma_width  =  20,
  parameter pma_bonding_mode  = "x1", // valid value "x1", "xN"
  parameter pma_direct = "false",
  parameter external_master_cgb = 0,   
  parameter fir_coeff_ctrl_sel = "ram_ctl"
) ( 
  //input port for aux
  input [bonded_lanes - 1 : 0]      calclk,
  //input port for buf
  input [(bonded_lanes * pma_width) -1: 0]      datain, 
  input [bonded_lanes - 1 : 0]      txelecidl,
  input                             rxdetclk,
  input [bonded_lanes - 1 : 0]      txdetrx,
  
  //output port for buf
  output  [bonded_lanes - 1 : 0]    dataout,
  output  [bonded_lanes - 1 : 0]    rxdetectvalid,
  output  [bonded_lanes - 1 : 0]    rxfound,
  
  //input ports for ser
  input                             rstn,
  input   [bonded_lanes - 1 : 0]    seriallpbken,
  
  //output ports for ser
  output  [bonded_lanes - 1 : 0]    clkdivtx,  
  output  [bonded_lanes - 1 : 0]    seriallpbkout,

  //input ports for cgb
  input   [bonded_lanes*plls-1:0]   clk,              // High-speed serial clocks from PLLs
  input                             pciesw,           // to the master channel
  input                             pcsrstn,
  input                             fref,
  input   [bonded_lanes*plls-1:0]   rstn_cgb_master,  
  input   [bonded_lanes - 1 : 0]    cpulsein,
  input   [bonded_lanes - 1 : 0]    hclkin,
  input   [bonded_lanes - 1 : 0]    lfclkin,
  input   [bonded_lanes*3-1 : 0]    pclkin,  

  //output ports for cgb
  output  [bonded_lanes-1 : 0]  pcieswdone,       // from the master channel

  input   [bonded_lanes-1:0 ]       avmmrstn,         // one for each lane
  input   [bonded_lanes-1:0 ]       avmmclk,          // one for each lane
  input   [bonded_lanes-1:0 ]       avmmwrite,        // one for each lane
  input   [bonded_lanes-1:0 ]       avmmread,         // one for each lane
  input   [(bonded_lanes*2)-1:0 ]   avmmbyteen,       // two for each lane
  input   [(bonded_lanes*11)-1:0 ]  avmmaddress,      // 11 for each lane
  input   [(bonded_lanes*16)-1:0 ]  avmmwritedata,    // 16 for each lane
  output  [(bonded_lanes*16)-1:0 ]  avmmreaddata_cgb, // CGB readdata
  output  [(bonded_lanes*16)-1:0 ]  avmmreaddata_ser, // SER readdata
  output  [(bonded_lanes*16)-1:0 ]  avmmreaddata_buf, // BUF readdata
  output  [bonded_lanes-1:0 ]       blockselect_cgb,  // CGB blockselect
  output  [bonded_lanes-1:0 ]       blockselect_ser,  // SER blockselect
  output  [bonded_lanes-1:0 ]       blockselect_buf,  // BUF blockselect
  output  [bonded_lanes-1:0 ]       atb_comp_out,     // Voltage comparator output for DCD
  
  input   [bonded_lanes-1:0 ]       vrlpbkp,
  input   [bonded_lanes-1:0 ]       vrlpbkn
);

  import altera_xcvr_functions::*;

  wire  [bonded_lanes-1:0]    w_hfclkp;
  wire  [bonded_lanes-1:0]    w_lfclkp;
  wire  [bonded_lanes-1:0]    w_cpulse;
  wire  [2:0]                 w_pclk [bonded_lanes-1:0];
  wire  [bonded_lanes*80-1:0] dadtain_padded;
  
  localparam  integer bonding_master_0 = str2int(get_value_at_index(0,bonding_master_ch_num));
  
  genvar i;  
  generate 
  for(i = 0; i < bonded_lanes; i = i + 1) begin:tx_pma_insts  
  
    assign dadtain_padded[(i+1)*80 - 1 : i*80] = (pma_width == 20) ? {60'b0 , datain[(i+1)*20 - 1 : i*20]} : datain[(i+1)*pma_width - 1 : i*pma_width];
    
    localparam [MAX_CHARS*8-1:0]  str_i = int2str(i);
    localparam is_single_chan = (bonded_lanes == 1 && pma_bonding_mode == "x1") ? 1 : 0;
    localparam is_master_only = ( (is_single_chan == 0) && 
                                  (is_in_legal_set(str_i,bonding_master_ch_num) == 1) &&
                                  (is_in_legal_set(str_i,bonding_master_only) == 1))
                                  ? 1 : 0;
    localparam is_master_chan = ( (is_single_chan == 0) &&
                                  (is_master_only == 0) &&
                                  (is_in_legal_set(str_i,bonding_master_ch_num) == 1))
                                  ? 1 : 0;
    localparam is_slave_chan  = ( (is_single_chan == 0) &&
                                  ((is_in_legal_set(str_i,bonding_master_ch_num) == 0) &&
                                  (is_in_legal_set(str_i,-1) == 0)))
                                  ? 1 : 0;
				  
    //localparam is_fb_comp     = ( (is_single_chan == 0) && 
    //                              (pma_bonding_type == "fb_compensation") && 
    //                              (is_in_legal_set(str_i,-1) == 0)) 
    //                              ? 1 : 0; 

    localparam is_fb_comp     = 0;

    // Determine PMA type
    localparam  [MAX_CHARS*8-1:0] tx_pma_type = (is_single_chan       == 1) ? "SINGLE_CHANNEL"        :
                                                (is_fb_comp           == 1) ? "FB_COMP_CHANNEL"       :
                                                (is_master_only       == 1) ? "MASTER_ONLY"           :
                                                (is_master_chan       == 1) ? "MASTER_SINGLE_CHANNEL" :
                                                (is_slave_chan        == 1) ? "SLAVE_CHANNEL"         :
                                                                        "EMPTY_CHANNEL"         ;
									
    // Determine the bonding master for this channel
    // If only one bonding master was specified, we select it.
    // If a bonding master per channel was specified, we select the corresponding master
    localparam  [MAX_CHARS*8-1:0] master_sel_str = get_value_at_index(i,bonding_master_ch_num);
    localparam  integer master_sel  = (master_sel_str == "NA") ? bonding_master_0 : str2int(master_sel_str);

    av_tx_pma_ch #(
      .mode(mode),
      .auto_negotiation(auto_negotiation),
      .plls(plls),
      .pll_sel(pll_sel),
      .ser_loopback(ser_loopback),
      .ht_delay_sel(ht_delay_sel),
      .tx_pma_type(tx_pma_type),
	  .base_data_rate(base_data_rate),
      .data_rate(data_rate),
      .rx_det_pdb(rx_det_pdb),
      .tx_clk_div(tx_clk_div),
      .pcie_rst(pcie_rst),
      .fref_vco_bypass(fref_vco_bypass),
      .pma_bonding_mode(pma_bonding_mode),
      .bonded_lanes(bonded_lanes),
      .pma_direct(pma_direct),
      .external_master_cgb(external_master_cgb),
      .fir_coeff_ctrl_sel(fir_coeff_ctrl_sel)
    ) av_tx_pma_ch_inst ( 
      //input port for aux
      .calclk         (calclk          [i] ),
      
      //input port for buf
      .datain         (dadtain_padded  [(i+1)*80 - 1 : i*80]),
      .txelecidl      (txelecidl       [i] ),
      .rxdetclk       (rxdetclk            ),
      .txdetrx        (txdetrx         [i] ),

      //output port for buf
      .dataout        (dataout         [i] ),
      .rxdetectvalid  (rxdetectvalid   [i] ),
      .rxfound        (rxfound         [i] ),
  
      //input ports for ser
      .rstn           (rstn                ),
      .seriallpbken   (seriallpbken    [i] ),
      
      //output ports for ser
      .clkdivtx       (clkdivtx        [i] ),
      .seriallpbkout  (seriallpbkout   [i] ),
  
      //input ports for cgb
      .clk            (clk             [i*plls+:plls]),
      .pciesw         (pciesw              ),
      .pcsrstn        (pcsrstn             ),
      .fref           (fref                ),
	  .rstn_cgb_master(rstn_cgb_master [i*plls+:plls]),

      // bonding clock inputs from master CGB
      .cpulsein     ((external_master_cgb == 1)? cpulsein[i]      : w_cpulse     [master_sel]  ),
      .hfclkpin     ((external_master_cgb == 1)? hclkin[i]        : w_hfclkp     [master_sel]  ),
      .lfclkpin     ((external_master_cgb == 1)? lfclkin[i]       : w_lfclkp     [master_sel]  ),
      .pclkin       ((external_master_cgb == 1)? pclkin[i*3+:3]   : w_pclk       [master_sel]  ),
  
      //output ports for cgb
      .pcieswdone   (pcieswdone        [i] ),

      //
      .cpulseout    (w_cpulse     [i] ),
      .hfclkpout    (w_hfclkp     [i] ),
      .lfclkpout    (w_lfclkp     [i] ),
      .pclkout      (w_pclk       [i] ),
	  
      .vrlpbkp      (vrlpbkp      [i] ),
      .vrlpbkn      (vrlpbkn      [i] ),
          
      // Avalon-MM interface
      .avmmrstn         (avmmrstn     [i]           ),
      .avmmclk          (avmmclk      [i]           ),
      .avmmwrite        (avmmwrite    [i]           ),
      .avmmread         (avmmread     [i]           ),
      .avmmbyteen       (avmmbyteen   [i*2+:2]      ),
      .avmmaddress      (avmmaddress  [i*11+:11]    ),
      .avmmwritedata    (avmmwritedata[i*16+:16]    ),
      .avmmreaddata_cgb (avmmreaddata_cgb[i*16+:16] ),  // CGB readdata
      .avmmreaddata_ser (avmmreaddata_ser[i*16+:16] ),  // SER readdata
      .avmmreaddata_buf (avmmreaddata_buf[i*16+:16] ),  // BUF readdata
      .blockselect_cgb  (blockselect_cgb[i]         ),  // CGB blockselect
      .blockselect_ser  (blockselect_ser[i]         ),  // SER blockselect
      .blockselect_buf  (blockselect_buf[i]         ),   // BUF blockselect       
      .atb_comp_out     (atb_comp_out   [i]         )
    );
  end
  endgenerate
endmodule

    
