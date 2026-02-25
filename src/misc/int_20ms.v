//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Interrupt 20ms (Z80 INT Signal)
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************

`timescale 1ns/1ps
`default_nettype none

module int_20ms (
    input   wire        clk_cpu,
    input   wire        reset_n,

    output  reg         int_n
);

    reg [15:0] int_counter = 0;

    always @(posedge clk_cpu or negedge reset_n) begin
        if (!reset_n) begin
            int_counter <= 0;
            int_n <= 1'b1;
        end
        else begin
            if (int_counter == 16'd65000 - 1) begin   // 3.25 MHz / 50 Hz = 65000 cykli
                int_counter <= 0;
                int_n <= 1'b0; 
            end
            else begin
                int_counter <= int_counter + 1;
                if (int_counter < 4)          // krótki impuls ~1 µs
                    int_n <= 1'b0;
                else
                    int_n <= 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
