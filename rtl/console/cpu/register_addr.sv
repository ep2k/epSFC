// ========================================
//  24bit Register for Address Registers
// ========================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module register_addr (
    input logic clk,
    input logic cpu_en,
    input logic reset,

    output logic [23:0] rdata,
    input logic [23:0] wdata,
    input logic [2:0] write,

    input logic inc,
    input logic page_wrap,
    input logic bank_inc
);

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [23:0] register = 24'h0;

    // ------------------------------
    //  Main
    // ------------------------------

    assign rdata = register;

    always_ff @(posedge clk) begin
        if (reset) begin
            register <= 24'h0;
        end else if (cpu_en) begin
            if (inc) begin
                if (page_wrap) begin
                    register[7:0] <= register[7:0] + 8'h1;
                end else begin
                    register <= register + 24'h1;
                end
            end else begin
                register[23:16] <= register[23:16] + bank_inc;
                if (write[0]) begin
                    register[7:0] <= wdata[7:0];
                end
                if (write[1]) begin
                    register[15:8] <= wdata[15:8];
                end
                if (write[2]) begin
                    register[23:16] <= wdata[23:16] + bank_inc;
                end
            end
        end
    end

endmodule
