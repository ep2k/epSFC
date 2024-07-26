// ==============================
//  Object (OBJ) / Sprite
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module obj
    import ppu_pkg::*;
(
    input logic clk,
    input logic obj_en,
    input logic dot_en,
    input logic reset,

    input logic rotation,
    input logic [6:0] top_obj,
    input logic [2:0] size_m,
    input logic [2:0] name_base,
    input logic [1:0] name_select,

    input logic [7:0] x,
    input logic [7:0] y,
    input logic newline,

    input logic start_oamprefetch,
    input logic start_objfetch,
    input logic ovf_clear,

    output logic [9:0] oam_addr,
    output logic oam_read,
    input logic [7:0] oam_rdata,

    output logic [14:0] vram_addr,
    output logic vram_read,
    input logic [15:0] vram_rdata,

    output obj_pixel_type obj_pixel,
    output logic range_ovf_flg,
    output logic time_ovf_flg
);

    genvar gi;
    
    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic finish_oamprefetch;
    logic finish_oamfetch;
    logic finish_objfetch;

    logic [9:0] oam_addr_oamprefetch;
    logic [9:0] oam_addr_oamfetch;
    logic [14:0] vram_addr_objfetch;

    // ---- 2. Obj Evaluation --------

    logic [2:0] size_x, size_y;
    logic [6:0] oam_num;
    logic [8:0] oam_y_lower;
    logic yhit;
    logic signed [8:0] oam_x;
    logic [7:0] tile_exist_raw, tile_exist;
    logic xhit;
    logic oamfetch_next;
    logic range_ovf;

    // ---- 3. Tile Fetch --------

    logic [2:0] xofs;
    logic [8:0] tile_index_eff;
    
    logic objfetch_next;
    logic time_ovf;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    obj_type objs[33:0];

    obj_type objs_next[33:0];
    obj_next_list_type obj_next_list[31:0];

    typedef enum logic [1:0] {
        OS_IDLE,
        OS_OAMPREFETCH,
        OS_OAMFETCH,
        OS_OBJFETCH
    } obj_state_type;

    obj_state_type state = OS_IDLE;

    logic [127:0] oam_size_i;
    logic [127:0] oam_x8;

    // ---- 1. OAM Prefetch --------

    logic [4:0] oamprefetch_ctr; // OAM下32バイトのフェッチカウント(0~31)

    // ---- 2. Obj Evaluation --------

    logic [6:0] oam_ctr;        // 0~127
    logic [1:0] oamfetch_step;  // 0: Yフェッチ, 1: Xフェッチ, 2: 第2バイトフェッチ, 3: 第3バイトフェッチ
    logic [5:0] range_ctr;      // obj_next_listの番号(0~32, 32のときobj_next_listがフル)

    logic [5:0] fine_y_reg;

    // ---- 3. Tile Fetch --------

    logic [6:0] time_ctr;   // タイルフェッチカウント(0~2*34-1)
    logic [4:0] obj_ctr;    // obj_next_list内でのobj番号(0~31)

    // ---- 4. Rendering --------

    logic [3:0] obj_pixel_main_list[33:0];

    // ------------------------------
    //  Main
    // ------------------------------
    
    // ---- RAM Access --------

    assign oam_addr = (state == OS_OAMPREFETCH) ? oam_addr_oamprefetch : oam_addr_oamfetch;
    assign oam_read = (state == OS_OAMPREFETCH) | (state == OS_OAMFETCH);

    assign vram_addr = vram_addr_objfetch;
    assign vram_read = (state == OS_OBJFETCH);

    // ---- State --------

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= OS_IDLE;
        end else if (obj_en & start_oamprefetch) begin
            state <= OS_OAMPREFETCH;
        end else if (obj_en & finish_oamprefetch) begin
            state <= OS_OAMFETCH;
        end else if (obj_en & finish_oamfetch) begin
            state <= OS_IDLE;
        end else if (dot_en & start_objfetch & (range_ctr != 6'h0)) begin
            state <= OS_OBJFETCH;
        end else if (dot_en & finish_objfetch) begin
            state <= OS_IDLE;
        end
    end

    // ---- 1. OAM Prefetch --------

    assign finish_oamprefetch = (oamprefetch_ctr == 5'd31);
    assign oam_addr_oamprefetch = {1'b1, 4'h0, oamprefetch_ctr};

    always_ff @(posedge clk) begin
        if (obj_en) begin
            oamprefetch_ctr <= (state == OS_OAMPREFETCH)
                    ? (oamprefetch_ctr + 5'd1) : 5'd0;
        end
    end

    always_ff @(posedge clk) begin
        if (obj_en & (state == OS_OAMPREFETCH)) begin
            oam_size_i[{oamprefetch_ctr, 2'b11}] <= oam_rdata[7];
            oam_size_i[{oamprefetch_ctr, 2'b10}] <= oam_rdata[5];
            oam_size_i[{oamprefetch_ctr, 2'b01}] <= oam_rdata[3];
            oam_size_i[{oamprefetch_ctr, 2'b00}] <= oam_rdata[1];
            oam_x8[{oamprefetch_ctr, 2'b11}] <= oam_rdata[6];
            oam_x8[{oamprefetch_ctr, 2'b10}] <= oam_rdata[4];
            oam_x8[{oamprefetch_ctr, 2'b01}] <= oam_rdata[2];
            oam_x8[{oamprefetch_ctr, 2'b00}] <= oam_rdata[0];
        end
    end
    
    // ---- 2. Obj Evaluation --------

    always_comb begin
        unique case ({size_m, oam_size_i[oam_num]})
            {3'h0, 1'b0}: {size_x, size_y} = {3'h0, 3'h0};
            {3'h0, 1'b1}: {size_x, size_y} = {3'h1, 3'h1};
            {3'h1, 1'b0}: {size_x, size_y} = {3'h0, 3'h0};
            {3'h1, 1'b1}: {size_x, size_y} = {3'h3, 3'h3};
            {3'h2, 1'b0}: {size_x, size_y} = {3'h0, 3'h0};
            {3'h2, 1'b1}: {size_x, size_y} = {3'h7, 3'h7};
            {3'h3, 1'b0}: {size_x, size_y} = {3'h1, 3'h1};
            {3'h3, 1'b1}: {size_x, size_y} = {3'h3, 3'h3};
            {3'h4, 1'b0}: {size_x, size_y} = {3'h1, 3'h1};
            {3'h4, 1'b1}: {size_x, size_y} = {3'h7, 3'h7};
            {3'h5, 1'b0}: {size_x, size_y} = {3'h3, 3'h3};
            {3'h5, 1'b1}: {size_x, size_y} = {3'h3, 3'h7};
            {3'h6, 1'b0}: {size_x, size_y} = {3'h1, 3'h3};
            {3'h6, 1'b1}: {size_x, size_y} = {3'h3, 3'h7};
            {3'h7, 1'b0}: {size_x, size_y} = {3'h1, 3'h3};
            {3'h7, 1'b1}: {size_x, size_y} = {3'h3, 3'h3};
        endcase
    end

    assign oam_num = oam_ctr + (rotation ? top_obj : 7'h0);
    always_comb begin
        case (oamfetch_step)
            2'h0: oam_addr_oamfetch = {1'b0, oam_num, 2'h1}; // Y座標
            2'h1: oam_addr_oamfetch = {1'b0, oam_num, 2'h0}; // X座標[7:0]
            default: oam_addr_oamfetch = {1'b0, oam_num, oamfetch_step}; // Byte 2,3
        endcase
    end

    assign finish_oamfetch =
            range_ovf | ((oam_ctr == 7'd127) & oamfetch_next);

    assign oam_y_lower = {1'b0, oam_rdata} + {3'h0, size_y, 3'b111};
        // [8]: オーバーフロー検出

    assign yhit =
            ((y >= oam_rdata) | oam_y_lower[8])
            & (y <= oam_y_lower[7:0]);
        // oam_y_lower[8]のときoam_y<0でスプライトの下部が画面内に

    assign oam_x = {oam_x8[oam_num], oam_rdata};

    generate
        for (gi = 0; gi < 8; gi++) begin : GenTileExistRaw
            // -7 <= x + 8*gi < 256
            assign tile_exist_raw[gi] =
                (oam_x >= -7 - 8 * gi) & (oam_x < (256 - 8 * gi));
        end
    endgenerate

    assign tile_exist =
        tile_exist_raw & {{4{size_x[2]}}, {2{size_x[1]}}, size_x[0], 1'b1};
    
    assign xhit = (tile_exist != 8'h0);

    // oamfetch_next
    always_comb begin
        unique case (oamfetch_step)
            2'h0: oamfetch_next = ~yhit;
            2'h1: oamfetch_next = ~xhit;
            2'h2: oamfetch_next = 1'b0;
            2'h3: oamfetch_next = 1'b1;
        endcase
    end

    // oamfetch_step
    always_ff @(posedge clk) begin
        if (obj_en) begin
            if (state != OS_OAMFETCH) begin
                oamfetch_step <= 2'h0;
            end else begin
                oamfetch_step <= oamfetch_next
                        ? 2'h0 : (oamfetch_step + 2'h1);
            end
        end
    end

    // oam_ctr
    always_ff @(posedge clk) begin
        if (obj_en) begin
            if (state != OS_OAMFETCH) begin
                oam_ctr <= 7'd0;
            end else if (oamfetch_next) begin
                oam_ctr <= oam_ctr + 7'd1;
            end
        end
    end

    // fine_y_reg
    always_ff @(posedge clk) begin
        if (obj_en & (oamfetch_step == 2'h0)) begin
            fine_y_reg <= y - oam_rdata;
        end
    end

    // range_ctr
    always_ff @(posedge clk) begin
        if (dot_en & newline) begin
            range_ctr <= 6'd0;
        end else if (obj_en & (oamfetch_step == 2'h3) & (range_ctr != 6'd32)) begin
            range_ctr <= range_ctr + 6'd1;
        end
    end

    assign range_ovf = (oamfetch_step == 2'h1) & xhit & (range_ctr == 6'd32);

    // range_ovf_flg
    always_ff @(posedge clk) begin
        if (reset) begin
            range_ovf_flg <= 1'b0;
        end else if (dot_en & ovf_clear) begin
            range_ovf_flg <= 1'b0;
        end else if (obj_en & range_ovf) begin
            range_ovf_flg <= 1'b1;
        end
    end

    // obj_next_list
    always_ff @(posedge clk) begin
        if (dot_en & newline) begin
            for (int i = 0; i < 32; i++) begin
                obj_next_list[i].tile_exist <= 8'h0;
            end
        end else if (obj_en & (state == OS_OAMFETCH)) begin
            if ((oamfetch_step == 2'h1) & xhit & (range_ctr != 6'd32)) begin
                obj_next_list[range_ctr[4:0]].x <= oam_x;
                obj_next_list[range_ctr[4:0]].tile_exist <= tile_exist;
            end else if (oamfetch_step == 2'h2) begin
                obj_next_list[range_ctr[4:0]].tile_index[7:0] <= oam_rdata;
            end else if (oamfetch_step == 2'h3) begin
                obj_next_list[range_ctr[4:0]].tile_index[8] <= oam_rdata[0];
                obj_next_list[range_ctr[4:0]].palette <= oam_rdata[3:1];
                obj_next_list[range_ctr[4:0]].prior <= oam_rdata[5:4];
                obj_next_list[range_ctr[4:0]].x_flip <= oam_rdata[6];
                obj_next_list[range_ctr[4:0]].size_x <= size_x;
                
                if (~oam_rdata[7]) begin // ~y_flip
                    obj_next_list[range_ctr[4:0]].fine_y <= fine_y_reg;
                end else begin // y_filp
                    obj_next_list[range_ctr[4:0]].fine_y <= fine_y_reg ^ {size_y, 3'b111};
                end
            end
        end else if (dot_en & (state == OS_OBJFETCH) & time_ctr[0]) begin
            for (int i = 0; i < 8; i++) begin
                if (obj_next_list[obj_ctr].tile_exist[i]) begin
                    obj_next_list[obj_ctr].tile_exist[i] <= 1'b0;
                    break;
                end
            end
        end
    end

    // ---- 3. Tile Fetch --------

    always_comb begin
        xofs = 3'h0;
        for (int i = 0; i < 8; i++) begin
            if (obj_next_list[obj_ctr].tile_exist[i]) begin
                if (~obj_next_list[obj_ctr].x_flip) begin // ~x_flip
                    xofs = i;
                end else begin // x_flip
                    xofs = i ^ obj_next_list[obj_ctr].size_x;
                end
                break;
            end
        end
    end

    assign tile_index_eff = obj_next_list[obj_ctr].tile_index
                + {2'b0, obj_next_list[obj_ctr].fine_y[5:3], 1'b0, xofs};

    assign vram_addr_objfetch =
        {name_base[2:0], 13'h0}
        + {
            tile_index_eff[7:0],
            time_ctr[0],
            obj_next_list[obj_ctr].fine_y[2:0]
        }
        + (tile_index_eff[8] ? {name_select + 2'h1, 12'h0} : 15'h0);

    assign objfetch_next = time_ctr[0] & (
                (obj_next_list[obj_ctr].tile_exist == 8'h1)
                | (obj_next_list[obj_ctr].tile_exist == 8'h2)
                | (obj_next_list[obj_ctr].tile_exist == 8'h4)
                | (obj_next_list[obj_ctr].tile_exist == 8'h8)
                | (obj_next_list[obj_ctr].tile_exist == 8'h10)
                | (obj_next_list[obj_ctr].tile_exist == 8'h20)
                | (obj_next_list[obj_ctr].tile_exist == 8'h40)
                | (obj_next_list[obj_ctr].tile_exist == 8'h80)
            );

    assign finish_objfetch =
            time_ovf | ((obj_ctr == (range_ctr - 6'h1)) & objfetch_next);

    assign time_ovf = (time_ctr == 7'd68) & (obj_ctr != (range_ctr - 6'h1));

    always_ff @(posedge clk) begin
        if (dot_en) begin
            time_ctr <= (state == OS_OBJFETCH) ? (time_ctr + 7'h1) : 7'h0;
        end
    end

    always_ff @(posedge clk) begin
        if (dot_en) begin
            if (state != OS_OBJFETCH) begin
                obj_ctr <= 5'h0;
            end else if (objfetch_next) begin
                obj_ctr <= obj_ctr + 5'h1;
            end
        end
    end

    // time_ovf_flg
    always_ff @(posedge clk) begin
        if (reset) begin
            time_ovf_flg <= 1'b0;
        end else if (dot_en & ovf_clear) begin
            time_ovf_flg <= 1'b0;
        end else if (dot_en & time_ovf) begin
            time_ovf_flg <= 1'b1;
        end
    end

    // objs_next
    always_ff @(posedge clk) begin
        if (dot_en) begin
            if (newline) begin
                for (int i = 0; i < 34; i++) begin
                    objs_next[i].x <= -256;
                end
            end else if (state == OS_OBJFETCH) begin
                if (~time_ctr[0]) begin
                    {objs_next[time_ctr[6:1]].pixels_1,
                    objs_next[time_ctr[6:1]].pixels_0} <=
                        (obj_next_list[obj_ctr].x_flip) ? {
                            vram_rdata[8],
                            vram_rdata[9],
                            vram_rdata[10],
                            vram_rdata[11],
                            vram_rdata[12],
                            vram_rdata[13],
                            vram_rdata[14],
                            vram_rdata[15],
                            vram_rdata[0],
                            vram_rdata[1],
                            vram_rdata[2],
                            vram_rdata[3],
                            vram_rdata[4],
                            vram_rdata[5],
                            vram_rdata[6],
                            vram_rdata[7]
                        } : vram_rdata;
                    for (int i = 0; i < 8; i++) begin
                        if (obj_next_list[obj_ctr].tile_exist[i]) begin
                            objs_next[time_ctr[6:1]].x
                                <= obj_next_list[obj_ctr].x + i * 8;
                            break;
                        end
                    end
                    objs_next[time_ctr[6:1]].palette <= obj_next_list[obj_ctr].palette;
                    objs_next[time_ctr[6:1]].prior <= obj_next_list[obj_ctr].prior;
                end else begin
                    {objs_next[time_ctr[6:1]].pixels_3,
                    objs_next[time_ctr[6:1]].pixels_2} <=
                        (obj_next_list[obj_ctr].x_flip) ? {
                            vram_rdata[8],
                            vram_rdata[9],
                            vram_rdata[10],
                            vram_rdata[11],
                            vram_rdata[12],
                            vram_rdata[13],
                            vram_rdata[14],
                            vram_rdata[15],
                            vram_rdata[0],
                            vram_rdata[1],
                            vram_rdata[2],
                            vram_rdata[3],
                            vram_rdata[4],
                            vram_rdata[5],
                            vram_rdata[6],
                            vram_rdata[7]
                        } : vram_rdata;
                end
            end
        end
    end

    // ---- 4. Rendering --------

    // objs
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 34; i++) begin
                objs[i].x <= -256;
            end
        end else if (dot_en & newline) begin
            objs <= objs_next;
        end
    end

    generate
        for (gi = 0; gi < 34; gi++) begin : GenObjPixelMainList
            logic x_in;
            logic [2:0] fine_x;

            // objs[gi].x <= x <= objs[gi].x + 7
            assign x_in =
                ($signed({1'b0, x}) >= objs[gi].x)
                & ($signed({1'b0, x}) <= (objs[gi].x + 7));
            assign fine_x = $signed({1'b0, x}) - objs[gi].x;
            assign obj_pixel_main_list[gi] = x_in ? {
                objs[gi].pixels_3[~fine_x],
                objs[gi].pixels_2[~fine_x],
                objs[gi].pixels_1[~fine_x],
                objs[gi].pixels_0[~fine_x]
            } : 4'h0;
        end
    endgenerate

    always_comb begin
        obj_pixel.main = 4'h0;
        obj_pixel.palette = 3'h0;
        obj_pixel.prior = 1'b0;
        for (int i = 0; i < 34; i++) begin
            if (obj_pixel_main_list[i] != 4'h0) begin
                obj_pixel.main = obj_pixel_main_list[i];
                obj_pixel.palette = objs[i].palette;
                obj_pixel.prior = objs[i].prior;
                break;
            end
        end
    end

endmodule
