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



// NOTES: parameter tx_pma_channel_type can take the following four values:
// (1) SINGLE_CHANNEL --
//
// the av_tx_pma block will instantiate a simple pipeline of cgb -> 
// ser -> tx_buf. It requires that a high frequency clock be connected to
// 'clk' input port. 'datain' and 'dataout' have to be connected as 
// expected.
//
// (2) MASTER_SINGLE_CHANNEL --
//
// the av_tx_pma block will instantiate a simple pipeline of cgb -> 
// ser -> tx_buf. It requires that a high frequency clock be connected to
// 'clk' input port. In addition, the module outputs the bonding clocks via ports
// (hfclkpout, lfclkpout,cpulseout,pclk0out,pclk1out). These clocks must be
// connected to another instance of av_tx_pma_ch that serves as SLAVE_CHANNEL. 
// 'datain' and 'dataout' have to be connected as expected.
//
// (3) SLAVE_CHANNEL --
//
// the av_tx_pma block will instantiate a simple pipeline of cgb -> 
// ser -> tx_buf. The cgb in this case is not used to divide the high frequency clock 
// from the tx pll, but to forward the bonding clocks to the serializer. It is required that
// the bonding clock bondle is connected to the inputs (hfclkpin, lfclkpin,cpulsein, 
// pclk0in,pclk1in). These clocks must come from a av_tx_pma_ch block that serves 
// as MASTER_SINGLE_CHANNEL or as MASTER_ONLY. 
// 'datain' and 'dataout' have to be connected as expected.
//
// (4) MASTER_ONLY
//
// the av_tx_pma_ch block will only instantiate a cgb -> ser. The cgb is used to divide the
// high frequency clock from the tx pll (input clk) and produce bonding clocks via ports
// (hfclkpout, lfclkpout,cpulseout,pclk0out,pclk1out). The serializer block in this case is
// configured in a special clk_forward_only_mode = true. This indicates that the serializer
// does not serve its usual role of converting data on a parallel bus input into a serial output,
// but serves to only forward the parallel clock from the cgb to the output clkdivtx.
// 

