// ==============================
//  Background (BG)
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module bg
    import ppu_pkg::*;
(
    input logic clk,
    input logic dot_en,

    /*
        000: OPT(Mode 2,6), 100: OPT(Mode 4)
        001: 2bpp, 101: 2bpp(True H-RES)
        010: 4bpp, 110: 4bpp(True H-RES)
        011: 8bpp
    */
    input logic [2:0] mode,

    input logic fetch_map,
    input logic fetch_data,
    input logic [2:0] fetch_data_num,

    input logic [8:0] x,    // これからフェッチする座標(0-263)
    input logic [7:0] y,    // これからフェッチする座標(0-239)
    input logic [9:0] xofs,
    input logic [9:0] yofs,
    input logic [5:0] map_base,
    input logic [1:0] map_size,
    input logic [2:0] data_base,
    input logic tile_big,

    output logic [14:0] vram_addr,
    input logic [15:0] vram_rdata,

    output bg_pixel_type pixel,

    input logic newline,
    output logic [9:0] opt_x,
    output logic [9:0] opt_y,
    output logic [1:0] opt_apply_x,
    output logic [1:0] opt_apply_y,

    input logic mosaic_enable,
    input logic mosaic_pixel_strobe
);

    genvar gi;

    // ------------------------------
    //  Wires
    // ------------------------------

    logic x_flip, y_flip;

    logic [9:0] xeff, yeff;
    logic [5:0] tile_y;
    logic [3:0] fine_y;

    logic [14:0] vram_map_addr, vram_data_addr;

    bg_pixel_type pixel_raw;

    // ------------------------------
    //  Registers
    // ------------------------------

    logic [9:0] tile_index;
    logic [5:0] attr, attr_next, attr_fetch;

    logic [5:0] tile_x;

    bg_pixel_type pixel_mosaic;

    // ------------------------------
    //  Main
    // ------------------------------
    
    assign vram_addr = fetch_data ? vram_data_addr : vram_map_addr;

    assign {y_flip, x_flip} = attr_fetch[5:4];
    assign pixel_raw.prior = attr[3];
    assign pixel_raw.palette = attr[2:0];

    assign xeff = xofs + {1'h0, x};
    assign yeff = yofs + {2'h0, y};

    assign tile_y = tile_big ? yeff[9:4] : yeff[8:3];
    assign fine_y = (tile_big ? yeff[3:0] : {1'b0, yeff[2:0]}) ^ {4{y_flip}};

    assign vram_map_addr = (mode[1:0] == 2'b00) // OPT
            ? (
                {map_base[4:0], 10'h0}
                + {
                    // 3'h0,
                    // (map_size == 2'b11) & tile_y[5],
                    // (map_size == 2'b10) & tile_y[5],
                    4'h0,
                    // fetch_data_num[0],
                    // yofs[8:3],
                    yofs[8:3] + {4'h0, fetch_data_num[0]},
                    // fetch_data_num[0],
                    tile_x[4:0]
                    // fetch_data_num[0]
                }
                // + {4'h0, map_size[0] & tile_x[5], 10'h0}
            ) : (
                {map_base[4:0], 10'h0}
                + {
                    3'h0,
                    (map_size == 2'b11) & tile_y[5],
                    (map_size == 2'b10) & tile_y[5],
                    tile_y[4:0],
                    tile_x[4:0]
                }
                + {4'h0, map_size[0] & tile_x[5], 10'h0}
            );

    always_comb begin
        case (mode)
            3'b001: vram_data_addr = tile_big // 2bpp
                        ? ({data_base, 12'h0} + {tile_index, fine_y, xeff[3]})
                        : ({data_base, 12'h0} + {2'h0, tile_index, fine_y[2:0]}); 
            3'b010: vram_data_addr = tile_big // 4bpp
                        ? ({data_base, 12'h0} + {tile_index[8:0], fetch_data_num[1], fine_y, xeff[3]})
                        : ({data_base, 12'h0} + {1'b0, tile_index, fetch_data_num[1], fine_y[2:0]});
            3'b011: vram_data_addr = tile_big // 8bpp
                        ? ({data_base, 12'h0} + {tile_index[7:0], fetch_data_num[2:1], fine_y, xeff[3]})
                        : ({data_base, 12'h0} + {tile_index, fetch_data_num[2:1], fine_y[2:0]});
            3'b101: vram_data_addr =
                        ({data_base, 12'h0} + {1'b0, tile_index, fine_y[2:0], fetch_data_num[0]}); // 2bpp H-RES
            3'b110: vram_data_addr =
                        ({data_base, 12'h0} + {tile_index, fetch_data_num[1], fine_y[2:0], fetch_data_num[0]}); // 4bpp H-RES
            default: vram_data_addr = 15'h0;
        endcase
    end

    // フェッチ8ピクセル開始時にtile_xを保存
    // (dot_en以外の3PPUクロックでも保存しているためx[2:0]==0でのフェッチもこれをそのまま使えば良い)
    always_ff @(posedge clk) begin
        if (x[2:0] == 3'b000) begin
            tile_x <= (tile_big | (mode[2] & (mode[1:0] != 2'h0))) ? xeff[9:4] : xeff[8:3];
        end
    end

    always_ff @(posedge clk) begin
        if (dot_en & fetch_map) begin
            {attr_fetch, tile_index} <= vram_rdata;
        end
    end

    generate
        for (gi = 0; gi < MAX_BPP; gi++) begin : BGShifterGen
            logic [7:0] px, px_next, px_fetch, px_fetch_in, px_fetch_in_raw, px_fetch_reg;
            logic [7:0] px_sub, px_sub_next, px_sub_fetch, px_sub_fetch_in, px_sub_fetch_in_raw, px_sub_fetch_reg;

            assign pixel_raw.main[gi] = px[~xeff[2:0]];
            assign pixel_raw.sub[gi] = px_sub[~xeff[2:0]];

            assign px_fetch =
                    ((x[2:0] == 3'b111) & fetch_data & (fetch_data_num[2:1] == gi / 2))
                            ? px_fetch_in : px_fetch_reg;
            assign px_sub_fetch =
                    ((x[2:0] == 3'b111) & fetch_data & (fetch_data_num[2:1] == gi / 2))
                            ? px_sub_fetch_in : px_sub_fetch_reg;

            // px_fetch_in_raw
            always_comb begin
                if (~fetch_data_num[0]) begin
                    px_fetch_in_raw = (gi % 2 == 0)
                        ? vram_rdata[7:0]
                        : vram_rdata[15:8];
                end else begin
                    px_fetch_in_raw[7:4] = {
                        px_fetch_reg[6],
                        px_fetch_reg[4],
                        px_fetch_reg[2],
                        px_fetch_reg[0]
                    };
                    px_fetch_in_raw[3:0] = (gi % 2 == 0) ? {
                        vram_rdata[6],
                        vram_rdata[4],
                        vram_rdata[2],
                        vram_rdata[0]
                    } : {
                        vram_rdata[14],
                        vram_rdata[12],
                        vram_rdata[10],
                        vram_rdata[8]
                    };
                end
            end

            assign px_fetch_in = x_flip ? {
                        px_fetch_in_raw[0],
                        px_fetch_in_raw[1],
                        px_fetch_in_raw[2],
                        px_fetch_in_raw[3],
                        px_fetch_in_raw[4],
                        px_fetch_in_raw[5],
                        px_fetch_in_raw[6],
                        px_fetch_in_raw[7]
                    } : px_fetch_in_raw;

            // px_sub_fetch_in_raw
            always_comb begin
                px_sub_fetch_in_raw[7:4] = {
                    px_sub_fetch_reg[7],
                    px_sub_fetch_reg[5],
                    px_sub_fetch_reg[3],
                    px_sub_fetch_reg[1]
                };
                px_sub_fetch_in_raw[3:0] = (gi % 2 == 0) ? {
                    vram_rdata[7],
                    vram_rdata[5],
                    vram_rdata[3],
                    vram_rdata[1]
                } : {
                    vram_rdata[15],
                    vram_rdata[13],
                    vram_rdata[11],
                    vram_rdata[9]
                };
            end

            assign px_sub_fetch_in = x_flip ? {
                        px_sub_fetch_in_raw[0],
                        px_sub_fetch_in_raw[1],
                        px_sub_fetch_in_raw[2],
                        px_sub_fetch_in_raw[3],
                        px_sub_fetch_in_raw[4],
                        px_sub_fetch_in_raw[5],
                        px_sub_fetch_in_raw[6],
                        px_sub_fetch_in_raw[7]
                    } : px_sub_fetch_in_raw;

            // px_fetch_reg, px_sub_fetch_reg
            always_ff @(posedge clk) begin
                if (dot_en & fetch_data & (fetch_data_num[2:1] == gi/2)) begin
                    px_fetch_reg <= px_fetch_in;
                    px_sub_fetch_reg <= px_sub_fetch_in;
                end
            end

            // px_next, px_sub_next
            always_ff @(posedge clk) begin
                if (dot_en & (x[2:0] == 3'b111)) begin // px_nextロード
                    px_next <= px_fetch;
                    px_sub_next <= px_sub_fetch;
                end
            end
            
            // px, px_sub
            always_ff @(posedge clk) begin
                if (dot_en & (xeff[2:0] == 3'b111)) begin // pxロード
                    px <= px_next;
                    px_sub <= px_sub_next;
                end
            end
            
        end
    endgenerate

    // attr_next
    always_ff @(posedge clk) begin
        if (dot_en & (x[2:0] == 3'b111)) begin // px_nextロード
            attr_next <= attr_fetch;
        end
    end

    // attr
    always_ff @(posedge clk) begin
        if (dot_en & (xeff[2:0] == 3'b111)) begin // pxロード
            attr <= attr_next;
        end
    end

    // OPT処理(BG3)
    always_ff @(posedge clk) begin
        if (dot_en) begin
            if (newline) begin
                opt_apply_x <= 2'b00;
                opt_apply_y <= 2'b00;
            end else if ((mode == 3'b000) & fetch_map) begin
                if (~fetch_data_num[0]) begin // Horizontal
                    opt_x <= vram_rdata[9:0];
                    opt_apply_x <= vram_rdata[14:13];
                end else begin // Vertical
                    opt_y <= vram_rdata[9:0];
                    opt_apply_y <= vram_rdata[14:13];
                end
            end else if ((mode == 3'b100) & fetch_map) begin
                opt_x <= vram_rdata[9:0];
                opt_y <= vram_rdata[9:0];
                opt_apply_x <= vram_rdata[15] ? 2'b00 : vram_rdata[14:13];
                opt_apply_y <= vram_rdata[15] ? vram_rdata[14:13] : 2'b00;
            end
        end
    end

    // Mosaic Vertical
    always_ff @(posedge clk) begin
        if (dot_en & mosaic_pixel_strobe) begin
            pixel_mosaic <= pixel_raw;
        end
    end

    assign pixel = (mosaic_enable & (~mosaic_pixel_strobe)) ? pixel_mosaic : pixel_raw;
    
endmodule
