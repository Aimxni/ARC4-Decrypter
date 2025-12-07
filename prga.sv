`define  IDLE           5'b00000
`define  READ_CT_L      5'b00001
`define  WAIT_CT_L      5'b00010
`define  SAVE_CT_L      5'b00011
`define  CALC_I         5'b00100
`define  READ_SI        5'b00101 
`define  CALC_J         5'b00110
`define  READ_SJ        5'b00111
`define  WAIT_SJ        5'b01000
`define  SAVES_J        5'b01001
`define  WRITE_SI_TO_SJ 5'b01010
`define  WRITE_SJ_TO_SI 5'b01011
`define  READ_SK        5'b01100
`define  WAIT_SK        5'b01101
`define  SAVES_K        5'b01110
`define  FINISH_K       5'b01111
`define  WRITE          5'b10000   // unused, but kept
`define  WAIT_SI        5'b10001
`define  WAIT_ADDR      5'b10011
`define  INC_K          5'b10100
`define SAVE_SJ         5'b10101

module prga(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] s_addr, input logic [7:0] s_rddata, output logic [7:0] s_wrdata, output logic s_wren,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    logic [4:0] state, next_state;
    
    logic [7:0] i, j, k;
    logic [7:0] length;
    logic [7:0] si, sj, pad;

    logic [7:0]  key1, key2, key3;

    // subkeys: key[i mod 3]
    logic [7:0]  key_byte;
    assign key1 = key[23:16];
    assign key2 = key[15:8];
    assign key3 = key[7:0];

    
    logic [7:0] i_n, j_n, k_n;
    logic [7:0] length_n;
    logic [7:0] si_n, sj_n, pad_n;

    
    logic [7:0] s_addr_n, s_wrdata_n;
    logic s_wren_n;
    logic [7:0] ct_addr_n;
    logic [7:0] pt_addr_n, pt_wrdata_n;
    logic pt_wren_n;
    logic rdy_n;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state     <= `IDLE;
            i         <= 8'd0;
            j         <= 8'd0;
            k         <= 8'd0;
            length    <= 8'd0;
            si        <= 8'd0;
            sj        <= 8'd0;
            pad       <= 8'd0;

            s_addr    <= 8'd0;
            s_wrdata  <= 8'd0;
            s_wren    <= 1'b0;
            ct_addr   <= 8'd0;
            pt_addr   <= 8'd0;
            pt_wrdata <= 8'd0;
            pt_wren   <= 1'b0;
            rdy       <= 1'b1;
        end else begin
            state     <= next_state;
            i         <= i_n;
            j         <= j_n;
            k         <= k_n;
            length    <= length_n;
            si        <= si_n;
            sj        <= sj_n;
            pad       <= pad_n;

            s_addr    <= s_addr_n;
            s_wrdata  <= s_wrdata_n;
            s_wren    <= s_wren_n;
            ct_addr   <= ct_addr_n;
            pt_addr   <= pt_addr_n;
            pt_wrdata <= pt_wrdata_n;
            pt_wren   <= pt_wren_n;
            rdy       <= rdy_n;
        end
    end

    always_comb begin
        next_state    = state;
        rdy_n         = 1'b0;

        i_n           = i;
        j_n           = j;
        k_n           = k;
        length_n      = length;
        si_n          = si;
        sj_n          = sj;
        pad_n         = pad;

        s_addr_n      = s_addr;
        s_wrdata_n    = s_wrdata;
        s_wren_n      = 1'b0;     
        ct_addr_n     = ct_addr;
        pt_addr_n     = pt_addr;
        pt_wrdata_n   = pt_wrdata;
        pt_wren_n     = 1'b0;     

        case (state)
            `IDLE: begin
                rdy_n = 1'b1;
                if (en) begin
                    rdy_n     = 1'b0;
                    i_n       = 8'd0;
                    j_n       = 8'd0;
                    k_n       = 8'd0;
                    ct_addr_n = 8'd0;
                    next_state = `READ_CT_L;
                end
            end

           `READ_CT_L: begin
                next_state = `WAIT_CT_L;
            end

            `WAIT_CT_L: begin
                length_n    = ct_rddata; 
                pt_addr_n   = 8'd0;
                pt_wrdata_n = ct_rddata;
                pt_wren_n   = 1'b1;
                k_n         = 8'd1;
                next_state  = `SAVE_CT_L;
            end

            `SAVE_CT_L: begin
                next_state = `CALC_I;
            end

            `CALC_I: begin
                i_n       = i + 8'd1;
                s_addr_n  = i + 8'd1;
                next_state = `WAIT_SI;
            end

            `WAIT_SI: begin
                next_state = `READ_SI;
            end

            `READ_SI: begin
                si_n      = s_rddata;          
                j_n       = j + s_rddata;      
                s_addr_n  = j + s_rddata;      
                next_state = `CALC_J;
            end

            `CALC_J: begin
                next_state = `SAVE_SJ;
            end

            `SAVE_SJ: begin
                 sj_n      = s_rddata; 
                 next_state = `READ_SJ;
            end


            `READ_SJ: begin         
                s_addr_n   = i;
                s_wrdata_n = sj;
                s_wren_n   = 1'b1;
                next_state = `SAVES_J;
            end

            `SAVES_J: begin
                s_addr_n   = j;
                s_wrdata_n = si;
                s_wren_n   = 1'b1;
                next_state = `WRITE_SI_TO_SJ;
            end

            `WRITE_SI_TO_SJ: begin
                s_addr_n   = si + sj;
                next_state = `WAIT_ADDR;
            end

            `WAIT_ADDR: begin
                next_state = `WRITE_SJ_TO_SI;
            end

            `WRITE_SJ_TO_SI: begin
                pad_n      = s_rddata;   
                ct_addr_n  = k;         
                next_state = `READ_SK;
            end

            `READ_SK: begin
                next_state = `WAIT_SK;
            end

            `WAIT_SK: begin
                pt_addr_n   = k;
                pt_wrdata_n = pad ^ ct_rddata;   
                pt_wren_n   = 1'b1;
                next_state  = `SAVES_K;
            end

            `SAVES_K: begin
                next_state = `INC_K;
            end

            `INC_K: begin
                if(k >= length)begin
                    next_state = `FINISH_K;
                end
                else begin
                    k_n = k + 8'd1;
                next_state = `CALC_I;
                end
            end

            `FINISH_K: begin
                rdy_n = 1'b1;
                next_state = `IDLE;
            end

            default: begin
                next_state = `IDLE;
                rdy_n      = 1'b1;
            end
        endcase
    end

endmodule : prga