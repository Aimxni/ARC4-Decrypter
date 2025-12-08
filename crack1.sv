module crack1(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,
    output logic        rdy,
    output logic [23:0] key,
    output logic        key_valid,
    output logic [7:0]  ct_addr,
    input  logic [7:0]  ct_rddata,
    input logic [7:0] num_cores,
    input logic [7:0] id,
    input logic [7:0] len,
    output logic [7:0] pt_wrdata_out,
    output logic [7:0] pt_addr_out,
    output logic pt_wren_out,
    output logic copy_done
);

    // ------------------------------------------------------------
    // State machine for cracking
    // ------------------------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE      = 3'd0,  // waiting for en
        S_START_ARC4= 3'd1,  // pulse arc4_en for one cycle
        S_WAIT_ARC4 = 3'd2,  // wait for arc4_rdy, watch plaintext
        S_NEXT_KEY  = 3'd3,  // increment key, maybe fail if max
        S_DONE_GOOD = 3'd4,  // found valid key
        S_DONE_BAD  = 3'd5   // exhausted key space, no key
    } state_t;

    state_t     state, state_n;

    // key guess register
    logic [23:0] key_reg, key_reg_n;

    // track if all chars so far are printable
    logic ascii_ok, ascii_ok_n;

    // ------------------------------------------------------------
    // Outputs
    // ------------------------------------------------------------
    assign key = key_reg;

    // rdy / key_valid depend only on the state
    always_comb begin
        rdy       = 1'b0;
        key_valid = 1'b0;

        unique case (state)
            S_IDLE: begin
                rdy       = 1'b1;
                key_valid = 1'b0;
            end
            S_DONE_GOOD: begin
                rdy       = 1'b1;
                key_valid = 1'b1;
            end
            S_DONE_BAD: begin
                rdy       = 1'b1;
                key_valid = 1'b0;
            end
            default: begin
                rdy       = 1'b0;
                key_valid = 1'b0;
            end
        endcase
    end

    // ------------------------------------------------------------
    // ARC4 interface
    // ------------------------------------------------------------
    logic        arc4_en;
    logic        arc4_rdy;
    logic [7:0]  arc4_ct_addr;
    logic [7:0]  arc4_ct_rddata;

    logic [7:0]  arc4_pt_addr;
    logic [7:0]  arc4_pt_rddata;
    logic [7:0]  arc4_pt_wrdata;
    logic        arc4_pt_wren;

    // CT is owned entirely by ARC4
    assign ct_addr        = arc4_ct_addr;
    assign arc4_ct_rddata = ct_rddata;

    // ------------------------------------------------------------
    // PT memory (ARC4 writes into it, we just snoop pt_wrdata)
    // ------------------------------------------------------------
    logic [7:0] pt_q;

    pt_mem pt(
        .address(arc4_pt_addr),
        .clock  (clk),
        .data   (arc4_pt_wrdata),
        .wren   (arc4_pt_wren),
        .q      (arc4_pt_rddata)   // not actually used by crack logic
    );

    assign pt_addr_out = arc4_pt_addr;
    assign pt_wrdata_out = arc4_pt_wrdata;
    assign pt_wren_out = arc4_pt_wren;

    // ------------------------------------------------------------
    // Sequential registers
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            key_reg  <= 24'd0;
            ascii_ok <= 1'b1;
        end else begin
            state    <= state_n;
            key_reg  <= key_reg_n;
            ascii_ok <= ascii_ok_n;
        end
    end

    always_ff @(posedge clk)begin
        if(!rst_n)begin
            copy_done <= 1'b0;
        end
        else if(state == S_DONE_GOOD)begin
            copy_done <= 1'b1;
        end
    end

    // ------------------------------------------------------------
    // Combinational next-state logic
    // ------------------------------------------------------------
    always_comb begin
        // defaults
        state_n    = state;
        key_reg_n  = key_reg;
        ascii_ok_n = ascii_ok;
        arc4_en    = 1'b0;

        case (state)
            // ----------------------------------------------------
            // Wait for top-level en to start brute-force
            // ----------------------------------------------------
            S_IDLE: begin
                key_reg_n  = key_reg;   // unchanged
                ascii_ok_n = 1'b1;
                if (en && arc4_rdy) begin
                    // start from key = 0
                    key_reg_n  = {16'd0, id};
                    ascii_ok_n = 1'b1;
                    state_n    = S_START_ARC4;
                end
            end

            // ----------------------------------------------------
            // Start ARC4 for current key: 1-cycle en pulse
            // ----------------------------------------------------
            S_START_ARC4: begin
                arc4_en    = 1'b1;
                ascii_ok_n = 1'b1;   // reset ASCII flag for this key
                state_n    = S_WAIT_ARC4;
            end

            // ----------------------------------------------------
            // While ARC4 is running:
            //   - monitor pt_wren/pt_wrdata
            //   - mark ascii_ok_n = 0 if any non-printable
            //   - when arc4_rdy goes high, decide next state
            // ----------------------------------------------------
            S_WAIT_ARC4: begin
                // once bad, stay bad
                ascii_ok_n = ascii_ok;

                // watch streaming plaintext writes
                if (arc4_pt_wren && (arc4_pt_addr != 8'd0)) begin
                    if (arc4_pt_wrdata < 8'h20 || arc4_pt_wrdata > 8'h7E)
                        ascii_ok_n = 1'b0;
                end

                if (arc4_rdy) begin
                    if (ascii_ok_n) begin
                        state_n = S_DONE_GOOD;  // found a good key
                    end else begin
                        state_n = S_NEXT_KEY;   // try next key
                    end
                end
            end

            // ----------------------------------------------------
            // Increment key, or fail if we've tried all
            // ----------------------------------------------------
            S_NEXT_KEY: begin
                if (key_reg == 24'hFFFFFF) begin
                    state_n = S_DONE_BAD;
                end else begin
                    key_reg_n  = key_reg + {16'd0, num_cores};
                    ascii_ok_n = 1'b1;
                    state_n    = S_START_ARC4;
                end
            end

            // ----------------------------------------------------
            // Terminal states
            // ----------------------------------------------------
            S_DONE_GOOD: begin
                // stay here until reset
                state_n    = S_DONE_GOOD;
                key_reg_n  = key_reg;
                ascii_ok_n = ascii_ok;
            end

            S_DONE_BAD: begin
                // stay here until reset
                state_n    = S_DONE_BAD;
                key_reg_n  = key_reg;
                ascii_ok_n = ascii_ok;
            end

            default: begin
                state_n    = S_IDLE;
                key_reg_n  = 24'd0;
                ascii_ok_n = 1'b1;
            end
        endcase
    end

    // ------------------------------------------------------------
    // ARC4 instance (your fixed version)
    // ------------------------------------------------------------
    arc4 a4(
        .clk       (clk),
        .rst_n     (rst_n),        // global reset only
        .en        (arc4_en),
        .rdy       (arc4_rdy),
        .key       (key_reg),
        .ct_addr   (arc4_ct_addr),
        .ct_rddata (arc4_ct_rddata),
        .pt_addr   (arc4_pt_addr),
        .pt_rddata (arc4_pt_rddata),
        .pt_wrdata (arc4_pt_wrdata),
        .pt_wren   (arc4_pt_wren)
    );

endmodule : crack1
