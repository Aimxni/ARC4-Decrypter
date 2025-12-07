`define RESET_WAIT 4'b0000  // idle, waiting for en
`define INIT_START 4'b0001  // 1-cycle pulse init.en
`define INIT_BUSY  4'b0010  // wait for init.rdy
`define KSA_START  4'b0011  // 1-cycle pulse ksa.en
`define KSA_BUSY   4'b0100  // wait for ksa.rdy
`define PRGA_START 4'b0101  // 1-cycle pulse prga.en
`define PRGA_BUSY  4'b0110  // wait for prga.rdy

module arc4(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,
    output logic        rdy,
    input  logic [23:0] key,
    output logic [7:0]  ct_addr,
    input  logic [7:0]  ct_rddata,
    output logic [7:0]  pt_addr,
    input  logic [7:0]  pt_rddata,
    output logic [7:0]  pt_wrdata,
    output logic        pt_wren
);

    // ============================================================
    // State register
    // ============================================================
    logic [3:0] state, next_state;

    always_ff @(posedge clk) begin
        if (!rst_n)
            state <= `RESET_WAIT;
        else
            state <= next_state;
    end

    // ============================================================
    // Wires to S memory
    // ============================================================
    logic [7:0] s_addr;
    logic [7:0] s_wrdata;
    logic [7:0] s_rddata;
    logic       s_wren;

    // ============================================================
    // init interface
    // ============================================================
    logic        init_rdy;
    logic        init_en;
    logic [7:0]  init_addr;
    logic [7:0]  init_wrdata;
    logic        init_wren;

    // ============================================================
    // ksa interface
    // ============================================================
    logic        ksa_rdy;
    logic        ksa_en;
    logic [7:0]  ksa_addr;
    logic [7:0]  ksa_wrdata;
    logic        ksa_wren;

    // ============================================================
    // prga interface
    // ============================================================
    logic        prga_rdy;
    logic        prga_en;
    logic [7:0]  prga_addr;
    logic [7:0]  prga_wrdata;
    logic        prga_wren;

    // ============================================================
    // Local reset for submodules (like mod_rst_n in the reference)
    //   - hold them in reset while idle
    //   - release reset once we start the pipeline
    // ============================================================
    logic mod_rst_n;
    assign mod_rst_n = (state != `RESET_WAIT);        // 0 in idle, 1 in all other states
    logic sub_rst_n;
    assign sub_rst_n = rst_n & mod_rst_n;             // global reset AND local pipeline reset

    // ============================================================
    // Top-level control FSM
    //
    // Sequence per "job" (one key decrypt):
    //   RESET_WAIT  --(en && init_rdy)--> INIT_START
    //   INIT_START  -> INIT_BUSY
    //   INIT_BUSY   --(init_rdy)-------> KSA_START
    //   KSA_START   -> KSA_BUSY
    //   KSA_BUSY    --(ksa_rdy)--------> PRGA_START
    //   PRGA_START  -> PRGA_BUSY
    //   PRGA_BUSY   --(prga_rdy)-------> RESET_WAIT
    //
    // rdy is high only in RESET_WAIT.
    // init_en / ksa_en / prga_en are 1-cycle pulses in *_START states.
    // ============================================================
    always_comb begin
        // defaults
        next_state = state;
        init_en    = 1'b0;
        ksa_en     = 1'b0;
        prga_en    = 1'b0;
        rdy        = 1'b0;

        case (state)

        // --------------------------------------------------------
        // Idle / ready for a new request from crack
        // --------------------------------------------------------
        `RESET_WAIT: begin
            rdy = 1'b1;   // ARC4 ready for new "en"
            // start a new decrypt when en is high and init is ready
            if (en && init_rdy) begin
                next_state = `INIT_START;
            end
        end

        // --------------------------------------------------------
        // INIT: 1-cycle start pulse
        // --------------------------------------------------------
        `INIT_START: begin
            // one-cycle pulse to start init
            init_en    = 1'b1;
            rdy        = 1'b0;
            next_state = `INIT_BUSY;
        end

        // --------------------------------------------------------
        // Wait for INIT to finish
        // --------------------------------------------------------
        `INIT_BUSY: begin
            rdy = 1'b0;
            // when init_rdy goes high again, move on to KSA
            if (init_rdy) begin
                next_state = `KSA_START;
            end
        end

        // --------------------------------------------------------
        // KSA: 1-cycle start pulse
        // --------------------------------------------------------
        `KSA_START: begin
            ksa_en     = 1'b1;
            rdy        = 1'b0;
            next_state = `KSA_BUSY;
        end

        // --------------------------------------------------------
        // Wait for KSA to finish
        // --------------------------------------------------------
        `KSA_BUSY: begin
            rdy = 1'b0;
            if (ksa_rdy) begin
                next_state = `PRGA_START;
            end
        end

        // --------------------------------------------------------
        // PRGA: 1-cycle start pulse (this will write PT)
        // --------------------------------------------------------
        `PRGA_START: begin
            prga_en    = 1'b1;
            rdy        = 1'b0;
            next_state = `PRGA_BUSY;
        end

        // --------------------------------------------------------
        // Wait for PRGA to finish (plaintext fully written)
        // --------------------------------------------------------
        `PRGA_BUSY: begin
            rdy = 1'b0;
            if (prga_rdy) begin
                // one full decrypt done → back to idle, rdy=1
                next_state = `RESET_WAIT;
            end
        end

        default: begin
            next_state = `RESET_WAIT;
            rdy        = 1'b1;
        end
        endcase
    end

    // ============================================================
    // S memory arbitration
    //   init uses S first, then ksa, then prga.
    //   Only one of them runs at a time.
    // ============================================================
    logic use_init, use_ksa, use_prga;

    assign use_init = (state == `INIT_START) || (state == `INIT_BUSY);
    assign use_ksa  = (state == `KSA_START)  || (state == `KSA_BUSY);
    assign use_prga = (state == `PRGA_START) || (state == `PRGA_BUSY);

    always_comb begin
        if (use_init) begin
            s_addr   = init_addr;
            s_wrdata = init_wrdata;
            s_wren   = init_wren;
        end else if (use_ksa) begin
            s_addr   = ksa_addr;
            s_wrdata = ksa_wrdata;
            s_wren   = ksa_wren;
        end else if (use_prga) begin
            s_addr   = prga_addr;
            s_wrdata = prga_wrdata;
            s_wren   = prga_wren;
        end else begin
            s_addr   = 8'd0;
            s_wrdata = 8'd0;
            s_wren   = 1'b0;
        end
    end

    // ============================================================
    // Memory + submodules
    // ============================================================
    s_mem s(
        .address(s_addr),
        .clock  (clk),
        .data   (s_wrdata),
        .wren   (s_wren),
        .q      (s_rddata)
    );

    init i(
        .clk   (clk),
        .rst_n (sub_rst_n),   // local reset + global reset
        .en    (init_en),
        .rdy   (init_rdy),
        .addr  (init_addr),
        .wrdata(init_wrdata),
        .wren  (init_wren)
    );

    ksa k(
        .clk   (clk),
        .rst_n (sub_rst_n),
        .en    (ksa_en),
        .rdy   (ksa_rdy),
        .key   (key),
        .addr  (ksa_addr),
        .rddata(s_rddata),
        .wrdata(ksa_wrdata),
        .wren  (ksa_wren)
    );

    prga p(
        .clk      (clk),
        .rst_n    (sub_rst_n),
        .en       (prga_en),
        .rdy      (prga_rdy),
        .key      (key),
        .s_addr   (prga_addr),
        .s_rddata (s_rddata),
        .s_wrdata (prga_wrdata),
        .s_wren   (prga_wren),
        .ct_addr  (ct_addr),
        .ct_rddata(ct_rddata),
        .pt_addr  (pt_addr),
        .pt_rddata(pt_rddata),
        .pt_wrdata(pt_wrdata),
        .pt_wren  (pt_wren)
    );

endmodule: arc4
