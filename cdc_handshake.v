`timescale 1ns / 1ps
module cdc_handshake #(
    parameter DATA_WIDTH = 8
)(
    // Sender side - clk_a domain
    input  wire                  clk_a,
    input  wire                  rst_a_n,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                  data_valid_in,   // pulse: "send this data"
    output wire                  data_ready_out,  // high when sender can accept new data

    // Receiver side - clk_b domain
    input  wire                  clk_b,
    input  wire                  rst_b_n,
    output reg  [DATA_WIDTH-1:0] data_out,
    output reg                   data_out_valid   // pulses for one clk_b cycle
);

    // ---------------- Sender FSM (clk_a domain) ----------------
    localparam S_IDLE         = 2'd0;
    localparam S_WAIT_ACK_HI  = 2'd1; // req asserted, waiting for ack to rise
    localparam S_WAIT_ACK_LO  = 2'd2; // req dropped, waiting for ack to fall

    reg [1:0]             sender_state;
    reg [DATA_WIDTH-1:0]  data_hold;
    reg                   req_a;

    wire ack_a_sync; // synchronized version of ack, in clk_a domain

    assign data_ready_out = (sender_state == S_IDLE);

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n) begin
            sender_state <= S_IDLE;
            data_hold    <= {DATA_WIDTH{1'b0}};
            req_a        <= 1'b0;
        end else begin
            case (sender_state)
                S_IDLE: begin
                    if (data_valid_in) begin
                        data_hold    <= data_in; // held stable until handshake completes
                        req_a        <= 1'b1;
                        sender_state <= S_WAIT_ACK_HI;
                    end
                end

                S_WAIT_ACK_HI: begin
                    if (ack_a_sync) begin
                        // receiver has captured the data; drop req
                        req_a        <= 1'b0;
                        sender_state <= S_WAIT_ACK_LO;
                    end
                end

                S_WAIT_ACK_LO: begin
                    if (!ack_a_sync) begin
                        sender_state <= S_IDLE; // ready for next transfer
                    end
                end

                default: sender_state <= S_IDLE;
            endcase
        end
    end

    // ---------------- Receiver FSM (clk_b domain) ----------------
    localparam R_IDLE = 1'b0;
    localparam R_ACK  = 1'b1;

    reg reg_state_b;
    reg ack_b;

    wire req_b_sync; // synchronized version of req, in clk_b domain

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            reg_state_b    <= R_IDLE;
            ack_b          <= 1'b0;
            data_out       <= {DATA_WIDTH{1'b0}};
            data_out_valid <= 1'b0;
        end else begin
            data_out_valid <= 1'b0; // default: single-cycle pulse

            case (reg_state_b)
                R_IDLE: begin
                    if (req_b_sync) begin
                        data_out       <= data_hold_b; // capture, see note below
                        data_out_valid <= 1'b1;
                        ack_b          <= 1'b1;
                        reg_state_b    <= R_ACK;
                    end
                end

                R_ACK: begin
                    if (!req_b_sync) begin
                        ack_b       <= 1'b0;
                        reg_state_b <= R_IDLE;
                    end
                end

                default: reg_state_b <= R_IDLE;
            endcase
        end
    end

    // The data bus crosses domains unsynchronized-by-design: it is
    // combinationally forwarded from the sender's held register and
    // is only ever sampled by the receiver once req_b_sync is high,
    // which guarantees data_hold has been stable for many clk_a
    // cycles already (sender only asserts req after data_hold is set,
    // and holds both constant through the entire handshake).
    wire [DATA_WIDTH-1:0] data_hold_b = data_hold;

    // ---------------- Synchronizers ----------------
    sync_2ff #(.RESET_VAL(1'b0)) u_sync_req (
        .clk_dest (clk_b),
        .rst_n    (rst_b_n),
        .async_in (req_a),
        .sync_out (req_b_sync)
    );

    sync_2ff #(.RESET_VAL(1'b0)) u_sync_ack (
        .clk_dest (clk_a),
        .rst_n    (rst_a_n),
        .async_in (ack_b),
        .sync_out (ack_a_sync)
    );

endmodule
