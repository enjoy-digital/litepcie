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
// SV-generation transceiver definitions and functions
//
// $Header$
//
// PACKAGE DECLARATION
package av_xcvr_h;

  // SV Reconfiguration address definitions

   // PMA, PCS Base address
   localparam RECONFIG_PMA_CH0_BASE = 11'h000;
   localparam RECONFIG_PCSPMAIF_CH0_BASE = 11'h064;
   localparam RECONFIG_PCS8G_CH0_BASE = 11'h096;
   localparam RECONFIG_PCSPLDIF_CH0_BASE = 11'h0FA;

   localparam RECONFIG_PMA_CH1_BASE = 11'h190;
   localparam RECONFIG_PCSPMAIF_CH1_BASE = RECONFIG_PMA_CH1_BASE + RECONFIG_PCSPMAIF_CH0_BASE;
   localparam RECONFIG_PCS8G_CH1_BASE = RECONFIG_PMA_CH1_BASE + RECONFIG_PCS8G_CH0_BASE;
   localparam RECONFIG_PCSPLDIF_CH1_BASE = RECONFIG_PMA_CH1_BASE + RECONFIG_PCSPLDIF_CH0_BASE;

   localparam RECONFIG_PMA_CH2_BASE = 11'h320;
   localparam RECONFIG_PCSPMAIF_CH2_BASE = RECONFIG_PMA_CH2_BASE + RECONFIG_PCSPMAIF_CH0_BASE;
   localparam RECONFIG_PCS8G_CH2_BASE = RECONFIG_PMA_CH2_BASE + RECONFIG_PCS8G_CH0_BASE;
   localparam RECONFIG_PCSPLDIF_CH2_BASE = RECONFIG_PMA_CH2_BASE + RECONFIG_PCSPLDIF_CH0_BASE;


   // PMA RECONFIG Address

   localparam RECONFIG_PMA_CH0_VOD = RECONFIG_PMA_CH0_BASE + 11'h004;
   localparam RECONFIG_PMA_CH0_PRETAP = RECONFIG_PMA_CH0_BASE + 11'h003;
   localparam RECONFIG_PMA_CH0_POSTTAP1 = RECONFIG_PMA_CH0_BASE + 11'h003;
   localparam RECONFIG_PMA_CH0_POSTTAP2 = RECONFIG_PMA_CH0_BASE + 11'h003;
   localparam RECONFIG_PMA_CH0_RX_EQA = RECONFIG_PMA_CH0_BASE + 11'h012;
   localparam RECONFIG_PMA_CH0_RX_EQB = RECONFIG_PMA_CH0_BASE + 11'h018;
   localparam RECONFIG_PMA_CH0_RX_EQC = RECONFIG_PMA_CH0_BASE + 11'h018;
   localparam RECONFIG_PMA_CH0_RX_EQD = RECONFIG_PMA_CH0_BASE + 11'h018;
   localparam RECONFIG_PMA_CH0_RX_EQV = RECONFIG_PMA_CH0_BASE + 11'h013;
   localparam RECONFIG_PMA_CH0_RX_EQDCGAIN = RECONFIG_PMA_CH0_BASE + 11'h013;

   localparam RECONFIG_PMA_CH0_RCRU_RLBK = RECONFIG_PMA_CH0_BASE + 11'h010;
   localparam RECONFIG_PMA_CH0_RREVLB_SW = RECONFIG_PMA_CH0_BASE + 11'h012;
   localparam RECONFIG_PMA_CH0_RRX_DLPBK = RECONFIG_PMA_CH0_BASE + 11'h013;

   localparam RECONFIG_PMA_CH0_RXBYPASSEQZ123 = RECONFIG_PMA_CH0_BASE + 11'h012; //chestan: cannot find this in S5, need to check with Gary
   localparam RECONFIG_PMA_CH0_RXSELHALFBW = RECONFIG_PMA_CH0_BASE + 11'h012;

   //DCD
   localparam RECONFIG_PMA_CH0_DCD_RSER_CLK_MON    = RECONFIG_PMA_CH0_BASE + 12'h001; // Forced data (test pattern)
   localparam RECONFIG_PMA_CH0_DCD_RTX_LST         = RECONFIG_PMA_CH0_BASE + 12'h002; // ATB 
   localparam RECONFIG_PMA_CH0_DCD_DC_TUNE         = RECONFIG_PMA_CH0_BASE + 12'h006; // DCD calibration

   // register bits offsets
   localparam RSER_CLK_MON_OFST    = 8; // Forced data (test pattern)
   localparam RTX_LST_3_OFST       = 15; // ATB to LPF mode - MSB
   localparam RTX_LST_2_OFST       = 14;
   localparam RTX_LST_1_OFST       = 13;
   localparam RTX_LST_0_OFST       = 12; // ATB to LPF mode - LSB
   localparam RSER_DC_TUNE_2_OFST  = 12; // DCD calibration -msb
   localparam RSER_DC_TUNE_1_OFST  = 11;
   localparam RSER_DC_TUNE_0_OFST  = 10; // DCD calibration -lsb
   localparam REYE_ISEL_2          = 2;  // ISEL msb
   localparam REYE_ISEL_1          = 1;  
   localparam REYE_ISEL_0          = 0;  // ISEL lsb
   localparam REYE_PDB             = 11; // power enable

   //MIF RMW offsets and masks
   localparam RECONFIG_PMA_CGB_REG_OFST             = 12'h000; // contains rcgb_clk_sel, rcgb_x_en bits
   localparam RECONFIG_PMA_CLKNET_CLKMON_REG_OFST   = 12'h001; // contains XN Line select (rcgb_clknet_in_en), DCD protected bits (rser_clk_mon)
   localparam RECONFIG_PMA_LST_REG_OFST             = 12'h002; // contains DCD protected bits (rtx_lst)
   localparam RECONFIG_PMA_BBPD_REG_OFST            = 12'h00f; // contains BBPD control (rcru_pdof_*i)
   localparam RECONFIG_PMA_TB_REG_OFST              = 12'h010; // contains Testbus control control (rcru_pdof_test)
   localparam RECONFIG_PMA_PCIEMD_RREF_REG_OFST     = 12'h012; // contains (pcie_mode_sel, rrefclk_sel) bit
   localparam RECONFIG_PMA_RXDATAO_REG_OFST         = 12'h022; // contains rx_data_out_sel //rdynamic_sw, rint_early_eios, rint_ltr, rrxp_reserved[29], rint_tx_elec_idle, rint_txdetectrx, rint_pcie_switch, rint_cvp_mode, rint_ffclk_pdb
   localparam RECONFIG_PMA_REFIQ_REG_OFST           = 12'h024; // contains pma_iq_clk_sel bits  
   localparam RECONFIG_PCS8G_POWER_TRL_REG_OFST     = RECONFIG_PCS8G_CH0_BASE + 12'h044; // contains r_pow_power_iso_ctrl bits 

   localparam RECONFIG_PMA_CGB_REG_MASK             = 16'h1e3f;
   localparam RECONFIG_PMA_CLKNET_CLKMON_REG_MASK   = 16'h0300;
   localparam RECONFIG_PMA_LST_REG_MASK             = 16'hf000;
   localparam RECONFIG_PMA_BBPD_REG_MASK            = 16'hffff;
   localparam RECONFIG_PMA_TB_REG_MASK              = 16'h0007;
   localparam RECONFIG_PMA_PCIEMD_RREF_REG_MASK     = 16'h0820;
   localparam RECONFIG_PMA_RXDATAO_REG_MASK         = 16'h01ff; // contains rx_data_out_sel
   localparam RECONFIG_PMA_REFIQ_REG_MASK           = 16'h07f8; // contains pma_iq_clk_sel bits
   localparam RECONFIG_PMA_DCD_DC_TUNE_REG_MASK     = 16'h1c00; // contains rser_dc_tune
   localparam RECONFIG_PCS8G_POWER_TRL_REG_MASK     = 16'h0004; // contains r_pow_power_iso_ctrl bits 



