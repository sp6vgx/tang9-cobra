//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Tape Interface
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************

`timescale 1ns/1ps
`default_nettype none

module tape_interface (
    input   wire        clk_cpu,
    input   wire        reset_n,

    // Tape Read Signals
    input   wire        tape_in,
    output  wire        tape_in_data,
    output  wire        tape_in_data_n,

    // Tape Write Signals
    input   wire        tape_out_data,
    output  wire        tape_out
);

    localparam [12:0] PULSE_TIME_READ   = 15'd1333; //1333 - 0.41ms
    localparam [12:0] PULSE_TIME_WRITE  = 15'd650; //650 - 0.2ms

    reg [2:0] tape_in_sync;
    always @(posedge clk_cpu) begin
        tape_in_sync <= {tape_in_sync[1:0], tape_in};

    end

    assign tape_in_data = tape_in_sync[2];


    // Read Data
    reg [12:0] counter_in;
    reg tape_in_data_old;

    always @(posedge clk_cpu or negedge reset_n) begin
        if (!reset_n) begin
            counter_in <= 0;
            tape_in_data_old <= 0;
        end else begin
            tape_in_data_old <= tape_in_data;
            
            if (tape_in_data && !tape_in_data_old) begin
                counter_in <= PULSE_TIME_READ;
            end else if (counter_in > 0) begin
                counter_in <= counter_in - 1'b1;
            end
        end
    end

    assign tape_in_data_n = (counter_in == 0);


   // Write Data
    reg [12:0] counter_out;
    reg tape_out_data_old;

    always @(posedge clk_cpu or negedge reset_n) begin
        if (!reset_n) begin
            counter_out <= 0;
            tape_out_data_old <= 0;
        end else begin
            tape_out_data_old <= tape_out_data;

            if (tape_out_data && !tape_out_data_old) begin
                counter_out <= PULSE_TIME_WRITE;
            end else if (counter_out > 0) begin
                counter_out <= counter_out - 1'b1;
            end
        end
    end

    assign tape_out = (counter_out == 0);

endmodule

`default_nettype wire
