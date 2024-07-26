// ==============================
//  Multiplier and Divider
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module muldiv
    import bus_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input a_op_type a_op,
    input logic [7:0] wdata,
    output logic [7:0] rdata
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [15:0] mul_result_1_next, div_result_2_next_0, div_result_2_next_1;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [7:0] mul_a = 8'h0;       // mul_bはresult_1[15:8]に格納される
    logic [15:0] div_a = 16'h0;
    logic [7:0] div_b = 8'h0;

    logic [15:0] result_1 = 16'h0;
    logic [15:0] result_2 = 16'h0;

    enum logic [1:0] { IDLE, MUL, DIV } mode;
    logic [3:0] ctr = 4'd0;

    // ------------------------------
    //  Main
    // ------------------------------

    always_comb begin
        case (a_op)
            A_RDDIVL: rdata = result_1[7:0];
            A_RDDIVH: rdata = result_1[15:8];
            A_RDMPYL: rdata = result_2[7:0];
            A_RDMPYH: rdata = result_2[15:8];
            default: rdata = 8'h0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            mode <= IDLE;
        end else if (cpu_en) begin
            if (a_op == A_WRMPYB) begin
                mode <= MUL;
            end else if (a_op == A_WRDIVB) begin
                mode <= DIV;
            end else if (((mode == MUL) & (ctr == 4'd7)) | ((mode == DIV) & (ctr == 4'd15))) begin
                mode <= IDLE;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            ctr <= 4'd0;
        end else if (cpu_en) begin
            ctr <= ((a_op == A_WRMPYB) | (a_op == A_WRDIVB)) ? 4'd0 : (ctr + 4'd1);
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            mul_a <= 8'h0;
        end else if (cpu_en) begin
            if (a_op == A_WRMPYA) begin
                mul_a <= wdata;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            div_a <= 16'h0;
            div_b <= 8'h0;
        end else if (cpu_en) begin
            if (a_op == A_WRDIVL) begin
                div_a[7:0] <= wdata;
            end else if (a_op == A_WRDIVH) begin
                div_a[15:8] <= wdata;
            end else if (a_op == A_WRDIVB) begin
                div_b <= wdata;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            result_1 <= 16'h0;
            result_2 <= 16'h0;
        end else if (cpu_en) begin
            if (a_op == A_WRMPYB) begin
                result_1 <= {wdata, 8'h0}; // mul_b write
                result_2 <= 16'h0;
            end else if (a_op == A_WRDIVB) begin
                result_1 <= 16'h0;
                result_2 <= 16'h0;
            end else if (mode == MUL) begin
                // result_1: mul_b (shift)
                // result_2: product
                result_1 <= mul_result_1_next;
                result_2 <= result_2 + (mul_a[~ctr[2:0]] ? mul_result_1_next : 16'h0);
            end else if (mode == DIV) begin
                // result_1: quotient
                // result_2: remainder
                if (~div_result_2_next_1[15]) begin // remainder >= div_b
                    result_1[~ctr] <= 1'b1;
                    result_2 <= div_result_2_next_1;
                end else begin
                    result_2 <= div_result_2_next_0;
                end
            end
        end
    end

    assign mul_result_1_next = {1'b0, result_1[15:1]};
    assign div_result_2_next_0 = {result_2[14:0], div_a[~ctr]};
    assign div_result_2_next_1 = div_result_2_next_0 - {8'h0, div_b};
    
endmodule