//****************************************************************************
//************************ Local channel registers ***************************

  // Register address offset to gain access to the soft reconfig registers.
  // This value must be added to the register addresses listed below.
  localparam AV_XR_LOCAL_OFFSET  = 12'h800;

  //****************************
  // Relative register addresses
  localparam AV_XR_ADDR_DUMMY   = 4'd0; // Dummy register for read/write testing
  localparam AV_XR_ADDR_ADCE    = 4'd1; // internal register for ADCE capture and standby
  localparam AV_XR_ADDR_OC      = 4'd2; // internal register for hard OC cal enable
  localparam AV_XR_ADDR_PRBS    = 4'd3; // internal register for PRBS control and status
  localparam AV_XR_ADDR_DCD     = 4'd4; // internal register for DCD control and status
  localparam AV_XR_ADDR_DCD_RES = 4'd5; // internal register for DCD results
  localparam AV_XR_ADDR_SLPBK   = 4'd6; // internal register for serial loopback control
  localparam AV_XR_ADDR_STATUS  = 4'd7; // internal register for channel status
  localparam AV_XR_ADDR_ID      = 4'd8; // internal register for channel ID
  localparam AV_XR_ADDR_REQUEST = 4'd9; // internal register for channel services request
  localparam AV_XR_ADDR_RSTCTL  = 4'd10; // internal register for channel reset control and override

  //****************************
  // Absolute register addresses
  localparam AV_XR_ABS_ADDR_DUMMY   = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_DUMMY;
  localparam AV_XR_ABS_ADDR_ADCE    = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_ADCE;
  localparam AV_XR_ABS_ADDR_OC      = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_OC;
  localparam AV_XR_ABS_ADDR_PRBS    = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_PRBS;
  localparam AV_XR_ABS_ADDR_DCD     = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_DCD;
  localparam AV_XR_ABS_ADDR_DCD_RES = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_DCD_RES;
  localparam AV_XR_ABS_ADDR_SLPBK   = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_SLPBK;
  localparam AV_XR_ABS_ADDR_STATUS  = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_STATUS;
  localparam AV_XR_ABS_ADDR_ID      = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_ID;
  localparam AV_XR_ABS_ADDR_REQUEST = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_REQUEST;
  localparam AV_XR_ABS_ADDR_RSTCTL  = AV_XR_LOCAL_OFFSET + AV_XR_ADDR_RSTCTL;

  //*****************************
  // Bit masks for DUMMY register
  localparam AV_XR_DUMMY_DUMMY_OFST   = 0;
  localparam AV_XR_DUMMY_DUMMY_LEN    = 1;
  localparam AV_XR_DUMMY_DUMMY_MASK   = 16'h0001;

  //****************************
  // Bit masks for ADCE register
  localparam AV_XR_ADCE_CAPTURE_OFST  = 0;
  localparam AV_XR_ADCE_STANDBY_OFST  = 1;
  localparam AV_XR_ADCE_DONE_OFST     = 2;
  localparam AV_XR_ADCE_UNUSED_OFST   = 3;

  localparam AV_XR_ADCE_CAPTURE_LEN   = 1;
  localparam AV_XR_ADCE_STANDBY_LEN   = 1;
  localparam AV_XR_ADCE_DONE_LEN      = 1;
  localparam AV_XR_ADCE_UNUSED_LEN    = 13;

  localparam AV_XR_ADCE_CAPTURE_MASK  = 16'h0001; // bitfield position of ADCE capture, within ADCE reg
  localparam AV_XR_ADCE_STANDBY_MASK  = 16'h0002; // bitfield position of ADCE standby, within ADCE reg
  localparam AV_XR_ADCE_DONE_MASK     = 16'h0004; // bitfield position of ADCE adapt done, within ADCE reg

  //************************************
  // Bit masks for HARDOC_CALEN register
  localparam AV_XR_OC_CALEN_OFST    = 0;
  localparam AV_XR_OC_CALDONE_OFST  = 1;
  localparam AV_XR_OC_UNUSED_OFST   = 2;

  localparam AV_XR_OC_CALEN_LEN     = 1;
  localparam AV_XR_OC_CALDONE_LEN   = 1;
  localparam AV_XR_OC_UNUSED_LEN    = 14;

  localparam AV_XR_OC_CALEN_MASK    = 16'h0001;
  localparam AV_XR_OC_CALDONE_MASK  = 16'h0002;

  //****************************
  // Bit masks for PRBS register
  localparam AV_XR_PRBS_CLR_OFST      = 0;
  localparam AV_XR_PRBS_8G_ERR_OFST   = 1;
  localparam AV_XR_PRBS_8G_DONE_OFST  = 2;
  localparam AV_XR_PRBS_UNUSED_OFST   = 3;

  localparam AV_XR_PRBS_CLR_LEN       = 1;
  localparam AV_XR_PRBS_8G_ERR_LEN    = 1;
  localparam AV_XR_PRBS_8G_DONE_LEN   = 1;
  localparam AV_XR_PRBS_10G_ERR_LEN   = 1;
  localparam AV_XR_PRBS_10G_DONE_LEN  = 1;
  localparam AV_XR_PRBS_UNUSED_LEN    = 13;

  localparam AV_XR_PRBS_CLR_MASK      = 16'h0001;
  localparam AV_XR_PRBS_8G_ERR_MASK   = 16'h0002;
  localparam AV_XR_PRBS_8G_DONE_MASK  = 16'h0004;
  localparam AV_XR_PRBS_10G_ERR_MASK  = 16'h0008;
  localparam AV_XR_PRBS_10G_DONE_MASK = 16'h0010;

  //***************************
  // Bit masks for DCD register
  localparam AV_XR_DCD_REQ_OFST     = 0;
  localparam AV_XR_DCD_ACK_OFST     = 1;
  localparam AV_XR_DCD_UNUSED_OFST  = 2;

  localparam AV_XR_DCD_REQ_LEN      = 1;
  localparam AV_XR_DCD_ACK_LEN      = 1;
  localparam AV_XR_DCD_UNUSED_LEN   = 14;

  localparam AV_XR_DCD_REQ_MASK  = 16'h0001;
  localparam AV_XR_DCD_ACK_MASK  = 16'h0002;

  //*******************************
  // Bit masks for DCD_RES register
  localparam AV_XR_DCD_RES_A_OFST  = 0;
  localparam AV_XR_DCD_RES_B_OFST  = 8;

  localparam AV_XR_DCD_RES_A_LEN   = 8;
  localparam AV_XR_DCD_RES_B_LEN   = 8;

  localparam AV_XR_DCD_RES_A_MASK  = 16'h00ff;
  localparam AV_XR_DCD_RES_B_MASK  = 16'hff00;

  //*****************************
  // Bit masks for SLPBK register
  localparam AV_XR_SLPBK_SLPBKEN_OFST = 0;
  localparam AV_XR_SLPBK_UNUSED_OFST  = 1;

  localparam AV_XR_SLPBK_SLPBKEN_LEN  = 1;
  localparam AV_XR_SLPBK_UNUSED_LEN   = 15;

  localparam AV_XR_SLPBK_SLPBKEN_MASK = 16'h0001;

  //******************************
  // Bit masks for STATUS register
  localparam AV_XR_STATUS_TX_DIGITAL_RESET_OFST  = 0;  // Valid only for channel interfaces
  localparam AV_XR_STATUS_RX_DIGITAL_RESET_OFST  = 1;  // Valid only for channel interfaces
  localparam AV_XR_STATUS_PLL_LOCKED_OFST        = 2;  // Valid only for PLL interfaces
  localparam AV_XR_STATUS_PLL_LOCKED_FLAG_OFST   = 3;  // Valid only for PLL interfaces
  localparam AV_XR_STATUS_UNUSED_OFST            = 4;  // Valid only for PLL interfaces

  localparam AV_XR_STATUS_TX_DIGITAL_RESET_LEN   = 1;
  localparam AV_XR_STATUS_RX_DIGITAL_RESET_LEN   = 1;
  localparam AV_XR_STATUS_PLL_LOCKED_LEN         = 1;
  localparam AV_XR_STATUS_PLL_LOCKED_FLAG_LEN    = 1;
  localparam AV_XR_STATUS_UNUSED_LEN             = 12;

  localparam AV_XR_STATUS_TX_DIGITAL_RESET_MASK  = 16'h0001;
  localparam AV_XR_STATUS_RX_DIGITAL_RESET_MASK  = 16'h0002;
  localparam AV_XR_STATUS_PLL_LOCKED_MASK        = 16'h0004;
  localparam AV_XR_STATUS_PLL_LOCKED_FLAG_MASK   = 16'h0008;

  //**************************
  // Bit masks for ID register
  localparam AV_XR_ID_TX_CHANNEL_OFST  = 0;
  localparam AV_XR_ID_RX_CHANNEL_OFST  = 1;
  localparam AV_XR_ID_PLL_TYPE_OFST    = 2;
  localparam AV_XR_ID_UNUSED_OFST      = 4;

  localparam AV_XR_ID_TX_CHANNEL_LEN   = 1;
  localparam AV_XR_ID_RX_CHANNEL_LEN   = 1;
  localparam AV_XR_ID_PLL_TYPE_LEN     = 2;
  localparam AV_XR_ID_UNUSED_LEN       = 12;

  localparam AV_XR_ID_TX_CHANNEL_MASK  = 16'h0001;
  localparam AV_XR_ID_RX_CHANNEL_MASK  = 16'h0002;
  localparam AV_XR_ID_PLL_TYPE_MASK    = 16'h000C;

  // Parameters for PLL Type field
  localparam AV_XR_ID_PLL_TYPE_NONE     = 0;
  localparam AV_XR_ID_PLL_TYPE_CMU      = 1;
  localparam AV_XR_ID_PLL_TYPE_LC       = 2;
  localparam AV_XR_ID_PLL_TYPE_FPLL     = 3;
  
  // Parameters for PMA bonding mode field
  localparam AV_XR_ID_PMA_BONDING_X1    = 0;
  localparam AV_XR_ID_PMA_BONDING_XN    = 1;
  localparam AV_XR_ID_PMA_BONDING_NONE  = 2;

  //*******************************
  // Bit masks for REQUEST register
  localparam AV_XR_REQUEST_DCD_OFST          = 0;
  localparam AV_XR_REQUEST_VRC_OFST          = 1;
  localparam AV_XR_REQUEST_OFFSET_OFST       = 2;
  localparam AV_XR_REQUEST_UNUSED_OFST       = 3;

  localparam AV_XR_REQUEST_DCD_LEN           = 1;
  localparam AV_XR_REQUEST_VRC_LEN           = 1;
  localparam AV_XR_REQUEST_UNUSED_LEN        = 13;

  localparam AV_XR_REQUEST_DCD_MASK          = 16'h0001;
  localparam AV_XR_REQUEST_VRC_MASK          = 16'h0002;
  localparam AV_XR_REQUEST_OFFSET_MASK       = 16'h0004;

