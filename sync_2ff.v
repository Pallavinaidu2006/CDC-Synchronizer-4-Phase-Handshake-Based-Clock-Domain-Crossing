`timescale 1ns / 1ps
module sync_2ff #(
    parameter RESET_VAL = 1'b0
)(
    input  wire clk_dest,
    input  wire rst_n,
    input  wire async_in,
    output reg  sync_out
);

    reg meta_stage;

    always @(posedge clk_dest or negedge rst_n) begin
        if (!rst_n) begin
            meta_stage <= RESET_VAL;
            sync_out   <= RESET_VAL;
        end else begin
            meta_stage <= async_in;    // may go metastable
            sync_out   <= meta_stage;  // resolved, stable value
        end
    end

endmodule
