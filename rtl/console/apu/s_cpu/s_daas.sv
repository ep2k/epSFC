// ===================================
//  DAA/DAS Instruction of SPC700 CPU
// ===================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module s_daas
    import s_cpu_pkg::*;
(
    input logic [7:0] a,
    input logic [7:0] psw,

    output logic [7:0] y,
    output logic [4:0] flgs,

    input daas_control_type control
);

    logic [7:0] correction;

    always_comb begin
        if (control == SC_DACTL_DAA) begin
            correction[3:0] = (psw[H] | (a[3:0] >= 4'ha)) ? 4'h6 : 4'h0;
            correction[7:4] = (psw[C] | (a[7:4] >= 4'ha)) ? 4'h6 : 4'h0;
            y = a + correction;
            flgs[AC] = psw[C] | (a > 8'h99);
        end else begin
            correction[3:0] = (psw[H] | (a[3:0] >= 4'ha)) ? 4'h6 : 4'h0;
            correction[7:4] = ((~psw[C]) | (a[7:4] >= 4'ha)) ? 4'h6 : 4'h0;
            y = a - correction;
            flgs[AC] = psw[C];
        end
    end

    assign flgs[AN] = y[7];
    assign flgs[AZ] = (y == 8'h0);
    assign {flgs[AV], flgs[AH]} = 2'b00;

endmodule
