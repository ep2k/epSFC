// ==============================
//  65816 CPU
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module cpu
    import cpu_pkg::*;
(
    input  logic clk,
    input  logic cpu_en,
    input  logic reset,

    input  logic irq,
    input  logic nmi,

    output logic [23:0] mem_addr,
    input  logic [7:0] mem_rdata,
    output logic [7:0] mem_wdata,
    output logic mem_read,
    output logic mem_write
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [15:0] a, x, y, sp, pc, dp;
    logic [7:0] p, pbr, dbr;
    logic [23:0] addr, addr2, vector_addr;
    logic e;            // emulation mode
    logic m8, x8;       // P[M], P[X]
    logic [4:0] ints;   // interrupt

    logic [15:0] reg_wdata;
    logic [7:0] p_wdata;
    logic [15:0] pc_wdata;
    logic [23:0] addr_wdata, addr2_wdata;

    logic [15:0] alu_a, alu_b, alu_y;
    logic alu_c;
    logic [3:0] alu_flgs;

    ctl_signals_type s;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic carry = 1'b0;

    // ------------------------------
    //  Main
    // ------------------------------

    // ---- Registers --------

    register16 reg_a(
        .clk,
        .cpu_en,
        .reset,

        .rdata(a),
        .wdata(reg_wdata),
        .write(s.a_write)
    );

    register16 reg_x(
        .clk,
        .cpu_en,
        .reset,

        .rdata(x),
        .wdata(x8 ? {8'h0, reg_wdata[7:0]} : reg_wdata),
        .write(s.x_write | {x8, 1'b0})
    );

    register16 reg_y(
        .clk,
        .cpu_en,
        .reset,

        .rdata(y),
        .wdata(x8 ? {8'h0, reg_wdata[7:0]} : reg_wdata),
        .write(s.y_write | {x8, 1'b0})
    );

    register16_inc reg_sp(
        .clk,
        .cpu_en,
        .reset,

        .rdata(sp),
        .wdata(e ? {8'h1, reg_wdata[7:0]} : reg_wdata),
        .write(s.sp_write | {e, 1'b0}),
        .inc(s.sp_inc)
    );

    register16 reg_dp(
        .clk,
        .cpu_en,
        .reset,

        .rdata(dp),
        .wdata(reg_wdata),
        .write(s.dp_write)
    );

    register8 reg_pbr(
        .clk,
        .cpu_en,
        .reset,

        .rdata(pbr),
        .wdata(reg_wdata[7:0]),
        .write(s.pbr_write)
    );

    register8 reg_dbr(
        .clk,
        .cpu_en,
        .reset,

        .rdata(dbr),
        .wdata(reg_wdata[7:0]),
        .write(s.dbr_write)
    );

    register_p reg_p(
        .clk,
        .cpu_en,
        .reset,

        .p,
        .e,
        .m(m8),
        .x(x8),
        .wdata(p_wdata),
        .write(s.p_write),

        .xce(s.xce)
    );

    register16 reg_pc(
        .clk,
        .cpu_en,
        .reset,

        .rdata(pc),
        .wdata(pc_wdata),
        .write(s.pc_write)
    );

    register_addr reg_addr(
        .clk,
        .cpu_en,
        .reset,

        .rdata(addr),
        .wdata(addr_wdata),
        .write(s.addr_write),

        .inc(s.addr_inc),
        .page_wrap(1'b0),
        .bank_inc(s.addr_bank_inc)
    );

    register_addr reg_addr2(
        .clk,
        .cpu_en,
        .reset,

        .rdata(addr2),
        .wdata(addr2_wdata),
        .write(s.addr2_write),

        .inc(s.addr2_inc),
        .page_wrap(s.addr2_page_wrap),
        .bank_inc(s.addr2_bank_inc)
    );

    // ---- Datapath --------

    assign mem_read = s.mem_read;
    assign mem_write = s.mem_write;

    // mem_addr
    always_comb begin
        case (s.mem_addr_src)
            C_MA_PC: mem_addr = {pbr, pc};
            C_MA_PC_1: mem_addr = {pbr, pc + 16'h1};
            C_MA_ADDR: mem_addr = addr;
            C_MA_ADDR_1: mem_addr = addr + 24'h1;
            C_MA_ADDR2: mem_addr = addr2;
            C_MA_SP: mem_addr = {8'h0, sp};
            C_MA_SP_1: mem_addr = e ? {16'h1, sp[7:0] + 8'h1} : {8'h0, sp + 16'h1}; // e=1ではsp[8]に繰り上がりをしないように
            C_MA_X: mem_addr = {dbr, x};
            C_MA_Y: mem_addr = {dbr, y};
            C_MA_VA: mem_addr = vector_addr;
            C_MA_VA_1: mem_addr = vector_addr + 24'h1;
            default: mem_addr = {pbr, pc};
        endcase
    end

    // mem_wdata
    always_comb begin
        case (s.mem_wdata_src)
            C_MW_AL: mem_wdata = a[7:0];
            C_MW_AH: mem_wdata = a[15:8];
            C_MW_XL: mem_wdata = x[7:0];
            C_MW_XH: mem_wdata = x[15:8];
            C_MW_YL: mem_wdata = y[7:0];
            C_MW_YH: mem_wdata = y[15:8];
            C_MW_DPL: mem_wdata = dp[7:0];
            C_MW_DPH: mem_wdata = dp[15:8];
            C_MW_PBR: mem_wdata = pbr;
            C_MW_DBR: mem_wdata = dbr;
            C_MW_P: mem_wdata = p;
            C_MW_PCL: mem_wdata = pc[7:0];
            C_MW_PCH: mem_wdata = pc[15:8];
            C_MW_ADDRL: mem_wdata = addr[7:0];
            C_MW_ADDRH: mem_wdata = addr[15:8];
            C_MW_ADDR2L: mem_wdata = addr2[7:0];
            C_MW_ADDR2H: mem_wdata = addr2[15:8];
            C_MW_0: mem_wdata = 8'h0;
            default: mem_wdata = 8'h0;
        endcase
    end

    // reg_wdata
    always_comb begin
        case (s.reg_wdata_src)
            C_RW_ALUY: reg_wdata = alu_y;
            C_RW_ALUYL: reg_wdata = {alu_y[7:0], alu_y[7:0]};
            C_RW_RD: reg_wdata = {mem_rdata, mem_rdata};
            C_RW_ADDRB: reg_wdata = {8'h0, addr[23:16]};
            default: reg_wdata = alu_y;
        endcase
    end

    // p_wdata
    always_comb begin
        case (s.p_wdata_src)
            C_PW_CTL: p_wdata = s.p_wdata_ctl;
            C_PW_ALUYL: p_wdata = alu_y[7:0];
            C_PW_RWL: p_wdata = reg_wdata[7:0];
            default: p_wdata = s.p_wdata_ctl;
        endcase
    end

    // pc_wdata
    always_comb begin
        case (s.pc_wdata_src)
            C_PCW_PC_1: pc_wdata = pc + 16'h1;
            C_PCW_ALUY: pc_wdata = alu_y;
            C_PCW_ADDR: pc_wdata = addr[15:0];
            C_PCW_RD: pc_wdata = {mem_rdata, mem_rdata};
            default: pc_wdata = pc + 16'h1;
        endcase
    end

    // addr_wdata
    always_comb begin
        case (s.addr_wdata_src)
            C_AW_ALUY: addr_wdata = {8'h0, alu_y};
            C_AW_ALUYL: addr_wdata = {alu_y[7:0], alu_y[7:0], alu_y[7:0]};
            C_AW_DBR: addr_wdata = {dbr, 16'h0};
            C_AW_PBR: addr_wdata = {pbr, 16'h0};
            C_AW_PC_1: addr_wdata = {pbr, pc + 16'h1};
            C_AW_DP: addr_wdata = {8'h0, dp};
            C_AW_A: addr_wdata = {8'h0, a};
            C_AW_RD: addr_wdata = {mem_rdata, mem_rdata, mem_rdata};
            C_AW_0: addr_wdata = 24'h0;
            default: addr_wdata = 24'h0;
        endcase
    end

    // addr2_wdata
    always_comb begin
        case (s.addr2_wdata_src)
            C_AW_ALUY: addr2_wdata = {8'h0, alu_y};
            C_AW_ALUYL: addr2_wdata = {alu_y[7:0], alu_y[7:0], alu_y[7:0]};
            C_AW_DBR: addr2_wdata = {dbr, 16'h0};
            C_AW_PBR: addr2_wdata = {pbr, 16'h0};
            C_AW_PC_1: addr2_wdata = {pbr, pc + 16'h1};
            C_AW_DP: addr2_wdata = {8'h0, dp};
            C_AW_A: addr2_wdata = {8'h0, a};
            C_AW_RD: addr2_wdata = {mem_rdata, mem_rdata, mem_rdata};
            C_AW_0: addr2_wdata = 24'h0;
            default: addr2_wdata = 24'h0;
        endcase
    end

    // alu_a
    always_comb begin
        case (s.alu_a_src)
            C_AA_A: alu_a = a;
            C_AA_AH: alu_a = {8'h0, a[15:8]};
            C_AA_X: alu_a = x;
            C_AA_XH: alu_a = {8'h0, x[15:8]};
            C_AA_Y: alu_a = y;
            C_AA_YH: alu_a = {8'h0, y[15:8]};
            C_AA_SP: alu_a = sp;
            C_AA_DP: alu_a = dp;
            C_AA_DPL: alu_a = {8'h0, dp[7:0]};
            C_AA_P: alu_a = {8'h0, p};
            C_AA_PC: alu_a = pc;
            C_AA_ADDR: alu_a = addr[15:0];
            C_AA_ADDR2: alu_a = addr2[15:0];
            C_AA_0: alu_a = 16'h0;
            default: alu_a = 16'h0;
        endcase
    end

    // alu_b
    always_comb begin
        case (s.alu_b_src)
            C_AB_0: alu_b = 16'h0;
            C_AB_1: alu_b = 16'h1;
            C_AB_2: alu_b = 16'h2;
            C_AB_A: alu_b = a;
            C_AB_ADDR: alu_b = addr[15:0];
            C_AB_ADDRL_SIGNED: alu_b = {{8{addr[7]}}, addr[7:0]};
            C_AB_ADDRH: alu_b = {8'h0, addr[15:8]};
            C_AB_ADDR2: alu_b = addr2[15:0];
            C_AB_RD: alu_b = {8'h0, mem_rdata};
            default: alu_b = 16'h0;
        endcase
    end

    // alu_c
    assign alu_c = (s.alu_c_src == C_AC_CARRY) ? carry : p[C];

    always_ff @(posedge clk) begin
        if (reset) begin
            carry <= 1'b0;
        end else if (cpu_en) begin
            carry <= alu_flgs[AC];
        end
    end

    // ---- Interrupt Vector Address --------

    // vector_addr
    always_comb begin
        priority casez ({e, ints})
            6'b0_????1: vector_addr = 24'h00fffc; // RESET
            6'b0_???10: vector_addr = 24'h00ffea; // NMI
            6'b0_??100: vector_addr = 24'h00ffee; // IRQ
            6'b0_?1000: vector_addr = 24'h00ffe6; // BRK
            6'b0_10000: vector_addr = 24'h00ffe4; // COP

            6'b1_????1: vector_addr = 24'h00fffc; // RESET
            6'b1_???10: vector_addr = 24'h00fffa; // NMI
            6'b1_??100: vector_addr = 24'h00fffe; // IRQ
            6'b1_?1000: vector_addr = 24'h00fffe; // BRK
            6'b1_10000: vector_addr = 24'h00fff4; // COP

            default: vector_addr = 24'h0;
        endcase
    end

    // ---- ALU --------

    alu alu(
        .a(alu_a),
        .b(alu_b),
        .c(alu_c),
        .y(alu_y),
        .flgs(alu_flgs),

        .control(s.alu_control),
        .bit8(s.alu_bit8),
        .bcd(s.alu_bcd)
    );

    // ---- Controller --------

    controller controller(
        .clk,
        .cpu_en,
        .reset,
        
        .mem_rdata,

        .e,
        .p,
        .alu_flgs,
        .carry,
        .m8,
        .x8,

        .a_max(a == 16'hffff),
        .dplz(dp[7:0] == 8'h0),
        .page_cross(alu_a[8] ^ alu_y[8]),

        .nmi,
        .irq,

        .ctl_signals(s),

        .ints
    );

endmodule
