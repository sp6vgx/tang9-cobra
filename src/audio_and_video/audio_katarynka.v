//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Audio Katarynka
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************


`timescale 1ns/1ps
`default_nettype none

module audio_katarynka (
    input   wire                clk_audio,

    input   wire                clk_cpu,
    input   wire                reset_n,

    input   wire                katarynka_clk1,
    input   wire                katarynka_clk2,
    input   wire                katarynka_data,

    input   wire [3:0]          volume,

    output  reg signed [15:0]   sample_out
);

    reg katarynka_clk1_d;
    reg katarynka_clk2_d;
    always @(posedge clk_cpu or negedge reset_n) begin
        if (!reset_n) begin
            katarynka_clk1_d <= 1'b0;
            katarynka_clk2_d <= 1'b0;
        end else begin        
            katarynka_clk1_d <= katarynka_clk1;
            katarynka_clk2_d <= katarynka_clk2;
        end
    end

    reg q1;
    reg q2;
    always @(posedge clk_cpu or negedge reset_n) begin
        if (!reset_n) begin
            q1 <= 1'b0;
            q2 <= 1'b0;
        end else begin                                          // Hmm ??? Niektóre programy z wejściem z D0 nie graja :( 
                                                                // Więc dajemy q = q_n 
            if (katarynka_clk1 && !katarynka_clk1_d) q1 <= ~q1; // katarynka_data;
            if (katarynka_clk2 && !katarynka_clk2_d) q2 <= ~q2; // katarynka_data;
        end
    end

    //----------------------------------------------------------------------------
    // SYNCHRONIZACJA DO DOMENY AUDIO
    //----------------------------------------------------------------------------

    reg q1_s1, q1_s2, q2_s1, q2_s2;
    reg [3:0] vol_s1, vol_s2;

    always @(posedge clk_audio or negedge reset_n) begin
        if (!reset_n) begin
            q1_s1  <= 1'b0;
            q1_s2  <= 1'b0;
            q2_s1  <= 1'b0;
            q2_s2  <= 1'b0;
            vol_s1 <= 4'd0;
            vol_s2 <= 4'd0;
        end
        else begin
            q1_s1  <= q1;   
            q1_s2  <= q1_s1;
            
            q2_s1  <= q2;   
            q2_s2  <= q2_s1;
            vol_s1 <= volume; 
            vol_s2 <= vol_s1;
        end
    end

    //----------------------------------------------------------------------------
    // GENEROWANIE PCM
    //----------------------------------------------------------------------------

    wire [1:0] level = q1_s2 + q2_s2;           // 0, 1 lub 2 (suma dwóch bitów)

    wire signed [15:0] dev = (level == 2'b00) ? -16'sd1 :
                             (level == 2'b01) ?  16'sd0 :
                              16'sd1 ;

    wire [15:0] unit_amp = vol_s2 << 8;
    
    always @(posedge clk_audio) begin
        if (!reset_n) begin
            sample_out <= 16'sd0;
        end else begin
            sample_out <= dev * $signed(unit_amp);
        end
    end

endmodule

`default_nettype wire
