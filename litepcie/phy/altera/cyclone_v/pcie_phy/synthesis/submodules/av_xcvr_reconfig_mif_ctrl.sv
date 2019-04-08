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


// MIF streamer control
//
//
// It receives user indirect registers from ALT_XRECONF_UIF and
// it generates write and read cycles to the ALT_XRECONF_BASIC.

// $Header$

`timescale 1 ns / 1 ps

module av_xcvr_reconfig_mif_ctrl #(
    parameter UIF_ADDR_WIDTH  = 12,
    parameter UIF_DATA_WIDTH  = 32,
    parameter CTRL_ADDR_WIDTH = 12,
    parameter MIF_ADDR_LEN    = 11,
    parameter CTRL_DATA_WIDTH = 16,
    parameter MIF_ADDR_WIDTH  = 32,
    parameter MIF_DATA_WIDTH  = 16
)
(
    input  wire        clk,
    input  wire        reset,
   
    // user interface
    input  wire                        uif_go,       // start user cycle
    input  wire [2:0]                  uif_mode,     // operation
    input  wire [1:0]                  uif_mif_mode, // MIF control mode (00b=Auto-stream, 01b=manual reconfig, 1xb=Raw access)
    output reg                         uif_busy,     // transfer in process
    input  wire [UIF_ADDR_WIDTH -1:0]  uif_addr,     // address offset
    input  wire [UIF_DATA_WIDTH -1:0]  uif_wdata,    // data in
    output reg  [UIF_DATA_WIDTH -1:0]  uif_rdata,    // data out
    input  wire                        ctrl_chan_err, // ctrl illegal channel
    output wire                        uif_chan_err, // illegal channel
    output reg                         uif_addr_err, // illegal address
    input  wire [9:0]                  uif_logical_ch_addr, //logical channel

    //MIF Avalon master SM interface
    output reg [MIF_ADDR_WIDTH -1:0]    mif_base_addr,
    output reg                          mif_addr_mode,
    output reg                          ctrl_av_go,
    output wire                         ctrl_op_done,
    output wire                         ctrl_op_err,
    output wire [9:0]                   ctrl_lch,

    input wire  [MIF_ADDR_LEN-1:0]      av_mif_addr,
    input wire  [MIF_DATA_WIDTH-1:0]    av_mif_data,
    input wire                          av_ctrl_req,
    input wire                          av_addr_burst,
    input wire                          av_opcode_err,
    input wire                          av_mif_type_valid,
    input wire [1:0]                    av_mif_type,
    input wire                          av_mif_type_err,
    input wire                          av_done, 
    input wire                          av_pll_err, 
 
    // basic block control interface
    output reg                         ctrl_go,      // start basic block cycle
    output reg  [2:0]                  ctrl_opcode,  // 0=read; 1=write;
    output reg                         ctrl_lock,    // multicycle lock 
    input  wire                        ctrl_wait,    // transfer in process
    output reg  [CTRL_ADDR_WIDTH -1:0] ctrl_addr,
    input  wire [CTRL_DATA_WIDTH -1:0] ctrl_rdata,   // data in
    output reg  [CTRL_DATA_WIDTH -1:0] ctrl_wdata    // data out
);

// state assignments
localparam [2:0] CTRL_IDLE      = 3'd0;
localparam [2:0] CTRL_MIF_WR    = 3'd1;
localparam [2:0] CTRL_WF_B      = 3'd2;
localparam [2:0] CTRL_RMW       = 3'd3;
localparam [2:0] CTRL_WF_AV     = 3'd4;
localparam [2:0] CTRL_MIF_RD    = 3'd5;
localparam [2:0] CTRL_CHK_ADDR  = 3'd6;
localparam [2:0] CTRL_CHK_CHN   = 3'd7;


// user modes
localparam UIF_MODE_RD   = 3'h0;
localparam UIF_MODE_WR   = 3'h1;
localparam UIF_MODE_PHYS = 3'h2;

localparam MIF_ADDR_OFFSET = 3'd0;
localparam MIF_CTRL_OFFSET = 3'd1;
localparam MIF_ERR_OFFSET  = 3'd2;

localparam MIF_STREAM_MODE  = 2'b00; //MIF stream mode to read ROM image
localparam MIF_DIRECT_MODE  = 2'b01; //MIF direct mode for parital MIF writes
localparam UIF_LDIRECT_MODE = 2'b10; //User Direct access to Basic block using logical address
localparam UIF_PDIRECT_MODE = 2'b11; //User Direct access to Basic block using physical address

// basic control commands
localparam CTRL_OP_RD   = 3'h0;
localparam CTRL_OP_WR   = 3'h1;
localparam CTRL_RD_PHY_CH = 3'h2;
localparam CTRL_OP_PRD  = 3'h5; //Physical addressing read/write
localparam CTRL_OP_PWR  = 3'h6;


localparam MIF_TYPE_DUPLEX   = 2'd0;
localparam MIF_TYPE_PLL      = 2'd1;
localparam MIF_TYPE_RX       = 2'd2;
localparam MIF_TYPE_TX       = 2'd3;

// register addresses
import alt_xcvr_reconfig_h::*; 
import av_xcvr_h::*;


// declarations
reg [2:0]                 ctrl_next_state;
reg [2:0]                 ctrl_state;


//internal registers
reg                         mif_strm_start;    // offset 1
reg                         av_ctrl_req_dly;
reg                         rmw_offset;
reg                         uif_ctrl_req;
reg                         chn_chk_active;
reg  [15:0]                 saved_read_data;
reg  [15:0]                 rmw_mask;
reg  [4:0]                  channel_id; //[4:3] = pll_type, [2] = ATT, [1] = rx_en, [0] = tx_en
reg  [4:0]                  mif_err_reg;
reg                         mif_clr_error;
reg                         av_chn_mismatch;

wire [15:0]                 mif_data_modify;
wire [UIF_DATA_WIDTH -1:0]  uif_wdata_modify;
wire                        av_ctrl_req_re;
wire                        uif_addr_err_re;
wire                        uif_addr_err_d;
wire                        uif_wr;
wire                        uif_rd;  
wire                        uif_rd_ch;
wire                        set_uif_ctrl_req;
wire                        clr_uif_ctrl_req;
wire [CTRL_ADDR_WIDTH-1:0]  mux_mif_addr;
wire [15:0]                 masked_rdata;     
wire [15:0]                 masked_wdata; 
wire [15:0]                 masked_uif_wdata;        


//pass logical channel info to Avalog IF for PLL reconfig
assign ctrl_lch = uif_logical_ch_addr;

assign uif_wr    = uif_go & (uif_mode == UIF_MODE_WR); 
assign uif_rd    = uif_go & (uif_mode == UIF_MODE_RD);
assign uif_rd_ch = uif_go & (uif_mode == UIF_MODE_PHYS);

//internal register interface
always @(posedge clk or posedge reset)
begin
    if (reset) begin
        mif_base_addr  <= {MIF_ADDR_WIDTH{1'b0}};
        mif_strm_start <= 1'b0;
        mif_addr_mode  <= 1'b0;
        mif_clr_error  <= 1'b0;
    end
    else begin
        if(uif_go && (uif_mode == UIF_MODE_WR) && (uif_mif_mode == MIF_STREAM_MODE)) begin
            case(uif_addr[2:0])
            MIF_ADDR_OFFSET: mif_base_addr                      <= uif_wdata[MIF_ADDR_WIDTH-1:0];
            MIF_CTRL_OFFSET: {mif_clr_error,mif_addr_mode,mif_strm_start}     <= uif_wdata[2:0];
            endcase
        end
        else begin
            mif_base_addr   <= mif_base_addr;
            mif_strm_start  <= 1'b0; //self clear bit to create a start strobe
            mif_addr_mode   <= mif_addr_mode;
            mif_clr_error   <= 1'b0; //self clear
        end
    end 
end


// user read data
always @(posedge clk or posedge reset)
begin
    if(reset)
        uif_rdata <= {CTRL_DATA_WIDTH{1'b0}};
    else begin
        if(uif_go && (uif_mode == UIF_MODE_RD) && (uif_mif_mode == MIF_STREAM_MODE)) begin
            case(uif_addr[2:0])
            MIF_ADDR_OFFSET:    uif_rdata <= mif_base_addr[MIF_ADDR_WIDTH-1:0];
            MIF_ERR_OFFSET:     uif_rdata <= {11'd0,mif_err_reg};
            default :           uif_rdata <= {CTRL_DATA_WIDTH{1'b0}};
            endcase
        end
        else if((uif_mode == UIF_MODE_RD) && (uif_mif_mode != MIF_STREAM_MODE)) 
            uif_rdata <= ctrl_rdata;
        else begin
            uif_rdata <= uif_rdata;
        end     
    end
end

//error status registers
always @(posedge clk or posedge reset)
begin
    if (reset)
        mif_err_reg <= 5'd0;
    else begin
        if(mif_clr_error)
          mif_err_reg <= 5'd0;
        else if(uif_addr_err_re) //strobe
          mif_err_reg[0] <= 1'b1;
        else if(av_opcode_err) //strobe
          mif_err_reg[1] <= 1'b1;
        else if(av_pll_err) //strobe
          mif_err_reg[2] <= 1'b1;
        else if(av_mif_type_err)
          mif_err_reg[3] <= 1'b1;
        else if(av_chn_mismatch) //strobe
          mif_err_reg[4] <= 1'b1;
    end
end

assign ctrl_op_err = |mif_err_reg;

//create strobe top set error flag
assign uif_addr_err_re = ~(uif_addr_err) & uif_addr_err_d;
assign uif_addr_err_d = (uif_mif_mode == MIF_STREAM_MODE) & (uif_addr > 12'd2);  

assign uif_chan_err = ctrl_chan_err;


////////////////////////////////////////////////////////
// Main control state machine.
// Interfaces with Avalon master SM, and Basic interface
/////////////////////////////////////////////////////////

//next state
always @ (*) begin
    case(ctrl_state)
    CTRL_IDLE: begin
        //User initiated a MIF stream operation
        if(mif_strm_start && (uif_mif_mode == MIF_STREAM_MODE))
            ctrl_next_state = CTRL_CHK_CHN;
        // User initiated a direct read
        else if(uif_rd && (uif_mif_mode != MIF_STREAM_MODE))
            ctrl_next_state = CTRL_MIF_RD;  
        //  User initiated a direct write
        else if(uif_wr && (uif_mif_mode != MIF_STREAM_MODE))
            ctrl_next_state = CTRL_CHK_ADDR;
        else if(uif_rd_ch) 
            ctrl_next_state = CTRL_MIF_RD;
        else
            ctrl_next_state = CTRL_IDLE;
    end
    CTRL_WF_AV: begin
            if(av_done)
                ctrl_next_state = CTRL_IDLE;
            //Check AVMM request address if RMW is needed
            else if(av_ctrl_req)  
                ctrl_next_state = CTRL_CHK_ADDR;
            else
                ctrl_next_state = CTRL_WF_AV;
    end
    //Check address to see if RMW is needed
    CTRL_CHK_ADDR: begin
            //Determine if the MIF address requires RMW
            if(rmw_offset)  
                ctrl_next_state = CTRL_MIF_RD;
            //Need to issue read-modify-write for this DPRIO offset
            else  
                ctrl_next_state = CTRL_MIF_WR;
    end
    //Issue Reconfig write
    CTRL_MIF_WR: ctrl_next_state = CTRL_WF_B;
    //Wait for B-Block access to finish
    CTRL_WF_B: begin
            //Basic access finished for either Avalon Wr request or initial Channel ID detection 
            if(!ctrl_wait && ((av_ctrl_req && !rmw_offset) || chn_chk_active)) 
                ctrl_next_state = CTRL_WF_AV;
            //Modify read data using appropriate mask
            else if(!ctrl_wait && (av_ctrl_req || uif_ctrl_req) && rmw_offset) 
                ctrl_next_state = CTRL_RMW;
            //Basic access finished for User Wr request
            else if (!ctrl_wait && uif_ctrl_req)
                ctrl_next_state = CTRL_IDLE;
            else
                ctrl_next_state = CTRL_WF_B;
    end
    //Issue Reconfig Read
    CTRL_MIF_RD: ctrl_next_state = CTRL_WF_B;
    //Check logical channel ID reg
    CTRL_CHK_CHN: ctrl_next_state = CTRL_WF_B;
    //One cycle to modify data
    CTRL_RMW: ctrl_next_state = CTRL_MIF_WR;
    default: ctrl_next_state = CTRL_IDLE;
    endcase 
end

// present state
always @(posedge clk or posedge reset)
begin
    if (reset)
        ctrl_state <= CTRL_IDLE;
    else
        ctrl_state <= ctrl_next_state;
end

// control outputs
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        uif_busy        <= 1'b0;
        ctrl_go         <= 1'b0;
        ctrl_lock       <= 1'b0;
        ctrl_opcode     <= 3'd0;
        uif_addr_err    <= 1'b0;
        ctrl_av_go      <= 1'b0;
        chn_chk_active  <= 1'b0;
    end
    else begin
        uif_busy     <= (ctrl_state != CTRL_IDLE);
        ctrl_go      <= (ctrl_next_state == CTRL_MIF_WR) | (ctrl_next_state == CTRL_MIF_RD) | (ctrl_next_state == CTRL_CHK_CHN);
        ctrl_lock    <= (rmw_offset | av_addr_burst) ? 1'b1 :1'b0; //only needed for RMW operations
        ctrl_av_go   <= (ctrl_state == CTRL_WF_B) && (ctrl_next_state == CTRL_WF_AV) && chn_chk_active;
        ctrl_opcode  <= (uif_mif_mode == UIF_PDIRECT_MODE) & (ctrl_next_state == CTRL_MIF_WR) ? CTRL_OP_PWR :
                        (uif_mif_mode == UIF_PDIRECT_MODE) & (ctrl_next_state == CTRL_MIF_RD) & (uif_mode == UIF_MODE_RD) ? CTRL_OP_PRD :
                        (ctrl_next_state == CTRL_MIF_RD) & (uif_mode == UIF_MODE_PHYS) ? CTRL_RD_PHY_CH : 
                        (ctrl_next_state == CTRL_MIF_WR) ? CTRL_OP_WR : 
                        (ctrl_next_state == CTRL_MIF_RD) | (ctrl_next_state == CTRL_CHK_CHN)  ? CTRL_OP_RD : ctrl_opcode;
        uif_addr_err    <= uif_addr_err_d; //illegal offset
        chn_chk_active  <= (ctrl_next_state == CTRL_CHK_CHN) ? 1'b1 :
                           (ctrl_state == CTRL_WF_B) & (ctrl_next_state == CTRL_WF_AV) ? 1'b0 : chn_chk_active;
    end
end

assign ctrl_op_done = (ctrl_state == CTRL_WF_B) & ((ctrl_next_state == CTRL_WF_AV) | (ctrl_next_state == CTRL_IDLE));

// ctrl_address  might be sourced by user or from MIF
always @(posedge clk or posedge reset)
 begin
    if(reset)
        ctrl_addr <= {CTRL_ADDR_WIDTH{1'b0}};
    else begin
        if(ctrl_next_state == CTRL_CHK_CHN)
            ctrl_addr <= AV_XR_ABS_ADDR_ID; 
        //capture MIF address from Avalon
        else if(uif_mif_mode == MIF_STREAM_MODE && av_ctrl_req_re) 
            ctrl_addr <= {1'b0,av_mif_addr};  //MSB is used for PHY-IP soft registers
        //capture User IF offset and use directly
        else if(uif_mif_mode != MIF_STREAM_MODE && set_uif_ctrl_req)
            ctrl_addr <= uif_addr;
    end
end

//Save channel ID information
always @(posedge clk or posedge reset)
begin
  if (reset) begin
    channel_id <= 5'd0;    
  end
  else begin
    if(ctrl_state == CTRL_IDLE) 
      channel_id <= 5'd0;
    else if(!ctrl_wait && (ctrl_opcode==CTRL_OP_RD) && chn_chk_active)
      channel_id <= ctrl_rdata[AV_XR_ID_PLL_TYPE_OFST+AV_XR_ID_PLL_TYPE_LEN-1:AV_XR_ID_TX_CHANNEL_OFST]; 
  end
end

always @(posedge clk or posedge reset)
begin
  if (reset) begin
    av_chn_mismatch <= 1'd0;    
  end
  else begin
    if(av_mif_type_valid) begin
      if((av_mif_type == MIF_TYPE_DUPLEX) && ((channel_id[AV_XR_ID_RX_CHANNEL_OFST] != 1'd1) || (channel_id[AV_XR_ID_TX_CHANNEL_OFST] != 1'd1)))
        av_chn_mismatch <= 1'b1;
      else if((av_mif_type == MIF_TYPE_RX) && ((channel_id[AV_XR_ID_RX_CHANNEL_OFST] != 1'd1) || (channel_id[AV_XR_ID_TX_CHANNEL_OFST] != 1'd0)))
        av_chn_mismatch <= 1'b1;
      else if((av_mif_type == MIF_TYPE_TX) && ((channel_id[AV_XR_ID_RX_CHANNEL_OFST] != 1'd0) || (channel_id[AV_XR_ID_TX_CHANNEL_OFST] != 1'd1)))
        av_chn_mismatch <= 1'b1;
      //we currently only support CMU PLLs
      else if((av_mif_type == MIF_TYPE_PLL) && (channel_id[AV_XR_ID_PLL_TYPE_OFST+AV_XR_ID_PLL_TYPE_LEN-1: AV_XR_ID_PLL_TYPE_OFST] != AV_XR_ID_PLL_TYPE_CMU))
        av_chn_mismatch <= 1'b1;
    end
    else
     av_chn_mismatch  <= 1'b0;  
  end
end




//Check for special RMW offsets
assign mux_mif_addr = (uif_mif_mode == MIF_STREAM_MODE) ? {1'b0,av_mif_addr} : uif_addr[CTRL_ADDR_WIDTH-1:0];

always @(posedge clk or posedge reset)
begin
  if (reset)
    rmw_offset <= 1'b0;
  else begin
    //clear rmw flag after data has been modified
    if((ctrl_state == CTRL_RMW) && (ctrl_next_state == CTRL_MIF_WR) )
      rmw_offset <= 1'b0;
    //Protect DPRIO with RMW if write request is STREAM or DIRECT modes
    else if(av_ctrl_req_re || (uif_wr && (uif_mif_mode == MIF_DIRECT_MODE))) begin
      case(mux_mif_addr)
        RECONFIG_PMA_CGB_REG_OFST, 
        RECONFIG_PMA_CLKNET_CLKMON_REG_OFST, 
        RECONFIG_PMA_LST_REG_OFST, 
        RECONFIG_PMA_BBPD_REG_OFST,
        RECONFIG_PMA_TB_REG_OFST,
        RECONFIG_PMA_PCIEMD_RREF_REG_OFST,
        RECONFIG_PMA_RXDATAO_REG_OFST,
        RECONFIG_PMA_REFIQ_REG_OFST,
        RECONFIG_PMA_CH0_DCD_DC_TUNE,
        RECONFIG_PCS8G_POWER_TRL_REG_OFST : rmw_offset <= 1'b1;  //CGB/RefClk bits 
      default :   rmw_offset <= 1'b0;
      endcase
    end
  end
end

//RMW masks
always @ (*) begin
  case(mux_mif_addr)
    RECONFIG_PMA_CGB_REG_OFST           : rmw_mask = RECONFIG_PMA_CGB_REG_MASK;             // contains rcgb_clk_sel bits
    RECONFIG_PMA_CLKNET_CLKMON_REG_OFST : rmw_mask = RECONFIG_PMA_CLKNET_CLKMON_REG_MASK;   // contains XN Line select (rcgb_clknet_in_en), DCD protected bits (rser_clk_mon)
    RECONFIG_PMA_LST_REG_OFST           : rmw_mask = RECONFIG_PMA_LST_REG_MASK;             // contains DCD protected bits (rtx_lst)
    RECONFIG_PMA_BBPD_REG_OFST          : rmw_mask = RECONFIG_PMA_BBPD_REG_MASK;            // contains BBPD control (rcru_pdof_*i)
    RECONFIG_PMA_TB_REG_OFST            : rmw_mask = RECONFIG_PMA_TB_REG_MASK;              // contains Testbus control control (rcru_pdof_test)
    RECONFIG_PMA_PCIEMD_RREF_REG_OFST   : rmw_mask = RECONFIG_PMA_PCIEMD_RREF_REG_MASK;     // contains (pcie_mode_sel, rrefclk_sel) bit
    RECONFIG_PMA_RXDATAO_REG_OFST       : rmw_mask = RECONFIG_PMA_RXDATAO_REG_MASK;         // contains rx_data_out_sel //rdynamic_sw, rint_early_eios, rint_ltr, rrxp_reserved[29], rint_tx_elec_idle, rint_txdetectrx, rint_pcie_switch, rint_cvp_mode, rint_ffclk_pdb
    RECONFIG_PMA_REFIQ_REG_OFST         : rmw_mask = RECONFIG_PMA_REFIQ_REG_MASK;           // contains pma_iq_clk_sel bits
    RECONFIG_PMA_CH0_DCD_DC_TUNE        : rmw_mask = RECONFIG_PMA_DCD_DC_TUNE_REG_MASK;     // contains rser_dc_tune 
    RECONFIG_PCS8G_POWER_TRL_REG_OFST   : rmw_mask = RECONFIG_PCS8G_POWER_TRL_REG_MASK;     // contains r_pow_power_iso_ctrl bits 
  default : rmw_mask = 16'h0000; //all bits are writable
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

//generate RMW data
assign masked_rdata     = saved_read_data & rmw_mask; //preserve existing DPRIO data
assign masked_wdata     = av_mif_data & ~(rmw_mask);   //Clear write bits that should be preserved
assign mif_data_modify  = masked_wdata | masked_rdata; //Create a new data word   //av_mif_data;

assign masked_uif_wdata = uif_wdata[15:0] & ~(rmw_mask);
assign uif_wdata_modify = masked_uif_wdata | masked_rdata;

// basic write data might be source from user or from MIF
always @(posedge clk or posedge reset)
begin
    if(reset)
        ctrl_wdata <= {CTRL_DATA_WIDTH{1'b0}};
    else begin
        if(uif_mif_mode == MIF_STREAM_MODE)
            ctrl_wdata <= mif_data_modify;
        else if (uif_mif_mode == MIF_DIRECT_MODE)
            ctrl_wdata <= uif_wdata_modify; 
        else
            ctrl_wdata <= uif_wdata[15:0]; 
    end
end


//create a UIF request flag to the Basic control SM
assign set_uif_ctrl_req = (ctrl_state == CTRL_IDLE) & ((ctrl_next_state == CTRL_CHK_ADDR) | (ctrl_next_state == CTRL_MIF_RD));
assign clr_uif_ctrl_req = ctrl_op_done;
always @(posedge clk or posedge reset)
begin
    if (reset)
        uif_ctrl_req    <= 1'd0;
    else begin
        if(set_uif_ctrl_req)
            uif_ctrl_req <= 1'b1;
        else if(clr_uif_ctrl_req)
            uif_ctrl_req <= 1'b0;
    end
end

//detect incoming Av request
//delay a cycle to allow Av data to get here
always @(posedge clk or posedge reset)
begin
    if(reset)
        av_ctrl_req_dly <= 1'b0;
    else begin
        av_ctrl_req_dly <= av_ctrl_req;
    end
end

assign av_ctrl_req_re = ~(av_ctrl_req_dly) & av_ctrl_req;

 
endmodule
