// ==============================
//  VGA Controller
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`include "config.vh"

module vga_controller (
    input logic clk,            // 25.175MHz
    input logic overscan,
    input logic interlace,

    output logic [8:0] y_next,  // to SDRAM Row
    output logic r_req,

    output logic [8:0] x_next,  // to r_buf
    input  logic [14:0] color,  // from r_buf

    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,
    output logic vga_hs,
    output logic vga_vs
);

    // ------------------------------
    //  Parameters
    // ------------------------------

    localparam H_SYNC = 10'd96;
    localparam H_BACK = `VGA_H_BACK;
    localparam H_ACTIVE = 10'd640;
    localparam H_FRONT = 10'd64 - `VGA_H_BACK;
    localparam H_MAX = H_SYNC + H_BACK + H_ACTIVE + H_FRONT - 10'd1;

    localparam V_SYNC = 10'd2;
    localparam V_BACK = `VGA_V_BACK;
    localparam V_ACTIVE = 10'd480;
    localparam V_FRONT = 10'd43 - `VGA_V_BACK;
    localparam V_MAX = V_SYNC + V_BACK + V_ACTIVE + V_FRONT - 10'd1;

    localparam H_BAR = 10'd64;

    // ------------------------------
    //  Wires
    // ------------------------------

    logic [9:0] v_bar;
    logic h_visible, v_visible;

    logic [8:0] y_next_raw;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [9:0] h_count = 10'd0;    // 0 ~ 799
    logic [9:0] v_count = 10'd0;    // 0 ~ 524

    logic [14:0] color_reg = 15'h0;

    // ------------------------------
    //  Main
    // ------------------------------
    
    assign v_bar = overscan ? 10'd1 : 10'd16;

    assign y_next_raw = v_count - (V_SYNC + V_BACK + v_bar) + 1;
    assign y_next = {y_next_raw[8:1], interlace & y_next_raw[0]};
    assign r_req = (h_count[9:1] == 0);

    // color_regへの書き込みに1クロック
    assign x_next = h_count - (H_SYNC + H_BACK + H_BAR) + 1;

    always_comb begin
        if (~(h_visible & v_visible)) begin
            {vga_r, vga_g, vga_b} = 12'h0;
        end else begin
            vga_r = color_reg[4:1];
            vga_g = color_reg[9:6];
            vga_b = color_reg[14:11];
        end
    end

    // dr_clk -> vga_clk
    always_ff @(posedge clk) begin
        color_reg <= color;
    end

    // ---- Horizontal --------

    assign vga_hs = (h_count >= H_SYNC);
    assign h_visible =
            (h_count >= H_SYNC + H_BACK + H_BAR)
            & (h_count < H_SYNC + H_BACK + H_ACTIVE - H_BAR);
    
    always_ff @(posedge clk) begin
        h_count <= (h_count == H_MAX) ? 10'd0 : (h_count + 10'd1);
    end

    // ---- Vertical --------
    
    assign vga_vs = (v_count >= V_SYNC);
    assign v_visible =
            (v_count >= V_SYNC + V_BACK + v_bar)
            & (v_count < V_SYNC + V_BACK + V_ACTIVE - v_bar);

    always_ff @(posedge clk) begin
        if (h_count == H_MAX) begin
            v_count <= (v_count == V_MAX) ? 10'd0 : (v_count + 10'd1);
        end
    end
    
endmodule
