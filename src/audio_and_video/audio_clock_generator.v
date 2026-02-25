//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Audio Clock Generator
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************


`timescale 1ns/1ps
`default_nettype none

module audio_clock_generator (
    input   wire            clk_pixel,
    input   wire [12:0]     clk_div,

    output  reg             clk_audio
);

    reg [12:0] counter;

    always @(posedge clk_pixel) begin
        if(counter < clk_div)
            counter <= counter + 12'd1;
        else begin
            counter <= 12'd0;
            clk_audio <= ~clk_audio;
        end
    end


endmodule

`default_nettype wire
