module decrypter(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    // your code here
    logic [7:0] ct_addr, ct_rddata;
    logic [7:0] pt_addr, pt_rddata, pt_wrdata;
    logic pt_wren;
    logic started;
    logic arc4_rdy, arc4_en;

    logic rst_n;
    assign rst_n = KEY[3];
    
    logic [23:0] arc4_key;
    assign arc4_key = 24'h1E4600;
    //assign arc4_key = {14'd0, SW};

        always_ff @(posedge CLOCK_50) begin
        if (!rst_n) begin
            started <= 1'b0;
            arc4_en <= 1'b0;
        end
        else begin
          
            if (!started && arc4_rdy) begin
                arc4_en <= 1'b1;   
                started <= 1'b1;
            end 
            else begin
                arc4_en <= 1'b0;
            end
        end
    end


    ct_mem ct(
        .address(ct_addr),
        .clock(CLOCK_50),
        .data(8'd0),
        .wren(1'b0),
        .q(ct_rddata)
    );

    pt_mem pt(
        .address(pt_addr),
        .clock(CLOCK_50),
        .data(pt_wrdata),
        .wren(pt_wren),
        .q(pt_rddata)
    );


    
    arc4 a4(
            .clk(CLOCK_50),
            .rst_n(rst_n),
            .en(arc4_en), 
            .rdy(arc4_rdy),
            .key(arc4_key),
            .ct_addr(ct_addr),
            .ct_rddata(ct_rddata),
            .pt_addr(pt_addr),
            .pt_rddata(pt_rddata),
            .pt_wrdata(pt_wrdata),
            .pt_wren(pt_wren)
    );

    assign LEDR[9] = started;
    assign LEDR[8] = arc4_en;


endmodule: decrypter
