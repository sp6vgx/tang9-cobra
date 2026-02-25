//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Audio Beep
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************

`timescale 1ns/1ps
`default_nettype none

module audio_beep (
    input   wire                clk_audio,
    input   wire                clk_cpu,
    input   wire                reset_n,
    
    input   wire                enable,
    input   wire [3:0]          volume,

    output  reg signed [15:0]   sample_out
);

    reg tone_enable;

    tone_generator tone_generator_Inst (
        .clk_sample(clk_audio),
        .reset_n(reset_n),
        .enable(tone_enable),
        .target_freq_hz(16'd500),
        .sample_rate_hz(24'd48000),
        .volume(volume),
        .sample_out(sample_out)
    );

    localparam N = 227500; // okolo 70ms dla 3.25MHz

    reg [17:0] cnt;

    always @(posedge clk_cpu or negedge reset_n) begin
        if (!reset_n) begin
            tone_enable <= 0;
            cnt <= 0;
        end
        else if (cnt == 0) begin
            tone_enable <= enable;
            cnt <= enable ? N : 0;
        end
        else begin
            cnt <= cnt - 1;
            tone_enable <= 1;
        end
    end

endmodule

`default_nettype wire
