module doublecrack(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,
    output logic        rdy,
    output logic [23:0] key,
    output logic        key_valid,
    output logic [7:0]  ct_addr,
    input  logic [7:0]  ct_rddata
);

    // -----------------------------
    // Internal signals
    // -----------------------------
    logic [1:0] rdy_c;
    logic [1:0] key_valid_c;
    logic [23:0] key_c [1:0];

    logic [1:0][7:0] ct_addr_c;
    logic [1:0][7:0] ct_rddata_c;

    logic [1:0][7:0] pt_wrdata_c;
    logic [1:0][7:0] pt_addr_c;
    logic [1:0]      pt_wren_c;

    logic [1:0] copy_done;

    logic [7:0] num_cores;
    assign num_cores = 8'd2;

    // -----------------------------
    // Shared CT Arbitration (OR)
    // -----------------------------
    assign ct_addr = ct_addr_c[0] | ct_addr_c[1];
    assign ct_rddata_c[0] = ct_rddata;
    assign ct_rddata_c[1] = ct_rddata;

    // -----------------------------
    // Two Crack Cores
    // -----------------------------
    crack1 c0 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .rdy(rdy_c[0]),
        .key(key_c[0]),
        .key_valid(key_valid_c[0]),
        .ct_addr(ct_addr_c[0]),
        .ct_rddata(ct_rddata_c[0]),
        .num_cores(num_cores),
        .id(8'd0),
        .len(),   // optional if not required by your arc4
        .pt_wrdata_out(pt_wrdata_c[0]),
        .pt_addr_out  (pt_addr_c[0]),
        .pt_wren_out  (pt_wren_c[0]),
        .copy_done(copy_done[0])
    );

    crack1 c1 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .rdy(rdy_c[1]),
        .key(key_c[1]),
        .key_valid(key_valid_c[1]),
        .ct_addr(ct_addr_c[1]),
        .ct_rddata(ct_rddata_c[1]),
        .num_cores(num_cores),
        .id(8'd1),
        .len(),
        .pt_wrdata_out(pt_wrdata_c[1]),
        .pt_addr_out  (pt_addr_c[1]),
        .pt_wren_out  (pt_wren_c[1]),
        .copy_done(copy_done[1])
    );

    // -----------------------------
    // Shared PT Memory (final output)
    // -----------------------------
    pt_mem pt (
        .address(pt_addr_c[0] | pt_addr_c[1]),
        .clock(clk),
        .data(pt_wrdata_c[0] | pt_wrdata_c[1]),
        .wren(pt_wren_c[0] | pt_wren_c[1]),
        .q()
    );

    // -----------------------------
    // Output Selection Logic
    // -----------------------------
    assign key_valid = key_valid_c[0] | key_valid_c[1];
    assign key = key_valid_c[0] ? key_c[0] :
                 key_valid_c[1] ? key_c[1] : 24'd0;

    assign rdy = rdy_c[0] & rdy_c[1];

endmodule
