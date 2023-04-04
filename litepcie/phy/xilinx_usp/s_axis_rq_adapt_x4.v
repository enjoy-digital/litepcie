 module s_axis_rq_adapt_x4 # (
      parameter DATA_WIDTH  = 128,
      parameter KEEP_WIDTH  = DATA_WIDTH/8
    )(

       input user_clk,
       input user_reset,

       output [DATA_WIDTH-1:0] s_axis_rq_tdata,
       output [KEEP_WIDTH-1:0] s_axis_rq_tkeep,
       output                  s_axis_rq_tlast,
       input             [3:0] s_axis_rq_tready,
       output            [3:0] s_axis_rq_tuser,
       output                  s_axis_rq_tvalid,

       input   [DATA_WIDTH-1:0] s_axis_rq_tdata_a,
       input   [KEEP_WIDTH-1:0] s_axis_rq_tkeep_a,
       input                    s_axis_rq_tlast_a,
       output             [3:0] s_axis_rq_tready_a,
       input              [3:0] s_axis_rq_tuser_a,
       input                    s_axis_rq_tvalid_a
    );

endmodule