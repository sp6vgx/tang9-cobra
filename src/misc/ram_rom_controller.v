//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// RAM & ROM Controller
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************

`timescale 1ns/1ps
`default_nettype none

module ram_rom_controller #(
    parameter CLK_PSRAM_FREQUENCY=72_000_000,
    parameter LATENCY=3,
    parameter DELAY_US=160
) (
    input   wire        clk,
    input   wire        clk_psram,
    input   wire        clk_psram_p,
    input   wire        pll_lock,
    input   wire        reset_n,

    input   wire [21:0] addr,
    input   wire [7:0]  din,
    output  reg  [7:0]  dout,
    input   wire        wr,
    input   wire        rd,

    output  wire        psram_ready,
    output  reg         psram_busy,
    output  reg         psram_error,

    output  wire        psram_ck,
    output  wire        psram_ck_n,
    inout   wire [7:0]  psram_dq,
    inout   wire        psram_rwds,
    output  wire        psram_cs_n,
    output  wire        psram_reset_n
);

    // -----------------------------------------------------------------------
    // Wewnętrzne sygnały
    // -----------------------------------------------------------------------
    reg [2:0] rd_sync;
    reg [2:0] wr_sync;
    reg [21:0] reg_addr;

    wire[15:0] rd_data;
    reg [15:0] wr_data;

    reg wr_pending;
    reg rd_pending;
    reg [2:0] state;
    
    reg [4:0] cycle;

    localparam ST_INIT  = 3'd0,         
               ST_IDLE  = 3'd1,
               ST_READ  = 3'd2,
               ST_WRITE = 3'd3,
               ST_ERROR = 3'd4;

    // -----------------------------------------------------------------------
    // Instancja W955D8MBYA
    // -----------------------------------------------------------------------
    reg write;
    reg read;
    wire ready;
    wire busy;

    W955D8MBYA #(
        .CLK_PSRAM_FREQUENCY(CLK_PSRAM_FREQUENCY),
        .LATENCY(LATENCY),
        .DELAY_US(DELAY_US)
    ) W955D8MBYA_0_Inst (
        .clk(clk),
        .clk_psram(clk_psram),
        .clk_psram_p(clk_psram_p),
        .reset_n(reset_n),
        .pll_lock(pll_lock),
    
        .addr(reg_addr),
        .din(wr_data),
        .dout(rd_data),
        .byte_write(1'b1),

        .wr(write),
        .rd(read),
        .ready(ready),
        .busy(busy),

        .psram_ck(psram_ck),
        .psram_ck_n(psram_ck_n),
        .psram_dq(psram_dq),
        .psram_rwds(psram_rwds),
        .psram_cs_n(psram_cs_n),
        .psram_reset_n(psram_reset_n)
    );

    assign psram_ready = ready;

    // -----------------------------------------------------------------------
    // Główna logika sterująca (domena clk_psram)
    // -----------------------------------------------------------------------
    always @(posedge clk_psram or negedge reset_n) begin
        if (!reset_n) begin
            dout <= 8'hff;
            state <= ST_INIT;
            rd_sync <= 3'b000;
            wr_sync <= 3'b000;
            reg_addr <= 21'h00;
            wr_data <= 16'h00;
            wr_pending <= 1'b0;
            rd_pending <= 1'b0;
            psram_busy <= 1'b1;
            psram_error <= 1'b0;
            read <= 1'b0; 
            write <= 1'b0;
            cycle <= 5'h00;
        end
        else begin
            // Synchronizacja requestów z domeny clk
            rd_sync <= {rd_sync[1:0], rd};
            wr_sync <= {wr_sync[1:0], wr};

            if (wr_pending && !wr_sync[2]) wr_pending <= 1'b0;
            if (rd_pending && !rd_sync[2]) rd_pending <= 1'b0;

            read <= 0; 
            write <= 0;

            case (state)
                ST_INIT: begin
                    if (ready && !busy) begin
                        state <= ST_IDLE;
                    end
                end

                ST_IDLE: begin
                    psram_busy <= 1'b0;
                    if (wr_sync[2] && !wr_pending) begin
                        state <= ST_WRITE;
                        wr_pending <= 1'b1;
                        psram_busy <= 1'b1;
                    end
                    else if (rd_sync[2] && !rd_pending) begin
                        state <= ST_READ;
                        rd_pending <= 1'b1;
                        reg_addr <= addr;
                        psram_busy <= 1'b1;
                    end
                end

                ST_READ: begin
                    cycle <= cycle + 1;
                    if (cycle == 0) begin
                        reg_addr <= addr;
                        read <= 1'b1;
                    end else if (!read && !busy) begin
                        psram_busy <= 1'b0;
                        dout <= reg_addr[0] ? rd_data[15:8] : rd_data[7:0];
                        cycle <= 5'h00;;
                        state <= ST_IDLE;
                    end else if (cycle == 10+LATENCY*2) begin
                        state <= ST_ERROR;
                    end
                end

                ST_WRITE: begin
                    cycle <= cycle + 1;
                    if (cycle == 0) begin
                        write <= 1'b1;
                        reg_addr <= addr;
                        wr_data <= {din, din};
                    end else if (!write && !busy) begin
                        psram_busy <= 1'b0;
                        cycle <= 5'h00;;
                        state <= ST_IDLE;
                    end else if (cycle == 5+LATENCY*2) begin
                        state <= ST_ERROR;
                    end
                end                
                
                ST_ERROR: begin
                    psram_error <= 1'b1;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
