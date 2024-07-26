// ==============================
//  Reference Palette Selector
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module refer_pal_selector
    import ppu_pkg::*;
	 #(parameter BG_SUB = 0)
(
    input logic [2:0] bgmode,
    input logic [4:0] enable,
    input logic bg3_prior,
    input bg_pixel_type bg_pixel[3:0],
    input obj_pixel_type obj_pixel,

    output refer_pal_type refer_pal
    // output logic [3:0] // prior_num // [todo] 消去
);

    genvar gi;

    logic [MAX_BPP-1:0] bg_pixel_ms[3:0];

    generate
        for (gi = 0; gi < 4; gi++) begin : GenBGPixelMS
            assign bg_pixel_ms[gi] = (BG_SUB == 1) ? bg_pixel[gi].sub : bg_pixel[gi].main;
        end
    endgenerate

    always_comb begin
        unique case (bgmode)
            3'h0: begin // (S3) 1H 2H (S2) 1L 2L (S1) 3H 4H (S0) 3L 4L
                if (enable[4] & (obj_pixel.prior == 2'h3) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd12;
                end else if (enable[0] & bg_pixel[0].prior & (bg_pixel_ms[0][1:0] != 2'h0)) begin
                    refer_pal = BG1_2;
                    // prior_num = 4'd11;
                end else if (enable[1] & bg_pixel[1].prior & (bg_pixel_ms[1][1:0] != 2'h0)) begin
                    refer_pal = BG2_2_0;
                    // prior_num = 4'd10;
                end else if (enable[4] & (obj_pixel.prior == 2'h2) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd9;
                end else if (enable[0] & (bg_pixel_ms[0][1:0] != 2'h0)) begin
                    refer_pal = BG1_2;
                    // prior_num = 4'd8;
                end else if (enable[1] & (bg_pixel_ms[1][1:0] != 2'h0)) begin
                    refer_pal = BG2_2_0;
                    // prior_num = 4'd7;
                end else if (enable[4] & (obj_pixel.prior == 2'h1) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd6;
                end else if (enable[2] & bg_pixel[2].prior & (bg_pixel_ms[2][1:0] != 2'h0)) begin
                    refer_pal = BG3_2_0;
                    // prior_num = 4'd5;
                end else if (enable[3] & bg_pixel[3].prior & (bg_pixel_ms[3][1:0] != 2'h0)) begin
                    refer_pal = BG4_2;
                    // prior_num = 4'd4;
                end else if (enable[4] & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd3;
                end else if (enable[2] & (bg_pixel_ms[2][1:0] != 2'h0)) begin
                    refer_pal = BG3_2_0;
                    // prior_num = 4'd2;
                end else if (enable[3] & (bg_pixel_ms[3][1:0] != 2'h0)) begin
                    refer_pal = BG4_2;
                    // prior_num = 4'd1;
                end else begin
                    refer_pal = BACK;
                    // prior_num = 4'd0;
                end
            end
            3'h1: begin // "3H" (S3) 1H 2H (S2) 1L 2L (S1) "3H" (S0) 3L
                if (bg3_prior & enable[2] & bg_pixel[2].prior & (bg_pixel_ms[2][1:0] != 2'h0)) begin
                    refer_pal  = BG3_2;
                    // prior_num = 4'd11;
                end else if (enable[4] & (obj_pixel.prior == 2'h3) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd10;
                end else if (enable[0] & bg_pixel[0].prior & (bg_pixel_ms[0][3:0] != 4'h0)) begin
                    refer_pal = BG1_4;
                    // prior_num = 4'd9;
                end else if (enable[1] & bg_pixel[1].prior & (bg_pixel_ms[1][3:0] != 4'h0)) begin
                    refer_pal = BG2_4;
                    // prior_num = 4'd8;
                end else if (enable[4] & (obj_pixel.prior == 2'h2) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd7;
                end else if (enable[0] & (bg_pixel_ms[0][3:0] != 4'h0)) begin
                    refer_pal = BG1_4;
                    // prior_num = 4'd6;
                end else if (enable[1] & (bg_pixel_ms[1][3:0] != 4'h0)) begin
                    refer_pal = BG2_4;
                    // prior_num = 4'd5;
                end else if (enable[4] & (obj_pixel.prior == 2'h1) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd4;
                end else if (enable[2] & bg_pixel[2].prior & (bg_pixel_ms[2][1:0] != 2'h0)) begin
                    refer_pal = BG3_2;
                    // prior_num = 4'd3;
                end else if (enable[4] & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd2;
                end else if (enable[2] & (bg_pixel_ms[2][1:0] != 2'h0)) begin
                    refer_pal = BG3_2;
                    // prior_num = 4'd1;
                end else begin
                    refer_pal = BACK;
                    // prior_num = 4'd0;
                end
            end
            3'h2: begin // (S3) 1H (S2) 2H (S1) 1L (S0) 2L
                if (enable[4] & (obj_pixel.prior == 2'h3) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd8;
                end else if (enable[0] & bg_pixel[0].prior & (bg_pixel_ms[0][3:0] != 4'h0)) begin
                    refer_pal = BG1_4;
                    // prior_num = 4'd7;
                end else if (enable[4] & (obj_pixel.prior == 2'h2) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd6;
                end else if (enable[1] & bg_pixel[1].prior & (bg_pixel_ms[1][3:0] != 4'h0)) begin
                    refer_pal = BG2_4;
                    // prior_num = 4'd5;
                end else if (enable[4] & (obj_pixel.prior == 2'h1) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd4;
                end else if (enable[0] & (bg_pixel_ms[0][3:0] != 4'h0)) begin
                    refer_pal = BG1_4;
                    // prior_num = 4'd3;
                end else if (enable[4] & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd2;
                end else if (enable[1] & (bg_pixel_ms[1][3:0] != 4'h0)) begin
                    refer_pal = BG2_4;
                    // prior_num = 4'd1;
                end else begin
                    refer_pal = BACK;
                    // prior_num = 4'd0;
                end
            end
            3'h3: begin // (S3) 1H (S2) 2H (S1) 1L (S0) 2L
                if (enable[4] & (obj_pixel.prior == 2'h3) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd8;
                end else if (enable[0] & bg_pixel[0].prior & (bg_pixel_ms[0] != 8'h0)) begin
                    refer_pal = BG1_8;
                    // prior_num = 4'd7;
                end else if (enable[4] & (obj_pixel.prior == 2'h2) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd6;
                end else if (enable[1] & bg_pixel[1].prior & (bg_pixel_ms[1][3:0] != 4'h0)) begin
                    refer_pal = BG2_4;
                    // prior_num = 4'd5;
                end else if (enable[4] & (obj_pixel.prior == 2'h1) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd4;
                end else if (enable[0] & (bg_pixel_ms[0] != 8'h0)) begin
                    refer_pal = BG1_8;
                    // prior_num = 4'd3;
                end else if (enable[4] & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd2;
                end else if (enable[1] & (bg_pixel_ms[1][3:0] != 4'h0)) begin
                    refer_pal = BG2_4;
                    // prior_num = 4'd1;
                end else begin
                    refer_pal = BACK;
                    // prior_num = 4'd0;
                end
            end
            3'h4: begin // (S3) 1H (S2) 2H (S1) 1L (S0) 2L
                if (enable[4] & (obj_pixel.prior == 2'h3) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd8;
                end else if (enable[0] & bg_pixel[0].prior & (bg_pixel_ms[0] != 8'h0)) begin
                    refer_pal = BG1_8;
                    // prior_num = 4'd7;
                end else if (enable[4] & (obj_pixel.prior == 2'h2) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd6;
                end else if (enable[1] & bg_pixel[1].prior & (bg_pixel_ms[1][1:0] != 2'h0)) begin
                    refer_pal = BG2_4;
                    // prior_num = 4'd5;
                end else if (enable[4] & (obj_pixel.prior == 2'h1) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd4;
                end else if (enable[0] & (bg_pixel_ms[0] != 8'h0)) begin
                    refer_pal = BG1_8;
                    // prior_num = 4'd3;
                end else if (enable[4] & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd2;
                end else if (enable[1] & (bg_pixel_ms[1][1:0] != 2'h0)) begin
                    refer_pal = BG2_4;
                    // prior_num = 4'd1;
                end else begin
                    refer_pal = BACK;
                    // prior_num = 4'd0;
                end
            end
            3'h5: begin // (S3) 1H (S2) 2H (S1) 1L (S0) 2L
                if (enable[4] & (obj_pixel.prior == 2'h3) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd8;
                end else if (enable[0] & bg_pixel[0].prior & (bg_pixel_ms[0][3:0] != 4'h0)) begin
                    refer_pal = BG1_4;
                    // prior_num = 4'd7;
                end else if (enable[4] & (obj_pixel.prior == 2'h2) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd6;
                end else if (enable[1] & bg_pixel[1].prior & (bg_pixel_ms[1][1:0] != 2'h0)) begin
                    refer_pal = BG2_2;
                    // prior_num = 4'd5;
                end else if (enable[4] & (obj_pixel.prior == 2'h1) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd4;
                end else if (enable[0] & (bg_pixel_ms[0][3:0] != 4'h0)) begin
                    refer_pal = BG1_4;
                    // prior_num = 4'd3;
                end else if (enable[4] & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd2;
                end else if (enable[1] & (bg_pixel_ms[1][1:0] != 2'h0)) begin
                    refer_pal = BG2_2;
                    // prior_num = 4'd1;
                end else begin
                    refer_pal = BACK;
                    // prior_num = 4'd0;
                end
            end
            3'h6: begin // (S3) 1H (S2) (S1) 1L (S0)
                if (enable[4] & (obj_pixel.prior == 2'h3) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd5;
                end else if (enable[0] & bg_pixel[0].prior & (bg_pixel_ms[0][3:0] != 4'h0)) begin
                    refer_pal = BG1_4;
                    // prior_num = 4'd4;
                end else if (enable[4] & (obj_pixel.prior != 2'h0) & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd3;
                end else if (enable[0] & (bg_pixel_ms[0][3:0] != 4'h0)) begin
                    refer_pal = BG1_4;
                    // prior_num = 4'd2;
                end else if (enable[4] & (obj_pixel.main != 4'h0)) begin
                    refer_pal = OBJ;
                    // prior_num = 4'd1;
                end else begin
                    refer_pal = BACK;
                    // prior_num = 4'd0;
                end
            end
            3'h7: begin // (S3) (S2) 2H (S1) 1L (S0) 2L
                refer_pal = BACK;
                // prior_num = 4'd0;
            end
        endcase
    end
    
endmodule