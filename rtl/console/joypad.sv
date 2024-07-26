// ==============================
//  SFC Joypad
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module joypad
    import bus_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input a_op_type a_op,
    input logic [7:0] wdata,
    output logic [7:0] rdata,

    input logic [11:0] joy1,
    input logic [11:0] joy2,
    input logic [11:0] joy3,
    input logic [11:0] joy4,

    input logic [3:0] connect,
    input logic auto_read_time
);
    
    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [15:0] joy_shifter[3:0];
    logic auto_read = 1'b0;

    // ------------------------------
    //  Main
    // ------------------------------

    always_ff @(posedge clk) begin
        if (reset) begin
            auto_read <= 1'b0;
        end else if (cpu_en & (a_op == A_NMITIMEN)) begin
            auto_read <= wdata[0];
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            joy_shifter[0] <= 16'h0;
            joy_shifter[1] <= 16'h0;
            joy_shifter[2] <= 16'h0;
            joy_shifter[3] <= 16'h0;
        end else if (auto_read_time & auto_read) begin
            joy_shifter[0] <= 16'hffff;
            joy_shifter[1] <= 16'hffff;
            joy_shifter[2] <= 16'hffff;
            joy_shifter[3] <= 16'hffff;
        end else if (cpu_en) begin
            if ((a_op == A_JOYWR) & wdata[0]) begin
                joy_shifter[0] <= {joy1, 4'h0};
                joy_shifter[1] <= {joy2, 4'h0};
                joy_shifter[2] <= {joy3, 4'h0};
                joy_shifter[3] <= {joy4, 4'h0};
            end else if (a_op == A_JOYA) begin
                joy_shifter[0] <= {joy_shifter[0][14:0], 1'b1};
                joy_shifter[2] <= {joy_shifter[2][14:0], 1'b1};
            end else if (a_op == A_JOYB) begin
                joy_shifter[1] <= {joy_shifter[1][14:0], 1'b1};
                joy_shifter[3] <= {joy_shifter[3][14:0], 1'b1};
            end
        end
    end

    always_comb begin
        case (a_op)
            A_JOYA: rdata = {
                    6'h0,
                    connect[2] & joy_shifter[2][15],
                    connect[0] & joy_shifter[0][15]
                };
            A_JOYB: rdata = {
                    3'h0,
                    3'b111,
                    connect[3] & joy_shifter[3][15],
                    connect[1] & joy_shifter[1][15]
                };
            A_JOY1L: rdata = {joy1[3:0], 4'h0};
            A_JOY1H: rdata = joy1[11:4];
            A_JOY2L: rdata = {joy2[3:0], 4'h0};
            A_JOY2H: rdata = joy2[11:4];
            A_JOY3L: rdata = {joy3[3:0], 4'h0};
            A_JOY3H: rdata = joy3[11:4];
            A_JOY4L: rdata = {joy4[3:0], 4'h0};
            A_JOY4H: rdata = joy4[11:4];
            default: rdata = 8'h0;
        endcase
    end
    
endmodule
