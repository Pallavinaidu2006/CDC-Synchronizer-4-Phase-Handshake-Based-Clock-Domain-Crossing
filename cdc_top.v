`timescale 1ns / 1ps
module cdc_top #(
    parameter DATA_WIDTH = 8
)(
    // Sender side - clk_a domain
    input  wire                  clk_a,
    input  wire                  rst_a_n,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                  data_valid_in,
    output wire                  data_ready_out,

    // Receiver side - clk_b domain
    input  wire                  clk_b,
    input  wire                  rst_b_n,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire                  data_out_valid
);

    cdc_handshake #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_cdc_handshake (
        .clk_a          (clk_a),
        .rst_a_n        (rst_a_n),
        .data_in        (data_in),
        .data_valid_in  (data_valid_in),
        .data_ready_out (data_ready_out),

        .clk_b          (clk_b),
        .rst_b_n        (rst_b_n),
        .data_out       (data_out),
        .data_out_valid (data_out_valid)
    );

endmodule
