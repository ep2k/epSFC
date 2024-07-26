// ==============================
//  1ch of DMA Controller
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module dma_ch
    import bus_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input a_op_type a_op,
    input logic [7:0] wdata,
    output logic [7:0] rdata,

    input logic mdma,

    input logic hdma_init_start,
    input logic hdma_init,

    input logic hdma_start,
    input logic hdma,

    output logic finish,
    output logic hdma_abort,

    output logic [23:0] a_addr,
    output logic [7:0] b_addr,
    output logic a_write,
    output logic a_read,
    output logic b_write,
    output logic b_read,
    output logic a2b
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic mdma_a_write, mdma_a_read, mdma_b_write, mdma_b_read;
    logic hdma_a_write, hdma_a_read, hdma_b_write, hdma_b_read;
    logic mdma_finish, hdma_init_finish, hdma_finish;

    logic [1:0] b_byte;
    logic b_last;

    logic [7:0] hdma_info_dec;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [7:0] param = 8'h0;
    logic [7:0] b_addr_reg = 8'h0;
    logic [23:0] a_addr_1 = 24'h0;  // MDMAアドレス / HDMAテーブルベースアドレス
    logic [15:0] a_addr_2 = 16'h0;  // HDMAテーブルアドレス (バンクはa_addr_1[23:16])
    logic [23:0] a_addr_3 = 24'h0;  // MDMAバイトカウンタ / HDMA間接アドレス(mem[a_addr_2])
    logic [7:0] hdma_info = 8'h0;   // HDMAリロードフラグ, ラインカウンタ
    logic [7:0] unused = 8'h0;

    logic [1:0] b_addr_ctr = 2'h0;

    logic mdma_now = 1'b0;

    logic do_hdma_transfer = 1'b0;
    logic [1:0] hdma_state = 2'h0;

    // ------------------------------
    //  Main
    // ------------------------------

    assign mdma_finish = mdma & mdma_now & (a_addr_3[15:0] == 16'h0);
    assign hdma_init_finish = hdma_init & ((~param[6]) | hdma_state == 2'h3);
    assign hdma_finish = hdma &
                (((hdma_state == 2'h1) & ((~param[6]) | hdma_info_dec[6:0] != 7'h0))
                | (hdma_state == 2'h3));
    assign finish = mdma_finish | hdma_init_finish | hdma_finish;

    assign hdma_abort = (hdma_state == 2'h1) & (wdata == 8'h0)
                            & (hdma_init | (hdma & hdma_info_dec[6:0] == 7'h0));

    // rdata
    always_comb begin
        case (a_op)
            A_DMAPX_R: rdata = param;
            A_BBADX_R: rdata = b_addr_reg;
            A_A1TXL_R: rdata = a_addr_1[7:0];
            A_A1TXH_R: rdata = a_addr_1[15:8];
            A_A1BX_R : rdata = a_addr_1[23:16];
            A_A2AXL_R: rdata = a_addr_2[7:0];
            A_A2AXH_R: rdata = a_addr_2[15:8];
            A_DASXL_R: rdata = a_addr_3[7:0];
            A_DASXH_R: rdata = a_addr_3[15:8];
            A_DASXB_R: rdata = a_addr_3[23:16];
            A_NTRLX_R: rdata = hdma_info;
            A_UNUSEDX_R: rdata = unused;
            default: rdata = 8'h0;
        endcase
    end

    // a_addr
    always_comb begin
        if (mdma) begin
            a_addr = a_addr_1;
        end else if (hdma & (hdma_state == 2'h0) & param[6]) begin // HDMA間接
            a_addr = a_addr_3;
        end else begin
            a_addr = {a_addr_1[23:16], a_addr_2};
        end
    end

    // b_addr
    always_comb begin
        unique case (param[2:0])
            3'h0: b_addr = b_addr_reg;
            3'h1: b_addr = b_addr_reg + {7'h0, b_addr_ctr[0]};
            3'h2: b_addr = b_addr_reg;
            3'h3: b_addr = b_addr_reg + {7'h0, b_addr_ctr[1]};
            3'h4: b_addr = b_addr_reg + {6'h0, b_addr_ctr};
            3'h5: b_addr = b_addr_reg + {7'h0, b_addr_ctr[0]};
            3'h6: b_addr = b_addr_reg;
            3'h7: b_addr = b_addr_reg + {7'h0, b_addr_ctr[1]};
        endcase
    end

    assign mdma_a_write = mdma & mdma_now & param[7];
    assign mdma_a_read = mdma & mdma_now & (~param[7]);
    assign mdma_b_write = mdma & mdma_now & (~param[7]);
    assign mdma_b_read = mdma & mdma_now & param[7];

    assign hdma_a_write = hdma & (hdma_state == 2'h0) & param[7];
    assign hdma_a_read = (hdma_init | hdma) & ((hdma_state != 2'h0) | (~param[7]));
    assign hdma_b_write = hdma & (hdma_state == 2'h0) & (~param[7]);
    assign hdma_b_read = hdma & (hdma_state == 2'h0) & param[7];

    assign a_write = mdma_a_write | hdma_a_write;
    assign a_read = mdma_a_read | hdma_a_read;
    assign b_write = mdma_b_write | hdma_b_write;
    assign b_read = mdma_b_read | hdma_b_read;

    assign a2b = ((hdma_init | hdma) & (hdma_state != 2'h0)) | (~param[7]);

    always_comb begin
        unique case (param[2:0])
            3'h0: b_byte = 2'h0;
            3'h1: b_byte = 2'h1;
            3'h2: b_byte = 2'h1;
            3'h3: b_byte = 2'h3;
            3'h4: b_byte = 2'h3;
            3'h5: b_byte = 2'h3;
            3'h6: b_byte = 2'h1;
            3'h7: b_byte = 2'h3;
        endcase
    end

    assign b_last = (b_addr_ctr == b_byte);

    // param
    always_ff @(posedge clk) begin
        if (reset) begin
            param <= 8'h0;
        end else if (cpu_en & (a_op == A_DMAPX_W)) begin
            param <= wdata;
        end
    end

    // b_addr_reg
    always_ff @(posedge clk) begin
        if (reset) begin
            b_addr_reg <= 8'h0;
        end else if (cpu_en & (a_op == A_BBADX_W)) begin
            b_addr_reg <= wdata;
        end
    end

    // a_addr_1
    always_ff @(posedge clk) begin
        if (reset) begin
            a_addr_1 <= 24'h0;
        end else if (cpu_en) begin
            if (a_op == A_A1TXL_W) begin
                a_addr_1[7:0] <= wdata;
            end else if (a_op == A_A1TXH_W) begin
                a_addr_1[15:8] <= wdata;
            end else if (a_op == A_A1BX_W) begin
                a_addr_1[23:16] <= wdata;
            end else if (mdma & mdma_now) begin
                if (param[4:3] == 2'b00) begin
                    a_addr_1[15:0] <= a_addr_1[15:0] + 16'h1;
                end else if (param[4:3] == 2'b10) begin
                    a_addr_1[15:0] <= a_addr_1[15:0] - 16'h1;
                end
            end
        end
    end

    // a_addr_2
    always_ff @(posedge clk) begin
        if (reset) begin
            a_addr_2 <= 16'h0;
        end else if (cpu_en) begin
            if (a_op == A_A2AXL_W) begin
                a_addr_2[7:0] <= wdata;
            end else if (a_op == A_A2AXH_W) begin
                a_addr_2[15:8] <= wdata;
            end else if (hdma_init_start) begin
                a_addr_2 <= a_addr_1[15:0];
            end else if (hdma_init) begin
                a_addr_2 <= a_addr_2 + 16'h1;
            end else if (hdma) begin
                case (hdma_state)
                    2'h0: if (~param[6]) begin
                        a_addr_2 <= a_addr_2 + 16'h1;
                    end
                    2'h1: if (hdma_info_dec[6:0] == 7'h0) begin
                        a_addr_2 <= a_addr_2 + 16'h1;
                    end
                    default: a_addr_2 <= a_addr_2 + 16'h1;
                endcase
            end
        end
    end

    // a_addr_3
    always_ff @(posedge clk) begin
        if (reset) begin
            a_addr_3 <= 24'h0;
        end else if (cpu_en) begin
            if (a_op == A_DASXL_W) begin
                a_addr_3[7:0] <= wdata;
            end else if (a_op == A_DASXH_W) begin
                a_addr_3[15:8] <= wdata;
            end else if (a_op == A_DASXB_W) begin
                a_addr_3[23:16] <= wdata;
            end else if (mdma & (~(mdma_now & (a_addr_3[15:0] == 16'h0)))) begin
                a_addr_3[15:0] <= a_addr_3[15:0] - 16'h1;
            end else if ((hdma_init | hdma) & (hdma_state == 2'h2)) begin
                a_addr_3[7:0] <= wdata;
            end else if ((hdma_init | hdma) & (hdma_state == 2'h3)) begin
                a_addr_3[15:8] <= wdata;
            end else if (hdma & (hdma_state == 2'h0) & param[6]) begin
                a_addr_3[15:0] <= a_addr_3[15:0] + 16'h1;
            end
        end
    end

    // hdma_info
    always_ff @(posedge clk) begin
        if (reset) begin
            hdma_info <= 8'h0;
        end else if (cpu_en) begin
            if (a_op == A_NTRLX_W) begin
                hdma_info <= wdata;
            end else if (hdma_init & (hdma_state == 2'h1)) begin
                hdma_info <= wdata;
            end else if (hdma & (hdma_state == 2'h1)) begin
                hdma_info <= (hdma_info_dec[6:0] == 7'h0) ? wdata : hdma_info_dec;
            end
        end
    end

    assign hdma_info_dec = hdma_info - 8'h1;

    // unused
    always_ff @(posedge clk) begin
        if (reset) begin
            unused <= 8'h0;
        end else if (cpu_en & (a_op == A_UNUSEDX_W)) begin
            unused <= wdata;
        end
    end

    // b_addr_ctr
    always_ff @(posedge clk) begin
        if (reset) begin
            b_addr_ctr <= 2'h0;
        end else if (cpu_en) begin
            if (b_write | b_read) begin
                b_addr_ctr <= b_last ? 2'h0 : (b_addr_ctr + 2'h1);
            end else begin
                b_addr_ctr <= 2'h0;
            end
        end
    end

    // mdma_now
    always_ff @(posedge clk) begin
        if (reset) begin
            mdma_now <= 1'b0;
        end else if (cpu_en) begin
            if (mdma_finish) begin
                mdma_now <= 1'b0;
            end else if (mdma) begin
                mdma_now <= 1'b1;
            end
        end
    end

    // do_hdma_transfer
    always_ff @(posedge clk) begin
        if (reset) begin
            do_hdma_transfer <= 1'b0;
        end else if (cpu_en) begin
            if (hdma_init_start) begin
                do_hdma_transfer <= 1'b1;
            end else if (hdma & (hdma_state == 2'h1)) begin
                do_hdma_transfer <= hdma_info[7] | (hdma_info_dec[6:0] == 7'h0);
            end
        end
    end

    // hdma_state
    always_ff @(posedge clk) begin
        if (reset) begin
            hdma_state <= 2'h0;
        end else if (cpu_en) begin
            if (hdma_init_start) begin
                hdma_state <= 2'h1;
            end else if (hdma_start) begin
                hdma_state <= do_hdma_transfer ? 2'h0 : 2'h1;
            end else if ((hdma_init | hdma) & ((hdma_state != 2'h0) | b_last)) begin
                hdma_state <= hdma_state + 2'h1;
            end
        end
    end
    
endmodule
