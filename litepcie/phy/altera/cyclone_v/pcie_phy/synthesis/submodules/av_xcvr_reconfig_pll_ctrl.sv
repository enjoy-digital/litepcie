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


`timescale 1 ns / 1 ps


module av_xcvr_reconfig_pll_ctrl #(
    parameter UIF_ADDR_WIDTH  = 3,
    parameter UIF_DATA_WIDTH  = 32,
    parameter CTRL_ADDR_WIDTH = 12,
    parameter CTRL_DATA_WIDTH = 32
  ) 
(
    input  wire        clk,
    input  wire        reset,

    // user interface
    input  wire                        uif_go,       // start user cycle
    input  wire [2:0]                  uif_mode,     // operation
    output reg                         uif_busy,     // transfer in process
    input  wire [UIF_ADDR_WIDTH -1:0]  uif_addr,     // address offset
    input  wire [UIF_DATA_WIDTH -1:0]  uif_wdata,    // data in
    output reg  [UIF_DATA_WIDTH -1:0]  uif_rdata,    // data out
    input  wire                        uif_chan_err, // illegal channel
    output reg                         uif_addr_err, // illegal address
    input  wire [9:0]                  uif_logical_ch_addr, //logical channel

    //MIF interface
    input wire          pll_mif_go,
    input wire          pll_mif_type,
    input wire [3:0]    pll_mif_data,
    input wire [9:0]    pll_mif_lch,
    output wire         pll_mif_busy,
    output wire         pll_mif_err, 


    // basic block control interface
    output reg                         ctrl_go,      // start basic block cycle
    output reg  [2:0]                  ctrl_opcode,  // 0=read; 1=write;
    output reg                         ctrl_lock,    // multicycle lock 
    input  wire                        ctrl_wait,    // transfer in process
    output wire [9:0]                  ctrl_lch,
    output reg  [CTRL_ADDR_WIDTH -1:0] ctrl_addr,
    input  wire [CTRL_DATA_WIDTH -1:0] ctrl_rdata,   // data in
    output reg  [CTRL_DATA_WIDTH -1:0] ctrl_wdata    // data out
   );

  // register addresses
  import alt_xcvr_reconfig_h::*; 
  import av_xcvr_h::*;

  localparam      REFCLK_WIDTH    = 5;
  localparam      CGB_WIDTH       = 4;
  localparam      WORD_SEL_CGB    = 12'd2;
  localparam      WORD_SEL_RC     = 12'd1;

  // user modes
  localparam [2:0] UIF_MODE_RD    = 3'b000;
  localparam [2:0] UIF_MODE_WR    = 3'b001;
  localparam [2:0] UIF_MODE_PHYS  = 3'b010;

  // basic control commands
  localparam [2:0] CTRL_OP_RD     = 3'b000;
  localparam [2:0] CTRL_OP_WR     = 3'b001;
  localparam [2:0] CTRL_OP_PHYS   = 3'b010;
  localparam [2:0] CTRL_OP_INT_WR = 3'b011;
  localparam [2:0] CTRL_OP_ROM_RD = 3'b100;

  // state assignments
  localparam [2:0] PLL_IDLE       = 3'd0;
  localparam [2:0] PLL_RD_L2P     = 3'd1; // Read contents of B-Block ROM
  localparam [2:0] PLL_RD         = 3'd2; // Read DPRIO
  localparam [2:0] PLL_WR         = 3'd3; // Write DPRIO
  localparam [2:0] PLL_DECIDE     = 3'd4; // Wait for CIF and decide next state
  localparam [2:0] PLL_WAIT       = 3'd5; // wait one cycle for ctrl_wait
  localparam [2:0] PLL_CHK_WORDS  = 3'd6; // check if there are any additional RMW words to address

  // state declarations
  reg [2:0]                   pll_next_state; 
  reg [2:0]                   pll_state;
  reg [2:0]                   state_event;

  // local storage of logical to physical info
  reg [5*REFCLK_WIDTH-1:0]    phys_refclk;               
  reg [5*CGB_WIDTH-1:0]       phys_cgb;
  reg [15:0]                  saved_read_data;

  //misc registers
  reg                         pll_uif_go;
  reg                         pll_uif_type;
  reg                         uif_l2p_active;
  reg                         mif_req;
  reg [1:0]                   word_cnt;
  reg [5:0]                   rcgb_clk_sel;
  reg [0:0]                   rcgb_clknet_in_en;
  reg [1:0]                   rcgb_x_en;

  reg [CGB_WIDTH-1:0]         cgb_sel;
  reg [7:0]                   pma_iq_clk_sel; 
  reg [REFCLK_WIDTH-1:0]      rc_sel;
  reg [2:0]                   pll_uif_cgb_sel;
  reg [2:0]                   pll_uif_rc_sel;
  reg                         rrefclk_sel;
  reg                         rcru_pcie_mode;

  //internal wires for UIF based reconfiguiration
  wire [2:0]                  pll_uif_data;
  wire                        pll_uif_rd_l2p;
  wire [15:0]                 modify_cgb_data;
  wire [15:0]                 modify_cgb_data_0;
  wire [15:0]                 modify_cgb_data_1;
  wire [15:0]                 modify_refclk_data;
  wire [15:0]                 modify_refclk_data_0;
  wire [15:0]                 modify_refclk_data_1;
  wire [31:0]                 modify_data;
  wire                        mux_pll_type;
  wire [3:0]                  logical_index;
  wire [11:0]                 refclk_sel_addr;
  wire [11:0]                 cgb_sel_addr;
  wire                        pll_uif_go_d;
  wire                        pll_uif_type_d;
  wire                        uif_rc_sel_wr;
  wire                        uif_cgb_sel_wr;
  wire                        uif_l2p_rc_rd;
  wire                        uif_l2p_cgb_rd;


  //create go strobe and delay to allow register data to be current
  assign pll_uif_go_d = uif_rc_sel_wr | uif_cgb_sel_wr;

  always @(posedge clk or posedge reset)
  begin
   if (reset) begin
      pll_uif_go    <= 1'b0;
    end
    else begin
      pll_uif_go    <= pll_uif_go_d;
    end
  end

  //determine operation depending on which register was written
  always @(posedge clk or posedge reset)
  begin
   if (reset) begin
      pll_uif_type    <= 1'b0;
    end
    else begin
      if(uif_rc_sel_wr || uif_l2p_rc_rd)
        pll_uif_type    <= 1'b0;
      else if(uif_cgb_sel_wr || uif_l2p_cgb_rd)
        pll_uif_type    <= 1'b1;
    end
  end

  //offset 0 - RefClk switch need to add a check for LC or CMU
  assign uif_rc_sel_wr = uif_go & (uif_mode == UIF_MODE_WR) & (uif_addr == 3'd0);

  always @(posedge clk or posedge reset)
  begin
    if (reset) begin
      pll_uif_rc_sel <= 3'd0;
    end
    else begin
      if(uif_rc_sel_wr)
         pll_uif_rc_sel <= uif_wdata[2:0];
    end
  end
  
  //offset 1 - CGB select and switch
  assign uif_cgb_sel_wr = uif_go & (uif_mode == UIF_MODE_WR) & (uif_addr == 3'd1);

  always @(posedge clk or posedge reset)
  begin
    if (reset) begin
      pll_uif_cgb_sel <= 3'd0;
    end
    else begin
      if(uif_cgb_sel_wr) 
         pll_uif_cgb_sel <= uif_wdata[2:0];
    end
  end

  //select the logical index source
  assign pll_uif_data = pll_uif_type ? pll_uif_cgb_sel : pll_uif_rc_sel;

  assign pll_uif_rd_l2p = uif_l2p_rc_rd | uif_l2p_cgb_rd;

  assign uif_l2p_rc_rd  = uif_go & (uif_mode == UIF_MODE_RD) & (uif_addr == 3'd2);
  assign uif_l2p_cgb_rd = uif_go & (uif_mode == UIF_MODE_RD) & (uif_addr == 3'd3);

  //UIF read back
  always @(posedge clk or posedge reset)
  begin
   if (reset) begin
      uif_rdata <= {UIF_DATA_WIDTH{1'b0}};
    end
    else begin
      if(uif_mode == UIF_MODE_RD) begin
        case(uif_addr)
          3'd0: uif_rdata <= {29'd0, pll_uif_rc_sel};
          3'd1: uif_rdata <= {29'd0, pll_uif_cgb_sel};
          3'd2: uif_rdata <= {7'd0,  phys_refclk}; //Physical readback
          3'd3: uif_rdata <= {12'd0, phys_cgb} ;  //Physical readback
        default : uif_rdata <= {UIF_DATA_WIDTH{1'd0}};
        endcase
      end
    end
  end

  //set a flag that indicates User L2P read to prevent a full RMW cycle
  always @(posedge clk or posedge reset)
  begin
   if (reset) begin
      uif_l2p_active <= 1'b0;
    end
    else begin
      if(pll_next_state == PLL_IDLE && pll_state == PLL_DECIDE)
        uif_l2p_active <= 1'b0;
      else if(pll_uif_rd_l2p)
        uif_l2p_active <= 1'b1;
    end
  end

  //Physical info store register
  integer i;
  always @(posedge clk or posedge reset)
  begin
    if (reset) begin
      phys_refclk <= {REFCLK_WIDTH*5{1'b0}};    
      phys_cgb    <= {CGB_WIDTH*5{1'b0}}; 
    end
    else begin
      if(!ctrl_wait && (ctrl_opcode==CTRL_OP_ROM_RD) && mux_pll_type) begin
        // store all five Physical words
        phys_cgb      <= ctrl_rdata[(CGB_WIDTH*5-1):0];
      end
      else if(!ctrl_wait && (ctrl_opcode==CTRL_OP_ROM_RD) && !mux_pll_type) begin
        // store all five Physical words
        phys_refclk <= ctrl_rdata[(REFCLK_WIDTH*5)-1:0];   
      end
    end
  end

  //select target physical CGB id
  always @ (*) begin
    case(logical_index[2:0])
    3'd0: cgb_sel     = phys_cgb[3:0];  
    3'd1: cgb_sel     = phys_cgb[7:4];  
    3'd2: cgb_sel     = phys_cgb[11:8]; 
    3'd3: cgb_sel     = phys_cgb[15:12];  
    3'd4: cgb_sel     = phys_cgb[19:16]; 
    default: cgb_sel  = phys_cgb[3:0]; 
    endcase
  end

  //Remapping of CGB selects to rcgb_x_en[3:2], rcgb_clknet_in_en, rcgb_clk_sel[5:0] bits
  always @ (*) begin
    case(cgb_sel)
    4'd0: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b00, 1'b0, 6'b10_11_00};  //SAME_CH_TXPLL
    4'd1: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b00, 1'b0, 6'b01_00_11};  //CH1_TXPLL_T
    4'd2: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b00, 1'b0, 6'b10_00_00};  //CH1_TXPLL_B
    4'd3: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b00, 1'b0, 6'b01_00_10};  //FFPLL
    4'd4: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b00, 1'b0, 6'b01_00_00};  //UP_SEGMENTED
    4'd5: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b00, 1'b0, 6'b01_00_01};  //DOWN_SEGMENTED
    4'd6: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b10, 1'b1, 6'b10_10_00};  //HFCLK_CH1_X6_UP
    4'd7: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b01, 1'b1, 6'b10_01_00};  //HFCLK_CH1_X6_DN
    4'd8: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b00, 1'b1, 6'b10_01_00}; //HFCLK_XN_UP
    4'd9: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b00, 1'b1, 6'b10_10_00};  //HFCLK_XN_DN
    default: {rcgb_x_en, rcgb_clknet_in_en, rcgb_clk_sel} = {2'b00, 1'b0, 6'b10_11_00}; //ERROR: set to CDR local
    endcase
  end

  //select target physical RefClk id
  always @ (*) begin
    case(logical_index[2:0])
    3'd0: rc_sel     = phys_refclk[4:0];  
    3'd1: rc_sel     = phys_refclk[9:5];  
    3'd2: rc_sel     = phys_refclk[14:10]; 
    3'd3: rc_sel     = phys_refclk[19:15];  
    3'd4: rc_sel     = phys_refclk[24:20]; 
    default: rc_sel  = phys_refclk[4:0]; 
    endcase
  end

  //Remapping of RefClk selects to pma_ch_sel_iqclk[6:3] bits
  //rrefclk_sel,rcru_pcie_mode = 00b (REFCLK_IQ or CALCLK)
  //rrefclk_sel,rcru_pcie_mode = 01b (REFCLK_LC)
  //rrefclk_sel,rcru_pcie_mode = 10b (PLDCLK)
  //pma_iq_clk_sel = selects REF_IQCLK or RX_IQCLK
  always @ (*) begin
    case(rc_sel)
    5'd0:  {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_0001};  //REF_IQCLK0
    5'd1:  {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_0010};  //REF_IQCLK1
    5'd2:  {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_0011};  //REF_IQCLK2
    5'd3:  {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_0100};  //REF_IQCLK3
    5'd4:  {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_0101};  //REF_IQCLK4
    5'd5:  {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_0110};  //REF_IQCLK5
    5'd6:  {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_0111};  //REF_IQCLK6
    5'd7:  {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_1000};  //REF_IQCLK7
    5'd8:  {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_1001};  //REF_IQCLK8
    5'd9:  {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_1010};  //REF_IQCLK9
    5'd10: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_1011};  //REF_IQCLK10
    5'd11: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0001_0000};  //RX_IQCLK0
    5'd12: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0010_0000};  //RX_IQCLK1
    5'd13: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0011_0000};  //RX_IQCLK2
    5'd14: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0100_0000};  //RX_IQCLK3
    5'd15: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0101_0000};  //RX_IQCLK4
    5'd16: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0110_0000};  //RX_IQCLK5
    5'd17: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0111_0000};  //RX_IQCLK6
    5'd18: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b1000_0000};  //RX_IQCLK7
    5'd19: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b1001_0000};  //RX_IQCLK8
    5'd20: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b1010_0000};  //RX_IQCLK9
    5'd21: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b1011_0000};  //RX_IQCLK10
    5'd22: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b1,1'b0,8'b0000_0000};  //PLD_CLK
    5'd23: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_0000};  //CAL_CLK - Requires oc_cal_en
    5'd24: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_1100};  //FFPLL_TOP
    5'd25: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_0000};  //FFPLL_BOT
    default: {rrefclk_sel,rcru_pcie_mode,pma_iq_clk_sel} = {1'b0,1'b0,8'b0000_0001}; //REF_IQCLK0
    endcase
  end

  //Saved DPRIO data for RMW
  always @(posedge clk or posedge reset)
  begin
    if (reset) begin
      saved_read_data <= 16'd0;    
    end
    else begin
      if(!ctrl_wait && (ctrl_opcode==CTRL_OP_RD))
        saved_read_data <= ctrl_rdata[15:0];  
    end
  end


  ////////////////////////////////////////
  // PLL reconfiguration state machine
  // ---------------------------------- 
  // Steps to perform a CGB or Refcllk switch
  // 1) Use CTRL_OP_ROM_RD to read Log-to-phys word from Basic
  // 2) Use CTRL_OP_RD to access PHY-IP DPRIO data for Refclk/CGB
  // 3) Modify select bits with Phys data indexed by logical data select
  // 4) Use CTRL_OP_WR to write modified word bac to DPRIO space
  // 5) Continue RMW as needed
  ////////////////////////////////////////

  // state register
  always @(posedge clk or posedge reset)
  begin
   if (reset) begin
        pll_state <= PLL_IDLE;
    end
    else begin
        pll_state <= pll_next_state;
    end
  end   

  // next state logic
  always @ (*) begin
    case(pll_state)
    PLL_IDLE: begin
        if(pll_mif_go || pll_uif_go || pll_uif_rd_l2p)
            pll_next_state = PLL_RD_L2P;
        else    
            pll_next_state = PLL_IDLE;
    end
    PLL_DECIDE: begin 
      //just read ROM
      if(!ctrl_wait && uif_l2p_active)
        pll_next_state = PLL_IDLE;
      //read DPRIO data
      else if(!ctrl_wait && (state_event == 3'd1))
        pll_next_state = PLL_RD;
      //write new data
      else if(!ctrl_wait && (state_event == 3'd2))
        pll_next_state = PLL_WR;
      //check if there are more RMW words for this opertation
      else if(!ctrl_wait && (state_event == 3'd3))
        pll_next_state = PLL_CHK_WORDS;
      else
        pll_next_state = PLL_DECIDE;
    end
    PLL_WAIT:     pll_next_state = PLL_DECIDE;
    PLL_RD_L2P:   pll_next_state = PLL_WAIT;
    PLL_RD:       pll_next_state = PLL_WAIT;
    PLL_WR:       pll_next_state = PLL_WAIT;
    //Make sure this is the last RMW word needed
    PLL_CHK_WORDS: begin
      if(word_cnt == 0)
        pll_next_state = PLL_IDLE;
      else
        pll_next_state = PLL_WAIT;
    end
    default :     pll_next_state = PLL_IDLE;
    endcase
  end

  //state machine event tracer to minimize states
  always @(posedge clk or posedge reset)
  begin
    if (reset)
      state_event  <= 3'd0;
    else begin
      //reset event counter when we go back to idle
      if(((pll_state == PLL_DECIDE) && (pll_next_state == PLL_CHK_WORDS)) || (pll_state == PLL_IDLE))
        state_event  <= 3'd0;  
      else if((pll_next_state == PLL_DECIDE) && (pll_state != PLL_DECIDE))
        state_event  <=  state_event + 1'd1;
    end
  end

    // output logic
  always @(posedge clk or posedge reset)
  begin
    if (reset)
    begin
      uif_busy     <= 1'b0;
      ctrl_go      <= 1'b0;
      ctrl_lock    <= 1'b0;
      ctrl_opcode  <= 3'd0;
      uif_addr_err <= 1'b0;
    end
    else begin
      uif_busy     <= (pll_next_state != PLL_IDLE);
      ctrl_go      <= (pll_state == PLL_RD_L2P) | (pll_state == PLL_RD) | (pll_state == PLL_WR);
      ctrl_lock    <= (pll_state != PLL_IDLE) & (state_event < 3'd3) & !uif_l2p_active;
      ctrl_opcode  <= (pll_next_state == PLL_IDLE)    ? 3'd0            :
                      (pll_state == PLL_RD_L2P)  ? CTRL_OP_ROM_RD  :
                      (pll_state == PLL_RD)      ? CTRL_OP_RD      :
                      (pll_state == PLL_WR)      ? CTRL_OP_WR      :
                                                   ctrl_opcode;
      uif_addr_err <= (uif_addr > 3'd3);
    end
  end

  //Word counter to track how many words are needed for a RefClk switch or CGB switch
  //RefClk switch involves RMW to three words
  //CGB switch is only one word
  always @(posedge clk or posedge reset)
  begin
    if (reset)
      word_cnt  <= 2'b0;
    else begin
      //Load counter depending on PLL switch type
      if(pll_state == PLL_RD_L2P && pll_next_state == PLL_WAIT) 
        word_cnt  <= mux_pll_type ? 2'd1 : 2'd1; //2 words for CGB select, 2 words for RefClk
      //Decrement word_cnt after each RMW operation
      else if( (pll_state == PLL_CHK_WORDS) && (pll_next_state == PLL_WAIT) && (word_cnt > 0) )
        word_cnt  <= word_cnt - 1'd1; 
    end
  end


  //Read modify write DPRIO data
  assign logical_index          = mif_req ? pll_mif_data : pll_uif_data;
  assign modify_cgb_data_0      = {saved_read_data[15:13], rcgb_x_en[1:0], saved_read_data[10:6], rcgb_clk_sel[5:0]};       //modify CGB select with phys info
  assign modify_cgb_data_1      = {saved_read_data[15:10], rcgb_clknet_in_en, saved_read_data[8:0]};
  assign modify_cgb_data        = (word_cnt == 2'b01) ? modify_cgb_data_1 : 
                                                        modify_cgb_data_0;
  //RefClk switch invloves three DPRIO offsets
  assign modify_refclk_data_0 = {saved_read_data[15:11],pma_iq_clk_sel[7:0],saved_read_data[2:0]};  // pma_iqclk_sel -> 3Ah[10:3]
  assign modify_refclk_data_1 = {saved_read_data[3:0], rrefclk_sel, saved_read_data[4:0], rcru_pcie_mode, saved_read_data[4:0]};                               // rrefclk_sel -> 17h[15]
  assign modify_refclk_data   = (word_cnt == 2'b01) ? modify_refclk_data_1 : 
                                                      modify_refclk_data_0;
  assign mux_pll_type         = mif_req ? pll_mif_type : pll_uif_type;
  assign modify_data          = mux_pll_type ? {16'd0,modify_cgb_data} : {16'd0,modify_refclk_data};

  //Generate control write data to Basic
  always @(posedge clk or posedge reset)
  begin
    if (reset)
      ctrl_wdata  <= {CTRL_DATA_WIDTH{1'b0}};
    else begin
      if(pll_state == PLL_IDLE) 
        ctrl_wdata  <= {CTRL_DATA_WIDTH{1'b0}};
      else if(pll_state == PLL_WR)
        ctrl_wdata  <= modify_data;
    end
  end

  assign refclk_sel_addr =  (word_cnt == 2'b01) ? RECONFIG_PMA_PCIEMD_RREF_REG_OFST    :
                                                  RECONFIG_PMA_REFIQ_REG_OFST;
                                                  
  assign cgb_sel_addr   =  (word_cnt == 2'b01) ? RECONFIG_PMA_CLKNET_CLKMON_REG_OFST    :
                                                 RECONFIG_PMA_CGB_REG_OFST; 
                                                  
                                                  
                                                  

  //Generate control address to Basic
  always @(posedge clk or posedge reset)
  begin
    if (reset)
      ctrl_addr  <= {CTRL_ADDR_WIDTH{1'b0}};
    else begin
      if(pll_state == PLL_IDLE)
        ctrl_addr  <= 12'd0;
      //set basic offset register to index into ROM based on Type
      else if(pll_state == PLL_RD_L2P)
        ctrl_addr  <= mux_pll_type ? WORD_SEL_CGB : WORD_SEL_RC;
      //select RefClk or CGB offset depending on Type field
      else if(pll_state == PLL_RD || pll_state == PLL_WR )
        ctrl_addr  <= mux_pll_type ?  cgb_sel_addr : refclk_sel_addr;
    end
  end

  //set logical channel
  assign ctrl_lch   = mif_req ? pll_mif_lch : uif_logical_ch_addr;


  /////////////////////
  // MIF interface
  assign pll_mif_busy = uif_busy;

  assign pll_mif_err = 1'b0;

  //status information to know current requester
  always @(posedge clk or posedge reset)
  begin
    if (reset)
      mif_req  <= 1'd0;
    else begin
      if((pll_state == PLL_CHK_WORDS) && (pll_next_state == PLL_IDLE))
         mif_req  <= 1'd0;  
      else if(pll_mif_go)
         mif_req  <= 1'd1; 
    end
  end

  
endmodule 
