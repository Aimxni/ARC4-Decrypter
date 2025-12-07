`define IDLE 4'b0000
`define READ_SI 4'b0001
`define READ_SJ 4'b0010
`define SAVES_I 4'b0011
`define WRITE_SJ_TO_SI 4'b0100
`define WRITE_SI_TO_SJ 4'b0101
`define CALC_J 4'b0110
`define SAVES_J 4'b0111
`define LOOP_SETUP 4'b1000
`define WAIT_I 4'b1001
`define WAIT_J 4'b1010

module ksa(input logic clk, input logic rst_n,
           input logic en, output logic rdy,
           input logic [23:0] key,
           output logic [7:0] addr, input logic [7:0] rddata, output logic [7:0] wrdata, output logic wren);

   
    logic [3:0] state, next_state;

    logic rdy_n;
    logic wren_n;    

    logic [7:0]  i, i_n;    
    logic [7:0]  j, j_n; 

    // temp variables for swapping S[i] and S[j]
    logic [7:0]  ti, ti_n;
    logic [7:0]  tj, tj_n;

    // outputs next-values
    logic [7:0]  addr_n;
    logic [7:0]  wrdata_n;

    logic [7:0]  key1, key2, key3;

    // subkeys: key[i mod 3]
    logic [7:0]  key_byte;
    assign key1 = key[23:16];
    assign key2 = key[15:8];
    assign key3 = key[7:0];

    always_comb begin
        case(i % 3)
        0: key_byte = key1;
        1: key_byte = key2;
        2: key_byte = key3;
		  default: key_byte = key1;
        endcase
    end
        
    // Change states
    always_ff @(posedge clk) begin
        if (!rst_n)
            state <= `IDLE;
        else
            state <= next_state;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rdy <= 1'b1;
            wren <= 1'b0;
            addr <= 8'd0;
            wrdata <= 8'd0;

            i <= 8'd0;
            j <= 8'd0;
            ti <= 8'd0;
            tj <= 8'd0;
        end else begin
            rdy <= rdy_n;
            wren <= wren_n;

            i <= i_n;
            j <= j_n;

            ti <= ti_n;
            tj <= tj_n;

            addr <= addr_n;     
            wrdata <= wrdata_n;   
        end
    end


    always_comb begin
        // defaults
        next_state = state;
        rdy_n      = 1'b0;
        wren_n     = 1'b0;

        i_n        = i;
        j_n        = j;

        addr_n     = addr;
        wrdata_n   = wrdata;
        ti_n       = ti;
        tj_n       = tj;
        case(state)
        `IDLE: begin
            rdy_n = 1'b1;

            if (en) begin
                rdy_n      = 1'b0;
                i_n        = 8'd0;
                j_n        = 8'd0;
                addr_n     = i;
                next_state = `READ_SI;
            end
        end

        `READ_SI: begin
            next_state = `WAIT_I;
        end

        `WAIT_I: begin
            ti_n = rddata;                       
            next_state = `SAVES_I;
        end

        `SAVES_I: begin
            
            next_state = `CALC_J;
            j_n = (j + ti_n + key_byte);
        end


        `CALC_J: begin
            addr_n = j_n;            
            next_state = `READ_SJ; 

        end

        `READ_SJ: begin
            next_state = `WAIT_J;
        end

        `WAIT_J: begin
            tj_n = rddata;
            next_state = `SAVES_J;
        end

        `SAVES_J: begin
            wren_n = 1'b1;
            addr_n = i;
            wrdata_n = tj;
            next_state = `WRITE_SI_TO_SJ;
        end

        `WRITE_SI_TO_SJ: begin 
            wren_n = 1'b1;
            addr_n = j;
            wrdata_n = ti;
            next_state = `WRITE_SJ_TO_SI;
        end

        `WRITE_SJ_TO_SI: begin

            if (i == 8'd255) begin
                rdy_n      = 1'b1;
                next_state = `IDLE;
            end else begin
                i_n = i + 8'd1;
                addr_n = i + 8'd1;
                next_state = `READ_SI;
            end

        end

        default: begin
            next_state = `IDLE;
            wren_n = 1'b0;
            addr_n = 8'd0;
            wrdata_n = 1'b0;
        end

        endcase
    end


endmodule: ksa
