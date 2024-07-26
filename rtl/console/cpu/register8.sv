// ==============================
//  8bit Register
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

/*
    WRITE_MODE = 0:
        Stores value when write = 1
    WRITE_MODE = 1:
        Stores bits corresponding to the bits set in the write[7:0] signal
*/

module register8 #(parameter WRITE_MODE = 0) (
    input logic clk,
    input logic cpu_en,
    input logic reset,

    output logic [7:0] rdata,
    input logic [7:0] wdata,

    input logic [select_width(WRITE_MODE)-1:0] write
);

    logic [7:0] register = 8'h0;
    assign rdata = register;

    always_ff @(posedge clk) begin
        if (reset) begin
            register <= 8'h0;
        end else if (cpu_en) begin
            if (WRITE_MODE == 1) begin
                register <= (register & (~write)) | (wdata & write);
            end else begin
                register <= write ? wdata : register;
            end
        end
    end

    function automatic int select_width(input int write_mode);
        if (write_mode == 1)
            return 8;
        else
            return 1;
    endfunction

endmodule
