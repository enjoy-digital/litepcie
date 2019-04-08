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


//************************************************************************************************************************
//
// Wiring adapter for native data from PLD-PCS interface, to a form suitable for encoded or unencoded data
// 
//
//************************************************************************************************************************

module av_xcvr_data_adapter #(
     parameter lanes           = 1,         //Number of lanes chosen by user. legal value: 1+
	 parameter channel_interface = 0,         //legal value: (0,1) 1-Enable channel reconfiguration
     parameter ser_base_factor   = 8,         // (8,10)
     parameter ser_words         = 1,         // (1,2,4)
     parameter skip_word         = 1          // (1,2)
) ( 

     input   wire    [(channel_interface? 44: ser_base_factor*ser_words)*lanes-1:0]   tx_parallel_data,
     input   wire    [ser_words*lanes                 -1:0]   tx_datak,
     input   tri0    [ser_words*lanes                 -1:0]   tx_forcedisp,
     input   wire    [ser_words*lanes                 -1:0]   tx_dispval,

     output  tri0    [44*lanes                        -1:0]   tx_datain_from_pld,
     input   tri0    [64*lanes                        -1:0]   rx_dataout_to_pld,

     output  wire    [(channel_interface? 64: ser_base_factor*ser_words)*lanes-1:0]   rx_parallel_data,
     output  wire    [ser_words*lanes                 -1:0]   rx_datak,
     output  wire    [ser_words*lanes                 -1:0]   rx_errdetect,
     output  wire    [ser_words*lanes                 -1:0]   rx_syncstatus,
     output  wire    [ser_words*lanes                 -1:0]   rx_disperr,
     output  wire    [ser_words*lanes                 -1:0]   rx_patterndetect,
     output  wire    [ser_words*lanes                 -1:0]   rx_rmfifodatainserted,
     output  wire    [ser_words*lanes                 -1:0]   rx_rmfifodatadeleted,
     output  wire    [ser_words*lanes                 -1:0]   rx_runningdisp,
     output  wire    [ser_words*lanes                 -1:0]   rx_a1a2sizeout
);

 localparam tx_data_bundle_size = 11; // TX PLD to PCS interface groups data and control in 11-bit bundles
 localparam rx_data_bundle_size = 16; // RX PCS to PLD interface groups data and status in 16-bit bundles
 
 generate begin			
    genvar num_ch;
    genvar num_word;
    for (num_ch=0; num_ch < lanes; num_ch = num_ch + 1) begin:channel
	
	  if (channel_interface == 0) begin
        for (num_word=0; num_word < ser_words; num_word=num_word+1) begin:word
          //***************************************************************
          //*********************** TX assignments ************************
          //With 8B/10B enabled, Tx datain from PLD to PCS has 8-bit data + 3 controls in 11-bit bundles
          //For 1 lane, [7:0] = data
	        //              [8] = k char
	        //              [9] = force disparity
	        //             [10] = disparity value (Tx Elec Idle for PIPE Gen1 & 2)
	 
	      assign tx_datain_from_pld[44*num_ch+num_word*tx_data_bundle_size*skip_word +: ser_base_factor] = tx_parallel_data[ser_base_factor*ser_words*num_ch+num_word*ser_base_factor +: ser_base_factor];
        
          if (ser_base_factor == 8) begin
            assign tx_datain_from_pld[44*num_ch+num_word*tx_data_bundle_size*skip_word +  8] = tx_datak        [ser_words*num_ch+num_word];
            assign tx_datain_from_pld[44*num_ch+num_word*tx_data_bundle_size*skip_word +  9] = tx_forcedisp    [ser_words*num_ch+num_word];  
            assign tx_datain_from_pld[44*num_ch+num_word*tx_data_bundle_size*skip_word + 10] = tx_dispval      [ser_words*num_ch+num_word];
          end
          
          //***************************************************************
          //*********************** RX assignments ************************
	        //With 8B/10B enabled, Rx dataout from PCS to PLD has 8-bit data + 8 controls in 16-bit bundles
	        //For 1 lane, [7:0] = data
	        //              [8] = k char
	        //              [9] = code violation
	        //             [10] = word aligner status
	        //             [11] = disparity error
	        //             [12] = pattern detect  
	        //          [14:13] = rate match FIFO status
	        //             [15] = running disparity	  
               
	      assign rx_parallel_data[ser_base_factor*ser_words*num_ch+num_word*ser_base_factor +: ser_base_factor]
                                                            = rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word +: ser_base_factor];
	      assign rx_datak        [ser_words*num_ch+num_word]  = rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word +  8]; 
	      assign rx_errdetect    [ser_words*num_ch+num_word]  = rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word +  9];
	      assign rx_syncstatus   [ser_words*num_ch+num_word]  = rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word + 10];
	      assign rx_disperr      [ser_words*num_ch+num_word]  = rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word + 11];
	      assign rx_patterndetect[ser_words*num_ch+num_word]  = rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word + 12];
          // rate-match FIFO status is encoded as 2 bits at offsets 13,14 within a bundle
          // 00: Normal data, 01: Deletion, 10: Insertion (or Underflow with 9'h1FE or 9'h1F7), 11: Overflow
          assign rx_rmfifodatainserted[ser_words*num_ch+num_word]  =    rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word + 14]
                                                                   & ~rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word + 13];
          assign rx_rmfifodatadeleted [ser_words*num_ch+num_word]  =   ~rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word + 14]
                                                                   &  rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word + 13];

	      assign rx_runningdisp   [ser_words*num_ch+num_word] = rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word + 15];
          assign rx_a1a2sizeout   [ser_words*num_ch+num_word] = rx_dataout_to_pld[64*num_ch+num_word*rx_data_bundle_size*skip_word +  8];
	    end //for word
      end
	  else begin
	    assign tx_datain_from_pld[44*num_ch +: 44] = tx_parallel_data[44*num_ch +: 44];
		assign rx_parallel_data[64*num_ch +: 64] = rx_dataout_to_pld[64*num_ch +: 64];
		
		// Drive unused outputs
		assign rx_datak               =  {(ser_words*lanes){1'b0}};
        assign rx_errdetect           =  {(ser_words*lanes){1'b0}};
        assign rx_syncstatus          =  {(ser_words*lanes){1'b0}};
        assign rx_disperr             =  {(ser_words*lanes){1'b0}};
        assign rx_patterndetect       =  {(ser_words*lanes){1'b0}};
        assign rx_rmfifodatainserted  =  {(ser_words*lanes){1'b0}};
        assign rx_rmfifodatadeleted   =  {(ser_words*lanes){1'b0}};
        assign rx_runningdisp         =  {(ser_words*lanes){1'b0}};
        assign rx_a1a2sizeout         =  {(ser_words*lanes){1'b0}};
      end
    end //for channel	
  end
 endgenerate
endmodule





     
