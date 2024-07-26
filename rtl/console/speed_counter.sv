// ==============================
//  Memory Access Speed Counter
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module speed_counter
    import bus_pkg::*;
(
    input  logic clk,
    input  logic reset,

    input  logic mem_access,
    input  mem_speed_type mem_speed,

    input  logic speed_change,
    input  logic new_speed,

    input  logic stop,

    output logic cpu_en,
    output logic n_cpu_en,
    output logic cpu_en_m1,
    output logic cpu_en_m2,
    output logic n_cpu_en_p1,
    output logic mid_en,

    output logic cpu_clk_out,

    output logic var_fast
);
    
    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [3:0] max_ctr;
    logic [3:0] max_ctr_1;

    // ------------------------------
    //  Registers
    // ------------------------------

    logic [3:0] ctr = 4'd0; // 0 - 11

    logic var_fast_reg = 1'b0;
    
    // ------------------------------
    //  Main
    // ------------------------------

    assign cpu_en = (ctr == max_ctr) & (~stop);
    assign n_cpu_en = (ctr != max_ctr) & (~stop);
    assign cpu_en_m1 = (ctr == (max_ctr - 1)) & (~stop);
    assign cpu_en_m2 = (ctr == (max_ctr - 2)) & (~stop);
    assign n_cpu_en_p1 = (ctr != 4'd0) & (~stop);
    assign mid_en = (ctr != 4'd0) & (ctr != max_ctr) & (~stop);

    assign var_fast =  var_fast_reg & (mem_speed == MEM_VAR);

    always_comb begin
        if (mem_access) begin
            case (mem_speed)
                MEM_FAST: max_ctr = 4'd5;           // Fast
                MEM_SLOW: max_ctr = 4'd7;           // Slow
                MEM_XSLOW: max_ctr = 4'd11;         // XSlow
                MEM_VAR: max_ctr
                    = var_fast_reg ? 4'd5 : 4'd7;   // Fast/Slow
                default: max_ctr = 4'd5;
            endcase
        end else begin
            max_ctr = 4'd5;     // Fast (Internal Operation)
        end
    end

    assign max_ctr_1 = max_ctr + 4'h1;

    always_ff @(posedge clk) begin
        if (reset) begin
            ctr <= 4'd0;
        end else if (~stop) begin
            ctr <= (ctr == max_ctr) ? 4'd0 : (ctr + 4'd1);
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            var_fast_reg <= 1'b0;
        end else if (cpu_en & speed_change) begin
            var_fast_reg <= new_speed;
        end
    end

    always_ff @(posedge clk) begin
        if (ctr == ({1'b0, max_ctr_1[3:1]} - 4'h1)) begin
            cpu_clk_out <= 1'b0;
        end else if (ctr == max_ctr) begin
            cpu_clk_out <= 1'b1;
        end
    end

endmodule
