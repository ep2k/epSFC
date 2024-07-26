// ==============================
//  Refresh Signal Controller
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module refresh_controller (
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input logic start,
    output logic refresh
);
    
    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [5:0] ctr = 6'd0;
    logic start_reg = 1'b0;
    logic start_prev;

    // ------------------------------
    //  Main
    // ------------------------------

    assign refresh = (ctr != 6'd0);

    always_ff @(posedge clk) begin
        start_prev <= start;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            start_reg <= 1'b0;
        end else if ((~start_prev) & start) begin
            start_reg <= 1'b1;
        end else if (cpu_en) begin
            start_reg <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            ctr <= 6'd0;
        end else if (start_reg & cpu_en) begin
            ctr <= 6'd1;
        end else if (ctr != 6'd0) begin
            ctr <= (ctr == 6'd40) ? 6'd0 : (ctr + 6'd1);
        end
    end
    
endmodule
