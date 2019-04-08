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


// MIF Avalon master IF State machine
//
//
// It receives a start indication from the MIF control block
// and will request Basic block access from control or PLL reconfig access
// $Header$

`timescale 1 ns / 1 ps

module av_xcvr_reconfig_mif_avmm #(
    parameter MIF_ADDR_WIDTH  = 32,
    parameter MIF_ADDR_LEN    = 11,
    parameter MIF_DATA_WIDTH  = 16
)
(
    input  wire        clk,
    input  wire        reset,
   
    // PLL reconfig interface
    input wire                          pll_busy,   
    input wire                          pll_err,

    // output from PLL reconfig
    output reg                          pll_go,
    output reg                          pll_type,
    output wire [9:0]                   pll_lch,
    output wire [3:0]                   pll_data,

    // Avalon Master streaming interface
    // output to MIF entity (ROM)
    output reg [MIF_ADDR_WIDTH - 1:0]   stream_address,   
    output reg                          stream_read,

    // input from MIF entity (ROM)
    input  wire                         stream_waitrequest, 
    input  wire [MIF_DATA_WIDTH - 1:0]  stream_readdata,
 
    // MIF control interface
    input wire [MIF_ADDR_WIDTH -1:0]    mif_base_addr,
    input wire                          mif_addr_mode,
    input wire                          ctrl_av_go,
    input wire                          ctrl_op_done,
    input wire                          ctrl_op_err,
    input wire [9:0]                    ctrl_lch,

    output reg   [MIF_ADDR_LEN-1:0]     av_mif_addr,
    output wire  [MIF_DATA_WIDTH-1:0]   av_mif_data,
    output reg                          av_ctrl_req,
    output reg                          av_addr_burst,
    output reg                          av_opcode_err,
    output reg                          av_mif_type_valid,
    output reg   [1:0]                  av_mif_type,
    output wire                         av_mif_type_err,
    output reg                          av_pll_err,
    output reg                          av_done
    
);

// Avalon Mst IF
localparam [2:0] AV_IDLE        = 3'h0;
localparam [2:0] AV_RD_HDR      = 3'h1;
localparam [2:0] AV_DEC_HDR     = 3'h2;
localparam [2:0] AV_RD_DATA     = 3'h3;
localparam [2:0] AV_WF_DONE     = 3'h4;
localparam [2:0] AV_REC_ERR     = 3'h5;

// MIF Opcodes
localparam [4:0] OP_SOM         = 5'h1;
localparam [4:0] OP_TYPE        = 5'h2;
localparam [4:0] OP_EOM         = 5'h1f;
localparam [4:0] OP_RC          = 5'h3;
localparam [4:0] OP_CGB         = 5'h4;

// MIF File types
localparam [1:0] DUPLEX         = 2'd0;
localparam [1:0] TXPLL          = 2'd1;
localparam [1:0] RX_CHN         = 2'd2;
localparam [1:0] TX_CHN         = 2'd3;

// register addresses
import alt_xcvr_reconfig_h::*; 
import av_xcvr_h::*;

// state machine declarations
reg [2:0]                 av_next_state;
reg [2:0]                 av_state;

//local storage for MIF content
reg [4:0]                 mif_rec_len;       // MIF length field 
reg [MIF_ADDR_LEN-1:0]    mif_rec_addr;      // MIF address field
reg [15:0]                mif_rec_data;      // MIF data field
reg [3:0]                 mif_op_data;       // MIF opode data field
reg [4:0]                 mif_len_cnt;
reg [MIF_ADDR_WIDTH-1:0]  mif_next_offset;
reg                       pll_active;
reg                       pll_active_dly;
reg                       first_mif_entry;
reg                       mif_strm_active;

wire                      rec_is_opcode;  // Current record is Opcode
wire                      rec_is_som;  // Start of MIF record 
wire                      rec_is_eom;  // End of MIF record
wire                      rec_is_cgb;  // CGB MIF record
wire                      rec_is_rc;       // RefClk MIF record
wire                      rec_is_type;
wire                      invalid_rec;
wire                      rd_data_valid;
wire                      set_av_ctrl_req;
wire                      clr_av_ctrl_req;
wire                      som_not_first_err;
wire [1:0]                mif_addr_incr;


////////////////////////////
// Avalon master state machine
////////////////////////////

// next state logic
always @ (*) begin
    case(av_state)
    AV_IDLE: begin
        if(ctrl_av_go)
            av_next_state = AV_RD_HDR;
        else    
            av_next_state = AV_IDLE;
    end
    //read a new MIF header
    AV_RD_HDR: begin
        //wait for slave to transfer data
        if(rd_data_valid)
            av_next_state = AV_DEC_HDR;
        else
            av_next_state = AV_RD_HDR;
    end
    //decode the record to determine if it is an opcode or just data record
    AV_DEC_HDR: begin
        if(rec_is_eom)
            av_next_state = AV_IDLE;
        //valid start of MIF go to WF state then read the next record
        else if(rec_is_som)
            av_next_state = AV_RD_HDR;
        //this is a PLL reconfig opcode
        else if(rec_is_rc || rec_is_cgb)
            av_next_state = AV_WF_DONE;
        //unknown record. end streaming
        else if(invalid_rec)
            av_next_state = AV_REC_ERR;
        //no special op, read first data word
        else if(mif_rec_len > 5'd0)
            av_next_state = AV_RD_DATA;

        else
            av_next_state = AV_RD_HDR;
    end
    // for data records, read a data word and invoke the Basic control interface
    AV_RD_DATA: begin
        // if we've read the last data entry, get the next header
        if(mif_len_cnt == 5'd0)
            av_next_state = AV_RD_HDR;
        //keep reading data until record is complete    
        else if(rd_data_valid)
            av_next_state = AV_WF_DONE;
        else
            av_next_state = AV_RD_DATA;
    end
    //invalid record type detected
    AV_REC_ERR: av_next_state = AV_IDLE;
    //invoke PLL reconfig or basic control SM, and wait for completion of operation
    AV_WF_DONE: begin
            //wait for PLL reconfig block to complete, then get next record header
            if((!pll_busy || pll_err) && pll_active_dly)
                av_next_state = AV_RD_HDR;
            else if(ctrl_op_err)
                av_next_state = AV_REC_ERR;
            //wait for control interface to finish basic access
            else if(ctrl_op_done) 
                av_next_state = AV_RD_DATA;
            else
                av_next_state = AV_WF_DONE;
    end
    default: av_next_state = AV_IDLE;
    endcase 
end

// state register
always @(posedge clk or posedge reset)
begin
    if (reset) begin
        av_state <= AV_IDLE;
    end
    else begin
        av_state <= av_next_state;
    end
end


// Avalon output and internal storage 
always @(posedge clk or posedge reset)
begin
  if (reset) begin
    stream_read     <= 1'b0;
    stream_address  <= {MIF_ADDR_WIDTH{1'b0}};
    mif_rec_len     <= {5{1'b0}};       // MIF length field 
    mif_rec_addr    <= {MIF_ADDR_LEN{1'b0}};      // MIF address field
    mif_rec_data    <= {16{1'b0}};      // MIF data field
    mif_next_offset <= {MIF_ADDR_WIDTH{1'b0}};
    pll_active      <= 1'b0;
    pll_type        <= 1'b0;
    mif_strm_active <= 1'b0;
    av_addr_burst   <= 1'b0;
    pll_go          <= 1'b0;
  end
  else begin
    //Avalon outputs
    stream_read     <= (av_next_state == AV_RD_HDR) | (av_next_state == AV_RD_DATA);
    stream_address  <= (av_next_state == AV_RD_HDR) | 
                       (av_next_state == AV_DEC_HDR)| 
                       (av_next_state == AV_RD_DATA)  ? (mif_base_addr + mif_next_offset) 
                                                      : {MIF_ADDR_WIDTH{1'b0}};

    //capture Record next record length and address
    mif_rec_len     <= (av_state == AV_RD_HDR) & rd_data_valid ? stream_readdata[15:11] : mif_rec_len;
    mif_rec_addr    <= (av_state == AV_RD_HDR) & rd_data_valid ? stream_readdata[10:0] : mif_rec_addr;

    //capture record DPRIO data information
    mif_rec_data    <= (av_state == AV_RD_DATA) & rd_data_valid ? stream_readdata[15:0] : mif_rec_data;
       
    //track where we are in the current MIF. Look for end of MIF record
    mif_next_offset <= ((av_state == AV_RD_HDR) & (av_next_state != AV_RD_HDR)) |
                       ((av_next_state == AV_WF_DONE) & (av_state == AV_RD_DATA))   ? mif_next_offset + mif_addr_incr : //go to next MIF offset
                        (av_next_state == AV_IDLE)                                  ? {MIF_ADDR_WIDTH{1'b0}} : //MIF stream is complete         
                                                                                          mif_next_offset;    
    pll_active      <= ((av_state == AV_DEC_HDR) & (av_next_state == AV_WF_DONE)) && (rec_is_cgb || rec_is_rc) ? 1'b1 :
                        (av_state == AV_WF_DONE) & (av_next_state == AV_RD_HDR)                                ? 1'b0: 
                                                                                                                pll_active;
    pll_go          <= ((av_state == AV_DEC_HDR) & (av_next_state == AV_WF_DONE)); // this arc taken for PLL reconfig
    pll_type        <= rec_is_cgb ? 1'b1 : 1'b0;
    //set a flag to indicate that a MIF is being processed for invalid_rec qual
    mif_strm_active <= (av_next_state == AV_DEC_HDR) ? 1'b1 : 
                       (av_next_state == AV_IDLE)    ? 1'b0 : mif_strm_active;
    //allow Basic interface to hold lock and be more efficient if we have a multi-length record
    av_addr_burst   <= (mif_len_cnt > 5'd1); 
  end
end

//select between word/byte addressing
assign mif_addr_incr = mif_addr_mode ? 2'd1 : 2'd2; //default to byte addressing 

//Pass the Logical channel info to the PLL reconfig IP
assign pll_lch = ctrl_lch;
assign pll_data = mif_rec_addr[8:5];

//pass MIF data to basic control interface
assign av_mif_data = mif_rec_data;


//Current record length tracker
always @(posedge clk or posedge reset)
begin
    if (reset) begin
        mif_len_cnt <= 5'd0;
    end
    else begin
        //Reading a new header from the MIF, load the record length counter
        if((av_state == AV_DEC_HDR) && (av_next_state == AV_RD_DATA)) begin
            mif_len_cnt <= mif_rec_len;
        end
        //decrement the count for every data entry we read. We are finished when mif_len_cnt = 0
        else if(((av_state == AV_RD_DATA) & (av_next_state == AV_WF_DONE)) && (mif_len_cnt > 5'd0)) begin
            mif_len_cnt <= mif_len_cnt - 1'd1;
        end
    end
end

//DPRIO address counter
always @(posedge clk or posedge reset)
begin
  if (reset) begin
    av_mif_addr <= 11'd0;
  end
  else begin
    //Reading a new header from the MIF, load the record length counter
    if((av_state == AV_DEC_HDR) && (av_next_state == AV_RD_DATA)) begin
      av_mif_addr <= mif_rec_addr;
    end
    else if((av_state == AV_RD_DATA) && (av_next_state == AV_WF_DONE) && (mif_rec_len != mif_len_cnt)) begin
      av_mif_addr <=  av_mif_addr + 1'd1; 
    end
  end
end
    


//decode MIF file information
assign rec_is_opcode = (mif_rec_len == 5'd0); //  & mif_rec_valid ???)
assign rec_is_som    = rec_is_opcode & (mif_rec_addr[4:0] == OP_SOM) & (av_state != AV_IDLE); // start of MIF record 
assign rec_is_eom    = rec_is_opcode & (mif_rec_addr[4:0] == OP_EOM) & (av_state != AV_IDLE); // End of MIF record
assign rec_is_cgb    = rec_is_opcode & (mif_rec_addr[4:0] == OP_CGB) & (av_state != AV_IDLE); // CGB MIF record
assign rec_is_rc     = rec_is_opcode & (mif_rec_addr[4:0] == OP_RC)  & (av_state != AV_IDLE); // RefClk MIF record
assign rec_is_type   = rec_is_opcode & (mif_rec_addr[4:0] == OP_TYPE)  & (av_state != AV_IDLE); // MIF Type record
assign invalid_rec   = rec_is_opcode & ~(rec_is_som | rec_is_eom | rec_is_cgb | rec_is_rc | rec_is_type) & mif_strm_active;
                                        

assign rd_data_valid = ~(stream_waitrequest) & stream_read;

//assign av_done       = (av_next_state == AV_IDLE) && (av_state != AV_IDLE); //Avalon access complete 
always @(posedge clk or posedge reset)
begin
    if (reset)
      av_done <= 1'd0;
    else begin
      av_done <= (av_next_state == AV_IDLE) && (av_state != AV_IDLE); //Avalon access complete;
    end
end


//Check for SOM as first record, flag opcode error if not in first record
always @(posedge clk or posedge reset)
begin
    if (reset)
        first_mif_entry <= 1'd0;
    else begin
        //delay one cycle to allow rec_is_som decode
        if((stream_address == mif_base_addr) && rd_data_valid)
          first_mif_entry <= 1'b1;
        else
          first_mif_entry <= 1'd0;
    end
end

assign som_not_first_err = first_mif_entry & ~(rec_is_som);

//Flag error for invalid opcode
always @(posedge clk or posedge reset)
begin
    if (reset)
        av_opcode_err <= 1'd0;
    else begin
        //first MIF entry is not SOM
        if(som_not_first_err)
          av_opcode_err  <= 1'b1;
        //Opcode is decoded, but is not valid
        else if(rec_is_opcode && invalid_rec)
          av_opcode_err  <= 1'b1;
        else
          av_opcode_err <= 1'b0;
    end
end

//The MIF Type is only 2-bits for now, so all encodings are invalid
assign av_mif_type_err = 1'b0;

//Pass MIF Type to MIF control to check against target local channel
always @(posedge clk or posedge reset)
begin
    if (reset) begin
        av_mif_type       <= 2'd0;
        av_mif_type_valid <= 1'd0;
    end
    else begin
        if(rec_is_type) begin
          av_mif_type       <= mif_rec_addr[6:5];
          av_mif_type_valid <= 1'b1;
        end
        else begin
          av_mif_type       <= 2'd0;
          av_mif_type_valid <= 1'b0;
        end
    end
end

//generate a strobe when an error is detected during MIF streaming
always @(posedge clk or posedge reset)
begin
    if (reset)
        av_pll_err <= 1'd0;
    else begin
        if(pll_err && (av_state != AV_IDLE))
            av_pll_err <= 1'b1;
        else 
            av_pll_err <= 1'b0;
    end
end



//create a request flag to the Basic control SM
assign set_av_ctrl_req  = (av_state == AV_RD_DATA) && (av_next_state == AV_WF_DONE);
assign clr_av_ctrl_req  = ctrl_op_done;
always @(posedge clk or posedge reset)
begin
    if (reset)
        av_ctrl_req <= 1'd0;
    else begin
        if(set_av_ctrl_req)
            av_ctrl_req <= 1'b1;
        else if(clr_av_ctrl_req)
            av_ctrl_req <= 1'b0;
    end
end

        
////////////////////////////
// PLL reconfig interface
////////////////////////////

// delay one cycle to wait to pll_busy assertion
always @(posedge clk or posedge reset)
begin
    if (reset) begin
       pll_active_dly <= 1'd0;
    end
    else begin
       pll_active_dly  <= pll_active;
    end
end

 
endmodule
