//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Winbond W955D8MBYA 32Mb HyperRAM
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************

`timescale 1ns/1ps
`default_nettype none

module W955D8MBYA #(
    parameter CLK_PSRAM_FREQUENCY,
    parameter LATENCY,
    parameter DELAY_US
) (
    input   wire        clk,
    input   wire        clk_psram,
    input   wire        clk_psram_p,
    input   wire        reset_n,
    input   wire        pll_lock,

    input   wire [21:0] addr,
    input   wire [15:0] din,
    output  reg  [15:0] dout,
    input   wire        byte_write,

    input   wire        wr,
    input   wire        rd,

    output  wire        ready,
    output  wire        busy,
    
    // Gowin W955D8MBYA interface (2 x W955D8MBYA)
    output  wire        psram_ck,
    output  wire        psram_ck_n,
    inout   wire [7:0]  psram_dq,
    inout   wire        psram_rwds,
    output  wire        psram_cs_n,
    output  wire        psram_reset_n
);

    reg [15:0] word_din;
    reg [15:0] word_dout;
    reg [23:0] cycles;
    reg [63:0] dq; 

    // -----------------------------------------------------------------------
    // Interfejs pamięci Winbond W955D8MBYA
    // W955D8MBYA Datasheet: 
    // https://www.winbond.com/resource-files/W955D8MBYA_85C_PKG_datasheet_A01-001_20190605.pdf
    // Gowin FPGA Primitive (ODDR & IDDR): 
    // https://www.gowinsemi.com/upload/database_doc/39/document/5bfcff2ce0b72.pdf
    // -----------------------------------------------------------------------

    // Chip Select
    //   Bus transactions are initiated with a High to Low transition. Bus transactions
    //   are terminated with a Low to High transition. The master device has a separate CS# for each slave.
    reg cs_n;
    wire cs_n_tristate;
 
    ODDR oddr_cs_n (
        .CLK(clk_psram), 
        .D0(cs_n), 
        .D1(cs_n), 
        .TX(1'b0),
        .Q0(cs_n_tristate)
    );
    
    assign psram_cs_n = cs_n_tristate;
    
    // Differential Clock:
    //   Command, address, and data information is output with respect to the crossing of the CK and CK# signals
    reg enable_ck;
    reg enable_ck_p;
    wire ck_p_tristate;
    wire ck_n_tristate;

    ODDR oddr_ck_p (
        .CLK(clk_psram_p), 
        .D0(enable_ck_p), 
        .D1(1'b0),
        .TX(1'b0),
        .Q0(ck_p_tristate)
    );
    
   ODDR oddr_ck_n (
        .CLK(clk_psram), 
        .D0(enable_ck), 
        .D1(1'b0), 
        .TX(1'b0),
        .Q0(ck_n_tristate)
    );

    assign psram_ck = ck_p_tristate;
    assign psram_ck_n = ck_n_tristate;

    // Data Input / Output:
    //   Command, Address, and Data information is transferred on these signals during Read and Write transactions.
    wire [7:0] dq_out_ris = dq[63:56];
    wire [7:0] dq_out_fal = dq[55:48];
    reg dq_oen;
    wire [7:0] dq_out_tristate;
    wire [7:0] dq_oen_tristate;
    wire [7:0] dq_in_ris;
    wire [7:0] dq_in_fal;

    genvar i;
    generate
        for (i=0; i<=7; i=i+1) begin: gen_dq_i
            ODDR oddr_dq_i (
                .CLK(clk_psram), 
                .D0(dq_out_ris[i]), 
                .D1(dq_out_fal[i]),
                .TX(dq_oen),
                .Q0(dq_out_tristate[i]),
                .Q1(dq_oen_tristate[i])
            );

            assign psram_dq[i] = dq_oen_tristate[i] ? 1'bz : dq_out_tristate[i];
            
            IDDR iddr_dq_i (
                .CLK(clk_psram), 
                .D(psram_dq[i]), 
                .Q0(dq_in_ris[i]), 
                .Q1(dq_in_fal[i])
            );
        end
    endgenerate

    // Read Write Data Strobe:
    //   During the Command/Address portion of all bus transactions RWDS is a
    //   slave output and indicates whether additional initial latency is required. Slave
    //   output during read data transfer, data is edge aligned with RWDS. Slave
    //   input during data transfer in write transactions to function as a data mask.
    //   (High = additional latency, Low = no additional latency).
    reg rwds_out_ris;
    reg rwds_out_fal;
    reg rwds_oen;
    wire rwds_out_tristate;
    wire rwds_oen_tristate;
    wire rwds_in_ris;
    wire rwds_in_fal;

    ODDR oddr_rwds (
        .CLK(clk_psram), 
        .D0(rwds_out_ris), 
        .D1(rwds_out_fal),
        .TX(rwds_oen),
        .Q0(rwds_out_tristate),
        .Q1(rwds_oen_tristate)
    );

    assign psram_rwds = rwds_oen_tristate ? 1'bz : rwds_out_tristate;

    IDDR iddr_rwds (
         .CLK(clk_psram), 
         .D(psram_rwds),
         .Q0(rwds_in_ris), 
         .Q1(rwds_in_fal)
    );

    // Hardware Reset:
    //   When Low the slave device will self-initialize and return to the Standby state.
    //   RWDS and DQ[7:0] are placed into the High-Z state when RESET# is Low.
    //   The slave RESET# input includes a weak pull-up, if RESET# is left
    //   unconnected it will be pulled up to the High state
    reg rst_n;
    wire rst_n_tristate;
 
    ODDR oddr_rst_n (
        .CLK(clk_psram), 
        .D0(rst_n), 
        .D1(rst_n), 
        .TX(1'b0),
        .Q0(rst_n_tristate)
    );
            
    assign psram_reset_n = rst_n_tristate;

    // -----------------------------------------------------------------------------
    // Synchronizacja pll_lock najpierw w stabilnej domenie clk
    // -----------------------------------------------------------------------------
    reg pll_lock_meta;
    reg pll_lock_clk;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pll_lock_meta <= 1'b0;
            pll_lock_clk  <= 1'b0;
        end
        else begin
            pll_lock_meta <= pll_lock;
            pll_lock_clk  <= pll_lock_meta;
        end    
    end

    // -----------------------------------------------------------------------------
    // Przeniesienie do domeny clk_psram (CDC – podwójny synchronizer)
    // -----------------------------------------------------------------------------
    reg pll_lock_sync1;
    reg pll_lock_sync2;

    always @(posedge clk_psram or negedge reset_n) begin
        if (!reset_n) begin
            pll_lock_sync1 <= 1'b0;
            pll_lock_sync2 <= 1'b0;
        end
        else begin
            pll_lock_sync1 <= pll_lock_clk;
            pll_lock_sync2 <= pll_lock_sync1;
        end
    end

    // -----------------------------------------------------------------------------
    // Bezpieczny reset dla całej logiki w domenie clk_psram
    // -----------------------------------------------------------------------------
    wire reset_n_safe = reset_n & pll_lock_sync2;

    // -----------------------------------------------------------------------------
    // Główna logika kontrolera PSRAM
    // -----------------------------------------------------------------------------
    reg [2:0] state;
    reg wait_for_data;
    reg additional_latency;


    localparam ST_WAIT_PLL  = 3'd0,
               ST_DELAY     = 3'd1,
               ST_INIT      = 3'd2,
               ST_CONFIG    = 3'd3,
               ST_IDLE      = 3'd4,
               ST_READ      = 3'd5,
               ST_WRITE     = 3'd6;

    localparam CLK_PERIOD_NS  = 1_000_000_000 / CLK_PSRAM_FREQUENCY;
    localparam DELAY_CYCLES   = (DELAY_US * 1000 + CLK_PERIOD_NS - 1) / CLK_PERIOD_NS;
    localparam DELAY_TIME     = DELAY_CYCLES;
    reg [$clog2(DELAY_TIME):0] delay_cnt;    

    localparam [3:0] CR_LATENCY = LATENCY == 3 ? 4'b1110 :
                                  LATENCY == 4 ? 4'b1111 :
                                  LATENCY == 5 ? 4'b0 :
                                  LATENCY == 6 ? 4'b0001 : 4'b1110;

    assign ready = (state >= ST_IDLE);
    assign busy = (state != ST_IDLE);

    always @(posedge clk_psram or negedge reset_n) begin
        if (!reset_n) begin
            state <= ST_WAIT_PLL;
            cs_n <= 1'b1;
            rst_n <= 1'b00;
            enable_ck <= 0;
            delay_cnt <= 0;
        end
        else if (!reset_n_safe) begin
            state <= ST_WAIT_PLL;
            cs_n <= 1'b1;
            rst_n <= 1'b0;
            enable_ck <= 0;
            delay_cnt <= 0;
        end
        else begin
            cycles <= {cycles[22:0], 1'b0};
            dq <= {dq[47:0], 16'b0}; 
            enable_ck_p <= enable_ck;

            case (state)
                ST_WAIT_PLL: begin
                    rst_n <= 1'b1;
                    if (reset_n_safe) begin
                        state <= ST_DELAY;
                        cs_n <= 1'b1;                        
                        delay_cnt <= 0;
                    end
                end

                ST_DELAY: begin
                    if (delay_cnt != DELAY_TIME) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        state <= ST_INIT;
                    end
                end

                ST_INIT: begin
                    cycles <= 24'b1;
                    cs_n <= 1'b0;
                    state <= ST_CONFIG;
                end

                ST_CONFIG: begin
                    if (cycles[0]) begin
                        dq <= {8'h60, 8'h00, 8'h01, 8'h00, 8'h00, 8'h00, 8'h9f, CR_LATENCY, 4'h7};

                       dq_oen <= 1'b0;
                       enable_ck <= 1;

                    end 
                    if (cycles[4]) begin
                        state <= ST_IDLE;
                        enable_ck <= 0;
                        cycles <= 24'b1;
                        dq_oen <= 1'b1;
                        cs_n <= 1'b1;
                    end
                end

                ST_IDLE: begin
                    rwds_oen <= 1'b1;
                    enable_ck <= 0;
                    cs_n <= 1'b1;
                    
                    if (rd || wr) begin
                        dq <= {~wr, 13'b010_0000_0000_00, addr[21:4], 13'b0, addr[3:1], 16'b0000_0100_1101_0100};
                        cs_n <= 1'b0;
                        enable_ck <= 1;
                        dq_oen <= 1'b0;
                        wait_for_data <= 0;
                        word_din <= din;
                        cycles <= 32'b10;
                        state <= wr ? ST_WRITE : ST_READ;                        
                    end
                end

                ST_READ: begin
                    if (cycles[3]) begin
                        dq_oen <= 1'b1;
                    end
                    if (cycles[9]) wait_for_data <= 1;

                    if (wait_for_data && (rwds_in_ris ^ rwds_in_fal)) begin
                        dout <= {dq_in_ris, dq_in_fal};
                        cs_n <= 1'b1;
                        enable_ck <= 0;
                        state <= ST_IDLE;
                    end
                end

                ST_WRITE: begin
                    if (cycles[5]) additional_latency <= rwds_in_fal;
                    
                    if (cycles[2+LATENCY] && (LATENCY == 3 ? ~rwds_in_fal : ~additional_latency) || cycles[2+LATENCY*2]) begin
                        rwds_oen <= 1'b0;
                        rwds_out_ris <= byte_write ? ~addr[0] : 1'b0;
                        rwds_out_fal <= byte_write ? addr[0] : 1'b0;
                        dq[63:48] <= word_din;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_WAIT_PLL;     // bezpiecznik – nigdy nie powinno się zdarzyć
                end
            endcase
        end
    end

endmodule

`default_nettype wire
