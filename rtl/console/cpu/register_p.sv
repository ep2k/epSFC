// ========================================
//  8bit Register for Status Register(P)
// ========================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module register_p (
    input logic clk,
    input logic cpu_en,
    input logic reset,

    output logic [7:0] p,
    output logic e, // emulationモード
    output logic m,
    output logic x,
    input logic [7:0] wdata,
    input logic [7:0] write,

    input logic xce
);

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [5:0] nvdizc_reg = 6'h0;
    logic m_reg = 1'b1;
    logic x_reg = 1'b1;
    logic b_reg = 1'b0;
    
    logic e_reg = 1'b1;

    // ------------------------------
    //  Main
    // ------------------------------
    
    assign {p[7:6], p[3:0]} = nvdizc_reg;
    assign p[5:4] = e_reg ? {1'b1, b_reg} : {m_reg, x_reg};
    assign e = e_reg;
    assign m = m_reg;
    assign x = x_reg;

    always_ff @(posedge clk) begin
        if (reset) begin
            nvdizc_reg <= 6'h0;
            m_reg <= 1'b1;
            x_reg <= 1'b1;
            b_reg <= 1'b0;
            e_reg <= 1'b1;
        end else begin
            if (cpu_en) begin
                if (xce) begin
                    nvdizc_reg[0] <= e_reg;
                    e_reg <= nvdizc_reg[0];
                    if (nvdizc_reg[0]) begin // e <- 1
                        m_reg <= 1'b1;
                        x_reg <= 1'b1;
                    end
                end else begin
                    nvdizc_reg <=
                        (nvdizc_reg & (~{write[7:6], write[3:0]}))
                        | ({wdata[7:6], wdata[3:0]} & {write[7:6], write[3:0]});
                    if (e_reg) begin
                        b_reg <= (b_reg & (~write[4])) | (wdata[4] & write[4]);
                    end else begin
                        m_reg <= (m_reg & (~write[5])) | (wdata[5] & write[5]);
                        x_reg <= (x_reg & (~write[4])) | (wdata[4] & write[4]);
                    end
                end
            end
        end
    end
    
endmodule
