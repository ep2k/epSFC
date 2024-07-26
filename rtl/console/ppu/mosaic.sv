// ==============================
//  BG Mosaic Controller
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module mosaic (
    input logic clk,
    input logic reset,
    input logic dot_en,

    input logic newframe,
    input logic newline,
    input logic period_start,

    input logic [3:0] size,
    output logic pixel_strobe,
    output logic [3:0] yofs_subtract
);

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [3:0] x_ctr = 4'h0;
    logic [3:0] y_ctr = 4'h0;

    // ------------------------------
    //  Main
    // ------------------------------

    // ---- Horizontal --------
    // ブロック初めにpixelを保存(bg内で保存)

    assign pixel_strobe = (x_ctr == 4'h0);

    always_ff @(posedge clk) begin
        if (reset) begin
            x_ctr <= 4'h0;
        end else if (dot_en) begin
            if (period_start) begin
                x_ctr <= 4'h0;
            end else begin
                x_ctr <= (x_ctr == size) ? 4'h0 : (x_ctr + 4'h1);
            end
        end
    end

    // ---- Vertical --------
    // yofsをオフセット分引きブロック最初の行にする(bgに入力するyofsで引く)

    assign yofs_subtract = y_ctr;

    always_ff @(posedge clk) begin
        if (reset) begin
            y_ctr <= 4'h0;
        end else if (dot_en) begin
            if (newframe) begin
                y_ctr <= 4'h0;
            end else if (newline) begin
                y_ctr <= (y_ctr == size) ? 4'h0 : (y_ctr + 4'h1);
            end
        end
    end

endmodule
