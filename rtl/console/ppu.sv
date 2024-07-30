// ===================================
//  Picture Processing Unit (PPU)
// ===================================

// Copyright(C) 2024 ep2k All Rights Reserved.

`include "config.vh"

module ppu
    import bus_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input b_op_type b_op,
    input logic [7:0] wdata,
    output logic [7:0] rdata,

    output logic [8:0] h_ctr,
    output logic [8:0] v_ctr,
    output logic [11:0] frame_ctr,

    output logic [8:0] xout,
    output logic [8:0] yout,
    output logic [14:0] color,
    output logic color_write,
    output logic dr_write_req,

    output logic overscan = 1'b0,   // register
    output logic interlace = 1'b0,  // register
    output logic [2:0] bgmode_out,
    input logic [4:0] graphic_off,
    input logic coord_pointer_en,
    input logic [7:0] coord_pointer_x,
    input logic [7:0] coord_pointer_y
);

    genvar gi;

    // ------------------------------
    //  Parameters
    // ------------------------------

    import ppu_pkg::*;
    
    // ------------------------------
    //  Wires
    // ------------------------------

    // ---- VRAM --------

    logic [14:0] vram_l_addr, vram_h_addr;
    logic [14:0] vram_access_addr;
    logic [14:0] vram_access_addr_trans;
    logic [14:0] bg7_vram_l_addr, bg7_vram_h_addr;
    logic [14:0] obj_vram_addr;
    logic obj_vram_read;
    logic [7:0] vram_rdata_l, vram_rdata_h;
    logic [15:0] vram_rdata;

    // ---- OAM --------

    logic [9:0] oam_addr;
    logic [9:0] obj_oam_addr;
    logic obj_oam_read;
    logic [7:0] oam_rdata;
    logic oamaddr_reload;

    // ---- CGRAM --------

    logic [7:0] cgram_addr, mixer_cgram_addr;
    logic [7:0] cgram_rdata_l, cgram_rdata_h;
    logic [14:0] cgram_rdata;

    // ---- Timing --------

    logic field, dot_en;
    logic [2:0] dot_ctr;
    logic [8:0] x_fetch;
    logic [7:0] x_mid, x_bg7, y;

    // ---- BG --------

    logic [2:0] bg_mode[3:0];
    logic [1:0] bg_target;
    logic fetch_map, fetch_data, bg7_period, color_period;
    logic [2:0] fetch_data_num;
    logic [14:0] bg_vram_addr[3:0];

    bg_pixel_type bg_pixel_06[3:0];     // Mode 0-6 の出力
    bg_pixel_type bg_pixel[3:0];

    logic [9:0] opt_x, opt_y;
    logic [1:0] opt_apply_x, opt_apply_y;

    logic mosaic_pixel_strobe;
    logic [3:0] mosaic_yofs_subtract;

    logic [7:0] bg7_pixel;
    logic bg7_black;

    logic [3:0] mosaic_x_subtract_bg7;
    logic [3:0] mosaic_y_subtract_bg7;
    
    // ---- OBJ --------

    logic obj_en;
    logic start_oamprefetch, start_objfetch;
    logic obj_ovf_clear;

    obj_pixel_type obj_pixel;
    logic obj_range_ovf, obj_time_ovf;

    // ---- Window --------

    logic [1:0] in_win;
    logic [5:0] effect_win1, effect_win2, effect_win;

    // ---- Pixel Mixer --------

    logic [14:0] color_left, color_right, color_raw, color_bright;

    // ---- Others --------

    logic [23:0] mul_result;

    // ------------------------------
    //  Registers
    // ------------------------------

    // ---- RAM Access --------

    logic [4:0] vram_access_control = 5'h0;
    logic [14:0] vram_access_addr_reg = 15'h0;
    logic [15:0] vram_prefetch = 16'h0;

    logic [8:0] oam_access_addr_reload = 9'h0;
    logic [9:0] oam_access_addr = 10'h0;

    logic [7:0] cgram_access_addr = 8'h0;
    logic cgram_access_tgl = 1'b0;

    // ---- BG --------

    logic high_res = 1'b0;

    logic [2:0] bgmode = 3'h0;
    logic [3:0] bg_tilesize = 4'h0;
    logic bg3_prior = 1'b0;

    logic [3:0] mosaic_size = 4'h0;
    logic [3:0] mosaic_enable = 4'h0;

    logic [5:0] bg_map_base[3:0];   // 6bit?
    logic [1:0] bg_map_size[3:0];
    logic [2:0] bg_data_base[3:0];  // 4bit?
    logic [9:0] bg_xofs[3:0];
    logic [9:0] bg_yofs[3:0];

    logic [7:0] bg_old;

    // ---- BG Mode 7 --------

    logic [3:0] m7sel = 4'h0;

    logic [15:0] m7_a = 16'h0;
    logic [15:0] m7_b = 16'h0;
    logic [15:0] m7_c = 16'h0;
    logic [15:0] m7_d = 16'h0;

    logic [12:0] m7_xofs = 13'h0;
    logic [12:0] m7_yofs = 13'h0;
    logic [12:0] m7_xorig = 13'h0;
    logic [12:0] m7_yorig = 13'h0;

    logic [7:0] m7_old;

    logic extbg = 1'b0;

    // ---- OBJ --------

    logic [2:0] obj_size = 3'h0;
    logic [2:0] obj_name_base = 3'h0;
    logic [1:0] obj_name_select = 2'h0;

    logic obj_rotation = 1'b0;
    logic [6:0] top_obj = 7'h0;

    logic interlace_obj = 1'b0;

    // ---- Window --------

    logic [7:0] win1_x1 = 8'h0;
    logic [7:0] win1_x2 = 8'h0;
    logic [7:0] win2_x1 = 8'h0;
    logic [7:0] win2_x2 = 8'h0;

    // 0-3: BG1-4, 4:OBJ, 5:MATH
    // 下位2bit: W1, 上位2bit: W2
    logic [3:0] winsel[5:0];
    logic [1:0] winlog[5:0];

    logic [4:0] win_mask_main = 5'h0;
    logic [4:0] win_mask_sub = 5'h0;

    // ---- Pixel Mixer --------

    logic [4:0] main_enable = 5'h0;
    logic [4:0] sub_enable = 5'h0;

    logic [1:0] main_black = 2'h0;
    logic [1:0] math_area = 2'h0;
    logic use_sub = 1'b0;
    logic use_direct_color = 1'b0;

    logic [7:0] math_control = 8'h0;

    logic [14:0] sub_backdrop = 15'h0;

    // ---- Others --------

    logic fblank = 1'b0;
    logic [3:0] brightness = 4'h0;

    logic [8:0] h_ctr_latch = 9'h0;
    logic [8:0] v_ctr_latch = 9'h0;
    logic hv_latch_flg = 1'b0;
    logic h_latch_tgl = 1'b0;
    logic v_latch_tgl = 1'b0;

    // ------------------------------
    //  Main
    // ------------------------------
    
    // rdata
    always_comb begin
        case (b_op)
            B_RDVRAML: rdata = vram_prefetch[7:0];
            B_RDVRAMH: rdata = vram_prefetch[15:8];
            B_RDOAM: rdata = oam_rdata;
            B_RDCGRAM: rdata = cgram_access_tgl
                    ? {1'b0, cgram_rdata[14:8]} : cgram_rdata[7:0];
            B_MPYL: rdata = mul_result[7:0];
            B_MPYM: rdata = mul_result[15:8];
            B_MPYH: rdata = mul_result[23:16];
            B_OPHCT: rdata = h_latch_tgl ? {7'h0, h_ctr_latch[8]} : h_ctr_latch[7:0];
            B_OPVCT: rdata = v_latch_tgl ? {7'h0, v_ctr_latch[8]} : v_ctr_latch[7:0];
            B_STAT77: rdata = {obj_time_ovf, obj_range_ovf, 2'h0, 4'h1};
            B_STAT78: rdata = {field, hv_latch_flg, 1'b0, 4'h2};
            default: rdata = 8'h0;
        endcase
    end

    assign bgmode_out = bgmode;

    // ---- VRAM --------

    bram_vram bram_vram_l(      // IP (RAM: 1-PORT, 8bit * 32768)
        .address(vram_l_addr),
        .clock(clk),
        .data(wdata),
        .wren(((~(fetch_map | fetch_data)) | fblank) & cpu_en & (b_op == B_VMDATAL)),
        .q(vram_rdata_l)
    );

    bram_vram bram_vram_h(      // IP (RAM: 1-PORT, 8bit * 32768)
        .address(vram_h_addr),
        .clock(clk),
        .data(wdata),
        .wren(((~(fetch_map | fetch_data)) | fblank) & cpu_en & (b_op == B_VMDATAH)),
        .q(vram_rdata_h)
    );

    assign vram_rdata = {vram_rdata_h, vram_rdata_l};

    always_comb begin
        if (fblank) begin
            vram_l_addr = vram_access_addr_trans;
            vram_h_addr = vram_access_addr_trans;
        end else if ((bgmode == 3'h7) & bg7_period) begin
            vram_l_addr = bg7_vram_l_addr;
            vram_h_addr = bg7_vram_h_addr;
        end else if (fetch_map | fetch_data) begin
            vram_l_addr = bg_vram_addr[bg_target];
            vram_h_addr = bg_vram_addr[bg_target];
        end else if (obj_vram_read) begin
            vram_l_addr = obj_vram_addr;
            vram_h_addr = obj_vram_addr;
        end else begin
            vram_l_addr = vram_access_addr_trans;
            vram_h_addr = vram_access_addr_trans;
        end
    end

    // vram_access_control
    always_ff @(posedge clk) begin
        if (reset) begin
            vram_access_control <= 5'h0;
        end else if (cpu_en & (b_op == B_VMAIN)) begin
            vram_access_control <= {wdata[7], wdata[3:0]};
        end
    end

    // vram_access_addr_reg
    always_ff @(posedge clk) begin
        if (reset) begin
            vram_access_addr_reg <= 15'h0;
        end else if (cpu_en) begin
            if (b_op == B_VMADDL) begin
                vram_access_addr_reg[7:0] <= wdata;
            end else if (b_op == B_VMADDH) begin
                vram_access_addr_reg[14:8] <= wdata[6:0];
            end else if (vram_access_control[4] ? ((b_op == B_VMDATAH) | (b_op == B_RDVRAMH)) : ((b_op == B_VMDATAL) | (b_op == B_RDVRAML))) begin
                if (vram_access_control[1]) begin
                    vram_access_addr_reg[14:7] <= vram_access_addr_reg[14:7] + 8'h1;
                end else if (vram_access_control[0]) begin
                    vram_access_addr_reg[14:5] <= vram_access_addr_reg[14:5] + 10'h1;
                end else begin
                    vram_access_addr_reg <= vram_access_addr_reg + 15'h1;
                end
            end
        end
    end

    // vram_access_addr
    /*
        B_RDVRAML,Hではインクリメント前のアドレスでプリフェッチする
        (次回の読み込み時には指定アドレスの1つ前のアドレスのデータが返される)
    */
    always_comb begin
        case (b_op)
            B_VMADDL: vram_access_addr = {vram_access_addr_reg[14:8], wdata};
            B_VMADDH: vram_access_addr = {wdata[6:0], vram_access_addr_reg[7:0]};
            default: vram_access_addr = vram_access_addr_reg;
        endcase
    end

    // vram_access_addr_trans
    always_comb begin
        unique case (vram_access_control[3:2])
            2'h0: vram_access_addr_trans = vram_access_addr;
            2'h1: vram_access_addr_trans = {
                vram_access_addr[14:8],
                vram_access_addr[4:0],
                vram_access_addr[7:5]
            };
            2'h2: vram_access_addr_trans = {
                vram_access_addr[14:9],
                vram_access_addr[5:0],
                vram_access_addr[8:6]
            };
            2'h3: vram_access_addr_trans = {
                vram_access_addr[14:10],
                vram_access_addr[6:0],
                vram_access_addr[9:7]
            };
        endcase
    end

    // vram_prefetch
    always_ff @(posedge clk) begin
        if (reset) begin
            vram_prefetch <= 16'h0;
        end else if (cpu_en & (
            (b_op == B_VMADDL)
            | (b_op == B_VMADDH)
            | (vram_access_control[4] ? (b_op == B_RDVRAMH) : (b_op == B_RDVRAML))
            )) begin
            vram_prefetch <= vram_rdata;
        end
    end

    // ---- OAM --------

    // 本来は1st access/偶数アドレスへの書き込みはOAMに反映されない(2nd access/奇数アドレスのときに反映される)が，ここでは反映させている(実装簡略化のため)
    bram_oam bram_oam(      // IP (RAM: 1-PORT, 8bit * 544)
        .address(oam_addr),
        .clock(clk),
        .data(wdata),
        .wren(((~obj_oam_read) | fblank) & cpu_en & (b_op == B_OAMDATA)),
        .q(oam_rdata)
    );

    // oam_access_addr_reload
    always_ff @(posedge clk) begin
        if (reset) begin
            oam_access_addr_reload <= 9'h0;
        end else if (cpu_en) begin
            case (b_op)
                B_OAMADDL: oam_access_addr_reload[7:0] <= wdata;
                B_OAMADDH: oam_access_addr_reload[8] <= wdata[0];
                default: ;
            endcase
        end
    end

    // oam_access_addr
    always_ff @(posedge clk) begin
        if (reset) begin
            oam_access_addr <= 10'h0;
        end else if (cpu_en & b_op == B_OAMADDL) begin
            oam_access_addr <= {oam_access_addr_reload[8], wdata, 1'b0};
        end else if (cpu_en & b_op == B_OAMADDH) begin
            oam_access_addr <= {wdata[0], oam_access_addr_reload[7:0], 1'b0};
        end else if (cpu_en & b_op == B_OAMDATA) begin
            oam_access_addr <= oam_access_addr + 10'h1;
        end else if (cpu_en & b_op == B_RDOAM) begin
            oam_access_addr <= oam_access_addr + 10'h1;
        end else if (dot_en & oamaddr_reload) begin
            oam_access_addr <= {oam_access_addr_reload, 1'b0};
        end else if ((v_ctr == (overscan ? 9'd240 : 9'd225)) & (cpu_en & fblank & (~wdata[7]) & (b_op == B_INDISP))) begin
            oam_access_addr <= {oam_access_addr_reload, 1'b0};
        end
    end

    assign oam_addr = (obj_oam_read & (~fblank)) ? obj_oam_addr : oam_access_addr;

    // ---- CGRAM --------

    bram_cgram bram_cgram_l(        // IP (RAM: 1-PORT, 8bit * 256)
        .address(cgram_addr),
        .clock(clk),
        .data(wdata),
        .wren(((~color_period) | fblank) & cpu_en & (b_op == B_CGDATA) & (~cgram_access_tgl)),
        .q(cgram_rdata_l)
    );

    bram_cgram bram_cgram_h(        // IP (RAM: 1-PORT, 8bit * 256)
        .address(cgram_addr),
        .clock(clk),
        .data({1'b0, wdata[6:0]}),
        .wren(((~color_period) | fblank) & cpu_en & (b_op == B_CGDATA) & cgram_access_tgl),
        .q(cgram_rdata_h)
    );

    assign cgram_rdata = {cgram_rdata_h[6:0], cgram_rdata_l};

    // cgram_access_addr, cgram_access_tgl
    always_ff @(posedge clk) begin
        if (reset) begin
            {cgram_access_addr, cgram_access_tgl} <= 9'h0;
        end else if (cpu_en) begin
            case (b_op)
                B_CGADD: {cgram_access_addr, cgram_access_tgl} <= {wdata, 1'b0};
                B_CGDATA: {cgram_access_addr, cgram_access_tgl}
                            <= {cgram_access_addr, cgram_access_tgl} + 9'h1;
                B_RDCGRAM: {cgram_access_addr, cgram_access_tgl}
                            <= {cgram_access_addr, cgram_access_tgl} + 9'h1;
                default: ;
            endcase
        end
    end

    assign cgram_addr = (color_period & (~fblank)) ? mixer_cgram_addr : cgram_access_addr;

    // ---- I/O Registers --------

    always_ff @(posedge clk) begin
        if (reset) begin
            {fblank, brightness} <= 5'h0;
            {main_enable, sub_enable} <= 10'h0;
            {extbg, high_res, overscan, interlace_obj, interlace} <= 5'h0;
            {bg_tilesize, bg3_prior, bgmode} <= 8'h0;
            {mosaic_size, mosaic_enable} <= 8'h0;
            for (int i = 0; i < 4; i++) begin
                {bg_map_base[i], bg_map_size[i]} <= 8'h0;
                bg_data_base[i] <= 3'h0;
                bg_xofs[i] <= 10'h0;
                bg_yofs[i] <= 10'h0;
            end
            m7sel <= 4'h0;
            m7_a <= 16'h0;
            m7_b <= 16'h0;
            m7_c <= 16'h0;
            m7_d <= 16'h0;
            m7_xofs <= 13'h0;
            m7_yofs <= 13'h0;
            m7_xorig <= 13'h0;
            m7_yorig <= 13'h0;
            {obj_size, obj_name_select, obj_name_base} <= 8'h0;
            top_obj <= 7'h0;
            obj_rotation <= 1'b0;
            win1_x1 <= 8'h0;
            win1_x2 <= 8'h0;
            win2_x1 <= 8'h0;
            win2_x2 <= 8'h0;
            for (int i = 0; i < 6; i++) begin
                winsel[i] <= 4'h0;
                winlog[i] <= 2'h0;
            end
            win_mask_main <= 5'h0;
            win_mask_sub <= 5'h0;
            {main_black, math_area, use_sub, use_direct_color} <= 6'h0;
            math_control <= 8'h0;
            sub_backdrop <= 15'h0;
        end else if (cpu_en) begin
            case (b_op)
                B_INDISP: {fblank, brightness} <= {wdata[7], wdata[3:0]};
                B_TM: main_enable <= wdata[4:0];
                B_TS: sub_enable <= wdata[4:0];
                B_SETINI: {extbg, high_res, overscan, interlace_obj, interlace}
                            <= {wdata[6], wdata[3:0]};
                B_BGMODE: {bg_tilesize, bg3_prior, bgmode} <= wdata;
                B_MOSAIC: {mosaic_size, mosaic_enable} <= wdata;
                B_BG1SC: {bg_map_base[0], bg_map_size[0]} <= wdata;
                B_BG2SC: {bg_map_base[1], bg_map_size[1]} <= wdata;
                B_BG3SC: {bg_map_base[2], bg_map_size[2]} <= wdata;
                B_BG4SC: {bg_map_base[3], bg_map_size[3]} <= wdata;
                B_BG12NBA: {bg_data_base[1], bg_data_base[0]} <= {wdata[6:4], wdata[2:0]};
                B_BG34NBA: {bg_data_base[3], bg_data_base[2]} <= {wdata[6:4], wdata[2:0]};
                B_BG1HOFS: begin
                    bg_xofs[0] <= {wdata[1:0], bg_old};
                    m7_xofs <= {wdata[4:0], m7_old};    // M7HOFS
                end
                B_BG1VOFS: begin
                    bg_yofs[0] <= {wdata[1:0], bg_old};
                    m7_yofs <= {wdata[4:0], m7_old};    // M7VOFS
                end
                B_BG2HOFS: bg_xofs[1] <= {wdata[1:0], bg_old};
                B_BG2VOFS: bg_yofs[1] <= {wdata[1:0], bg_old};
                B_BG3HOFS: bg_xofs[2] <= {wdata[1:0], bg_old};
                B_BG3VOFS: bg_yofs[2] <= {wdata[1:0], bg_old};
                B_BG4HOFS: bg_xofs[3] <= {wdata[1:0], bg_old};
                B_BG4VOFS: bg_yofs[3] <= {wdata[1:0], bg_old};
                B_M7SEL: m7sel <= {wdata[7:6], wdata[1:0]};
                B_M7A: m7_a <= {wdata, m7_old};
                B_M7B: m7_b <= {wdata, m7_old};
                B_M7C: m7_c <= {wdata, m7_old};
                B_M7D: m7_d <= {wdata, m7_old};
                B_M7X: m7_xorig <= {wdata[4:0], m7_old};
                B_M7Y: m7_yorig <= {wdata[4:0], m7_old};
                B_OBSEL: {obj_size, obj_name_select, obj_name_base} <= wdata;
                B_OAMADDL: top_obj <= wdata[7:1];
                B_OAMADDH: obj_rotation <= wdata[7];
                B_WH0: win1_x1 <= wdata;
                B_WH1: win1_x2 <= wdata;
                B_WH2: win2_x1 <= wdata;
                B_WH3: win2_x2 <= wdata;
                B_W12SEL: {winsel[1], winsel[0]} <= wdata;
                B_W34SEL: {winsel[3], winsel[2]} <= wdata;
                B_WOBJSEL: {winsel[5], winsel[4]} <= wdata;
                B_WBGLOG: {winlog[3], winlog[2], winlog[1], winlog[0]} <= wdata;
                B_WOBJLOG: {winlog[5], winlog[4]} <= wdata[3:0];
                B_TMW: win_mask_main <= wdata[4:0];
                B_TSW: win_mask_sub <= wdata[4:0];
                B_CGWSEL: {main_black, math_area, use_sub, use_direct_color}
                            <= {wdata[7:4], wdata[1:0]};
                B_CGADSUB: math_control <= wdata;
                B_COLDATA: begin
                    if (wdata[7]) begin
                        sub_backdrop[14:10] <= wdata[4:0];
                    end
                    if (wdata[6]) begin
                        sub_backdrop[9:5] <= wdata[4:0];
                    end
                    if (wdata[5]) begin
                        sub_backdrop[4:0] <= wdata[4:0];
                    end
                end
                default: ;
            endcase
        end
    end

    // bg_old
    always_ff @(posedge clk) begin
        if (cpu_en & ((b_op == B_BG1HOFS) | (b_op == B_BG1VOFS) | (b_op == B_BG2HOFS) | (b_op == B_BG2VOFS) | (b_op == B_BG3HOFS) | (b_op == B_BG3VOFS) | (b_op == B_BG4HOFS) | (b_op == B_BG4VOFS))) begin
            bg_old <= wdata;
        end
    end

    // m7_old
    always_ff @(posedge clk) begin
        if (cpu_en & ((b_op == B_BG1HOFS) | (b_op == B_BG1VOFS) | (b_op == B_M7A) | (b_op == B_M7B) | (b_op == B_M7C) | (b_op == B_M7D) | (b_op == B_M7X) | (b_op == B_M7Y))) begin
            m7_old <= wdata;
        end
    end

    // hv_latch
    always_ff @(posedge clk) begin
        if (reset) begin
            h_ctr_latch <= 9'h0;
            v_ctr_latch <= 9'h0;
            hv_latch_flg <= 1'b0;
            h_latch_tgl <= 1'b0;
            v_latch_tgl <= 1'b0;
        end else if (cpu_en) begin
            if (b_op == B_SLHV) begin
                h_ctr_latch <= h_ctr;
                v_ctr_latch <= v_ctr;
                hv_latch_flg <= 1'b1;
            end else if (b_op == B_OPHCT) begin
                h_latch_tgl <= ~h_latch_tgl;
            end else if (b_op == B_OPVCT) begin
                v_latch_tgl <= ~v_latch_tgl;
            end else if (b_op == B_STAT78) begin
                hv_latch_flg <= 1'b0;
                h_latch_tgl <= 1'b0;
                v_latch_tgl <= 1'b0;
            end
        end
    end

    // ---- PPU Controller --------

    ppu_controller ppu_controller(
        .clk,
        .reset,
        .overscan,
        .interlace,
        .bgmode,

        .dot_ctr,
        .h_ctr,
        .v_ctr,
        .field,
        .frame_ctr,

        .dot_en,
        .obj_en,
        
        .x_fetch,
        .x_mid,
        .x_bg7,
        .y,

        .bg_mode,
        .bg_target,
        .fetch_map,
        .fetch_data,
        .fetch_data_num,

        .oamaddr_reload,
        .start_oamprefetch,
        .start_objfetch,
        .obj_ovf_clear,

        .bg7_period,
        .color_period,

        .xout,
        .yout,
        .color_write,
        .dr_write_req
    );

    // ---- Background (BG) --------

    generate
        for (gi = 0; gi < 4; gi++) begin : BGGen
            
            logic [9:0] opt_x_gi;
            logic [9:0] opt_y_gi;
            logic [1:0] opt_apply_x_gi;
            logic [1:0] opt_apply_y_gi;
            
            if (gi == 2) begin  // OPTはBG3が行う
                assign opt_x = opt_x_gi;
                assign opt_y = opt_y_gi;
                assign opt_apply_x = opt_apply_x_gi;
                assign opt_apply_y = opt_apply_y_gi;
            end

            logic [9:0] bg_xofs_eff, bg_yofs_eff;
            if (gi < 2) begin   // OPTの適用先: BG1, 2
                assign bg_xofs_eff = opt_apply_x[gi] ? {opt_x[9:3], bg_xofs[gi][2:0]} : bg_xofs[gi];
                assign bg_yofs_eff = opt_apply_y[gi] ? opt_y : bg_yofs[gi];
            end else begin
                assign bg_xofs_eff = bg_xofs[gi];
                assign bg_yofs_eff = bg_yofs[gi];
            end

            bg bg(
                .clk,
                .dot_en,

                .mode(bg_mode[gi]),
                
                .fetch_map(fetch_map & (bg_target == gi)),
                .fetch_data(fetch_data & (bg_target == gi)),
                .fetch_data_num,

                .x(x_fetch),
                .y,
                .xofs(bg_xofs_eff),
                .yofs(bg_yofs_eff - (mosaic_enable[gi] ? {6'h0, mosaic_yofs_subtract} : 10'h0)), // Mosaic Horizontal handling
                .map_base(bg_map_base[gi]),
                .map_size(bg_map_size[gi]),
                .data_base(bg_data_base[gi]),
                .tile_big(bg_tilesize[gi]),

                .vram_addr(bg_vram_addr[gi]),
                .vram_rdata,

                .pixel(bg_pixel_06[gi]),

                .newline(h_ctr == 9'h0),
                .opt_x(opt_x_gi),
                .opt_y(opt_y_gi),
                .opt_apply_x(opt_apply_x_gi),
                .opt_apply_y(opt_apply_y_gi),

                .mosaic_enable(mosaic_enable[gi]),
                .mosaic_pixel_strobe
            );

        end
    endgenerate

    mosaic mosaic(
        .clk,
        .reset,
        .dot_en,

        .newframe(v_ctr == 9'd0),
        .newline(h_ctr == 9'd0),
        .period_start(x_mid == 8'hff),

        .size(mosaic_size),

        .pixel_strobe(mosaic_pixel_strobe),
        .yofs_subtract(mosaic_yofs_subtract),

        .x_subtract_bg7(mosaic_x_subtract_bg7),
        .y_subtract_bg7(mosaic_y_subtract_bg7)
    );

    bg7 bg7(
        .clk,
        .reset,
        .dot_en,
        .dot_ctr,

        .m7sel,

        .m7_a,
        .m7_b,
        .m7_c,
        .m7_d,

        .m7_xofs,
        .m7_yofs,
        .m7_xorig,
        .m7_yorig,

        .x(x_bg7 - (mosaic_enable[0] ? {4'h0, mosaic_x_subtract_bg7} : 8'h0)),
        .y(y - (mosaic_enable[0] ? {4'h0, mosaic_y_subtract_bg7} : 8'h0)),

        .vram_l_addr(bg7_vram_l_addr),
        .vram_h_addr(bg7_vram_h_addr),
        .vram_rdata_l,
        .vram_rdata_h,

        .pixel(bg7_pixel),
        .black(bg7_black)
    );

    always_comb begin

        if (bgmode == 3'h7) begin   // BG Mode 7

            for (int i = 0; i < 4; i++) begin
                bg_pixel[i].main = 8'h0;
                bg_pixel[i].sub = 8'h0;
                bg_pixel[i].palette = 3'h0;
                bg_pixel[i].prior = 1'b0;
            end

            bg_pixel[0].main = bg7_pixel;
            if (extbg) begin    // EXTBG
                bg_pixel[1].main = {1'b0, bg7_pixel[6:0]};
                bg_pixel[1].prior = bg7_pixel[7];
            end

        end else begin  // BG Mode 0-6

            bg_pixel = bg_pixel_06;
            
        end

    end

    // ---- Object (OBJ) / Sprite --------

    obj obj(
        .clk,
        .obj_en,
        .dot_en,
        .reset,

        .rotation(obj_rotation),
        .top_obj,
        .size_m(obj_size),
        .name_base(obj_name_base),
        .name_select(obj_name_select),

        .x(x_mid),
        .y,
        .newline(h_ctr == 9'h0),

        .start_oamprefetch,
        .start_objfetch,
        .ovf_clear(obj_ovf_clear & (~fblank)),

        .oam_addr(obj_oam_addr),
        .oam_read(obj_oam_read),
        .oam_rdata,

        .vram_addr(obj_vram_addr),
        .vram_read(obj_vram_read),
        .vram_rdata,

        .obj_pixel,
        .range_ovf_flg(obj_range_ovf),
        .time_ovf_flg(obj_time_ovf)
    );

    // ---- Window --------

    assign in_win[0] = (win1_x1 <= x_mid) & (x_mid <= win1_x2);
    assign in_win[1] = (win2_x1 <= x_mid) & (x_mid <= win2_x2);

    // winsel = 0?:無効, 10:win内, 11:win外
    generate
        for (gi = 0; gi < 6; gi++) begin : WinGen

            assign effect_win1[gi] = winsel[gi][0] ^ in_win[0];
            assign effect_win2[gi] = winsel[gi][2] ^ in_win[1];

            always_comb begin
                unique case ({winsel[gi][3], winsel[gi][1]}) // win2,win1有効
                    2'b00: effect_win[gi] = 1'b0;
                    2'b01: effect_win[gi] = effect_win1[gi];
                    2'b10: effect_win[gi] = effect_win2[gi];
                    2'b11: begin
                        unique case (winlog[gi])
                            2'b00: effect_win[gi] = effect_win1[gi] | effect_win2[gi];
                            2'b01: effect_win[gi] = effect_win1[gi] & effect_win2[gi];
                            2'b10: effect_win[gi] = effect_win1[gi] ^ effect_win2[gi];
                            2'b11: effect_win[gi] = effect_win1[gi] ~^ effect_win2[gi];
                        endcase
                    end
                endcase
            end
        end
    endgenerate

    // ---- Pixel Mixer (BG + OBJ + CGRAM -> Pixel Color) --------

    pixel_mixer pixel_mixer(
        .clk,
        .step(dot_ctr[1:0]),

        .bg_pixel,
        .obj_pixel,

        .bgmode,
        .bg3_prior,
        .high_res,
        .use_direct_color,

        .main_enable(
            main_enable & (~graphic_off)
            & (~(effect_win[4:0] & win_mask_main))
        ),
        .sub_enable(
            sub_enable & (~graphic_off)
            & (~(effect_win[4:0] & win_mask_sub))
        ),
        
        .in_win_math(effect_win[5]),
        .main_black,
        .use_sub,
        .math_control,
        .math_area,

        .cgram_addr(mixer_cgram_addr),
        .cgram_rdata,

        .sub_backdrop,

        .color_left,
        .color_right
    );

    assign color_raw = fblank ? 15'h0 : (
            h_ctr[1]
            ? color_right
            : color_left
        );

    generate
        // gi=0/1/2: Red/Green/Blue
        for (gi = 0; gi < 3; gi++) begin : GenBrightnessTable
            brightness_table brightness_table(
                .color_raw(color_raw[gi*5+4:gi*5]),
                .brightness,

                .color(color_bright[gi*5+4:gi*5])
            );
        end
    endgenerate

    assign color = (
            coord_pointer_en
            & (coord_pointer_x == xout[8:1])
            & (coord_pointer_y == yout[8:1])
        ) ? {`COORD_POINTER_B, `COORD_POINTER_G, `COORD_POINTER_R} : color_bright;

    // ---- PPU Multiplier --------

    assign mul_result = $signed(m7_a) * $signed(m7_b[15:8]);
    
endmodule
