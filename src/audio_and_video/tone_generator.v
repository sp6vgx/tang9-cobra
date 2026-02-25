//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Tone Generator
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************


`timescale 1ns/1ps
`default_nettype none

module tone_generator (
    input   wire                clk_sample,
    input   wire                reset_n,
    
    input   wire                enable,
    input   wire [15:0]         target_freq_hz,
    input   wire [23:0]         sample_rate_hz,
    input   wire [3:0]          volume,
    
    output  reg signed [15:0]   sample_out
);

    localparam PHASE_WIDTH = 24;
    localparam PHASE_FULL  = 32'h1_000000;

    wire [PHASE_WIDTH-1:0] phase_step;
    
    assign phase_step = ( {1'b0, target_freq_hz} * PHASE_FULL + (sample_rate_hz >> 1) ) 
                        / sample_rate_hz;

    reg  [PHASE_WIDTH-1:0] phase_acc = 0;

    reg signed [15:0] amplitude;

    always @(posedge clk_sample or negedge reset_n) begin
        if (!reset_n) begin
            phase_acc   <= 0;
            sample_out  <= 0;
        end
        
        else if (!enable || volume == 0 || target_freq_hz == 0) begin
            phase_acc   <= 0;
            sample_out  <= 0;
        end
        
        else begin
            phase_acc <= phase_acc + phase_step;

            amplitude = { {10{1'b0}}, volume, 6'b000000 };

            if (amplitude == 0) begin
                sample_out <= 0;
            end
            else begin
                sample_out <= phase_acc[PHASE_WIDTH-1] ? amplitude : -amplitude;
            end
        end
    end

endmodule

`default_nettype wire
