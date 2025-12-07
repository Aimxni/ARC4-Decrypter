`define IDLE 2'b00
`define WRITE 2'b01
`define FINISH 2'b10


module init(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            output logic [7:0] addr, output logic [7:0] wrdata, output logic wren);

logic [1:0] state, next_state;
logic [7:0] i, i_n;
logic wren_n;
logic rdy_n;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        state <= `IDLE;
    end
    else begin
        state <= next_state;
    end
end

always_ff @(posedge clk)begin
    if(!rst_n)begin
        rdy <= 1'b1;
        addr <= 8'd0;
        wrdata <= 8'd0;
        wren <= 1'b0;
        i <= 8'd0;
  
    end
    else begin
        rdy <= rdy_n;
        i <= i_n;
        addr <= i;
        wrdata <= i;
        wren <= wren_n;
     
    end
end

always_comb begin
    i_n = i;
    next_state = state;
    wren_n = 1'b0;
    rdy_n = 1'b0;

    case(state)
    `IDLE: begin
        rdy_n = 1'b1;
        if(en)begin
            next_state = `WRITE;
            i_n = 8'd0;
            rdy_n = 1'b0;
        end
    end

    `WRITE: begin
        wren_n = 1'b1;
        if(i == 8'd255)begin
            next_state = `FINISH;
        end
        else begin
            i_n = i + 8'd1;
        end
    end

    `FINISH: begin
        wren_n = 1'b0;
        rdy_n = 1'b1;
        next_state = `IDLE;
    end
    default: next_state = `IDLE;
    endcase

end


    




endmodule: init