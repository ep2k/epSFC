// ==============================
//  SPC700 CPU
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module s_cpu (
    input logic clk,
    input logic cpu_en,
    input logic reset,

    output logic [15:0] mem_addr,
    input logic [7:0] mem_rdata,
    output logic [7:0] mem_wdata,
    output logic mem_read,
    output logic mem_write
);

    // ------------------------------
    //  Parameters
    // ------------------------------
    
    import s_cpu_pkg::*;

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [7:0] a, x, y, sp, psw;
    logic [15:0] pc;
    logic [7:0] op, temp;
    logic [15:0] addr;

    logic [7:0] wdata, a_wdata, y_wdata, temp_wdata;
    logic [7:0] psw_wdata, psw_write;
    logic [15:0] addr_wdata, pc_wdata;

    logic [7:0] reg1, reg2;

    logic [15:0] alu_a, alu_b, alu_y;
    logic alu_c;
    logic [4:0] alu_flgs;

    logic [2:0] bitalu_b;
    logic [7:0] bitalu_y;
    logic bitalu_c;

    logic [7:0] daas_y;
    logic [4:0] daas_flgs;

    logic [15:0] mul_ya;
    logic [8:0] div_cy, div_va;

    reg_src_type reg1_src, reg2_src;
    ctl_signals_type s;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic c2 = 1'b0;

    // ------------------------------
    //  Main
    // ------------------------------

    // ---- Registers --------

    // register8: rtl/console/cpu/register8.sv
    // register16: rtl/console/cpu/register16.sv

    register8 reg_a(
        .clk,
        .cpu_en,
        .reset,

        .rdata(a),
        .wdata(a_wdata),
        .write((s.reg1_write & (reg1_src == SC_R_A)) | (s.reg2_write & (reg2_src == SC_R_A)) | s.mul_init | s.mul | s.div)
    );

    always_comb begin
        if (s.mul_init) begin
            a_wdata = a[7] ? y : 8'h0;
        end else if (s.mul) begin
            a_wdata = mul_ya[7:0];
        end else if (s.div) begin
            a_wdata = div_va[7:0];
        end else begin
            a_wdata = wdata;
        end
    end

    register8 reg_x(
        .clk,
        .cpu_en,
        .reset,

        .rdata(x),
        .wdata,
        .write((s.reg1_write & (reg1_src == SC_R_X)) | (s.reg2_write & (reg2_src == SC_R_X)))
    );

    register8 reg_y(
        .clk,
        .cpu_en,
        .reset,

        .rdata(y),
        .wdata(y_wdata),
        .write((s.reg1_write & (reg1_src == SC_R_Y)) | (s.reg2_write & (reg2_src == SC_R_Y)) | s.mul_init | s.mul | s.div | s.div_last)
    );

    always_comb begin
        if (s.mul_init) begin
            y_wdata = 8'h0;
        end else if (s.mul) begin
            y_wdata = mul_ya[15:8];
        end else if (s.div) begin
            y_wdata = div_cy[7:0];
        end else if (s.div_last) begin
            y_wdata = {c2, y[7:1]};
        end else begin
            y_wdata = wdata;
        end
    end

    register8 reg_sp(
        .clk,
        .cpu_en,
        .reset,

        .rdata(sp),
        .wdata,
        .write((s.reg1_write & (reg1_src == SC_R_SP)) | (s.reg2_write & (reg2_src == SC_R_SP)))
    );

    register8 #(.WRITE_MODE(1)) reg_psw(
        .clk,
        .cpu_en,
        .reset,

        .rdata(psw),
        .wdata(psw_wdata),
        .write(psw_write)
    );

    always_comb begin
        psw_write = 8'h0;
        if (s.mul) begin
            {psw_write[N], psw_write[Z]} = 2'b11;
        end else if (s.div) begin
            psw_write[V] = 1'b1;
        end else if (s.div_last) begin
            {psw_write[N], psw_write[Z]} = 2'b11;
        end else begin
            psw_write = s.psw_write;
        end
    end

    register16 #(.INIT(16'hffc0)) reg_pc(
        .clk,
        .cpu_en,
        .reset,

        .rdata(pc),
        .wdata(pc_wdata),
        .write(s.pc_write)
    );

    register8 reg_op(
        .clk,
        .cpu_en(1'b1),
        .reset,

        .rdata(op),
        .wdata,
        .write(s.op_write)
    );

    register16 reg_addr(
        .clk,
        .cpu_en,
        .reset,

        .rdata(addr),
        .wdata(addr_wdata),
        .write(s.addr_write | {1'b0, s.mul_init | s.mul | s.div_init | s.div})
    );

    register8 reg_temp(
        .clk,
        .cpu_en,
        .reset,

        .rdata(temp),
        .wdata(temp_wdata),
        .write(s.temp_write | s.mul_init | s.div_init)
    );

    always_comb begin
        if (s.mul_init) begin
            temp_wdata = y;
        end else if (s.div_init) begin
            temp_wdata = x;
        end else begin
            temp_wdata = wdata;
        end
    end

    // c2
    always_ff @(posedge clk) begin
        if (reset) begin
            c2 <= 1'b0;
        end else if (cpu_en) begin
            if (s.div_init) begin
                c2 <= 1'b0;
            end else if (s.div) begin
                c2 <= div_cy[8];
            end else if (s.c2_write) begin
                c2 <= alu_flgs[AC];
            end
        end
    end

    // ---- Datapath --------

    assign mem_wdata = wdata;
    assign mem_read = s.mem_read;
    assign mem_write = s.mem_write;

    // reg1
    always_comb begin
        case (reg1_src)
            SC_R_A: reg1 = a;
            SC_R_X: reg1 = x;
            SC_R_Y: reg1 = y;
            SC_R_SP: reg1 = sp;
            default: reg1 = a;
        endcase
    end

    // reg2
    always_comb begin
        case (reg2_src)
            SC_R_A: reg2 = a;
            SC_R_X: reg2 = x;
            SC_R_Y: reg2 = y;
            SC_R_SP: reg2 = sp;
            default: reg2 = a;
        endcase
    end

    // mem_addr
    always_comb begin
        case (s.mem_addr_src)
            SC_MA_PC: mem_addr = pc;
            SC_MA_DP: mem_addr = {psw[P] ? 8'h1 : 8'h0, addr[7:0]};
            SC_MA_DP_1: mem_addr = {psw[P] ? 8'h1 : 8'h0, addr[7:0] + 8'h1};
            SC_MA_DP2: mem_addr = {psw[P] ? 8'h1 : 8'h0, addr[15:8]};
            SC_MA_DT: mem_addr = {psw[P] ? 8'h1 : 8'h0, temp};
            SC_MA_DT_1: mem_addr = {psw[P] ? 8'h1 : 8'h0, temp + 8'h1};
            SC_MA_DR1: mem_addr = {psw[P] ? 8'h1 : 8'h0, reg1};
            SC_MA_DR2: mem_addr = {psw[P] ? 8'h1 : 8'h0, reg2};
            SC_MA_ABS: mem_addr = addr;
            SC_MA_ABS_1: mem_addr = addr + 16'h1;
            SC_MA_ABSMINI: mem_addr = {3'h0, addr[12:0]};
            SC_MA_SR2: mem_addr = {8'h1, reg2};
            SC_MA_SR2_1: mem_addr = {8'h1, reg2 + 8'h1};
            SC_MA_SR2_2: mem_addr = {8'h1, reg2 + 8'h2};
            SC_MA_FFDE: mem_addr = 16'hffde - {3'h0, op[7:4], 1'b0};
            SC_MA_FFDF: mem_addr = 16'hffdf - {3'h0, op[7:4], 1'b0};
            default: mem_addr = pc;
        endcase
    end

    // wdata
    always_comb begin
        case (s.wdata_src)
            // SC_W_REG1: wdata = reg1;
            // SC_W_REG1_XCN: wdata = {reg1[3:0], reg1[7:4]};
            // SC_W_REG2: wdata = reg2;
            SC_W_PSW: wdata = psw;
            SC_W_PCH: wdata = pc[15:8];
            SC_W_PCL: wdata = pc[7:0];
            // SC_W_TEMP: wdata = temp;
            SC_W_ALUY: wdata = alu_y[7:0];
            SC_W_BITALUY: wdata = bitalu_y;
            SC_W_DAASY: wdata = daas_y;
            SC_W_RD: wdata = mem_rdata;
            default: wdata = mem_rdata;
        endcase
    end

    // psw_wdata
    always_comb begin
        psw_wdata = 8'h0;
        if (s.mul) begin
            psw_wdata[N] = y[7];
            psw_wdata[Z] = (y == 8'h0);
        end else if (s.div) begin
            psw_wdata[V] = div_va[8];
        end else if (s.div_last) begin
            psw_wdata[N] = a[7];
            psw_wdata[Z] = (a == 8'h0);
        end else begin
            case (s.psw_wdata_src)
                SC_PW_ALUF: begin
                        psw_wdata[N] = alu_flgs[AN];
                        psw_wdata[V] = alu_flgs[AV];
                        psw_wdata[H] = alu_flgs[AH];
                        psw_wdata[Z] = alu_flgs[AZ];
                        psw_wdata[C] = alu_flgs[AC];
                    end
                SC_PW_ALUF2: begin
                        psw_wdata[N] = alu_flgs[AN];
                        psw_wdata[V] = alu_flgs[AV];
                        psw_wdata[H] = alu_flgs[AH];
                        psw_wdata[Z] = alu_flgs[AZ] & psw[Z];
                        psw_wdata[C] = alu_flgs[AC];
                    end
                SC_PW_BITALUC: psw_wdata[C] = bitalu_c;
                SC_PW_DAASF: begin
                        psw_wdata[N] = daas_flgs[AN];
                        psw_wdata[Z] = daas_flgs[AZ];
                        psw_wdata[C] = daas_flgs[AC];
                    end
                SC_PW_NOTC: psw_wdata[C] = ~psw[C];
                SC_PW_BRK: begin
                        psw_wdata[B] = 1'b1;
                        psw_wdata[I] = 1'b0;
                    end
                SC_PW_FF: psw_wdata = 8'hff;
                SC_PW_0: psw_wdata = 8'h0;
                SC_PW_RD: psw_wdata = mem_rdata;
                default: ;
            endcase
        end
    end

    // pc_wdata
    always_comb begin
        case (s.pc_wdata_src)
            SC_PCW_PC_1: pc_wdata = pc + 16'h1;
            SC_PCW_ALUY: pc_wdata = alu_y;
            SC_PCW_RD: pc_wdata = {mem_rdata, mem_rdata};
            SC_PCW_RD_TEMP: pc_wdata = {mem_rdata, temp};
            SC_PCW_FF_ADL: pc_wdata = {8'hff, addr[7:0]};
            default: pc_wdata = pc + 16'h1;
        endcase
    end

    // addr_wdata
    always_comb begin
        if (s.mul_init) begin
            addr_wdata = {8'h0, a[6:0], 1'b0};
        end else if (s.div_init) begin
            addr_wdata = {8'h0, a};
        end else if (s.mul | s.div) begin
            addr_wdata = {8'h0, addr[6:0], 1'b0};
        end else begin
           case (s.addr_wdata_src)
                SC_AW_ALUY: addr_wdata = alu_y;
                SC_AW_RD: addr_wdata = {mem_rdata, mem_rdata};
                default: addr_wdata = {mem_rdata, mem_rdata};
            endcase 
        end
    end

    // alu_a
    always_comb begin
        case (s.alu_a_src)
            SC_AA_REG1: alu_a = {8'h0, reg1};
            SC_AA_REG1_XCN: alu_a = {8'h0, reg1[3:0], reg1[7:4]};
            SC_AA_REG2: alu_a = {8'h0, reg2};
            SC_AA_PC: alu_a = pc;
            SC_AA_TEMP: alu_a = {8'h0, temp};
            SC_AA_ADDR: alu_a = addr;
            SC_AA_RD: alu_a = {8'h0, mem_rdata};
            default: alu_a = {8'h0, reg1};
        endcase
    end

    // alu_b
    always_comb begin
        case (s.alu_b_src)
            SC_AB_0: alu_b = 16'h0;
            SC_AB_1: alu_b = 16'h1;
            SC_AB_2: alu_b = 16'h2;
            // SC_AB_REG1: alu_b = {8'h0, reg1};
            SC_AB_REG2: alu_b = {8'h0, reg2};
            SC_AB_TEMP: alu_b = {{8{temp[7]}}, temp};
            SC_AB_RD: alu_b = {8'h0, mem_rdata};
            default: alu_b = 16'h0;
        endcase
    end

    // alu_c
    always_comb begin
        case (s.alu_c_src)
            SC_AC_C: alu_c = psw[C];
            SC_AC_C2: alu_c = c2;
            default: alu_c = psw[C];
        endcase
    end

    // bitalu_b
    always_comb begin
        case (s.bitalu_b_src)
            SC_BAB_OP75: bitalu_b = op[7:5];
            SC_BAB_ADDR1513: bitalu_b = addr[15:13];
            default: bitalu_b = op[7:5];
        endcase
    end

    // ---- ALU --------

    s_alu alu(
        .a(alu_a),
        .b(alu_b),
        .c(alu_c),

        .y(alu_y),
        .flgs(alu_flgs),

        .control(s.alu_control),
        .bit8(s.alu_bit8)
    );

    s_bitalu bitalu(
        .a(mem_rdata),
        .b(bitalu_b),
        .c(psw[C]),

        .y(bitalu_y),
        .cout(bitalu_c),

        .control(s.bitalu_control)
    );

    s_daas daas(
        .a(reg1),
        .psw,
        
        .y(daas_y),
        .flgs(daas_flgs),

        .control(s.daas_control)
    );

    // ---- Multiplier & Divider --------

    assign mul_ya = {y[6:0], a, 1'b0} + {8'h0, addr[7] ? temp : 8'h0};
    assign div_va = {a, c2 | alu_flgs[AC]};
    assign div_cy = (c2 | alu_flgs[AC]) ? {alu_y[7:0], addr[7]} : {y, addr[7]};
    
    // ---- Controller --------

    s_controller controller(
        .clk,
        .cpu_en,
        .reset,

        .op,
        
        .psw,
        .reg2_0(reg2 == 8'h0),
        .flgz(alu_flgs[AZ]),
        .temp_0(temp == 8'h0),
        .not_bsc(mem_rdata[op[7:5]] == op[4]),

        .reg1_src,
        .reg2_src,
        .ctl_signals(s)
    );
    
endmodule
