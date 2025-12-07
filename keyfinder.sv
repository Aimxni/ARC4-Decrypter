module keyfinder(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
 output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
output logic [9:0] LEDR);
/*
 * This module connects the de1-soc's interface to allow the user to import
 * a ciphertext and then enable the cracking algorithm
 * it outputs the key found to the 7seg display
 */

 logic [7:0] ct_addr, ct_rddata;
 logic key_valid;
 logic [23:0] key;
 logic crack_en, crack_rdy, rst_n;
 logic [6:0] seg_HEX0, seg_HEX1, seg_HEX2, seg_HEX3, seg_HEX4, seg_HEX5;
 logic [4:0] state;
 logic [3:0] hex0, hex1, hex2, hex3, hex4, hex5;

/*
 * State Encoding
 * 0: rst_n
 * 1: crack_en
 * rest are state
 */
parameter IDLE = 5'b111_00,
 EN_C = 5'b001_11,
 CONT = 5'b010_01,
 DONE = 5'b011_01,
 FAIL = 5'b100_01;

/* HEX */
always_comb begin : hex
if (state === DONE) begin
{hex5, hex4, hex3, hex2, hex1, hex0} = key;
 HEX0 = seg_HEX0;
 HEX1 = seg_HEX1;
 HEX2 = seg_HEX2;
 HEX3 = seg_HEX3;
 HEX4 = seg_HEX4;
 HEX5 = seg_HEX5;
end
else if (state == FAIL) begin
{hex5, hex4, hex3, hex2, hex1, hex0} = '0;
 HEX0 = 7'b0111111;
 HEX1 = 7'b0111111;
 HEX2 = 7'b0111111;
 HEX3 = 7'b0111111;
 HEX4 = 7'b0111111;
 HEX5 = 7'b0111111;
end
else begin
{hex5, hex4, hex3, hex2, hex1, hex0} = '0;
 HEX0 = 7'b1111111;
 HEX1 = 7'b1111111;
 HEX2 = 7'b1111111;
 HEX3 = 7'b1111111;
 HEX4 = 7'b1111111;
 HEX5 = 7'b1111111;
end
end

always_ff @(posedge CLOCK_50) begin : state_transitions
if (~KEY[3])
state <= IDLE;
else begin
case (state)
 IDLE: state <= crack_rdy ? EN_C : IDLE;
 EN_C: state <= CONT;
 CONT: begin
if (key_valid && crack_rdy)
state <= DONE;
else if (~key_valid && crack_rdy)
state <= FAIL;
else
state <= CONT;
end
 FAIL: state <= FAIL;
 DONE: state <= DONE;
default: state <= 5'd0;
endcase
end
end

always_comb begin : state_encoding
rst_n = state[0];
crack_en = state[1];
end

ct_mem ct(
 .address(ct_addr),
 .clock(CLOCK_50),
 .data(),
 .wren(1'd0),
 .q(ct_rddata)
 );
crack c(
 .clk(CLOCK_50),
 .rst_n(rst_n),
 .en(crack_en),
 .rdy(crack_rdy),
 .key(key),
 .key_valid(key_valid),
 .ct_addr(ct_addr),
 .ct_rddata(ct_rddata)
 );
hex7seg key2_0(.hex(hex0), .seg7(seg_HEX0));
hex7seg key2_1(.hex(hex1), .seg7(seg_HEX1));
hex7seg key1_0(.hex(hex2), .seg7(seg_HEX2));
hex7seg key1_1(.hex(hex3), .seg7(seg_HEX3));
hex7seg key0_0(.hex(hex4), .seg7(seg_HEX4));
hex7seg key0_1(.hex(hex5), .seg7(seg_HEX5));
endmodule: keyfinder