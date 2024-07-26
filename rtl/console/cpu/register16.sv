// ==============================
//  16bit Register
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module register16 #(parameter logic [15:0] INIT = 16'h0) (
    input logic clk,
    input logic cpu_en,
    input logic reset,

    output logic [15:0] rdata,
    input logic [15:0] wdata,
    input logic [1:0] write
);

    logic [15:0] register = INIT;
    assign rdata = register;

    always_ff @(posedge clk) begin
        if (reset) begin
            register <= INIT;
        end else if (cpu_en) begin
            if (write[0]) begin
                register[7:0] <= wdata[7:0];
            end
            if (write[1]) begin
                register[15:8] <= wdata[15:8];
            end
        end
    end

endmodule
