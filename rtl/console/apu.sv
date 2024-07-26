// ==============================
//  Audio Processing Unit (APU)
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module apu
    import bus_pkg::*;
(
    input logic clk,                // 10.24 MHz
    input logic reset,

    input logic c_clk,              // 21.47727 MHz
    input logic c_cpu_en,

    input b_op_type b_op,
    input logic [7:0] c_wdata,
    output logic [7:0] c_rdata,

    output logic [15:0] sound_l,
    output logic [15:0] sound_r,

    input logic [1:0] interpol_sel,
    input logic [7:0] sound_off,
    input logic echo_off,
    output logic [6:0] envx_x[7:0]
);

    genvar gi;

    // ------------------------------
    //  Parameters
    // ------------------------------
    
    import apu_pkg::*;

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic cpu_en;

    logic [2:0] timer_inc;
    logic [2:0] counter_read;

    logic [15:0] addr, cpu_addr, dsp_addr_0, dsp_addr_1;
    apu_target_type target;
    logic [7:0] wdata, cpu_wdata, dsp_wdata_0, dsp_wdata_1;
    logic [7:0] rdata, aram_rdata, ipl_rdata, dspaddr_rdata;
    logic write, read, cpu_write, cpu_read, dsp_write;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    // ---- Clock Divider --------

    logic [3:0] clk_step = 4'h0;

    // ---- Communication with 65816 CPU --------

    logic [7:0] io_in_send[3:0], io_in_recv[3:0];
    logic io_in_req_send[3:0];
    logic [1:0] io_in_req_recv[3:0];
    logic io_in_ack_send[3:0];
    logic [1:0] io_in_ack_recv[3:0];

    logic [7:0] io_out_send[3:0], io_out_recv[3:0];
    logic io_out_req_send[3:0];
    logic [1:0] io_out_req_recv[3:0];
    logic io_out_ack_send[3:0];
    logic [1:0] io_out_ack_recv[3:0];

    // ---- I/O Registers --------

    logic [5:0] test = 6'b001010;

    logic ipl_enable = 1'b1;

    logic [7:0] dspaddr = 8'h0;

    logic [2:0] timer_enable = 3'h0;
    logic [6:0] timer_counter = 7'h0;
    logic [7:0] timer[2:0];
    logic [7:0] interval[2:0];
    logic [3:0] counter[2:0];

    // ---- rdata --------

    logic [7:0] cpu_rdata, dsp_rdata_0, dsp_rdata_1;

    // ------------------------------
    //  Main
    // ------------------------------

    // ---- APU Clock Divider --------
    // cpu_en = 10.24 MHz / 10 = 1.24 MHz

    always_ff @(posedge clk) begin
        if (reset) begin
            clk_step <= 4'h0;
        end else begin
            clk_step <= (clk_step == 4'h9) ? 4'h0 : (clk_step + 4'h1);
        end
    end

    assign cpu_en = (clk_step == 4'd9);

    // ---- Communication with 65816 CPU --------

    always_comb begin
        case (b_op)
            B_APUIO0_R: c_rdata = io_out_recv[0];
            B_APUIO1_R: c_rdata = io_out_recv[1];
            B_APUIO2_R: c_rdata = io_out_recv[2];
            B_APUIO3_R: c_rdata = io_out_recv[3];
            default: c_rdata = 8'h0;
        endcase
    end
    
    // [ 65816 CPU -> APU ]

    // [65816] Stores data from 65816 CPU
    always_ff @(posedge c_clk) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) begin
                io_in_send[i] <= 8'h0;
            end
        end else if (c_cpu_en) begin
            case (b_op)
                B_APUIO0_W: io_in_send[0] <= c_wdata;
                B_APUIO1_W: io_in_send[1] <= c_wdata;
                B_APUIO2_W: io_in_send[2] <= c_wdata;
                B_APUIO3_W: io_in_send[3] <= c_wdata;
                default: ;
            endcase
        end
    end
    
    // [65816] Req.: 65816 CPU ->
    //         Clear Req. when Ack.=1
    always_ff @(posedge c_clk) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) begin
                io_in_req_send[i] <= 1'b0;
            end
        end else if (c_cpu_en) begin
            case (b_op)
                B_APUIO0_W: io_in_req_send[0] <= 1'b1;
                B_APUIO1_W: io_in_req_send[1] <= 1'b1;
                B_APUIO2_W: io_in_req_send[2] <= 1'b1;
                B_APUIO3_W: io_in_req_send[3] <= 1'b1;
                default: ;
            endcase
        end else begin
            for (int i = 0; i < 4; i++) begin
                if (io_in_ack_recv[i]) begin
                    io_in_req_send[i] <= 1'b0;
                end
            end
        end
    end

    // [APU] Req.: -> APU (Synchronization)
    always_ff @(posedge clk) begin
        for (int i = 0; i < 4; i++) begin
            if (reset) begin
                io_in_req_recv[i] <= 2'b00;
            end else begin
                io_in_req_recv[i] <= {io_in_req_recv[i][0], io_in_req_send[i]};
            end
        end
    end

    // [APU] Recives data when Req.=1 (APUIO0, APUIO1)
    always_ff @(posedge clk) begin
        for (int i = 0; i <= 1; i++) begin
            if (reset) begin
                io_in_recv[i] <= 8'h0;
            end else if (io_in_req_recv[i][1]) begin
                io_in_recv[i] <= io_in_send[i];
            end else if ((target == AT_CONTROL) & write & wdata[4]) begin
                io_in_recv[i] <= 8'h0;
            end
        end
    end

    // [APU] Recives data when Req.=1 (APUIO2, APUIO3)
    always_ff @(posedge clk) begin
        for (int i = 2; i <= 3; i++) begin
            if (reset) begin
                io_in_recv[i] <= 8'h0;
            end else if (io_in_req_recv[i][1]) begin
                io_in_recv[i] <= io_in_send[i];
            end else if ((target == AT_CONTROL) & write & wdata[5]) begin
                io_in_recv[i] <= 8'h0;
            end
        end
    end

    // [APU] Ack.: APU ->
    always_ff @(posedge clk) begin
        for (int i = 0; i < 4; i++) begin
            if (reset) begin
                io_in_ack_send[i] <= 1'b0;
            end else if (io_in_req_recv[i][1]) begin
                io_in_ack_send[i] <= 1'b1;
            end else begin
                io_in_ack_send[i] <= 1'b0;
            end
        end
    end

    // [65816] Ack.: -> 65816 CPU (Synchronization)
    always_ff @(posedge c_clk) begin
        for (int i = 0; i < 4; i++) begin
            if (reset) begin
                io_in_ack_recv[i] <= 2'b00;
            end else begin
                io_in_ack_recv[i] <= {io_in_ack_recv[i][0], io_in_ack_send[i]};
            end
        end
    end

    // [ APU -> 65816 CPU]

    // [APU] Stores data from APU
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) begin
                io_out_send[i] <= 8'h0;
            end
        end else if (write) begin
            case (target)
                AT_PORT0: io_out_send[0] <= wdata;
                AT_PORT1: io_out_send[1] <= wdata;
                AT_PORT2: io_out_send[2] <= wdata;
                AT_PORT3: io_out_send[3] <= wdata;
                default: ;
            endcase
        end
    end
    
    // [APU] Req.: APU ->
    //       Clear Req. when Ack.=1
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) begin
                io_out_req_send[i] <= 1'b0;
            end
        end else if (write) begin
            case (target)
                AT_PORT0: io_out_req_send[0] <= 1'b1;
                AT_PORT1: io_out_req_send[1] <= 1'b1;
                AT_PORT2: io_out_req_send[2] <= 1'b1;
                AT_PORT3: io_out_req_send[3] <= 1'b1;
                default: ;
            endcase
        end else begin
            for (int i = 0; i < 4; i++) begin
                if (io_out_ack_recv[i]) begin
                    io_out_req_send[i] <= 1'b0;
                end
            end
        end
    end

    // [65816] Req.: -> 65816 CPU (Synchronization)
    always_ff @(posedge c_clk) begin
        for (int i = 0; i < 4; i++) begin
            if (reset) begin
                io_out_req_recv[i] <= 2'b00;
            end else begin
                io_out_req_recv[i] <= {io_out_req_recv[i][0], io_out_req_send[i]};
            end
        end
    end

    // [65816] Recives data when Req.=1
    always_ff @(posedge c_clk) begin
        for (int i = 0; i < 4; i++) begin
            if (reset) begin
                io_out_recv[i] <= 8'h0;
            end else if (io_out_req_recv[i][1]) begin
                io_out_recv[i] <= io_out_send[i];
            end
        end
    end

    // [65816] Ack.: 65816 CPU ->
    always_ff @(posedge c_clk) begin
        for (int i = 0; i < 4; i++) begin
            if (reset) begin
                io_out_ack_send[i] <= 1'b0;
            end else if (io_out_req_recv[i][1]) begin
                io_out_ack_send[i] <= 1'b1;
            end else begin
                io_out_ack_send[i] <= 1'b0;
            end
        end
    end

    // [APU] Ack.: -> APU (Synchronization)
    always_ff @(posedge clk) begin
        for (int i = 0; i < 4; i++) begin
            if (reset) begin
                io_out_ack_recv[i] <= 2'b00;
            end else begin
                io_out_ack_recv[i] <=
                    {io_out_ack_recv[i][0], io_out_ack_send[i]};
            end
        end
    end

    // ---- I/O Registers --------

    // addr, ipl_enable -> target
    always_comb begin
        if (addr[15:4] == 12'h00f) begin
            case (addr[3:0])
                4'h0: target = AT_TEST;
                4'h1: target = AT_CONTROL;
                4'h2: target = AT_DSPADDR;
                4'h3: target = AT_DSPDATA;
                4'h4: target = AT_PORT0;
                4'h5: target = AT_PORT1;
                4'h6: target = AT_PORT2;
                4'h7: target = AT_PORT3;
                4'ha: target = AT_TIMER0;
                4'hb: target = AT_TIMER1;
                4'hc: target = AT_TIMER2;
                4'hd: target = AT_COUNTER0;
                4'he: target = AT_COUNTER1;
                4'hf: target = AT_COUNTER2;
                default: target = AT_ARAM;
            endcase
        end else if ((addr[15:6] == '1) & ipl_enable) begin
            target = AT_IPLROM;
        end else begin
            target = AT_ARAM;
        end
    end

    // target -> rdata
    always_comb begin
        case (target)
            AT_ARAM: rdata = aram_rdata;
            AT_IPLROM: rdata = ipl_rdata;
            AT_DSPADDR: rdata = {1'b0, dspaddr[6:0]};
            AT_DSPDATA: rdata = dspaddr_rdata;
            AT_PORT0: rdata = io_in_recv[0];
            AT_PORT1: rdata = io_in_recv[1];
            AT_PORT2: rdata = io_in_recv[2];
            AT_PORT3: rdata = io_in_recv[3];
            AT_COUNTER0: rdata = {4'h0, counter[0]};
            AT_COUNTER1: rdata = {4'h0, counter[1]};
            AT_COUNTER2: rdata = {4'h0, counter[2]};
            default: rdata = 8'h0;
        endcase
    end

    always_ff @(posedge clk) begin // 未実装
        if (reset) begin
            test <= 6'b001010;
        end else if ((target == AT_TEST) & write) begin
            test <= {wdata[6], wdata[4:0]};
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            {ipl_enable, timer_enable} <= 4'b1000;
        end else if ((target == AT_CONTROL) & write) begin
            {ipl_enable, timer_enable} <= {wdata[7], wdata[2:0]};
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            dspaddr <= 8'h0;
        end else if ((target == AT_DSPADDR) & write) begin
            dspaddr <= wdata;
        end
    end

    // [ Timer ]

    always_ff @(posedge clk) begin
        if (reset) begin
            timer_counter <= 7'h0;
        end else if ((target == AT_CONTROL) & write) begin
            timer_counter <= 7'h0;
        end else if (cpu_en) begin
            timer_counter <= timer_counter + 7'h1;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            interval[0] <= 8'h0;
            interval[1] <= 8'h0;
            interval[2] <= 8'h0;
        end else if (write) begin
            case (target)
                AT_TIMER0: interval[0] <= wdata;
                AT_TIMER1: interval[1] <= wdata;
                AT_TIMER2: interval[2] <= wdata;
                default: ;
            endcase
        end
    end

    assign timer_inc[0] = timer_enable[0] & (timer_counter == '1);
    assign timer_inc[1] = timer_enable[1] & (timer_counter == '1);
    assign timer_inc[2] = timer_enable[2] & (timer_counter[3:0] == '1);
    assign counter_read[0] = (target == AT_COUNTER0) & read;
    assign counter_read[1] = (target == AT_COUNTER1) & read;
    assign counter_read[2] = (target == AT_COUNTER2) & read;

    generate
        for (gi = 0; gi < 3; gi++) begin : GenAPUCTR

            logic counter_inc;
            assign counter_inc = (timer[gi] == (interval[gi] - 8'h1));

            always_ff @(posedge clk) begin
                if (reset) begin
                    timer[gi] <= 8'h0;
                end else if (cpu_en & timer_inc[gi]) begin
                    timer[gi] <= counter_inc ? 8'h0 : (timer[gi] + 8'h1);
                end
            end

            always_ff @(posedge clk) begin
                if (reset) begin
                    counter[gi] <= 4'h0;
                end else if (counter_read[gi]) begin
                    counter[gi] <= 4'h0;
                end else if (cpu_en & timer_inc[gi] & counter_inc) begin
                    counter[gi] <= counter[gi] + 4'h1;
                end
            end

        end
    endgenerate

    // ---- RAM/ROM --------

    bram_aram bram_aram(        // IP (RAM: 1-PORT, 8bit * 131072, 出力前後にDFF(q取得に2クロック))
        .address(addr),
        .clock(clk),
        .data(wdata),
        .wren((target == AT_ARAM) & write),
        .q(aram_rdata)
    );

    ipl_rom ipl_rom(
        .address(addr[5:0]),
        .q(ipl_rdata)
    );

    // ---- Timing Controller --------

    // clk_step, cpu_addr, cpu_w/r, cpu_wdata, dsp_addr, dsp_write, dsp_wdata
    //          -> addr, write, read, wdata
    always_comb begin
        addr = 16'h0;
        write = 1'b0;
        read = 1'b0;
        wdata = 8'h0;
        case (clk_step)
            4'h0: {addr, wdata} = {cpu_addr, cpu_wdata};
            4'h1: {addr, wdata} = {cpu_addr, cpu_wdata};
            4'h2: {addr, write, read, wdata}
                    = {cpu_addr, cpu_write, cpu_read, cpu_wdata};
            4'h3: {addr, wdata} = {dsp_addr_0, dsp_wdata_0};
            4'h4: {addr, wdata} = {dsp_addr_0, dsp_wdata_0};
            4'h5: {addr, write, wdata} = {dsp_addr_0, dsp_write, dsp_wdata_0};
            4'h6: {addr, wdata} = {dsp_addr_1, dsp_wdata_1};
            4'h7: {addr, wdata} = {dsp_addr_1, dsp_wdata_1};
            4'h8: {addr, write, wdata} = {dsp_addr_1, dsp_write, dsp_wdata_1};
            default: ;
        endcase
    end

    always_ff @(posedge clk) begin
        case (clk_step)
            4'h2: cpu_rdata <= rdata;
            4'h5: dsp_rdata_0 <= rdata;
            4'h8: dsp_rdata_1 <= rdata;
            default: ;
        endcase
    end

    // ---- SPC700 CPU --------

    s_cpu s_cpu(
        .clk,
        .cpu_en,
        .reset,

        .mem_addr(cpu_addr),
        .mem_rdata(cpu_rdata),
        .mem_wdata(cpu_wdata),
        .mem_read(cpu_read),
        .mem_write(cpu_write)
    );

    // ---- S-DSP (ADPCM Audio Processing) --------

    dsp dsp(
        .clk,
        .cpu_en,
        .clk_step,
        .reset,

        .dspaddr(dspaddr[6:0]),
        .dspaddr_wdata(wdata),
        .dspaddr_rdata,
        .dspaddr_write((target == AT_DSPDATA) & write & (~dspaddr[7])),

        .addr_0(dsp_addr_0),
        .rdata_0(dsp_rdata_0),
        .wdata_0(dsp_wdata_0),
        .addr_1(dsp_addr_1),
        .rdata_1(dsp_rdata_1),
        .wdata_1(dsp_wdata_1),
        .write(dsp_write),

        .sound_l,
        .sound_r,

        .envx_x,
        .sound_off,
        .interpol_sel,
        .echo_off
    );

endmodule
