
module tb_cdc;

    localparam DATA_WIDTH  = 8;
    localparam NUM_TRANSFERS = 2000;

    reg                    clk_a;
    reg                    clk_b;
    reg                    rst_a_n;
    reg                    rst_b_n;

    reg  [DATA_WIDTH-1:0]  data_in;
    reg                    data_valid_in;
    wire                   data_ready_out;

    wire [DATA_WIDTH-1:0]  data_out;
    wire                   data_out_valid;

    integer sent_count;
    integer recv_count;
    integer errors;

    // simple queue (scoreboard) implemented as an array + pointers
    reg [DATA_WIDTH-1:0] scoreboard [0:NUM_TRANSFERS-1];
    integer sb_wr_ptr;
    integer sb_rd_ptr;

    // ---------------- DUT ----------------
    cdc_top #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
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

    // ---------------- Clock generation ----------------
    // Unrelated, non-integer-multiple frequencies on purpose.
    // clk_a period = 10.0 ns  (~100 MHz)
    // clk_b period = 14.6 ns  (~68.5 MHz)
    initial clk_a = 1'b0;
    always #5.0  clk_a = ~clk_a;

    initial clk_b = 1'b0;
    always #7.3  clk_b = ~clk_b;

    // ---------------- Reset ----------------
    initial begin
        rst_a_n = 1'b0;
        rst_b_n = 1'b0;
        // randomize how the two async resets deassert relative
        // to each other, within reason
        #23      rst_a_n = 1'b1;
        #31      rst_b_n = 1'b1;
    end

    // ---------------- Stimulus: sender side ----------------
    initial begin
        sent_count    = 0;
        data_in       = {DATA_WIDTH{1'b0}};
        data_valid_in = 1'b0;
        sb_wr_ptr     = 0;

        // wait for reset to clear on clk_a domain
        wait (rst_a_n == 1'b1);
        @(posedge clk_a);

        while (sent_count < NUM_TRANSFERS) begin
            // random gap before next send: mix of back-to-back
            // and spaced-out sends to stress both fast and slow paths
            repeat ($urandom_range(0, 4)) @(posedge clk_a);

            @(posedge clk_a);
            if (data_ready_out) begin
                data_in       = $urandom_range(0, (1 << DATA_WIDTH) - 1);
                data_valid_in = 1'b1;

                // record expected value in scoreboard, in order
                scoreboard[sb_wr_ptr] = data_in;
                sb_wr_ptr = sb_wr_ptr + 1;
                sent_count = sent_count + 1;

                @(posedge clk_a);
                data_valid_in = 1'b0;

                // wait until sender is ready again before looping
                // (data_ready_out only goes high again once the
                // handshake for this transfer has fully completed)
                wait (data_ready_out == 1'b1);
            end
        end

        $display("[%0t] Sender finished issuing %0d transfers", $time, sent_count);
    end

    // ---------------- Checker: receiver side ----------------
    initial begin
        recv_count = 0;
        errors     = 0;
        sb_rd_ptr  = 0;

        wait (rst_b_n == 1'b1);

        while (recv_count < NUM_TRANSFERS) begin
            @(posedge clk_b);
            if (data_out_valid) begin
                if (data_out !== scoreboard[sb_rd_ptr]) begin
                    $display("[%0t] MISMATCH at transfer %0d: expected %0h, got %0h",
                              $time, recv_count, scoreboard[sb_rd_ptr], data_out);
                    errors = errors + 1;
                end
                sb_rd_ptr  = sb_rd_ptr + 1;
                recv_count = recv_count + 1;
            end
        end

        $display("[%0t] Receiver finished collecting %0d transfers", $time, recv_count);

        if (errors == 0) begin
            $display("=========================================");
            $display(" TEST PASSED: %0d transfers, 0 errors", NUM_TRANSFERS);
            $display("=========================================");
        end else begin
            $display("=========================================");
            $display(" TEST FAILED: %0d errors out of %0d transfers", errors, NUM_TRANSFERS);
            $display("=========================================");
        end

        #100;
        $finish;
    end

    // ---------------- Safety timeout ----------------
    initial begin
        #2_000_000; // generous upper bound
        $display("[%0t] TIMEOUT: test did not complete in time", $time);
        $display("sent_count=%0d recv_count=%0d", sent_count, recv_count);
        $finish;
    end

  

endmodule
