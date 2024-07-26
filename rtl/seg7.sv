// ==============================
//  Seven Segment Decoder
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module seg7 (
    input  logic [3:0] din,
    output logic [6:0] dout
);

    always_comb begin
        case (din)
            4'h0: dout = 7'b1000000;
            4'h1: dout = 7'b1111001;
            4'h2: dout = 7'b0100100;
            4'h3: dout = 7'b0110000;
            4'h4: dout = 7'b0011001;
            4'h5: dout = 7'b0010010;
            4'h6: dout = 7'b0000010;
            4'h7: dout = 7'b1011000;
            4'h8: dout = 7'b0000000;
            4'h9: dout = 7'b0010000;
            4'ha: dout = 7'b0001000;
            4'hb: dout = 7'b0000011;
            4'hc: dout = 7'b1000110;
            4'hd: dout = 7'b0100001;
            4'he: dout = 7'b0000110;
            4'hf: dout = 7'b0001110;
            default: dout = 7'b1111111;
        endcase
    end
    
endmodule
