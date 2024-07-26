// ========================================
//  16bit Register with Increment Signal
// ========================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module register16_inc (
    input logic clk,
    input logic cpu_en,
    input logic reset,

    output logic [15:0] rdata,
    input logic [15:0] wdata,
    input logic [1:0] write,
    input logic inc
);

    logic [15:0] register = 16'h0;
    assign rdata = register;

    always_ff @(posedge clk) begin
        if (reset) begin
            register <= 16'h0;
        end else if (cpu_en) begin
            if (inc) begin
                register <= register + 16'h1;
            end else begin
                if (write[0]) begin
                    register[7:0] <= wdata[7:0];
                end
                if (write[1]) begin
                    register[15:8] <= wdata[15:8];
                end
            end
        end
    end

endmodule
