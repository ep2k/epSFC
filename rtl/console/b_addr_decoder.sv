// ==============================
//  Bus-B Address Decoder
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module b_addr_decoder
    import bus_pkg::*;
(
    input logic [7:0] b_addr,
    input logic b_write,
    input logic b_read,

    output b_read_target_type b_read_target,
    output b_op_type b_op
);

    // b_addr, b_write, b_read -> b_read_target, b_op
    always_comb begin

        b_read_target = B_RT_CART;
        b_op = B_NONE;

        if (b_write) begin
            priority casez (b_addr)
                8'h00: b_op = B_INDISP;
                8'h01: b_op = B_OBSEL;
                8'h02: b_op = B_OAMADDL;
                8'h03: b_op = B_OAMADDH;
                8'h04: b_op = B_OAMDATA;
                8'h05: b_op = B_BGMODE;
                8'h06: b_op = B_MOSAIC;
                8'h07: b_op = B_BG1SC;
                8'h08: b_op = B_BG2SC;
                8'h09: b_op = B_BG3SC;
                8'h0a: b_op = B_BG4SC;
                8'h0b: b_op = B_BG12NBA;
                8'h0c: b_op = B_BG34NBA;
                8'h0d: b_op = B_BG1HOFS;
                8'h0e: b_op = B_BG1VOFS;
                8'h0f: b_op = B_BG2HOFS;
                8'h10: b_op = B_BG2VOFS;
                8'h11: b_op = B_BG3HOFS;
                8'h12: b_op = B_BG3VOFS;
                8'h13: b_op = B_BG4HOFS;
                8'h14: b_op = B_BG4VOFS;
                8'h15: b_op = B_VMAIN;
                8'h16: b_op = B_VMADDL;
                8'h17: b_op = B_VMADDH;
                8'h18: b_op = B_VMDATAL;
                8'h19: b_op = B_VMDATAH;
                8'h1a: b_op = B_M7SEL;
                8'h1b: b_op = B_M7A;
                8'h1c: b_op = B_M7B;
                8'h1d: b_op = B_M7C;
                8'h1e: b_op = B_M7D;
                8'h1f: b_op = B_M7X;
                8'h20: b_op = B_M7Y;
                8'h21: b_op = B_CGADD;
                8'h22: b_op = B_CGDATA;
                8'h23: b_op = B_W12SEL;
                8'h24: b_op = B_W34SEL;
                8'h25: b_op = B_WOBJSEL;
                8'h26: b_op = B_WH0;
                8'h27: b_op = B_WH1;
                8'h28: b_op = B_WH2;
                8'h29: b_op = B_WH3;
                8'h2a: b_op = B_WBGLOG;
                8'h2b: b_op = B_WOBJLOG;
                8'h2c: b_op = B_TM;
                8'h2d: b_op = B_TS;
                8'h2e: b_op = B_TMW;
                8'h2f: b_op = B_TSW;
                8'h30: b_op = B_CGWSEL;
                8'h31: b_op = B_CGADSUB;
                8'h32: b_op = B_COLDATA;
                8'h33: b_op = B_SETINI;

                8'b01??_??00: b_op = B_APUIO0_W;
                8'b01??_??01: b_op = B_APUIO1_W;
                8'b01??_??10: b_op = B_APUIO2_W;
                8'b01??_??11: b_op = B_APUIO3_W;

                8'h80: b_op = B_WMDATA_W;
                8'h81: b_op = B_WMADDL;
                8'h82: b_op = B_WMADDM;
                8'h83: b_op = B_WMADDH;

                default: b_op = B_NONE;
            endcase
        end else if (b_read) begin
            priority casez (b_addr)
                8'h34: {b_read_target, b_op} = {B_RT_PPU, B_MPYL};
                8'h35: {b_read_target, b_op} = {B_RT_PPU, B_MPYM};
                8'h36: {b_read_target, b_op} = {B_RT_PPU, B_MPYH};
                8'h37: {b_read_target, b_op} = {B_RT_CART, B_SLHV};
                8'h38: {b_read_target, b_op} = {B_RT_PPU, B_RDOAM};
                8'h39: {b_read_target, b_op} = {B_RT_PPU, B_RDVRAML};
                8'h3a: {b_read_target, b_op} = {B_RT_PPU, B_RDVRAMH};
                8'h3b: {b_read_target, b_op} = {B_RT_PPU, B_RDCGRAM};
                8'h3c: {b_read_target, b_op} = {B_RT_PPU, B_OPHCT};
                8'h3d: {b_read_target, b_op} = {B_RT_PPU, B_OPVCT};
                8'h3e: {b_read_target, b_op} = {B_RT_PPU, B_STAT77};
                8'h3f: {b_read_target, b_op} = {B_RT_PPU, B_STAT78};

                8'b01??_??00: {b_read_target, b_op} = {B_RT_APU, B_APUIO0_R};
                8'b01??_??01: {b_read_target, b_op} = {B_RT_APU, B_APUIO1_R};
                8'b01??_??10: {b_read_target, b_op} = {B_RT_APU, B_APUIO2_R};
                8'b01??_??11: {b_read_target, b_op} = {B_RT_APU, B_APUIO3_R};

                8'h80: {b_read_target, b_op} = {B_RT_WRAM, B_WMDATA_R};

                default: {b_read_target, b_op} = {B_RT_CART, B_NONE};
            endcase
        end else begin
            ;
        end
    end

endmodule
