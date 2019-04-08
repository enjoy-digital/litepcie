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


// (C) 2001-2011 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


`timescale 1ps/1ps


//************************************************************************************************************************
//
// Adapter for PIPE signals <---> EMSIP signals
//
//************************************************************************************************************************

module av_xcvr_emsip_adapter #(
     parameter lanes          = 1,   //Number of lanes chosen by user. legal value: 1+
     parameter total_lanes    = 1,   //Total number of lanes - special case only for x8 HIP designs where lanes=8, total_lanes=9. 
     parameter deser_factor   = 16,  //Deserialization factor. legal value: 8, 16
     parameter word_size      = 8,    
     parameter hip_hard_reset = "disable" //Controls is Hard Reset Controller block is used by the HIP  
) 
( 
     
     //PIPE interface ports 
    input  wire [lanes*deser_factor -1:0]     pipe_txdata,
    input  wire [(lanes*deser_factor)/8 -1:0] pipe_txdatak,
    input  wire [lanes -1:0]                  pipe_txcompliance,
    input  wire [lanes -1:0]                  pipe_txelecidle,
    input  wire [lanes -1:0]                  pipe_rxpolarity,
    input  wire	[lanes -1:0]	              pipe_txdetectrx_loopback,
    input  wire	[lanes -1:0]	              pipe_txswing,
    input  wire	[lanes*3 -1:0]	              pipe_txmargin,
    input  wire	[lanes -1:0]	              pipe_txdeemph,
    input  wire	[lanes -1:0]	              pipe_rate,  
    input  wire	         	              rate_ctrl,  
    input  wire	[lanes*2 -1:0]	              pipe_powerdown,
    input  wire	[lanes*3 -1:0]	              rx_eidleinfersel,

    output reg	[lanes -1:0]	              pipe_phystatus,
    
    output reg [lanes*deser_factor -1:0]      pipe_rxdata,
    output reg [(lanes*deser_factor)/8 -1:0]  pipe_rxdatak,
    output reg [lanes -1:0]                   pipe_rxvalid,
    output reg [lanes -1:0]                   pipe_rxelecidle,
    output reg [lanes*3 -1:0]                 pipe_rxstatus,

    output wire  pipe_pclk,
    output wire  pipe_pclkch1, 	
    output wire  pipe_pclkcentral,
    output wire  pllfixedclkcentral,
    output wire  pllfixedclkch0,
    output wire  pllfixedclkch1,
	
    //non-PIPE ports
    //MM ports
    input  wire [lanes -1:0]                  rx_set_locktoref,         
    input  wire [lanes -1:0]                  tx_invpolarity,
    
    output reg [(lanes*deser_factor)/8 -1:0] rx_errdetect, 
    output reg [(lanes*deser_factor)/8 -1:0] rx_disperr,
    output reg [(lanes*deser_factor)/8 -1:0] rx_patterndetect, 
    output reg [(lanes*deser_factor)/8 -1:0] rx_syncstatus, 
    output reg [lanes -1:0]                  rx_phase_comp_fifo_error,
    output reg [lanes -1:0]                  tx_phase_comp_fifo_error,
    output reg [lanes -1:0]                  rx_signaldetect,
    output reg	[lanes -1:0]	             rx_rlv,
    output reg [lanes*5  -1:0]               rx_bitslipboundaryselectout,

    // Hard reset controller signals (PCS PLD IF -> HIP)
    output reg [lanes:0] frefclk,
    output reg [lanes:0] offcaldone,
    //output reg [lanes:0] txlcplllock,
    output reg [lanes:0] rxfreqtxcmuplllock, 
    //output reg [lanes:0] masktxplllock,
    output reg [lanes:0] rxpllphaselock, 
    
    // Hard reset controller signals (PCS PLD IF -> HIP)
    input wire [lanes:0]  offcalen,
    input wire [lanes:0]  txpcsrstn,          // active-low reset from HRC to 8g Tx PCS
    input wire [lanes:0]  rxpcsrstn,          // active-low reset from HRC to 8g Rx PCS
    input wire [lanes:0]  rxpmarstb,          // active-low reset from HRC to Rx PMA (Channel PLL and CMU PLL )
    input wire [lanes:0]  txpmasyncp,
    //input wire [lanes:0]  txlcpllrstb,
    
    //EMSIP ports
    output wire [total_lanes*104     -1:0]	out_pcspldif_emsip_tx_in,
    output wire [total_lanes*13      -1:0]	out_pcspldif_emsip_tx_special_in,
    output wire [total_lanes*3       -1:0]	out_pcspldif_emsip_tx_clk_in,
    
    output wire [total_lanes*20      -1:0]	out_pcspldif_emsip_rx_in,
    output wire [total_lanes*13      -1:0]	out_pcspldif_emsip_rx_special_in,
    output wire [total_lanes*3       -1:0]	out_pcspldif_emsip_rx_clk_in,
    
    output wire [total_lanes*38      -1:0]	out_pcspldif_emsip_com_in,
    output wire [total_lanes*20      -1:0]	out_pcspldif_emsip_com_special_in,

    input  wire [total_lanes*12      -1:0]	in_pcspldif_emsip_tx_out,
    input  wire [total_lanes*16      -1:0]	in_pcspldif_emsip_tx_special_out,
    input  wire [total_lanes*3       -1:0]	in_pcspldif_emsip_tx_clk_out,
    
    input  wire [total_lanes*129     -1:0]	in_pcspldif_emsip_rx_out,
    input  wire [total_lanes*16      -1:0]	in_pcspldif_emsip_rx_special_out,
    input  wire [total_lanes*3       -1:0]	in_pcspldif_emsip_rx_clk_out,
    
    input  wire [total_lanes*27      -1:0]	in_pcspldif_emsip_com_out,
    input  wire [total_lanes*20      -1:0]	in_pcspldif_emsip_com_special_out,
    input  wire [total_lanes*3       -1:0]	in_pcspldif_emsip_com_clk_out
);

   // Adjust for x8 HIP case where total_lanes=9 and lanes=8. Bonding master channel=4 which is a master only channel(no data). 
   // Adjust the pipe and other inputs to total_lanes wide and interleave for lane 4 to connect directly to emsip signals to PCS
    reg [total_lanes*deser_factor -1:0]     r_pipe_txdata;
    reg [(total_lanes*deser_factor)/8 -1:0] r_pipe_txdatak;
    reg [total_lanes   -1:0]                r_pipe_txcompliance;
    reg [total_lanes   -1:0]                r_pipe_txelecidle;
    reg [total_lanes   -1:0]                r_pipe_rxpolarity;
    reg [total_lanes   -1:0]	            r_pipe_txdetectrx_loopback;
    reg [total_lanes   -1:0]	            r_pipe_txswing;
    reg [total_lanes*3 -1:0]	            r_pipe_txmargin;
    reg [total_lanes   -1:0]	            r_pipe_txdeemph;
    reg [total_lanes   -1:0]	            r_pipe_rate;  
    reg [total_lanes*2 -1:0]	            r_pipe_powerdown;
    reg [total_lanes*3 -1:0]	            r_rx_eidleinfersel;
    reg [total_lanes   -1:0]                r_rx_set_locktoref;  
           
    reg [total_lanes   -1:0]                r_tx_invpolarity;
    // Hard reset controller signals (HIP -> PCS PLD IF)
    reg [total_lanes   -1:0]                r_off_cal_en; 
    reg [total_lanes   -1:0]                r_tx_pcs_rst_n; 
    reg [total_lanes   -1:0]                r_rx_pcs_rst_n;
    reg [total_lanes   -1:0]                r_rx_pma_rstb; 
    reg [total_lanes   -1:0]                r_tx_pma_syncp; 
    //reg [total_lanes   -1:0]                r_tx_lc_pll_rstb; 

   //Wires for connecting up the emsip signals from PCS as it is (total_lanes wide)
   //The PIPE and other outputs are assigned from these wires with channel 4 interleaved
    wire [total_lanes -1:0]	             w_pipe_phystatus;
    wire [total_lanes*deser_factor -1:0]     w_pipe_rxdata;
    wire [(total_lanes*deser_factor)/8 -1:0] w_pipe_rxdatak;
    wire [total_lanes   -1:0]                w_pipe_rxvalid;
    wire [total_lanes   -1:0]                w_pipe_rxelecidle;
    wire [total_lanes*3 -1:0]                w_pipe_rxstatus;
    wire [(total_lanes*deser_factor)/8 -1:0] w_rx_errdetect; 
    wire [(total_lanes*deser_factor)/8 -1:0] w_rx_disperr;
    wire [(total_lanes*deser_factor)/8 -1:0] w_rx_patterndetect; 
    wire [(total_lanes*deser_factor)/8 -1:0] w_rx_syncstatus; 
    wire [total_lanes    -1:0]               w_rx_phase_comp_fifo_error;
    wire [total_lanes    -1:0]               w_tx_phase_comp_fifo_error;
    wire [total_lanes    -1:0]               w_rx_signaldetect;
    wire [total_lanes    -1:0]	             w_rx_rlv;
    wire [total_lanes*5  -1:0]               w_rx_bitslipboundaryselectout;
    // Hard reset controller signals (PCS PLD IF -> HIP)
    wire [total_lanes -1:0]                  w_fref_clk;
    wire [total_lanes -1:0]                  w_off_cal_done;
    wire [total_lanes -1:0]                  w_rx_freq_tx_cmu_pll_lock;
    //wire [total_lanes -1:0]                  w_tx_lc_pll_lock;    
    //wire [total_lanes -1:0]                  w_mask_tx_pll_lock;  
    wire [total_lanes -1:0]                  w_rx_pll_phase_lock;
 
	generate
    //For all designs except x8 HIP 
    if (lanes == total_lanes)
    begin
        always @ (*)
        begin
			//Assign directly from inputs
			r_pipe_txdata              <= pipe_txdata;
			r_pipe_txdatak             <= pipe_txdatak;
			r_pipe_txcompliance        <= pipe_txcompliance;
			r_pipe_txelecidle          <= pipe_txelecidle;
			r_pipe_rxpolarity          <= pipe_rxpolarity;
			r_pipe_txdetectrx_loopback <= pipe_txdetectrx_loopback;
			r_pipe_txswing             <= pipe_txswing;
			r_pipe_txmargin            <= pipe_txmargin;
			r_pipe_txdeemph            <= pipe_txdeemph;
			r_pipe_rate                <= pipe_rate;  
			r_pipe_powerdown           <= pipe_powerdown;
			r_rx_eidleinfersel         <= rx_eidleinfersel;
			r_rx_set_locktoref         <= rx_set_locktoref;         
			r_tx_invpolarity           <= tx_invpolarity;
			// Hard reset controller signals (HIP -> PCS PLD IF)
			// HIP always connects lanes+1 wide signals to HRC. Data channels (lanes) + CMU channel (+1).
			// For x1 and x4, PHY IP stamps only data channels and does not stamp out If blocks, PCS etc for the CMu channel.
			//  Therefore, connect only from the indices corresponding to data channels.
			// HIP controls from which channels the HRC will enable.
			r_off_cal_en               <= offcalen[lanes-1:0]; 
			r_tx_pcs_rst_n             <= txpcsrstn[lanes-1:0]; 
			r_rx_pcs_rst_n             <= rxpcsrstn[lanes-1:0]; 
			r_rx_pma_rstb              <= rxpmarstb[lanes-1:0]; 
			r_tx_pma_syncp             <= txpmasyncp[lanes-1:0]; 
			//r_tx_lc_pll_rstb           <= txlcpllrstb[lanes-1:0]; 

			//Assign directly to outputs
			pipe_phystatus              <= w_pipe_phystatus;
			pipe_rxdata                 <= w_pipe_rxdata;
			pipe_rxdatak                <= w_pipe_rxdatak;
			pipe_rxvalid                <= w_pipe_rxvalid;
			pipe_rxelecidle             <= w_pipe_rxelecidle;
			pipe_rxstatus               <= w_pipe_rxstatus;
			rx_errdetect                <= w_rx_errdetect; 
			rx_disperr                  <= w_rx_disperr;
			rx_patterndetect            <= w_rx_patterndetect; 
			rx_syncstatus               <= w_rx_syncstatus; 
			rx_phase_comp_fifo_error    <= w_rx_phase_comp_fifo_error;
			tx_phase_comp_fifo_error    <= w_tx_phase_comp_fifo_error;
			rx_signaldetect             <= w_rx_signaldetect;
			rx_rlv                      <= w_rx_rlv;
			rx_bitslipboundaryselectout <= w_rx_bitslipboundaryselectout;
			// Hard reset controller signals (PCS PLD IF -> HIP)
			// HIP always expects lanes+1 wide signals to HRC. Data channels (lanes) + CMU channel (+1).
			// For x1 and x4, PHY IP does not stamp out If blocks/PCS etc for the CMU channel. Therefore, connect only to the indices corresponding to          // the data channels.
			// rxfreqtxcmuplllock for the CMU channel comes from the pll lock from the Tx CMU PLL. HIP controls from which channels the HRC
			// will listen to.
			frefclk[lanes-1:0]             <= w_fref_clk;                
			offcaldone[lanes-1:0]          <= w_off_cal_done;
			rxfreqtxcmuplllock[lanes-1:0]  <= w_rx_freq_tx_cmu_pll_lock;
			//txlcplllock[lanes-1:0]         <= w_tx_lc_pll_lock;           
			//masktxplllock[lanes-1:0]       <= w_mask_tx_pll_lock;         
			rxpllphaselock[lanes-1:0]       <= w_rx_pll_phase_lock; 
        end //always
    end //if (lanes == total_lanes)  
    //for x8 with HIP 
    else
    begin
        always @ (*)
        begin
			//Interleave channel 4 (dummy master only channel for x8) with 0 for data 
			r_pipe_txdata              <= {pipe_txdata[8*deser_factor-1:4*deser_factor],{deser_factor{1'b0}},pipe_txdata[4*deser_factor-1:0]};
			r_pipe_txdatak             <= {pipe_txdatak[(8*deser_factor)/8-1:(4*deser_factor)/8],{(deser_factor/8){1'b0}},pipe_txdatak[(4*deser_factor)/8-1:0]};
			r_pipe_txcompliance        <= {pipe_txcompliance[7:4],1'b0,pipe_txcompliance[3:0]};
			r_pipe_txelecidle          <= {pipe_txelecidle[7:4],  1'b0,pipe_txelecidle[3:0]};

			//Interleave channel 4 (dummy master only channel for x8) with tie-off to 0
			r_pipe_rxpolarity          <= {pipe_rxpolarity[7:4],         1'b0,      pipe_rxpolarity[3:0]};
			r_pipe_txdetectrx_loopback <= {pipe_txdetectrx_loopback[7:4],1'b0,      pipe_txdetectrx_loopback[3:0]};
			r_pipe_txswing             <= {pipe_txswing[7:4],            1'b0,      pipe_txswing[3:0]};
			r_pipe_txmargin            <= {pipe_txmargin[8*3-1:4*3],     3'b0,      pipe_txmargin[4*3-1:0]};
			r_pipe_txdeemph            <= {pipe_txdeemph[7:4],           1'b0,      pipe_txdeemph[3:0]};
			r_pipe_rate                <= {pipe_rate[7:4],               rate_ctrl, pipe_rate[3:0]};  
			r_pipe_powerdown           <= {pipe_powerdown[8*2-1:4*2],    2'b0,      pipe_powerdown[4*2-1:0]};
			r_rx_eidleinfersel         <= {rx_eidleinfersel[8*3-1:4*3],  3'b0,      rx_eidleinfersel[4*3-1:0]};
			r_rx_set_locktoref         <= {rx_set_locktoref[7:4],        1'b0,      rx_set_locktoref[3:0]};         
			r_tx_invpolarity           <= {tx_invpolarity[7:4],          1'b0,      tx_invpolarity[3:0]};

			// Hard reset controller signals (HIP -> PCS PLD IF)
			// HIP always connects lanes+1 wide signals to HRC. Data channels (lanes) + CMU channel (+1).
			// For x8, PHY IP stamps out a complete data channel including If blocks, PCS, and Tx PMA for the CMU channel as the CMU channel (4) also
			// contains the master CGB and ASN block from Gen1/2 PIPE. Therefore, connect from all the indices. 
			// HIP controls from which channels the HRC will enable.
			r_off_cal_en               <= offcalen; 
			r_tx_pma_syncp             <= txpmasyncp; 
			r_tx_pcs_rst_n             <= txpcsrstn;
			r_rx_pcs_rst_n             <= rxpcsrstn; 
			r_rx_pma_rstb              <= rxpmarstb; //rxpmarstb[4] is connected to the Tx PLL also. 
			//r_tx_lc_pll_rstb           <= txlcpllrstb; //TODO for Gen3

			//Interleave channel 4 (dummy master only channel for x8) and assign to outputs
			pipe_phystatus              <= {w_pipe_phystatus[8:5],                                      w_pipe_phystatus[3:0]};
			pipe_rxdata                 <= {w_pipe_rxdata[9*deser_factor-1:5*deser_factor],             w_pipe_rxdata[4*deser_factor-1:0]};
			pipe_rxdatak                <= {w_pipe_rxdatak[(9*deser_factor)/8-1:(5*deser_factor)/8],    w_pipe_rxdatak[(4*deser_factor)/8-1:0]};
			pipe_rxvalid                <= {w_pipe_rxvalid[8:5],                                        w_pipe_rxvalid[3:0]};
			pipe_rxelecidle             <= {w_pipe_rxelecidle[8:5],                                     w_pipe_rxelecidle[3:0]};
			pipe_rxstatus               <= {w_pipe_rxstatus[9*3-1:5*3],                                 w_pipe_rxstatus[4*3-1:0]};
			rx_errdetect                <= {w_rx_errdetect[(9*deser_factor)/8-1:(5*deser_factor)/8],    w_rx_errdetect[(4*deser_factor)/8-1:0]}; 
			rx_disperr                  <= {w_rx_disperr[(9*deser_factor)/8-1:(5*deser_factor)/8],      w_rx_disperr[(4*deser_factor)/8-1:0]};
			rx_patterndetect            <= {w_rx_patterndetect[(9*deser_factor)/8-1:(5*deser_factor)/8],w_rx_patterndetect[(4*deser_factor)/8-1:0]}; 
			rx_syncstatus               <= {w_rx_syncstatus[(9*deser_factor)/8-1:(5*deser_factor)/8],   w_rx_syncstatus[(4*deser_factor)/8-1:0]}; 
			rx_phase_comp_fifo_error    <= {w_rx_phase_comp_fifo_error[8:5],                            w_rx_phase_comp_fifo_error[3:0]};
			tx_phase_comp_fifo_error    <= {w_tx_phase_comp_fifo_error[8:5],                            w_tx_phase_comp_fifo_error[3:0]};
			rx_signaldetect             <= {w_rx_signaldetect[8:5],                                     w_rx_signaldetect[3:0]};
			rx_rlv                      <= {w_rx_rlv[8:5],                                              w_rx_rlv[3:0]};
			rx_bitslipboundaryselectout <= {w_rx_bitslipboundaryselectout[9*5-1:5*5],                   w_rx_bitslipboundaryselectout[4*5-1:0]};
			// Hard reset controller signals (PCS PLD IF -> HIP)
			// HIP always expects lanes+1 wide signals to HRC. Data channels (lanes) + CMU channel (+1).
			// For x8, PHY IP stamps out a complete data channel including If blocks, PCS, and Tx PMA for the CMU channel as the CMU channel (4) also
			// contains the master CGB and ASN block from Gen1/2 PIPE. Therefore, connect to all the indices of the outputs except rxfreqtxcmuplllock.
			// For channel 4 (CMU), rxfreqtxcmuplllock comes from the pll lock from the Tx CMU PLL. HIP controls from which channels the HRC
			// will listen to.
			frefclk                 <= w_fref_clk;
			offcaldone              <= w_off_cal_done;
			rxfreqtxcmuplllock[8:5] <= w_rx_freq_tx_cmu_pll_lock[8:5];
			rxfreqtxcmuplllock[3:0] <= w_rx_freq_tx_cmu_pll_lock[3:0];
			//txlcplllock               <= TODO for Gen3
			//masktxplllock             <= TODO for Gen3
			rxpllphaselock          <= w_rx_pll_phase_lock;
        end //always
    end //else
	endgenerate

   // loop through total_lanes and assign to emsip signals to pcs from pipe/other inputs and 
   // assign to pipe/other outputs from emsip signals from pcs.
   // In case of x8 design, total_lanes=9 and the interleaving of ch4 is takes care of in the above always block
	genvar num_ch;
	
	generate for (num_ch=0; num_ch < total_lanes; num_ch = num_ch + 1) 
	begin:channel
        
	     
		//****************************************************************************************************
		// emsip_tx_in[103:0] <-> PLD signals mapping for data 
		//
		// 63:0	= pcs_tx_data 	(pipe_txdata, pipe_txdatak, pipe_txcompliance, pipe_txelecidle)
		//****************************************************************************************************

			//PORT MAPPING for ARRIA-V - TX
			//CHANNEL-1
				// emsip_tx_in[7:0]   	= pipe_txdata[7:0]
					// emsip_tx_in[8] 		= r_pipe_txdatak [0]
					// emsip_tx_in[9] 		= r_pipe_txcompliance [0]
					// emsip_tx_in[10] 		= r_pipe_txelecidle [0]

			
			//CHANNEL-2
				// emsip_tx_in[111:104]   	= pipe_txdata[15:8]
					// emsip_tx_in[112] 		= r_pipe_txdatak [1]
					// emsip_tx_in[113] 		= r_pipe_txcompliance [1]
					// emsip_tx_in[114] 		= r_pipe_txelecidle [1]
			
			//CHANNEL-3
				// emsip_tx_in[215:208]		= pipe_txdata[23:16]
					// emsip_tx_in[216] 		= r_pipe_txdatak [2]
					// emsip_tx_in[217] 		= r_pipe_txcompliance [2]
					// emsip_tx_in[218] 		= r_pipe_txelecidle [2]
				
			//and so on...
				
			assign out_pcspldif_emsip_tx_in[104*num_ch +: word_size] = r_pipe_txdata[8*num_ch +: word_size];
				
			assign out_pcspldif_emsip_tx_in[104*num_ch+8]  = r_pipe_txdatak[num_ch];
		
			// In PIPE, only negative running disparity enforcement is provided 
			assign out_pcspldif_emsip_tx_in[104*num_ch+9]  = r_pipe_txcompliance[num_ch]; 
                
		    assign out_pcspldif_emsip_tx_in[104*num_ch+10] = r_pipe_txelecidle[num_ch];

		//******************************************************************************************************************
		// PLD <-> emsip_rx_out[128:0] mapping for data
		//
		// 63:0	= pcs_rx_data  (pipe_rxdata, pipe_rxdatak, rx_errdetect, rx_syncstatus, rx_disperr, rx_patterndetect)
		//******************************************************************************************************************	  
	  
		/*	PORT MAPPING for ARRIA-V - TX
			CHANNEL-1
				w_pipe_rxdata[7:0]		= in_pcspldif_emsip_rx_out[7:0]
					w_pipe_rxdatak[0]		= in_pcspldif_emsip_rx_out[8]
					w_rx_errdetect[0]		= in_pcspldif_emsip_rx_out[9]
					w_rx_syncstatus[0]		= in_pcspldif_emsip_rx_out[10]
					w_rx_disperr[0]			= in_pcspldif_emsip_rx_out[11]
					w_rx_patterndetect[0]	= in_pcspldif_emsip_rx_out[12]
			
			CHANNEL-2
				w_pipe_rxdata[15:8]		= in_pcspldif_emsip_rx_out[136:129]
					w_pipe_rxdatak[1]		= in_pcspldif_emsip_rx_out[137]
					w_rx_errdetect[1]		= in_pcspldif_emsip_rx_out[138]
					w_rx_syncstatus[1]		= in_pcspldif_emsip_rx_out[139]
					w_rx_disperr[1]			= in_pcspldif_emsip_rx_out[140]
					w_rx_patterndetect[1]	= in_pcspldif_emsip_rx_out[141]
			
			and so on...
		*/
	  
	  
	  
	  
		// rxdata[31:24][23:16][15:8][7:0]   = emsip_rx_out[55:48][39:32][23:16][7:0]
		assign w_pipe_rxdata[8*num_ch +: word_size] = in_pcspldif_emsip_rx_out[129*num_ch +: word_size];

		// rxdatak[3][2][1][0] = emsip_rx_out[56][40][24][8]
		assign w_pipe_rxdatak[num_ch]              = in_pcspldif_emsip_rx_out[129*num_ch+8];

		// 8B/10B code violation is offset 9 within a bundle when 8B/10B enabled
		assign w_rx_errdetect[num_ch]              = in_pcspldif_emsip_rx_out[129*num_ch+9];

		// word aligner/sync status is offset 10 within a bundle
		// When sync state machine is enabled, asserted on the first data byte after KNUMBER of comma patterns
		assign w_rx_syncstatus[num_ch]             = in_pcspldif_emsip_rx_out[129*num_ch+10];

		// disparity error is offset 11 within a bundle
		assign w_rx_disperr[num_ch]                = in_pcspldif_emsip_rx_out[129*num_ch+11];

		// pattern detect is offset 12 within a bundle
		assign w_rx_patterndetect[num_ch]          = in_pcspldif_emsip_rx_out[129*num_ch+12];
	  
		// The following assignments are not dependent on num_word --> assign only once
         
	    //**********************************************************************************************
	    // emsip_tx_in[63:0] <-> PLD signals mapping for data signals (unused bits)
	    // 63:44	= undefined/unused
	    
            // emsip_tx_in[103:64] <-> PLD signals mapping for non data signals
	    //
	    // 103 	= pcs_8g_rddisable_tx    (unused?) 				//TODO
	    // 102	= pcs_8g_polinv_tx       (tx_invpolarity MM input)
	    // 101:97	= pcs_8g_tx_boundary_sel (unused)
	    // 96:86	= 10G signals            (unused)
	    // 85	= pcs8g_wrenable_tx      (unused?) 			//TODO
	    // 84:81	= pcs_8g_tx_data_valid   (pipe_tx_data_valid - Gen3 PIPE input)	//TODO
	    // 80:77	= pcs_8g_tx_blk_start    (pipe_tx_blk_start - Gen3 PIPE input)	//TODO
	    // 76:75	= pcs_8g_tx_sync_hdr     (pipe_tx_sync_hdr - Gen3 PIPE input) 	//TODO
	    // 74	= pcs_8g_rev_loopbk      (unused for PIPE) 
	    // 73:64	= 10G signals 		 (unused)
	    //************************************************************************************************

  	    assign out_pcspldif_emsip_tx_in [104*num_ch+63:104*num_ch+44]  = 0;       //undefined/unused
  	    assign out_pcspldif_emsip_tx_in [104*num_ch+73:104*num_ch+64]  = 0;       //10G signals (unused)
	    assign out_pcspldif_emsip_tx_in [104*num_ch+74]  	           = 1'b0;    //unused for PIPE
		assign out_pcspldif_emsip_tx_in [104*num_ch+75 +: 2]           = 2'b00;   
		assign out_pcspldif_emsip_tx_in [104*num_ch+77 +: 4]           = 4'b0000; 
		assign out_pcspldif_emsip_tx_in [104*num_ch+81 +: 4]           = 4'b0000; 
	    assign out_pcspldif_emsip_tx_in [104*num_ch+85]  	           = 1'b0;    //unused signals 
	    assign out_pcspldif_emsip_tx_in [104*num_ch+96:104*num_ch+86]  = 0;       //unused signals	
	    assign out_pcspldif_emsip_tx_in [104*num_ch+101:104*num_ch+97] = 0;       //unused signals	
	    assign out_pcspldif_emsip_tx_in [104*num_ch+102]  	           = r_tx_invpolarity[num_ch];	 //MM input 
	    assign out_pcspldif_emsip_tx_in [104*num_ch+103]  	           = 1'b0;    //unused signal
			
	    //**********************************************************************************************
	    // emsip_tx_special_in[12:0] <-> PLD signals mapping
	    //
	    // 12:6 = not defined in tx_pcs_pld interface block
	    // 5    = in_pld_tx_pma_syncp_fbkp_out () //From HIP hard reset controller tx_pma_syncp
	    // 4    = in_pld_lc_cmu_rstb_out	   () //From HIP hard reset controller tx_lc_pll_rstb
	    // 3    = in_pld_gen3_tx_rstn	   (g3txpcsrstn) 	
	    // 2    = pcs_8g_phfifourst_tx_n	   (unused?)
	    // 1    = pcs_8g_txurstpcs_n	   (txpcsrstn) // From HIP hard reset controller
	    // 0    = pcs_10g_txurstpcs_n	   (unused)
	    //**********************************************************************************************
	    assign out_pcspldif_emsip_tx_special_in [13*num_ch+12:13*num_ch+6]   = 0;   	 //unused 
	    assign out_pcspldif_emsip_tx_special_in [13*num_ch+5] 	         = r_tx_pma_syncp[num_ch];   	 	  
	    //assign out_pcspldif_emsip_tx_special_in [13*num_ch+4] 		 = r_tx_lc_pll_rstb; //TODO for Gen3    	 	  
	    assign out_pcspldif_emsip_tx_special_in [13*num_ch+3] 		 	 = 0; 		//was r_g3_tx_pcs_rst_n[num_ch] for Stratix V
	    assign out_pcspldif_emsip_tx_special_in [13*num_ch+2] 		     = 1'b1;   	 
	    assign out_pcspldif_emsip_tx_special_in [13*num_ch+1] 		     = r_tx_pcs_rst_n[num_ch]; //Active-low reset from HIP HRC. 
	    assign out_pcspldif_emsip_tx_special_in [13*num_ch+0] 		     = 1'b1;   	 //unused 
	  
	    //**********************************************************************************************
	    // emsip_tx_clk_in[2:0] <-> PLD signals mapping
	    //
	    // 2    = assigned to out_pld_tx_iq_clk_out	 (which input?) //TODO
	    // 1    = pcs_8g_pld_tx_clk		         (not used by PCS to close PC FIFO timing). 
	    // 0    = pcs_10g_tx_pld_clk 		 (unused)
	    //**********************************************************************************************	
	    assign out_pcspldif_emsip_tx_clk_in [3*num_ch+2]	 = 1'b0;  //TODO - iq clk? which input?
	    // In HIP mode, PCS closes timing by using the PC FIFO synchronous to tx_clk_out for both its 
	    // write and read domains. emsip_tx_clk_out[1] goes out to HIP as pipe_pclk*. It is not looped back.
	    assign out_pcspldif_emsip_tx_clk_in [3*num_ch+1]	 = 1'b0;  	
	    assign out_pcspldif_emsip_tx_clk_in [3*num_ch+0]	 = 1'b0;  //unused 
		  
	    //**********************************************************************************************
	    // emsip_rx_in[19:0] <-> PLD signals mapping
	    // All the below signals are unused by PCIe PHY IP
	    // 19 = undefined?
	    // 18 = pcs_8g_wrdisable_rx 
	    // 17 = pcs_8g_bytordpld 
	    // 16 = pcs_8g_byte_rev_en		
	    // 15 = pcs_8g_bitloc_rev_en		
	    // 14 = pcs_8g_polinv_rx		
	    // 13 = pcs_8g_wrenable_rmf		
	    // 12 = pcs_8g_rdenable_rmf		
	    // 11 = pcs_8g_a1a2_size		
	    // 10 = pcs_8g_encdt	
	    //  9 = pcs_8g_bitslip		
	    //8:4  = 10g		
	    //  3 = pcs_8g_rdenable_rx		
	    //2:0 = 10g	
	    //********************************************************************************************** 
	    assign out_pcspldif_emsip_rx_in [20*num_ch + 19 : 20*num_ch]	 = 20'b0;  
	    
	    //**********************************************************************************************
	    // emsip_rx_special_in[12:0] <-> PLD signals mapping
	  
	    // 12:7 = undefined?
	    //    6 = in_pld_rxpma_rstb_in	(rxpmarstb) //From HIP hard reset controller 
	    //    5 = pld_rx_clk_slip_in	(0)
	    //    4 = in_pld_gen3_rx_rstn	(?) //TODO for Gen3
	    //    3 = pcs_8g_phfifourst_rx_n	(1)
	    //    2 = pcs_8g_cmpfifousrt_n	(1) 
	    //    1 = pcs_8g_rxurstpcs_n 	(rxpcsrst) //From HIP hard reset controller
	    //    0 = pcs_10g_rx_rst_n		(1)
	    //**********************************************************************************************
	    assign out_pcspldif_emsip_rx_special_in [13*num_ch+12:13*num_ch+7]  = 0;    
	    assign out_pcspldif_emsip_rx_special_in [13*num_ch+6]               = r_rx_pma_rstb[num_ch];    
	    assign out_pcspldif_emsip_rx_special_in [13*num_ch+5]  	        = 1'b0;    
	    assign out_pcspldif_emsip_rx_special_in [13*num_ch+4]  	        = 0; //was r_g3_rx_pcs_rst_n[num_ch] for Stratix V
	    assign out_pcspldif_emsip_rx_special_in [13*num_ch+3]  	        = 1'b1;    
	    assign out_pcspldif_emsip_rx_special_in [13*num_ch+2]  	        = 1'b1;    
	    assign out_pcspldif_emsip_rx_special_in [13*num_ch+1]  	        = r_rx_pcs_rst_n[num_ch]; //Active-low reset from HIP HRC.    
	    assign out_pcspldif_emsip_rx_special_in [13*num_ch+0]  	        = 1'b1;    
	  
	    //**********************************************************************************************
	    // emsip_rx_clk_in[2:0] <-> PLD signals mapping
	    //
	    // 2    = assigned to out_pld_rx_iq_clk_out	 (which input?) //TODO
	    // 1    = pcs_8g_pld_rx_clk   (not used by PCS to close PC FIFO timing).  
	    // 0    = pcs_10g_rx_pld_clk  (unused)
	    //**********************************************************************************************	
	    assign out_pcspldif_emsip_rx_clk_in [3*num_ch+2]	 = 1'b0;  			 
	    // In HIP mode, PCS closes timing by using the PC FIFO synchronous to tx_clk_out for both its 
	    // write and read domains. emsip_tx_clk_out[1] goes out to HIP as pipe_pclk*. It is not looped back.
	    assign out_pcspldif_emsip_rx_clk_in [3*num_ch+1]	 = 1'b0; 
	    assign out_pcspldif_emsip_rx_clk_in [3*num_ch+0]	 = 1'b0;  			//10G. Unused.
	  
	    //**********************************************************************************************
	    // emsip_com_in[37:0] <-> PLD signals mapping
	    // 
	    // 37:35 = in_pld_gen3_current_rxpreset	(TODO for Gen3)  
	    // 34:17 = in_pld_gen3_current_coeff	(TODO for Gen3)  
	    //    16 = pipe_rxpolarity
	    // 15:13 = rx_eidleinfersel
            //    12 = unused as pipe_rate is now 1-bit wide
	    //    11 = pipe_rate //1-bit wide
	    //    10 = tie-off 
	    //     9 = unused 
	    //     8 = rx_set_locktoref 
	    //   7:6 = pipe_powerdown
	    //     5 = pipe_txswing
	    //   4:2 = pipe_txmargin
	    //     1 = pipe_txdeemph
	    //     0 = pipe_txdetectrxloopback
	    //**********************************************************************************************
	    assign out_pcspldif_emsip_com_in [38*num_ch+37:38*num_ch+35] = 3'b0;	//TODO for Gen3
	    assign out_pcspldif_emsip_com_in [38*num_ch+34:38*num_ch+17] = 18'b0;	//TODO for Gen3
	    assign out_pcspldif_emsip_com_in [38*num_ch+16] 		 = r_pipe_rxpolarity[num_ch];
	    assign out_pcspldif_emsip_com_in [38*num_ch+15:38*num_ch+13] = r_rx_eidleinfersel[3*num_ch +: 3];
	    assign out_pcspldif_emsip_com_in [38*num_ch+12]              = 1'b0;
	    assign out_pcspldif_emsip_com_in [38*num_ch+11]              = r_pipe_rate[num_ch];
	    assign out_pcspldif_emsip_com_in [38*num_ch+10] 		 = 1'b0; //tie-off
	    assign out_pcspldif_emsip_com_in [38*num_ch+9] 		 = 1'b0; //unused
	    assign out_pcspldif_emsip_com_in [38*num_ch+8] 		 = r_rx_set_locktoref[num_ch];
	    assign out_pcspldif_emsip_com_in [38*num_ch+7:38*num_ch+6]   = r_pipe_powerdown[2*num_ch +: 2];
	    assign out_pcspldif_emsip_com_in [38*num_ch+5] 		 = r_pipe_txswing[num_ch];
	    assign out_pcspldif_emsip_com_in [38*num_ch+4:38*num_ch+2]   = r_pipe_txmargin[3*num_ch +: 3];
	    assign out_pcspldif_emsip_com_in [38*num_ch+1] 		 = r_pipe_txdeemph[num_ch];
	    assign out_pcspldif_emsip_com_in [38*num_ch+0] 		 = r_pipe_txdetectrx_loopback[num_ch];
	
	    //**********************************************************************************************
	    // emsip_com_special_in[19:0] <-> PLD signals mapping
	    // 
	    // 19:13 = undefined
	    // 12:1  = reserved
	    //    0  = pld_off_cal_en_out //To HIP hard reset controller  
	    //**********************************************************************************************
	    assign out_pcspldif_emsip_com_special_in [20*num_ch+19:20*num_ch+1] = 19'b0;	
	    assign out_pcspldif_emsip_com_special_in [20*num_ch+0]              = r_off_cal_en[num_ch];


	    //**********************************************************************************************
	    // PLD <-> emsip_tx_out[11:0] mapping
	    //
	    // 11:6  	= 10G signals
	    // 5	= out_pld_8g_full_tx
	    // 4	= out_pld_8g_empty_tx
	    // 3:1	= 10G signals    
	    // 0        = assigned to 0 in PCSPLD interface
	    //************************************************************************************************
	    //Assert Tx Phase Comp FIFO error if the FIFO is either empty or full
	    assign w_tx_phase_comp_fifo_error[num_ch] = in_pcspldif_emsip_tx_out[12*num_ch+5] | in_pcspldif_emsip_tx_out[12*num_ch+4];
       
	    //**********************************************************************************************
	    // PLD <-> emsip_tx_special_out[15:0] mapping
	    //
	    // 15:5  	= assigned to 0 in PCSPLD interface 
	    // 4	= pma_rx_freq_tx_cmu_pll_lock //To HIP hard reset controller
	    // 3	= pma_tx_lc_pll_lock          //To HIP hard reset controller
	    // 2:0      = assigned to 0 in PCSPLD interface
	    //************************************************************************************************
	    //assign w_tx_lc_pll_lock[num_ch]           = in_pcspldif_emsip_tx_special_out[16*num_ch+3]; //TODO for Gen3
	    assign w_rx_freq_tx_cmu_pll_lock[num_ch]  = in_pcspldif_emsip_tx_special_out[16*num_ch+4];

            //**********************************************************************************************
	    // PLD <-> emsip_rx_out[128:0] mapping for non-data signals
	    //
	    // 128  	= pcs_8g_align_status		(unused?) //TODO
	    // 127:123	= pcs_8g_wa_boundary 		(rx_bitslipboundaryselectout)
	    // 122:119	= pcs_8g_a1a2_k1k2_flag 	(unused)
	    // 118      = pcs_8g_empty_rmf		(unused)
	    // 117      = pcs_8g_full_rmf		(unused)
	    // 116      = pcs_8g_rlv_lt			(rx_rlv)
	    // 115 	= pcs_8g_signal_detect_out	(rx_signaldetect)
	    // 114	= pcs_8g_bistdone		(unused)
	    // 113	= pcs_8g_bisterr		(unused)
	    // 112:95	= 10G				(unused)
	    // 94       = pcs_8g_empty_rx		(derive rx_phase_comp_fifo_error)
	    // 93       = pcs_8g_full_rx		(derive rx_phase_comp_fifo_error)
	    // 92:89    = pcs_8g_rx_data_valid 		//TODO for Gen3
	    // 88:85    = pcs_8g_rx_blk_start 		//TODO for Gen3
	    // 84:83    = pcs_8g_rx_sync_hdr 		//TODO for Gen3
	    // 82 	= pcs_8g_byteord_flag		(unused)
	    // 81:64	= 10G				(unused)
	    //************************************************************************************************
	    assign w_rx_bitslipboundaryselectout[num_ch*5 +: 5] = in_pcspldif_emsip_rx_out[129*num_ch+123 +: 5];
	    assign w_rx_rlv[num_ch]                             = in_pcspldif_emsip_rx_out[129*num_ch+116];
	    assign w_rx_signaldetect[num_ch]                    = in_pcspldif_emsip_rx_out[129*num_ch+115];

	    //Assert Rx Phase Comp FIFO error if the FIFO is either empty or full
	    assign w_rx_phase_comp_fifo_error[num_ch]           = in_pcspldif_emsip_rx_out[129*num_ch+94] | in_pcspldif_emsip_rx_out[129*num_ch+93];

	    //**********************************************************************************************
	    // PLD <-> emsip_rx_special_out[15:0] mapping for non-data signals
	    //
	    // 15:4  	= 0
	    // 3	= pma_rx_pll_phase_lock (rx_is_lockedtodata)
	    // 2:0	= 0
	    //**********************************************************************************************
	    assign w_rx_pll_phase_lock[num_ch] = in_pcspldif_emsip_rx_special_out[16*num_ch+3];

	    //**********************************************************************************************
	    // PLD <-> emsip_com_out[26:0] mapping 
	    //
	    // 26  	= pcs_gen3_mask_tx_pll //To mask_tx_pll_lock to HIP hard reset controller
	    // 25:24  	= pcs_gen3_rx_eq_ctrl  //TODO for Gen3
	    // 23:6  	= pcs_gen3_rxdeemph    //TODO for Gen3
	    // 5	= pcs_8g_rxelecidle (pipe_rxelecidle)
	    // 4	= pcs_8g_phystatus  (pipe_phystatus)
	    // 3:1	= pcs_8g_rxstatus   (pipe_rxstatus)
	    // 0        = pcs_8g_rxvalid    (pipe_rxvalid)
	    //**********************************************************************************************
	    //assign w_mask_tx_pll_lock[num_ch]     = in_pcspldif_emsip_com_out[27*num_ch+26]; //TODO for Gen3
	    assign w_pipe_rxelecidle[num_ch]      = in_pcspldif_emsip_com_out[27*num_ch+5];
	    assign w_pipe_phystatus[num_ch]       = in_pcspldif_emsip_com_out[27*num_ch+4];
	    assign w_pipe_rxstatus[num_ch*3 +: 3] = in_pcspldif_emsip_com_out[27*num_ch+1 +: 3];
	    assign w_pipe_rxvalid[num_ch]         = in_pcspldif_emsip_com_out[27*num_ch];

	    //**********************************************************************************************
	    // PLD <-> emsip_com_special_out[19:0] mapping 
	    // 
	    // 19:16	= 0
	    // 15:12	= pcs_gen3_extra_out
	    // 11	= 0
	    // 10:8	= pcs_8g_pld_extraout
	    // 7:4	= pcs_10g_extra_out
	    // 3	= pld_off_cal_done //To HIP hard reset controller
	    // 2:0	= 0
	    //**********************************************************************************************
	    assign w_off_cal_done[num_ch]      = in_pcspldif_emsip_com_special_out[20*num_ch+3];
	    
            
            //**********************************************************************************************
	    // PLD <-> emsip_com_clk_out[2:0] mapping
	    //
	    // 2 = pld_hclk_in    
	    // 1 = pma_clklow
	    // 0 = pma_fref to HIP hard reset controller
	    //************************************************************************************************ 
	    assign w_fref_clk[num_ch]         = in_pcspldif_emsip_com_clk_out[3*num_ch];

         

		//**********************************************************************************************
		// PLD <-> emsip_tx_clk_out[2:0] mapping
		//
		// 2 = pma_clkdiv33_lc    //TODO
		// 1 = pcs_8g_tx_clk_out - need to be connected to pipe_pclk
		// 0 = pcs_10g_tx_clk_out
		//************************************************************************************************

		if (lanes == 8) 
		begin // for x8 case
			assign pipe_pclk          = 1'b0;
			assign pipe_pclkch1       = 1'b0;
			assign pipe_pclkcentral   = in_pcspldif_emsip_tx_clk_out[13];  // channel 4, bit 1 (pcs_8g_tx_clk_out fanned out)
			assign pllfixedclkch0     = 1'b0;
			assign pllfixedclkch1     = 1'b0;
			assign pllfixedclkcentral = in_pcspldif_emsip_com_clk_out[14]; // channel 4, bit 2 (pld_hclk_in)
		end else if (lanes > 1) 
		begin // for x2 and x4 case
			assign pipe_pclk          = 1'b0;
			assign pipe_pclkch1       = in_pcspldif_emsip_tx_clk_out[4];   // channel 1, bit 1 (pcs_8g_tx_clk_out fanned out)
			assign pipe_pclkcentral   = 1'b0;
			assign pllfixedclkch0     = 1'b0;
			assign pllfixedclkch1     = in_pcspldif_emsip_com_clk_out[5];  // channel 1, bit 2 (pld_hclk_in)
			assign pllfixedclkcentral = 1'b0;
		end else
		begin
			assign pipe_pclk          = in_pcspldif_emsip_tx_clk_out[1];   // channel 0, bit 1 (pcs_8g_tx_clk_out fanned out)
			assign pipe_pclkch1       = 1'b0;
			assign pipe_pclkcentral   = 1'b0;
			assign pllfixedclkch0     = in_pcspldif_emsip_com_clk_out[2];  // channel 0, bit 2 (pld_hclk_in)
			assign pllfixedclkch1     = 1'b0;
			assign pllfixedclkcentral = 1'b0;
		end

		//**********************************************************************************************
		// PLD <-> emsip_rx_clk_out[2:0] mapping
		//
		// 2 = pma_clkdiv33_txorrx    //TODO
		// 1 = pcs_8g_rx_clk_out - not connected
		// 0 = pcs_10g_rx_clk_out
		//************************************************************************************************ 
		
    end
    endgenerate 

endmodule
