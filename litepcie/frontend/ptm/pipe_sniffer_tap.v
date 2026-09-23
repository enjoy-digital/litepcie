// Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
// SPDX-License-Identifier: BSD-2-Clause

module pipe_sniffer_tap #(
    parameter DATA_WIDTH = 16,
    parameter CTRL_WIDTH = 2
) (
    (* mark_debug = "true" *) input wire clk_in,
    (* mark_debug = "true" *) input wire [DATA_WIDTH-1:0] rx_data_in,
    (* mark_debug = "true" *) input wire [CTRL_WIDTH-1:0] rx_ctrl_in,
    output wire clk_out,
    output wire [DATA_WIDTH-1:0] rx_data_out,
    output wire [CTRL_WIDTH-1:0] rx_ctrl_out
);
    assign clk_out = clk_in;
    assign rx_data_out = rx_data_in;
    assign rx_ctrl_out = rx_ctrl_in;
endmodule
