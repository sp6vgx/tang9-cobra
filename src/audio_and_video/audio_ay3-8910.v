//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Audio AY3-8910
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************

`timescale 1ns/1ps
`default_nettype none

module audio_ay3_8910 (
    input   wire                clk_audio,

    input   wire                clk_cpu,
    input   wire                reset_n,

    input   wire                ay_bc,
    input   wire                ay_bidir,
    input   wire [7:0]          ay_din,
    
    output  reg signed [15:0]   sample_out
);


    //----------------------------------------------------------------------------
    // YM2149 
    //----------------------------------------------------------------------------

    wire [13:0] pcm14s_o;

    ym2149_audio ym2149_audio_Inst (
        .clk_i(clk_cpu),
        .en_clk_psg_i(1'b1),
        .sel_n_i(1'b1),
        .reset_n_i(reset_n),
        .bc_i(ay_bc),
        .bdir_i(ay_bidir),
        .data_i(ay_din),
        .pcm14s_o(pcm14s_o)
    );

    always @(posedge clk_audio) begin
        sample_out <=  { {2{pcm14s_o[13]}}, pcm14s_o };
    end

endmodule

`default_nettype wire
