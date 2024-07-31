// ==============================
//  Pixel Mixer
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module pixel_mixer
    import ppu_pkg::*;
(
    input logic clk,
    input logic [1:0] step,

    input bg_pixel_type bg_pixel[3:0],
    input obj_pixel_type obj_pixel,
    input logic bg7_black,
    
    input logic [2:0] bgmode,
    input logic bg3_prior,
    input logic high_res,
    input logic use_direct_color,

    input logic [4:0] main_enable,
    input logic [4:0] sub_enable,

    input logic in_win_math,
    input logic [1:0] main_black,
    input logic use_sub,
    input logic [7:0] math_control,
    input logic [1:0] math_area,

    output logic [7:0] cgram_addr,
    input logic [14:0] cgram_rdata,

    input logic [14:0] sub_backdrop,

    output logic [14:0] color_left,
    output logic [14:0] color_right
);

    genvar gi;
    
    // ------------------------------
    //  Wires
    // ------------------------------

    refer_pal_type refer_pal_main, refer_pal_sub, refer_pal_sub_hres;

    logic [7:0] cgram_addr_main, cgram_addr_sub;

    logic [14:0] direct_color;

    logic do_main_black;
    logic do_math;
    logic do_div2;

    logic [6:0] color_adsub_raw[2:0];
    logic [5:0] color_adsub_div2_raw[2:0];
    logic [4:0] color_adsub[2:0];
    logic [4:0] color_adsub_div2[2:0];

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [14:0] color_main, color_sub;
    logic [14:0] color_math;

    // ------------------------------
    //  Main
    // ------------------------------
    
    // ---- Color Register (Output) --------

    // step=1: color_main, step=2: color_sub, step=3: color_left/color_right
    // color_left, color_rightはH-RESでの左/右ピクセル, 非H-RESではcolor_left=color_right
    always_ff @(posedge clk) begin
        if (step == 2'h1) begin
            if (do_main_black | ((bgmode == 3'h7) & bg7_black)) begin
                color_main <= 15'h0;
            end else if ((refer_pal_main == BG1_8) & use_direct_color) begin
                color_main <= direct_color;
            end else begin
                color_main <= cgram_rdata;
            end
        end else if (step == 2'h2) begin
            if ((refer_pal_sub == BG1_8) & use_direct_color) begin
                color_sub <= direct_color;
            end else if (refer_pal_sub == BACK) begin
                color_sub <= sub_backdrop;
            end else begin
                color_sub <= cgram_rdata;
            end
        end else if (step == 2'h3) begin
            if (high_res | (bgmode == 3'd5) | (bgmode == 3'd6)) begin
                color_left <= color_sub;
                color_right <= color_main;
            end else if (do_math) begin
                color_left <= color_math;
                color_right <= color_math;
            end else begin
                color_left <= color_main;
                color_right <= color_main;
            end
        end
    end

    // ---- Palette Select --------

    // refer_pal_main: Main Screen
    refer_pal_selector #(.BG_SUB(0)) refer_pal_main_selector(
        .bgmode,
        .enable(main_enable),
        .bg3_prior,
        .bg_pixel,
        .obj_pixel,
        .use_direct_color,

        .refer_pal(refer_pal_main)
    );

    // refer_pal_sub: Normal Sub Screen
    refer_pal_selector #(.BG_SUB(0)) refer_pal_sub_selector(
        .bgmode,
        .enable(use_sub ? sub_enable : 5'h0),
        .bg3_prior,
        .bg_pixel,
        .obj_pixel,
        .use_direct_color,

        .refer_pal(refer_pal_sub)
    );

    // refer_pal_sub_hres: Sub Screen for H-RES
    refer_pal_selector #(.BG_SUB(1)) refer_pal_sub_hres_selector(
        .bgmode,
        .enable(sub_enable),
        .bg3_prior,
        .bg_pixel,
        .obj_pixel,
        .use_direct_color,

        .refer_pal(refer_pal_sub_hres)
    );

    // ---- CGRAM Access --------

    assign cgram_addr = (step[1] ^ step[0])
        ? cgram_addr_sub : cgram_addr_main; // step=0,3でmain, 1,2でsub

    // refer_pal_main -> cgram_addr_main
    always_comb begin
        case (refer_pal_main)
            BG1_2   : cgram_addr_main = {3'h0, bg_pixel[0].palette, bg_pixel[0].main[1:0]};
            BG2_2_0 : cgram_addr_main = {3'h1, bg_pixel[1].palette, bg_pixel[1].main[1:0]};
            BG2_2   : cgram_addr_main = {3'h0, bg_pixel[1].palette, bg_pixel[1].main[1:0]};
            BG3_2_0 : cgram_addr_main = {3'h2, bg_pixel[2].palette, bg_pixel[2].main[1:0]};
            BG3_2   : cgram_addr_main = {3'h0, bg_pixel[2].palette, bg_pixel[2].main[1:0]};
            BG4_2   : cgram_addr_main = {3'h3, bg_pixel[3].palette, bg_pixel[3].main[1:0]};
            BG1_4   : cgram_addr_main = {1'b0, bg_pixel[0].palette, bg_pixel[0].main[3:0]};
            BG2_4   : cgram_addr_main = {1'b0, bg_pixel[1].palette, bg_pixel[1].main[3:0]};
            BG1_8   : cgram_addr_main = bg_pixel[0].main;
            BG2_7   : cgram_addr_main = bg_pixel[1].main;
            OBJ     : cgram_addr_main = {1'b1, obj_pixel.palette, obj_pixel.main};
            default : cgram_addr_main = 8'h0;   // backdrop
        endcase
    end

    // refer_pal_sub -> cgram_addr_sub
    always_comb begin
        if ((bgmode == 3'h5) | (bgmode == 3'h6)) begin  // H-RES
            case (refer_pal_sub_hres)
                BG1_2   : cgram_addr_sub = {3'h0, bg_pixel[0].palette, bg_pixel[0].sub[1:0]};
                BG2_2_0 : cgram_addr_sub = {3'h1, bg_pixel[1].palette, bg_pixel[1].sub[1:0]};
                BG2_2   : cgram_addr_sub = {3'h0, bg_pixel[1].palette, bg_pixel[1].sub[1:0]};
                BG3_2_0 : cgram_addr_sub = {3'h2, bg_pixel[2].palette, bg_pixel[2].sub[1:0]};
                BG3_2   : cgram_addr_sub = {3'h0, bg_pixel[2].palette, bg_pixel[2].sub[1:0]};
                BG4_2   : cgram_addr_sub = {3'h3, bg_pixel[3].palette, bg_pixel[3].sub[1:0]};
                BG1_4   : cgram_addr_sub = {1'b0, bg_pixel[0].palette, bg_pixel[0].sub[3:0]};
                BG2_4   : cgram_addr_sub = {1'b0, bg_pixel[1].palette, bg_pixel[1].sub[3:0]};
                BG1_8   : cgram_addr_sub = bg_pixel[0].sub;
                OBJ     : cgram_addr_sub = {1'b1, obj_pixel.palette, obj_pixel.main};
                default : cgram_addr_sub = 8'h0;    // backdrop
            endcase
        end else begin  // Normal
            case (refer_pal_sub)
                BG1_2   : cgram_addr_sub = {3'h0, bg_pixel[0].palette, bg_pixel[0].main[1:0]};
                BG2_2_0 : cgram_addr_sub = {3'h1, bg_pixel[1].palette, bg_pixel[1].main[1:0]};
                BG2_2   : cgram_addr_sub = {3'h0, bg_pixel[1].palette, bg_pixel[1].main[1:0]};
                BG3_2_0 : cgram_addr_sub = {3'h2, bg_pixel[2].palette, bg_pixel[2].main[1:0]};
                BG3_2   : cgram_addr_sub = {3'h0, bg_pixel[2].palette, bg_pixel[2].main[1:0]};
                BG4_2   : cgram_addr_sub = {3'h3, bg_pixel[3].palette, bg_pixel[3].main[1:0]};
                BG1_4   : cgram_addr_sub = {1'b0, bg_pixel[0].palette, bg_pixel[0].main[3:0]};
                BG2_4   : cgram_addr_sub = {1'b0, bg_pixel[1].palette, bg_pixel[1].main[3:0]};
                BG1_8   : cgram_addr_sub = bg_pixel[0].main;
                BG2_7   : cgram_addr_sub = bg_pixel[1].main;
                OBJ     : cgram_addr_sub = {1'b1, obj_pixel.palette, obj_pixel.main};
                default : cgram_addr_sub = 8'h0;    // backdrop
            endcase
        end
    end

    // ---- Direct Color --------

    // Mode7にも対応 (Mode7ではbg_pixel[0].palette=0であるため)
    assign direct_color = {
        bg_pixel[0].main[7:6], bg_pixel[0].palette[2], 2'b0,
        bg_pixel[0].main[5:3], bg_pixel[0].palette[1], 1'b0,
        bg_pixel[0].main[2:0], bg_pixel[0].palette[0], 1'b0
    };

    // ---- Color Math --------
    
    // do_main_black: メインスクリーンを強制的に黒に
    assign do_main_black =
        (main_black == 2'b11) | (main_black[1] & in_win_math) | (main_black[0] & (~in_win_math));

    // do_math: Color Mathを実行
    // math_area, refer_pal_main, obj_pixel.palette, math_control[5:0], prior_num_main/subから決定
    always_comb begin
        if ((math_area == 2'b00) | ((~math_area[1]) & in_win_math) | ((~math_area[0]) & (~in_win_math))) begin
            case (refer_pal_main)
                BG1_2   : do_math = math_control[0];
                BG2_2_0 : do_math = math_control[1];
                BG2_2   : do_math = math_control[1];
                BG3_2_0 : do_math = math_control[2];
                BG3_2   : do_math = math_control[2];
                BG4_2   : do_math = math_control[3];
                BG1_4   : do_math = math_control[0];
                BG2_4   : do_math = math_control[1];
                BG1_8   : do_math = math_control[0];
                BG2_7   : do_math = math_control[1];
                OBJ     : do_math = obj_pixel.palette[2] & math_control[4];
                default : do_math = math_control[5];    // backdrop
            endcase
        end else begin
            do_math = 1'b0;
        end
    end

    // do_div2: Color Mathにて÷2を実行
    // サブスクリーンがbackdropの場合は実行しない
    assign do_div2 = math_control[6] & ((~use_sub) | ((~do_main_black) & (refer_pal_sub != BACK)));

    generate
        // gi=0/1/2: Red/Green/Blue
        for (gi = 0; gi < 3; gi++) begin : GenColorAdSub
            assign color_adsub_raw[gi] = {2'b0, color_main[gi*5+4:gi*5]}
                        + (math_control[7] ? (-{2'b0, color_sub[gi*5+4:gi*5]}) : {2'b0, color_sub[gi*5+4:gi*5]});
            assign color_adsub_div2_raw[gi] = color_adsub_raw[gi][6:1];
            assign color_adsub[gi] = color_adsub_raw[gi][6] ? 5'h0
                                    : (color_adsub_raw[gi][5] ? 5'h1f : color_adsub_raw[gi][4:0]);
            assign color_adsub_div2[gi] = color_adsub_div2_raw[gi][5] ? 5'h0 : color_adsub_div2_raw[gi][4:0];
        end
    endgenerate

    // Color Math Result
    assign color_math = do_div2
        ? {color_adsub_div2[2], color_adsub_div2[1], color_adsub_div2[0]}
        : {color_adsub[2], color_adsub[1], color_adsub[0]};

endmodule
