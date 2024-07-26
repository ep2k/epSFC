// ==============================
//  Bus-A Address Decoder
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module a_addr_decoder
    import bus_pkg::*;
(
    input logic [23:0] a_addr,
    input logic a_write,
    input logic a_read,

    output logic cart_en,
    output logic wram_en,
    output logic b_en,

    output a_read_target_type a_read_target,
    output a_op_type a_op,

    output mem_speed_type mem_speed
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic system_bank, wram_bank, cart_bank;

    // ------------------------------
    //  Main
    // ------------------------------

    assign system_bank = ~a_addr[22];
    assign wram_bank = (a_addr[23:17] == 7'b0111_111);
    assign cart_bank = (~system_bank) & (~wram_bank);

    assign cart_en = cart_bank | (system_bank & a_addr[15]);
    assign wram_en = wram_bank | (system_bank & (a_addr[15:13] == 3'b000));
    assign b_en = system_bank & (a_addr[15:8] == 8'h21);

    // a_addr, a_write, a_read -> a_read_target, a_op
    always_comb begin

        a_read_target = A_RT_CART;
        a_op = A_NONE;

        if (cart_en) begin
            a_read_target = A_RT_CART;
        end else if (wram_en) begin
            a_read_target = A_RT_WRAM;
        end else if (system_bank & (a_addr[15:10] == 6'b0100_00)) begin // プロセッサ内部レジスタ
            if (a_write) begin
                priority casez (a_addr[9:0])
                    10'h016: a_op = A_JOYWR;
                    10'h200: a_op = A_NMITIMEN;
                    10'h201: a_op = A_WRIO;
                    10'h202: a_op = A_WRMPYA;
                    10'h203: a_op = A_WRMPYB;
                    10'h204: a_op = A_WRDIVL;
                    10'h205: a_op = A_WRDIVH;
                    10'h206: a_op = A_WRDIVB;
                    10'h207: a_op = A_HTIMEL;
                    10'h208: a_op = A_HTIMEH;
                    10'h209: a_op = A_VTIMEL;
                    10'h20a: a_op = A_VTIMEH;
                    10'h20b: a_op = A_MDMAEN;
                    10'h20c: a_op = A_HDMAEN;
                    10'h20d: a_op = A_MEMSEL;

                    10'h3?0: a_op = (~a_addr[7]) ? A_DMAPX_W : A_NONE;
                    10'h3?1: a_op = (~a_addr[7]) ? A_BBADX_W : A_NONE;
                    10'h3?2: a_op = (~a_addr[7]) ? A_A1TXL_W : A_NONE;
                    10'h3?3: a_op = (~a_addr[7]) ? A_A1TXH_W : A_NONE;
                    10'h3?4: a_op = (~a_addr[7]) ? A_A1BX_W : A_NONE;
                    10'h3?5: a_op = (~a_addr[7]) ? A_DASXL_W : A_NONE;
                    10'h3?6: a_op = (~a_addr[7]) ? A_DASXH_W : A_NONE;
                    10'h3?7: a_op = (~a_addr[7]) ? A_DASXB_W : A_NONE;
                    10'h3?8: a_op = (~a_addr[7]) ? A_A2AXL_W : A_NONE;
                    10'h3?9: a_op = (~a_addr[7]) ? A_A2AXH_W : A_NONE;
                    10'h3?a: a_op = (~a_addr[7]) ? A_NTRLX_W : A_NONE;
                    10'h3?b: a_op = (~a_addr[7]) ? A_UNUSEDX_W : A_NONE;
                    10'h3?f: a_op = (~a_addr[7]) ? A_UNUSEDX_W : A_NONE;
                    default: a_op = A_NONE;
                endcase
            end else if (a_read) begin
                priority casez (a_addr[9:0])
                    10'h016: {a_read_target, a_op} = {A_RT_JOY, A_JOYA};
                    10'h017: {a_read_target, a_op} = {A_RT_JOY, A_JOYB};
                    10'h210: {a_read_target, a_op} = {A_RT_HV, A_RDNMI};
                    10'h211: {a_read_target, a_op} = {A_RT_HV, A_TIMEUP};
                    10'h212: {a_read_target, a_op} = {A_RT_HV, A_HVBJOY};
                    10'h213: {a_read_target, a_op} = {A_RT_JOY, A_RDIO};
                    10'h214: {a_read_target, a_op} = {A_RT_MD, A_RDDIVL};
                    10'h215: {a_read_target, a_op} = {A_RT_MD, A_RDDIVH};
                    10'h216: {a_read_target, a_op} = {A_RT_MD, A_RDMPYL};
                    10'h217: {a_read_target, a_op} = {A_RT_MD, A_RDMPYH};
                    10'h218: {a_read_target, a_op} = {A_RT_JOY, A_JOY1L};
                    10'h219: {a_read_target, a_op} = {A_RT_JOY, A_JOY1H};
                    10'h21a: {a_read_target, a_op} = {A_RT_JOY, A_JOY2L};
                    10'h21b: {a_read_target, a_op} = {A_RT_JOY, A_JOY2H};
                    10'h21c: {a_read_target, a_op} = {A_RT_JOY, A_JOY3L};
                    10'h21d: {a_read_target, a_op} = {A_RT_JOY, A_JOY3H};
                    10'h21e: {a_read_target, a_op} = {A_RT_JOY, A_JOY4L};
                    10'h21f: {a_read_target, a_op} = {A_RT_JOY, A_JOY4H};

                    10'h3?0: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_DMAPX_R} : {A_RT_CART, A_NONE};
                    10'h3?1: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_BBADX_R} : {A_RT_CART, A_NONE};
                    10'h3?2: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_A1TXL_R} : {A_RT_CART, A_NONE};
                    10'h3?3: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_A1TXH_R} : {A_RT_CART, A_NONE};
                    10'h3?4: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_A1BX_R} : {A_RT_CART, A_NONE};
                    10'h3?5: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_DASXL_R} : {A_RT_CART, A_NONE};
                    10'h3?6: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_DASXH_R} : {A_RT_CART, A_NONE};
                    10'h3?7: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_DASXB_R} : {A_RT_CART, A_NONE};
                    10'h3?8: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_A2AXL_R} : {A_RT_CART, A_NONE};
                    10'h3?9: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_A2AXH_R} : {A_RT_CART, A_NONE};
                    10'h3?a: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_NTRLX_R} : {A_RT_CART, A_NONE};
                    10'h3?b: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_UNUSEDX_R} : {A_RT_CART, A_NONE};
                    10'h3?f: {a_read_target, a_op} =
                        (~a_addr[7]) ? {A_RT_DMA, A_UNUSEDX_R} : {A_RT_CART, A_NONE};
                    default: {a_read_target, a_op} = {A_RT_CART, A_NONE};
                endcase
            end else begin
                ;
            end
        end else begin
            a_read_target = A_RT_CART;
        end
    end

    // a_addr -> mem_speed
    always_comb begin
        if (wram_en) begin
            mem_speed = MEM_SLOW;
        end else if (b_en) begin
            mem_speed = MEM_FAST;
        end else if (cart_en) begin
            mem_speed = a_addr[23] ? MEM_VAR : MEM_SLOW;
        end else if (a_addr[15:9] == 7'b0100_000) begin // 4000-41FF(oldstyle joypad)
            mem_speed = MEM_XSLOW;
        end else if (a_addr[15:13] == 3'b011) begin // 6000-7FFF
            mem_speed = MEM_SLOW;
        end else begin
            mem_speed = MEM_FAST;
        end
    end

endmodule