//********************************
  // Bit masks for RSTCTL register
  localparam AV_XR_RSTCTL_TX_RST_OVR_OFST           = 0;
  localparam AV_XR_RSTCTL_TX_DIGITAL_RST_N_VAL_OFST = 1;
  localparam AV_XR_RSTCTL_RX_RST_OVR_OFST           = 2;
  localparam AV_XR_RSTCTL_RX_DIGITAL_RST_N_VAL_OFST = 3;
  localparam AV_XR_RSTCTL_RX_ANALOG_RST_N_VAL_OFST  = 4;
  localparam AV_XR_RSTCTL_UNUSED_OFST               = 5;

  localparam AV_XR_RSTCTL_TX_RST_OVR_LEN            = 1;
  localparam AV_XR_RSTCTL_TX_DIGITAL_RST_N_VAL_LEN  = 1;
  localparam AV_XR_RSTCTL_RX_RST_OVR_LEN            = 1;
  localparam AV_XR_RSTCTL_RX_DIGITAL_RST_N_VAL_LEN  = 1;
  localparam AV_XR_RSTCTL_RX_ANALOG_RST_N_VAL_LEN   = 1;
  localparam AV_XR_RSTCTL_UNUSED_LEN                = 11;

  localparam AV_XR_RSTCTL_TX_RST_OVR_MASK           = 16'h0001;
  localparam AV_XR_RSTCTL_TX_DIGITAL_RST_N_MASK     = 16'h0002;
  localparam AV_XR_RSTCTL_RX_RST_OVR_MASK           = 16'h0004;
  localparam AV_XR_RSTCTL_RX_DIGITAL_RST_N_MASK     = 16'h0008;
  localparam AV_XR_RSTCTL_RX_ANALOG_RST_N_MASK      = 16'h0010;

//********************** End local channel registers *************************
//****************************************************************************


endpackage

