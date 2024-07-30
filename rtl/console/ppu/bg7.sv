// ==============================
//  BG Mode 7 (Rotation/Scaling)
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module bg7
    import ppu_pkg::*;
(
    input logic clk,
    input logic reset,
    input logic dot_en,
    input logic [2:0] dot_ctr,

    input logic [3:0] m7sel,

    input logic [15:0] m7_a,
    input logic [15:0] m7_b,
    input logic [15:0] m7_c,
    input logic [15:0] m7_d,

    input logic [12:0] m7_xofs,
    input logic [12:0] m7_yofs,
    input logic [12:0] m7_xorig,
    input logic [12:0] m7_yorig,

    input logic [7:0] x,
    input logic [7:0] y,

    output logic [14:0] vram_l_addr,
    output logic [14:0] vram_h_addr,
    input logic [7:0] vram_rdata_l,
    input logic [7:0] vram_rdata_h,

    output logic [7:0] pixel,
    output logic black
);
    
    // ------------------------------
    //  Wires
    // ------------------------------

    logic signed [15:0] mul1_a, mul2_a;     // A, B, C, D
    logic signed [12:0] mul1_b, mul2_b;     // X + XOFS - XO, Y + YOFS - YO
                                            // (12(+1)bit + 12(+1)bit + 8bit -> Max. 12(+1)bit)
    logic signed [27:0] mul1_y, mul2_y;     // 15bit+12bit+1bit=28bit

    logic [27:0] vram_x_calc, vram_y_calc;

    logic transparent_0, black_0;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [27:0] mul1_y_reg_0, mul1_y_reg_1;
    logic [27:0] mul2_y_reg_0, mul2_y_reg_1;

    logic [9:0] vram_x, vram_y;                     // map fetch で使用
    logic [2:0] vram_x_prev_2_0, vram_y_prev_2_0;   // data fetch で使用
    logic [2:0] screen_over;                        // スクリーンオーバーの有無を記録するシフトレジスタ
                                                    // VRAM.X/Y計算 -> map fetch -> data fetch で 3クロック遅れる

    logic [7:0] tile_index;
    logic [7:0] pixel_raw;

    logic [7:0] pixel_shifter[6:0];     // x_midに合わせるために7クロック遅らせて出力
    logic [6:0] black_shifter;

    // ------------------------------
    //  Main
    // ------------------------------
    
    // ---- Multiplier --------

    /*
        Mul1:
            t=0(VRAM.X): A * (X + XOFS - XO)
            t=1(VRAM.Y): C * (X + XOFS - XO)
        Mul2:
            t=0(VRAM.X): B * (Y + YOFS - YO)
            t=1(VRAM.Y): D * (Y + YOFS - YO)
    */

    assign mul1_a = dot_ctr[0] ? m7_c : m7_a;
    assign mul1_b = {5'h0, m7sel[0] ? (~x) : x} + m7_xofs - m7_xorig;       // x_flip if m7sel[0]=1

    assign mul2_a = dot_ctr[0] ? m7_d : m7_b;
    assign mul2_b = {5'h0, m7sel[1] ? (~y) : y} + m7_yofs - m7_yorig;       // y_flip if m7sel[1]=1

    assign mul1_y = $signed(mul1_a) * $signed(mul1_b);
    assign mul2_y = $signed(mul2_a) * $signed(mul2_b);

    always_ff @(posedge clk) begin
        if (dot_ctr == 3'd0) begin
            mul1_y_reg_0 <= mul1_y;
            mul2_y_reg_0 <= mul2_y;
        end else if (dot_ctr == 3'd1) begin
            mul1_y_reg_1 <= mul1_y;
            mul2_y_reg_1 <= mul2_y;
        end
    end

    // ---- VRAM.X/Y Calculation --------

    /*
        VRAM.X = (A(X + XOFS - XO) + B(Y + YOFS - YO) + XO << 8) >> 8
        VRAM.Y = (C(X + XOFS - XO) + D(Y + YOFS - YO) + YO << 8) >> 8
    */

    assign vram_x_calc = mul1_y_reg_0 + mul2_y_reg_0 + {{7{m7_xorig[12]}}, m7_xorig, 8'h0};
    assign vram_y_calc = mul1_y_reg_1 + mul2_y_reg_1 + {{7{m7_yorig[12]}}, m7_yorig, 8'h0};

    always_ff @(posedge clk) begin
        if (dot_en) begin
            vram_x <= vram_x_calc[17:8];
            vram_y <= vram_y_calc[17:8];

            vram_x_prev_2_0 <= vram_x[2:0];
            vram_y_prev_2_0 <= vram_y[2:0];

            screen_over <= {
                screen_over[1:0],
                (vram_x_calc[27:18] != 10'h0) | (vram_y_calc[27:18] != 10'h0)
            };
        end
    end

    // ---- VRAM Access --------

    // Tilemap Address
    assign vram_l_addr = {1'b0, vram_y[9:3], vram_x[9:3]};

    always_ff @(posedge clk) begin
        if (dot_en) begin
            tile_index <= vram_rdata_l;
        end
    end

    // Tile Data Address
    assign vram_h_addr = {1'b0, tile_index, vram_y_prev_2_0, vram_x_prev_2_0};

    always_ff @(posedge clk) begin
        if (dot_en) begin
            pixel_raw <= vram_rdata_h;
        end
    end

    // ---- Pixel Output --------

    assign transparent_0 = screen_over[2] & (m7sel[3:2] == 2'b10);
    assign black_0 = screen_over[2] & (m7sel[3:2] == 2'b11);

    always_ff @(posedge clk) begin
        if (dot_en) begin

            pixel_shifter[0] <= transparent_0 ? 8'h0 : pixel_raw;
            for (int i = 0; i < 6; i++) begin
                pixel_shifter[i+1] <= pixel_shifter[i];
            end

            black_shifter[0] <= black_0;
            black_shifter[6:1] <= black_shifter[5:0];

        end
    end

    assign pixel = pixel_shifter[6];
    assign black = black_shifter[6];

endmodule
