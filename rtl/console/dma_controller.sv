// ========================================
//  Direct Memory Access (DMA) Controller
// ========================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module dma_controller
    import bus_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input a_op_type a_op,
    input logic [2:0] op_ch,
    input logic [7:0] wdata,
    output logic [7:0] rdata,

    input logic hdma_init,
    input logic hdma_start,

    output logic dma,
    output logic [23:0] a_addr,
    output logic [7:0] b_addr,
    output logic a_write,
    output logic a_read,
    output logic b_write,
    output logic b_read,
    output logic a2b
);

    genvar gi;

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [7:0] ch;
    logic [7:0] finish, hdma_abort;
    logic hdma_init_start, hdma_start_eff;
    
    logic [7:0] rdata_list[7:0];
    logic [23:0] a_addr_list[7:0];
    logic [7:0] b_addr_list[7:0];
    logic [7:0] a_write_list;
    logic [7:0] a_read_list;
    logic [7:0] b_write_list;
    logic [7:0] b_read_list;
    logic [7:0] a2b_list;

    // ------------------------------
    //  Registers
    // ------------------------------

    logic [7:0] mdma_en = 8'h0;
    logic [7:0] hdma_en = 8'h0;
    logic [7:0] hdma_en_reg = 8'h0;
    logic [7:0] hdma_en_line = 8'h0;

    logic mdma_reg = 1'b0;

    logic hdma_init_reg = 1'b0;
    logic hdma_reg = 1'b0;
    logic hdma_init_reg_prev, hdma_reg_prev;
    
    // ------------------------------
    //  Main
    // ------------------------------

    assign rdata = rdata_list[op_ch];
    
    assign dma = mdma_reg | hdma_init_reg | hdma_reg;

    always_comb begin
        a_addr = 24'h0;
        b_addr = 8'h0;
        a_write = 1'b0;
        a_read = 1'b0;
        b_write = 1'b0;
        b_read = 1'b0;
        a2b = 1'b0;
        for (int i = 0; i < 8; i++) begin
            if (ch[i]) begin
                a_addr = a_addr_list[i];
                b_addr = b_addr_list[i];
                a_write = a_write_list[i];
                a_read = a_read_list[i];
                b_write = b_write_list[i];
                b_read = b_read_list[i];
                a2b = a2b_list[i];
            end
        end
    end

    // ch
    always_comb begin
        if (hdma_init_reg | hdma_reg) begin
            priority casez (hdma_en_line)
                8'b????_???1: ch = 8'b0000_0001;
                8'b????_??10: ch = 8'b0000_0010;
                8'b????_?100: ch = 8'b0000_0100;
                8'b????_1000: ch = 8'b0000_1000;
                8'b???1_0000: ch = 8'b0001_0000;
                8'b??10_0000: ch = 8'b0010_0000;
                8'b?100_0000: ch = 8'b0100_0000;
                8'b1000_0000: ch = 8'b1000_0000;
                default: ch = 8'h0;
            endcase
        end else begin
            priority casez (mdma_en)
                8'b????_???1: ch = 8'b0000_0001;
                8'b????_??10: ch = 8'b0000_0010;
                8'b????_?100: ch = 8'b0000_0100;
                8'b????_1000: ch = 8'b0000_1000;
                8'b???1_0000: ch = 8'b0001_0000;
                8'b??10_0000: ch = 8'b0010_0000;
                8'b?100_0000: ch = 8'b0100_0000;
                8'b1000_0000: ch = 8'b1000_0000;
                default: ch = 8'h0;
            endcase
        end
    end

    assign hdma_init_start = (~hdma_init_reg_prev) & hdma_init_reg;
    assign hdma_start_eff = (~hdma_reg_prev) & hdma_reg;

    // mdma_en
    always_ff @(posedge clk) begin
        if (reset) begin
            mdma_en <= 8'h0;
        end else if (cpu_en) begin
            if (a_op == A_MDMAEN) begin
                mdma_en <= wdata;
            end else begin
                mdma_en <= mdma_en & (~finish);
            end
        end
    end

    // hdma_en, hdma_en_reg
    always_ff @(posedge clk) begin
        if (reset) begin
            hdma_en <= 8'h0;
            hdma_en_reg <= 8'h0;
        end else if (cpu_en) begin
            if (cpu_en & (a_op == A_HDMAEN)) begin
                hdma_en <= wdata;
                hdma_en_reg <= wdata;
            end else if (hdma_init_start) begin
                hdma_en_reg <= hdma_en;
            end else begin
                hdma_en_reg <= hdma_en_reg & (~hdma_abort);
            end
        end
    end

    // hdma_en_line
    always_ff @(posedge clk) begin
        if (reset) begin
            hdma_en_line <= 8'h0;
        end else if (cpu_en) begin
            if (hdma_init_start) begin
                hdma_en_line <= hdma_en;
            end else if (hdma_start_eff) begin
                hdma_en_line <= hdma_en_reg;
            end else begin
                hdma_en_line <= hdma_en_line & (~finish);
            end
        end
    end

    // mdma_reg
    always_ff @(posedge clk) begin
        if (reset) begin
            mdma_reg <= 1'b0;
        end else if (cpu_en) begin
            mdma_reg <= (mdma_en != 8'h0);
        end
    end

    // hdma_init_reg
    always_ff @(posedge clk) begin
        if (reset) begin
            hdma_init_reg <= 1'b0;
        end else if (hdma_init & (hdma_en != 8'h0)) begin
            hdma_init_reg <= 1'b1;
        end else if (cpu_en & (~hdma_init_start) & (hdma_en_line == 8'h0)) begin
            hdma_init_reg <= 1'b0;
        end
    end

    // hdma_reg
    always_ff @(posedge clk) begin
        if (reset) begin
            hdma_reg <= 1'b0;
        end else if (hdma_start & (hdma_en_reg != 8'h0)) begin
            hdma_reg <= 1'b1;
        end else if (cpu_en & (~hdma_start_eff) & (hdma_en_line == 8'h0)) begin
            hdma_reg <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (cpu_en) begin
            hdma_init_reg_prev <= hdma_init_reg;
            hdma_reg_prev <= hdma_reg;
        end
    end

    generate
        for (gi = 0; gi < 8; gi++) begin : DMAGen
            dma_ch dma_ch(
                .clk,
                .cpu_en,
                .reset,

                .a_op((op_ch == gi) ? a_op : A_NONE),
                .wdata,
                .rdata(rdata_list[gi]),

                .mdma(mdma_reg & ch[gi]),

                .hdma_init_start(hdma_init_start & hdma_en[gi]),
                .hdma_init((~hdma_init_start) & hdma_init_reg & ch[gi]),

                .hdma_start(hdma_start_eff & hdma_en_reg[gi]),
                .hdma((~hdma_start_eff) & hdma_reg & ch[gi]),

                .finish(finish[gi]),
                .hdma_abort(hdma_abort[gi]),

                .a_addr(a_addr_list[gi]),
                .b_addr(b_addr_list[gi]),
                .a_write(a_write_list[gi]),
                .a_read(a_read_list[gi]),
                .b_write(b_write_list[gi]),
                .b_read(b_read_list[gi]),
                .a2b(a2b_list[gi])
            );
        end
    endgenerate

endmodule
