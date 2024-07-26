// ==============================
//  ΔΣ Digital-Analog Converter
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module delta_sigma #(parameter int WIDTH = 9) (
    input  logic clk,
    input  logic [WIDTH-1:0] data_in,
    output logic pulse_out
);

    logic [WIDTH-1:0] data_in_reg = 0;
    logic [WIDTH:0] sigma_reg = '1; // 初期値-1

    always_ff @(posedge clk) begin
        data_in_reg <= data_in;
        sigma_reg <= sigma_reg + {pulse_out, data_in_reg};
    end

    assign pulse_out = ~sigma_reg[WIDTH];
    
endmodule