`timescale 1ps/1ps

import altera_xcvr_functions::*;

module av_tx_pma_ch #(
  parameter mode = 8,
  parameter channel_number    = 0,
  parameter auto_negotiation  = "true",
  parameter plls              = 1,
  parameter pll_sel           = 0,
  parameter ser_loopback      = "false",
  parameter ht_delay_sel      = "false",
  parameter tx_pma_type       = "SINGLE_CHANNEL",
  parameter base_data_rate    = "0 ps",
  parameter data_rate         = "0 ps",
  parameter rx_det_pdb        = "false",
  parameter tx_clk_div        = 1, //(1,2,4,8)
  parameter pcie_rst          = "normal_reset",
  parameter fref_vco_bypass   = "normal_operation",
  parameter enable_dcd        = 1, // mask off PLL AUX until fitter support is ready
  parameter pma_bonding_mode  = "x1", // valid value "x1", "xN"
  parameter bonded_lanes      = 1,
  parameter pma_direct        = "false",
  parameter external_master_cgb = 0,
  parameter fir_coeff_ctrl_sel = "ram_ctl"	//Valid values: dynamic_ctl|ram_ctrl
  ) ( 
  //input port for aux
  input             calclk,
  //input port for buf
  input   [79:0]    datain,
  input             txelecidl,
  input             rxdetclk,
  input             txdetrx,
  
  //output port for buf
  output            dataout,
  output            rxdetectvalid,
  output            rxfound,
  
  //input ports for ser
  input               rstn,
  input               seriallpbken,
  
  //output ports for ser
  output              clkdivtx,
  output              seriallpbkout,
  
  //input ports for cgb
  input   [plls-1:0]  clk,
  input               pciesw,
  input               pcsrstn,
  input               fref,
  input   [plls-1:0]  rstn_cgb_master,
  
  // bonding clock inputs from master CGB
  input               cpulsein,
  input               hfclkpin,
  input               lfclkpin,
  input   [2:0]       pclkin,
  
  //output ports for cgb
  output              pcieswdone,
  
  // bonding clock outputs (driven if this CGB is acting as a master)
  output              hfclkpout,
  output              lfclkpout,
  output              cpulseout,
  output  [2:0]       pclkout,
  
  // input/outputs related to reconfiguration
  input               avmmrstn,
  input               avmmclk,
  input               avmmwrite,
  input               avmmread,
  input   [1:0 ]      avmmbyteen,
  input   [10:0 ]     avmmaddress,
  input   [15:0 ]     avmmwritedata,
  output  [15:0 ]     avmmreaddata_cgb, // CGB readdata
  output  [15:0 ]     avmmreaddata_ser, // SER readdata
  output  [15:0 ]     avmmreaddata_buf, // BUF readdata
  output              blockselect_cgb,  // CGB blockselect
  output              blockselect_ser,  // SER blockselect
  output              blockselect_buf,  // BUF blockselect
  output              atb_comp_out,     // Voltage comparator output for DCD
  
  input               vrlpbkp,
  input               vrlpbkn  
  );
  
  genvar ig;
  
  localparam MAX_PLLS = 7;
  localparam PLL_CNT = (plls < MAX_PLLS)? plls : MAX_PLLS;
  
  localparam  integer is_single_chan       = (tx_pma_type == "SINGLE_CHANNEL"       ) ? 1 : 0;
  localparam  integer is_master_only       = (tx_pma_type == "MASTER_ONLY"          ) ? 1 : 0;
  localparam  integer is_master_chan       = (tx_pma_type == "MASTER_SINGLE_CHANNEL") ? 1 : 0;
  localparam  integer is_slave_chan        = (tx_pma_type == "SLAVE_CHANNEL"        ) ? 1 : 0;
  localparam  integer is_empty_chan        = (tx_pma_type == "EMPTY_CHANNEL"        ) ? 1 : 0;
  
  // to support bonding 
  
  // Select clock source for g2 and g1 based on auto_negotiation
  localparam X1_CLOCK_SOURCE_SEL_AUTONEG = (auto_negotiation == "true") ? "same_ch_txpll"
                                         //: (pll_sel ==11) ? "hfclk_ch1_x6_up"// 9  - hfclkp_x6_up
													  //: (pll_sel ==10) ? "hfclk_xn_dn"    // 8  - hfclkp_xn_dn
													  //: (pll_sel == 9) ? "hfclk_ch1_x6_dn"// 7  - hfclkp_x6_dn
													  //: (pll_sel == 8) ? "hfclk_xn_up"    // 6  - hfclkp_xn_up
													  : (pll_sel == 5) ? "down_segmented" // 1  - clk_dn_seg
													  : (pll_sel == 4) ? "up_segmented"   // 0  - clk_up_seg
													  //: (pll_sel == 5) ? "lcpll_bottom"   // 11 - clk_lc_b
													  //: (pll_sel == 4) ? "lcpll_top"      // 10 - clk_lc_t
													  : (pll_sel == 3) ? "ffpll"          // 2  - clk_ffpll
													  : (pll_sel == 2) ? "ch1_txpll_b"    // 4  - clk_cdr_1b
													  : (pll_sel == 1) ? "ch1_txpll_t"    // 3  - clk_cdr_1t 
													  : (pll_sel == 0) ? "same_ch_txpll"  // 5  - clk_cdr_loc
													  : "x1_clk_unused";
													  
  localparam X1_DIV_M_SEL = (tx_clk_div == 2) ? 2 :
                            (tx_clk_div == 4) ? 4 :
									 (tx_clk_div == 8) ? 8 :
									 1;  
	
  
  localparam  [plls*2:0]  bonding_mode_sel_bin  = pma_bonding_str2bin(pma_bonding_mode);
  localparam              master_cgb_en         = (bonded_lanes == 1)? bonding_mode_sel_bin[plls*2] : 0;
  localparam              is_pll_switching       = (plls > 1)? 1 : 0; // PLL switching only supported for nonbonded mode. Bonded clocks disconnected when in nonbonded mode.
  
  //main PLL settings
  localparam              pma_bonding_sel      = ((bonding_mode_sel_bin >> (2*pll_sel)) & 2'b11);
  localparam              pma_is_xn            = (pma_bonding_sel == av_xcvr_h::AV_XR_ID_PMA_BONDING_XN) ? 1 : 0;
  localparam              pma_is_xn_non_bonded = (pma_is_xn == 1 && bonded_lanes == 1)? 1 : 0;
  localparam              pma_is_xn_bonded     = (pma_is_xn == 1 && bonded_lanes != 1)? 1 : 0;
    
  generate if(is_empty_chan == 0) begin:tx_pma_ch
     wire  [MAX_PLLS-1:0] wire_clk;
	 wire  [MAX_PLLS-1:0] int_wire_clk;
	 
	 wire  [79:0]  w_datain;
	 wire          w_txelecidl;
	 wire          w_rxdetclk;
	 wire          w_txdetrx;
	 
	 wire        cpulse_from_cgb;
	 wire        hclk_from_cgb;
	 wire        lfclk_from_cgb;
	 wire  [2:0] pclk_from_cgb;
	 wire        dataout_from_ser;
	 
	 wire        wire_hfclkpin;
	 wire        wire_lfclkpin;
	 wire        wire_cpulsein;
	 wire  [2:0] wire_pclkin;
	 
	 wire             wire_hfclkpout;
	 wire             wire_lfclkpout;
	 wire             wire_cpulseout;
	 wire  [2:0]      wire_pclkout;
	 wire  [plls-1:0] hfclkpout_from_master;
	 
	 wire        wire_rstn;
	 wire        wire_pcsrstn;
	 
	 wire        w_pciesw;  
	 
	 assign  w_datain    = (is_master_only == 0) ? datain    : 80'd0;
	 assign  w_txelecidl = (is_master_only == 0) ? txelecidl : 1'b0;
	 assign  w_rxdetclk  = (is_master_only == 0) ? rxdetclk  : 1'b0;
	 assign  w_txdetrx   = (is_master_only == 0) ? txdetrx   : 1'b0;
	 
	 // Determine what drives the bonding lines input to the CGB
	 assign wire_hfclkpin = (is_single_chan       == 1) ? 1'b0               : 
                        	(pma_is_xn_bonded     == 1) ? hfclkpin           : // Master CGB resides with PLL for xN bonded
							(pma_is_xn_non_bonded == 1) ? 1'b0               : // xn non bonded should not connect bonded clocks
									(is_pll_switching == 1) ? 1'b0               : // x1/xN switching should not connect bonded clocks					   
									(is_master_chan       == 1) ? wire_hfclkpout     :
									(is_master_only       == 1) ? wire_hfclkpout     :
									                              hfclkpin           ;
																			
	 assign wire_lfclkpin = (is_single_chan       == 1) ? 1'b0               :
	                        (pma_is_xn_bonded     == 1) ? lfclkpin           : // Master CGB resides with PLL for xN bonded
							(pma_is_xn_non_bonded == 1) ? 1'b0               : // xn non bonded should not connect bonded clocks
									(is_pll_switching == 1) ? 1'b0               : // x1/xN switching should not connect bonded clocks		
									(is_master_chan       == 1) ? wire_lfclkpout     :
                           (is_master_only       == 1) ? wire_lfclkpout     :
                                                         lfclkpin           ;
    
    assign wire_cpulsein = (is_single_chan       == 1) ? 1'b0               :
	                        (pma_is_xn_bonded    == 1) ? cpulsein           : // Master CGB resides with PLL for xN bonded
							(pma_is_xn_non_bonded  == 1) ? 1'b0               :  // xn non bonded should not connect bonded clocks
								   (is_pll_switching  == 1) ? 1'b0               :  // x1/xN switching should not connect bonded clocks		                     
									(is_master_chan       == 1) ? wire_cpulseout     :
									(is_master_only       == 1) ? wire_cpulseout     :
									                              cpulsein           ;
																			
	 assign wire_pclkin   = (is_single_chan       == 1) ? 3'b000             :
	                        (pma_is_xn_bonded     == 1) ? pclkin             : // Master CGB resides with PLL for xN bonded
							(pma_is_xn_non_bonded == 1) ? 3'b000   :      // xn non bonded should not connect bonded clocks
									(is_pll_switching == 1) ? 3'b000   :   // x1/xN switching should not connect bonded clocks		        
									(is_master_chan       == 1) ? wire_pclkout       :
									(is_master_only       == 1) ? wire_pclkout       :
									                              pclkin             ;
																			
	 // determine what drives the bonding lines output from this module
	 assign hfclkpout =  (is_single_chan == 1) ? 1'b0 :
	                     (is_slave_chan  == 1) ? 1'b0 :
								                        wire_hfclkpout;
																
	 assign lfclkpout =  (is_single_chan == 1) ? 1'b0 :
	                     (is_slave_chan  == 1) ? 1'b0 :
								                        wire_lfclkpout;
																
	 assign cpulseout =  (is_single_chan == 1) ? 1'b0 :
	                     (is_slave_chan  == 1) ? 1'b0 :
								                        wire_cpulseout;
																
	 assign pclkout =  (is_single_chan == 1) ? 1'b0 :
	                   (is_slave_chan  == 1) ? 1'b0 :
							                         wire_pclkout;
															 
	 // determine what drives the HF clock input into CGB
	 assign wire_clk = (is_slave_chan == 1) ? {MAX_PLLS{1'b0}} // no clock can be connected in a slave mode
	                   : {{(MAX_PLLS-PLL_CNT){1'b0}},clk};  // otherwise, connect the input clock
							 
	 assign w_pciesw = (auto_negotiation == "false") ? 1'b0 : pciesw;  
	 
	 // determine what drives the HF clock input into CGB
	
   // Non PCIe designs may drive "NORMAL_RESET", the default on the xcvr_native and pcs_ch.sv 
   // is "normal_reset". Accounting for both the conditions
	 assign wire_rstn = (pcie_rst == "NORMAL_RESET" || pcie_rst == "normal_reset") ? rstn
	                    : 1'b1;
			
   // txpcsrstn of HIP connects directly to out_pma_reserved port of PCS 
   // which in turn connects to pcsrstn of CGB. We will not model this since 
   // simulation can not reproduce this issue. 
   
   // Possible values for pcie_rst: 
   // Gen1 w/ HIP w/ HRC, Gen1 w/ HIP w/ SRC, Gen1/2 PIPE       - "normal_reset" 
   // Gen2 w/ HIP w/ HRC                                        - "pcie_rst" 
   
   // Tieing pcsrstn to 1 for Gen2 HRC cases. 
	 assign wire_pcsrstn = 1'b1;
								  
    arriav_hssi_pma_tx_cgb #(
	  .mode                   (mode            ),
      .auto_negotiation       (auto_negotiation),
      .data_rate              (data_rate  ),
       // fogbugz:153853 mux select attribute on CGB
      .pcie_rst               (pcie_rst),   
      .x1_clock_source_sel    ((pma_is_xn_bonded == 1)? "x1_clk_unused"
		                        :(((pma_is_xn_non_bonded == 1)   ||
	                           (is_single_chan == 1) ||
                              (is_master_chan == 1) ||
                              (is_master_only == 1)) ? X1_CLOCK_SOURCE_SEL_AUTONEG     // corresponds to .clkcdrloc input
                              : "x1_clk_unused")),  // a special setting when the front-end mux of the CGB is not used (SLAVE CHANNEL ONLY)
      .xn_clock_source_sel    ((pma_is_xn_non_bonded == 1 || 
	                          (bonded_lanes == 1) && (ht_delay_sel != "true"))? "cgb_x1_m_div"
	                          :(((is_master_chan == 1) ||
                              (is_slave_chan == 1) ||
                              (is_master_only == 1))? "xn_up" : // corresponds to *xnup ports
                              ((is_single_chan == 1) && (ht_delay_sel == "true")) ? "cgb_ht" 
                              : "cgb_x1_m_div")),
      .x1_div_m_sel           (X1_DIV_M_SEL)
	) tx_cgb (
      .rstn           (wire_rstn             ),
      .pcsrstn        (wire_pcsrstn          ),
      .clkcdrloc      (int_wire_clk[0]      ),  // Switch between this
      .clkcdr1t       (int_wire_clk[1]      ),
      .clkcdr1b       (int_wire_clk[2]      ),
      .clkffpll       (int_wire_clk[3]      ),
      .clkupseg       (int_wire_clk[4]      ),
      .clkdnseg       (int_wire_clk[5]      ),	
      .fref           (fref             ),
      .pciesw         (w_pciesw         ),
      .hfclkpxnup     (wire_hfclkpin    ),
      .lfclkpxnup     (wire_lfclkpin    ),
      .cpulsexnup     (wire_cpulsein    ),
      .pclkxnup       (wire_pclkin      ),
    
      // to serializer
      .cpulse         (cpulse_from_cgb  ),
      .hfclkp         (hclk_from_cgb    ),
      .lfclkp         (lfclk_from_cgb   ),
      .pclk           (pclk_from_cgb    ),
    
      // when used as a CGB master, these are bonding clocks
      .cpulseout      (wire_cpulseout   ),
      .hfclkpout      (wire_hfclkpout   ),
      .lfclkpout      (wire_lfclkpout   ),
      .pclkout        (wire_pclkout     ),
      .pcieswdone     (pcieswdone       ),
		
      .avmmrstn       (avmmrstn     ),
      .avmmclk        (avmmclk      ),
      .avmmwrite      (avmmwrite    ),
      .avmmread       (avmmread     ),
      .avmmbyteen     (avmmbyteen   ),
      .avmmaddress    (avmmaddress  ),
      .avmmwritedata  (avmmwritedata),
      .avmmreaddata   (avmmreaddata_cgb ),
      .blockselect    (blockselect_cgb  )
          
      `ifndef ALTERA_RESERVED_QIS 
      ,
      // Unused inputs
      .rxclk          (1'b0             ), //to pma_rx_pma_clk
      //.clklct         (1'b0/*TODO*/     ),
      //.clklcb         (1'b0/*TODO*/     ),
      .hfclkn         (                 ),
      .hfclknout      (                 ),
      .lfclkn         (                 ),
      .lfclknout      (                 ),
      .rxiqclk        (                 ),
      .clkbcdr1t      (1'b0             ),
      .clkbcdr1b      (1'b0             ),
      .clkbcdrloc     (1'b0             ),
      .clkbdnseg      (1'b0             ),
      .clkbffpll      (1'b0             ),
      //.clkblcb        (1'b0             ),
      //.clkblct        (1'b0             ),
      .clkbupseg      (1'b0             ),
      .cpulsex6up     (1'b0             ),
      .cpulsex6dn     (1'b0             ),
      .cpulsexndn     (1'b0             ),
      .hfclknx6up     (1'b0             ),
      .hfclknx6dn     (1'b0             ),
      .hfclknxndn     (1'b0             ),
      .hfclknxnup     (1'b0             ),
      .hfclkpx6up     (1'b0             ),
      .hfclkpx6dn     (1'b0             ),
      .hfclkpxndn     (1'b0             ),
      .lfclknx6up     (1'b0             ),
      .lfclknx6dn     (1'b0             ),
      .lfclknxndn     (1'b0             ),
      .lfclknxnup     (1'b0             ),
      .lfclkpx6up     (1'b0             ),
      .lfclkpx6dn     (1'b0             ),
      .lfclkpxndn     (1'b0             ),
      .pciesyncp      (/*TODO*/         ),
      //.pciefbclk      (/*TODO*/         ),
      .pclkx6up       (1'b0             ),
      .pclkx6dn       (1'b0             ),
      .pclkxndn       (1'b0             )
      //.pllfbsw        (/*TODO*/         ),
      //.txpmasyncp     (1'b0             )
      `endif // ifndef ALTERA_RESERVED_QIS
    );
  
    if(master_cgb_en == 0) begin
      assign int_wire_clk = (pma_is_xn_bonded == 1)? {MAX_PLLS{1'b0}} : wire_clk;
    end else begin
	  for(ig=0; ig<plls; ig = ig + 1) begin: master_cgb_inst
		
	    // define PMA bonding mode
	    localparam  [2:0] bonding_mode_sel  = ((bonding_mode_sel_bin >> (2*ig)) & 2'b11);
	    localparam  is_xn = (bonding_mode_sel[1:0] == av_xcvr_h::AV_XR_ID_PMA_BONDING_XN) ? 1 : 0;
		
		localparam  [MAX_CHARS*8-1:0] base_data_rate_sel = get_value_at_index(ig,base_data_rate);
		
		if (is_xn) begin
		  assign int_wire_clk[ig] = hfclkpout_from_master[ig];
		  
          arriav_hssi_pma_tx_cgb #(
            .auto_negotiation       (auto_negotiation),
            .data_rate              (base_data_rate_sel),  
            .x1_clock_source_sel    ((is_pll_switching == 0)? X1_CLOCK_SOURCE_SEL_AUTONEG : "same_ch_txpll"),  
            .xn_clock_source_sel    ("cgb_xn_unused"),
            .x1_div_m_sel           (1)
	      ) tx_cgb_master (
            .rstn           (rstn_cgb_master[ig]   ),
            .pcsrstn        (wire_pcsrstn          ),
            .clkcdrloc      ((is_pll_switching == 1)? wire_clk[ig] : wire_clk[0] ),  // Switch between this
            .clkcdr1t       ((is_pll_switching == 1)? 1'b0 : wire_clk[1]         ),
            .clkcdr1b       ((is_pll_switching == 1)? 1'b0 : wire_clk[2]         ),
            .clkffpll       ((is_pll_switching == 1)? 1'b0 : wire_clk[3]         ),
            .clkupseg       ((is_pll_switching == 1)? 1'b0 : wire_clk[4]         ),
            .clkdnseg       ((is_pll_switching == 1)? 1'b0 : wire_clk[5]         ),	
            .fref           (fref             ),
            .pciesw         (w_pciesw         ),
            .hfclkpxnup     (1'b0             ),
            .lfclkpxnup     (1'b0             ),
            .cpulsexnup     (1'b0             ),
            .pclkxnup       (1'b0           ),
    
            // to serializer
            .cpulse         (),
            .hfclkp         (),
            .lfclkp         (),
            .pclk           (),
    
            // xn non-bonded only need the fast clock from Master CGB
            .cpulseout      (),
            .hfclkpout      (hfclkpout_from_master[ig]),
            .lfclkpout      (),
            .pclkout        (),
            .pcieswdone     (pcieswdone       ),
		
            .avmmrstn       (1'd1     ),
            .avmmclk        (1'd0      ),
            .avmmwrite      (1'd0    ),
            .avmmread       (1'd0     ),
            .avmmbyteen     (2'd0   ),
            .avmmaddress    (11'd0  ),
            .avmmwritedata  (16'd0),
            .avmmreaddata   ( ),
            .blockselect    ( )
          
		        `ifndef ALTERA_RESERVED_QIS 
		        ,
		        // Unused inputs
            .rxclk          (1'b0             ), //to pma_rx_pma_clk
            //.clklct         (1'b0/*TODO*/     ),
            //.clklcb         (1'b0/*TODO*/     ),
            .hfclkn         (                 ),
            .hfclknout      (                 ),
            .lfclkn         (                 ),
            .lfclknout      (                 ),
            .rxiqclk        (                 ),
            .clkbcdr1t      (1'b0             ),
            .clkbcdr1b      (1'b0             ),
            .clkbcdrloc     (1'b0             ),
            .clkbdnseg      (1'b0             ),
            .clkbffpll      (1'b0             ),
            //.clkblcb        (1'b0             ),
            //.clkblct        (1'b0             ),
            .clkbupseg      (1'b0             ),
            .cpulsex6up     (1'b0             ),
            .cpulsex6dn     (1'b0             ),
            .cpulsexndn     (1'b0             ),
            .hfclknx6up     (1'b0             ),
            .hfclknx6dn     (1'b0             ),
            .hfclknxndn     (1'b0             ),
            .hfclknxnup     (1'b0             ),
            .hfclkpx6up     (1'b0             ),
            .hfclkpx6dn     (1'b0             ),
            .hfclkpxndn     (1'b0             ),
            .lfclknx6up     (1'b0             ),
            .lfclknx6dn     (1'b0             ),
            .lfclknxndn     (1'b0             ),
            .lfclknxnup     (1'b0             ),
            .lfclkpx6up     (1'b0             ),
            .lfclkpx6dn     (1'b0             ),
            .lfclkpxndn     (1'b0             ),
            .pciesyncp      (/*TODO*/         ),
            //.pciefbclk      (/*TODO*/         ),
            .pclkx6up       (1'b0             ),
            .pclkx6dn       (1'b0             ),
            .pclkxndn       (1'b0             )
            //.pllfbsw        (/*TODO*/         ),
            //.txpmasyncp     (1'b0             )
		        `endif // ifndef ALTERA_RESERVED_QIS
          );
		end
		else
		  assign int_wire_clk[ig] = wire_clk[ig];
	  end
    end
    
    arriav_hssi_pma_tx_ser #(
	  .mode                 (mode),
      .auto_negotiation     (auto_negotiation),
      .ser_loopback         (ser_loopback),
      .clk_forward_only_mode((is_master_only == 1) ? "true" : "false"),
      .pma_direct           (pma_direct)
	) tx_pma_ser (
      .cpulse         (cpulse_from_cgb  ),
      .datain         (w_datain         ),
      .hfclk          (hclk_from_cgb    ),
      .lfclk          (lfclk_from_cgb   ),
      .pclk           (pclk_from_cgb    ),
      //.pciesw         (w_pciesw         ),
      .rstn           (rstn             ),
      .clkdivtx       (clkdivtx         ),
      .dataout        (dataout_from_ser ),
      .lbvop          (seriallpbkout    ),
      .slpbk          (seriallpbken     ),
      .hfclkn         (1'b0             ),
      .lfclkn         (1'b0             ),
      //.lbvon          (/*TODO*/         ),
      .preenout       (/*TODO*/         ),
      //.pciesyncp      (/*TODO*/         ),
      .avgvon         (                 ),
      .avgvop         (                 ),
      .avmmrstn       (avmmrstn         ),
      .avmmclk        (avmmclk          ),
      .avmmwrite      (avmmwrite        ),
      .avmmread       (avmmread         ),
      .avmmbyteen     (avmmbyteen       ),
      .avmmaddress    (avmmaddress      ),
      .avmmwritedata  (avmmwritedata    ),
      .avmmreaddata   (avmmreaddata_ser ),
      .blockselect    (blockselect_ser  )
    );
    
    

    if (is_master_only == 0) begin:tx_pma_buf
      wire nonuserfrompmaux;
      wire atb0outtopllaux;
      wire atb1outtopllaux;
      
      arriav_hssi_pma_aux #(
        .continuous_calibration ("true")
      ) tx_pma_aux (
        .calpdb       (1'b1             ),
        .calclk       (calclk           ),
        .nonusertoio  (nonuserfrompmaux ),
        .zrxtx50      (/*unused*/       ),
				.atb0out (atb0outtopllaux),
        .atb1out (atb1outtopllaux)
        
        `ifndef ALTERA_RESERVED_QIS 
        ,
        // Unused inputs
        .testcntl     (1'b0             ),
        .refiqclk     (6'b0             )
        `endif // ifndef ALTERA_RESERVED_QIS
      ); 
                          
      arriav_hssi_pma_tx_buf #(
        .rx_det_pdb(rx_det_pdb),
        .fir_coeff_ctrl_sel(fir_coeff_ctrl_sel)
      ) tx_pma_buf (
        .nonuserfrompmaux (nonuserfrompmaux ),
        .datain           (dataout_from_ser ),
        .rxdetclk         (w_rxdetclk       ),
        .txdetrx          (w_txdetrx        ),
        .txelecidl        (w_txelecidl      ),
        .rxdetectvalid    (rxdetectvalid    ),
        .dataout          (dataout          ),
        .rxfound          (rxfound          ),
        //.txqpipulldn      (1'b0             ),
        //.txqpipullup      (1'b0             ),
        .fixedclkout      (/*TODO*/         ),
        .vrlpbkn          (vrlpbkn          ),
        .vrlpbkp          (vrlpbkp          ),
        .vrlpbkp1t        (/*TODO*/         ),
        .vrlpbkn1t        (/*TODO*/         ),
        .icoeff           (/*TODO*/         ),
        .avgvon           (                 ),
        .avgvop           (                 ),
        .compass          (                 ),
        .detecton         (                 ),
        .probepass        (                 ),
        .avmmrstn         (avmmrstn         ),
        .avmmclk          (avmmclk          ),
        .avmmwrite        (avmmwrite        ),
        .avmmread         (avmmread         ),
        .avmmbyteen       (avmmbyteen       ),
        .avmmaddress      (avmmaddress      ),
        .avmmwritedata    (avmmwritedata    ),
        .avmmreaddata     (avmmreaddata_buf ),
        .blockselect      (blockselect_buf  )
      );
      
      if ( enable_dcd == 1 ) begin
      //pll aux for DCD calibration
      arriav_pll_aux # (
        .pl_aux_atb_comp_minus(1'b1),
	.pl_aux_atb_comp_plus (1'b1),
	.pl_aux_comp_pwr_dn   (1'b0)
      ) pll_aux (
        .atb0out(atb0outtopllaux),
        .atb1out(atb1outtopllaux),
        .atbcompout(atb_comp_out)
      );
      end else begin
        assign atb_comp_out = 1'b0;
      end
    end // end of if (is_master_only == 0)
  end else begin  // if dummy_chan
    // Warning avoidance
    assign  dataout = {1'b0,calclk,datain,txelecidl,rxdetclk,txdetrx,
              rstn,seriallpbken,clk,pciesw,1'b0,cpulsein,
              hfclkpin,lfclkpin,pclkin,avmmrstn,avmmclk,avmmwrite,
              avmmread,avmmbyteen,avmmaddress,avmmwritedata, 
              vrlpbkp,vrlpbkn};

    assign  rxdetectvalid = 1'b0;
    assign  rxfound       = 1'b0;
    assign  clkdivtx      = 1'b0;
    assign  seriallpbkout = 1'b0;
    assign  pcieswdone    = 2'b00;
    assign  hfclkpout     = 1'b0;
    assign  lfclkpout     = 1'b0;
    assign  cpulseout     = 1'b0;
    assign  pclkout       = 3'b000;
    
    assign  avmmreaddata_cgb  = 16'd0;
    assign  avmmreaddata_ser  = 16'd0;
    assign  avmmreaddata_buf  = 16'd0;
    assign  blockselect_cgb   = 1'b0;
    assign  blockselect_ser   = 1'b0;
    assign  blockselect_buf   = 1'b0;
  end	    

  endgenerate  

initial begin
  if( (tx_clk_div != 1) && (tx_clk_div != 2) && (tx_clk_div != 4) && (tx_clk_div != 8) ) begin
    $display("Critical Warning: parameter 'tx_clk_div' of instance '%m' has illegal value '%0d' assigned to it. Valid parameter values are: '1,2,4,8'. Using value '%0d'", tx_clk_div, X1_DIV_M_SEL);
  end
end


// Function takes in a string of comma seperated values containing PMA bonding mode.
// returns a binary where every two bits represents the PMA bonding mode. 
// MSB indicate whether any of the PLLs using xN non bonded mode.

function  [plls*2:0]  pma_bonding_str2bin(
  input [MAX_CHARS*MAX_STRS*8-1:0]  pma_bonding_set
);
  int index;
  reg [MAX_CHARS*8-1:0] pma_bonding_str;
  reg [1:0] pma_bonding_bin;
  reg master_cgb_en; //check whether all PLLs are using x1

  pma_bonding_str2bin = {plls{2'b00}};
  for(index = 0; index < plls; index = index + 1) begin
    pma_bonding_str = altera_xcvr_functions::get_value_at_index(index,pma_bonding_set);
    pma_bonding_bin = (pma_bonding_str == "x1") ? av_xcvr_h::AV_XR_ID_PMA_BONDING_X1[1:0]:
                      (pma_bonding_str == "xN") ? av_xcvr_h::AV_XR_ID_PMA_BONDING_XN [1:0]:
                                                  av_xcvr_h::AV_XR_ID_PMA_BONDING_NONE[1:0];
    pma_bonding_str2bin[plls*2-1:0] = pma_bonding_str2bin[plls*2-1:0] | (( {plls{2'b00}} | pma_bonding_bin ) << (index*2));
	pma_bonding_str2bin[plls*2] = pma_bonding_str2bin[plls*2] | pma_bonding_str2bin[index*2];
  end
endfunction 

endmodule
                
