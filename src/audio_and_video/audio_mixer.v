//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Audio Mixer
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************


`timescale 1ns/1ps
`default_nettype none

module audio_mixer (
    input   wire                clk,
    input   wire                reset_n,

    input   wire signed [15:0]  mono_katarynka,
    input   wire signed [15:0]  mono_beep,
    input   wire signed [15:0]  mono_ay,

    // Wyjście do HDMI audio
    output  reg signed [15:0]   audio_left,
    output  reg signed [15:0]   audio_right
);



    // Współczynniki skalowania – sumujemy 4 kanały → dzielimy przez ~4
    // Można tu później dodać osobne głośności dla każdego źródła
    localparam integer SCALE_SHIFT = 2;         // /4
    localparam integer SCALE_GAIN  = 1 << SCALE_SHIFT;

    //----------------------------------------------------------------------------
    // Wewnętrzne sumy (przed ograniczeniem)
    //----------------------------------------------------------------------------

    reg signed [17:0] sum_left;     // 16 bit + 2 bity zapasu na przepełnienie
    reg signed [17:0] sum_right;

    always @(*) begin
        // Lewy kanał
        sum_left =
            {{2{mono_katarynka[15]}}, mono_katarynka} +    // mono → lewy
            {{2{mono_beep[15]}},      mono_beep}      +
            {{2{mono_ay[15]}},        mono_ay};

        // Prawy kanał
        sum_right =
            {{2{mono_katarynka[15]}}, mono_katarynka} +    // mono → prawy
            {{2{mono_beep[15]}},      mono_beep}      +
            {{2{mono_ay[15]}},        mono_ay};
    end

    //----------------------------------------------------------------------------
    // Ostateczne skalowanie + saturacja (soft clip)
    //----------------------------------------------------------------------------

    wire signed [15:0] out_left_raw  = sum_left  >>> SCALE_SHIFT;
    wire signed [15:0] out_right_raw = sum_right >>> SCALE_SHIFT;

    // Prosta saturacja – obcinamy do ±32767
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            audio_left  <= 16'sd0;
            audio_right <= 16'sd0;
        end
        else begin
            // Lewy
            if (out_left_raw[15] != sum_left[17])
                audio_left <= sum_left[17] ? 16'h8000 : 16'h7FFF;  // saturacja
            else
                audio_left <= out_left_raw;

            // Prawy
            if (out_right_raw[15] != sum_right[17])
                audio_right <= sum_right[17] ? 16'h8000 : 16'h7FFF;
            else
                audio_right <= out_right_raw;
        end
    end

endmodule

`default_nettype wire
