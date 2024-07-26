// ==============================
//  Work RAM (128KB)
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module wram
    import bus_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input logic [16:0] addr_a,
    input logic wram_en,
    input logic a_write,

    input b_op_type b_op,

    input logic [7:0] wdata,
    output logic [7:0] rdata
);

    logic [16:0] addr_b = 17'h0;

    bram_wram bram_wram(        // IP (RAM: 1-PORT, 8bit*131072)
        .address(wram_en ? addr_a : addr_b),
        .clock(clk),
        .data(wdata),
        .wren(cpu_en & ((wram_en & a_write) | (b_op == B_WMDATA_W))),
        .q(rdata)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            addr_b <= 17'h0;
        end else if (cpu_en) begin
            if (b_op == B_WMADDL) begin
                addr_b[7:0] <= wdata;
            end else if (b_op == B_WMADDM) begin
                addr_b[15:8] <= wdata;
            end else if (b_op == B_WMADDH) begin
                addr_b[16] <= wdata[0];
            end else if ((b_op == B_WMDATA_R) | (b_op == B_WMDATA_W)) begin
                addr_b <= addr_b + 17'h1;
            end
        end
    end

endmodule
