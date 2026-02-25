//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Video Font Cache
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************


`timescale 1ns/1ps
`default_nettype none

module video_font_cache #(
    parameter CLK_PSRAM_FREQUENCY=72_000_000,
    parameter LATENCY=3,
    parameter DELAY_US=160
) (
    input   wire        clk,

    input   wire        clk_pixel,
    input   wire        reset_n_pixel,

    input   wire        clk_psram,
    input   wire        clk_psram_p,
    input   wire        pll_lock,
    input   wire        reset_n_psram,

    input   wire [7:0]  font_bank_addr,

    input   wire [10:0] font_addr,
    output  wire [7:0]  font_data_out,

    output  wire        use_font_vram,

    input  wire         font_psram_wr_pulse,
    input  wire [21:0]  font_psram_wr_addr,
    input  wire [15:0]  font_psram_wr_data,
    output wire         font_psram_ready,

    output  reg         psram_error,

    output  wire        psram_ck,
    output  wire        psram_ck_n,
    inout   wire [7:0]  psram_dq,
    inout   wire        psram_rwds,
    output  wire        psram_cs_n,
    output  wire        psram_reset_n
);

    // -----------------------------------------------------------------------
    // Instancja W955D8MBYA
    // -----------------------------------------------------------------------

    reg psram_write;
    reg psram_read;
    wire psram_ready;
    wire psram_busy;
    reg [21:0] psram_addr;
    reg [15:0] psram_rd_data;
    reg [15:0] psram_wr_data;
    
    W955D8MBYA #(
        .CLK_PSRAM_FREQUENCY(CLK_PSRAM_FREQUENCY),
        .LATENCY(LATENCY),
        .DELAY_US(DELAY_US)
    ) W955D8MBYA_1_Inst (
        .clk(clk),
        .clk_psram(clk_psram),
        .clk_psram_p(clk_psram_p),
        .reset_n(reset_n_psram),
        .pll_lock(pll_lock),
    
        .addr(psram_addr),
        .din(psram_wr_data),
        .dout(psram_rd_data),
        .byte_write(1'b0),

        .wr(psram_write),
        .rd(psram_read),
        .ready(psram_ready),
        .busy(psram_busy),

        .psram_ck(psram_ck),
        .psram_ck_n(psram_ck_n),
        .psram_dq(psram_dq),
        .psram_rwds(psram_rwds),
        .psram_cs_n(psram_cs_n),
        .psram_reset_n(psram_reset_n)
    );

    //----------------------------------------------------------------------------
    // SYNCHRONIZACJA CLK 27MHz
    //----------------------------------------------------------------------------
    reg [1:0] font_psram_wr_pulse_sync;
    reg [21:0] font_psram_wr_addr_meta;
    reg [21:0] font_psram_wr_addr_sync;
    reg [15:0] font_psram_wr_data_meta;
    reg [15:0] font_psram_wr_data_sync;

    always @(posedge clk or negedge reset_n_pixel) begin
        if (!reset_n_pixel) begin
            font_psram_wr_pulse_sync <= 2'b00;
            font_psram_wr_addr_meta <= 22'd0;
            font_psram_wr_addr_sync <= 22'd0;
            font_psram_wr_data_meta <= 16'd0;
            font_psram_wr_data_sync <= 16'd0;
        end else begin
            font_psram_wr_pulse_sync <= {font_psram_wr_pulse_sync[0], font_psram_wr_pulse};

            font_psram_wr_addr_meta <= font_psram_wr_addr;
            font_psram_wr_addr_sync <= font_psram_wr_addr_meta;

            font_psram_wr_data_meta <= font_psram_wr_data;
            font_psram_wr_data_sync <= font_psram_wr_data_meta;
        end
    end


    //----------------------------------------------------------------------------
    // SYNCHRONIZACJA CLK PIXEL
    //----------------------------------------------------------------------------

    reg [7:0] font_bank_pixel_meta;
    reg [7:0] font_bank_pixel_sync;

    always @(posedge clk_pixel or negedge reset_n_pixel) begin
        if (!reset_n_pixel) begin
            font_bank_pixel_meta <= 8'd0;
            font_bank_pixel_sync <= 8'd0;
        end else begin
            font_bank_pixel_meta <= font_bank_addr;
            font_bank_pixel_sync <= font_bank_pixel_meta;
        end
    end
    
    assign use_font_vram = font_bank_pixel_sync[7]; // Cobra Double RAM
    
    //----------------------------------------------------------------------------
    // SYNCHRONIZACJA CLK PSRAM
    //----------------------------------------------------------------------------

    reg [7:0] font_bank_psram_meta;
    reg [7:0] font_bank_psram_sync;

    always @(posedge clk_psram or negedge reset_n_psram) begin
        if (!reset_n_psram) begin
            font_bank_psram_meta <= 8'd0;
            font_bank_psram_sync <= 8'd0;
        end else begin
            font_bank_psram_meta <= font_bank_addr;
            font_bank_psram_sync <= font_bank_psram_meta;
        end
    end

    //----------------------------------------------------------------------------
    // DOUBLE BUFFER
    //----------------------------------------------------------------------------

    wire [9:0] cache_a_wr_addr;
    wire [15:0] cache_a_wr_data;
    reg cache_a_wr_en;

    wire [9:0] cache_a_rd_addr;
    wire [15:0] cache_a_rd_data;    

    Gowin_DPB_1K_16B dpb_cache_a (
        .clka(clk_psram),
        .reseta(!reset_n_psram),
        .ada(cache_a_wr_addr),
        .dina(cache_a_wr_data),
        .ocea(1'b1),
        .cea(1'b1),
        .wrea(cache_a_wr_en),

        .clkb(clk_pixel),
        .resetb(!reset_n_pixel),
        .adb(cache_a_rd_addr),
        .doutb(cache_a_rd_data),
        .oceb(1'b1),
        .ceb(1'b1)
    );

    wire [9:0] cache_b_wr_addr;
    wire [15:0] cache_b_wr_data;
    reg cache_b_wr_en;

    wire [9:0] cache_b_rd_addr;
    wire [15:0] cache_b_rd_data;    

    Gowin_DPB_1K_16B dpb_cache_b (
        .clka(clk_psram),
        .reseta(!reset_n_psram),
        .ada(cache_b_wr_addr),
        .dina(cache_b_wr_data),
        .ocea(1'b1),
        .cea(1'b1),
        .wrea(cache_b_wr_en),

        .clkb(clk_pixel),
        .resetb(!reset_n_pixel),
        .adb(cache_b_rd_addr),
        .doutb(cache_b_rd_data),
        .oceb(1'b1),
        .ceb(1'b1)
    );
    
    reg active_buffer;
    reg [6:0] loaded_bank;
    reg bank_loaded;

    assign cache_a_rd_addr = font_addr[10:1];
    assign cache_b_rd_addr = font_addr[10:1];
    assign cache_a_wr_data = psram_rd_data;
    assign cache_b_wr_data = psram_rd_data;

    assign font_data_out = active_buffer ?
                       (font_addr[0] ? cache_b_rd_data[15:8] : cache_b_rd_data[7:0]) :
                       (font_addr[0] ? cache_a_rd_data[15:8] : cache_a_rd_data[7:0]);

    //----------------------------------------------------------------------------
    // LADOWANIE FONTÓW Z PSRAM DO CACHE
    //----------------------------------------------------------------------------

    localparam ST_INIT  = 3'd0,
               ST_IDLE  = 3'd1,         
               ST_LOAD  = 3'd2,
               ST_WRITE = 3'd3,
               ST_ERROR = 3'd4;

    reg [2:0] state;             // 0=idle, 1=czytanie, 2=koniec
    reg [9:0] load_cnt;
    reg [6:0] target_bank;
    reg load_pending;
    reg swap_buffers;           // impuls do przełączenia bufora (do clk_pixel)
    reg [4:0] cycle;

    assign cache_a_wr_addr = load_cnt - 1;
    assign cache_b_wr_addr = load_cnt - 1;

    assign font_psram_ready = (state == ST_IDLE) && !load_pending && !psram_busy && psram_ready;

    always @(posedge clk_psram or negedge reset_n_psram) begin
        if (!reset_n_psram) begin
            state <= ST_INIT;
            load_cnt <= 11'd0;
            load_pending <= 1'b0;
            target_bank <= 7'd0;
            loaded_bank <= 7'd0;
            bank_loaded   <= 1'b0;
            swap_buffers <= 1'b0;
            psram_read <= 1'b0;
            psram_write <= 1'b0;
            psram_error <= 1'b0;
        end
        else begin
            
            psram_read <= 1'b0;
            psram_write <= 1'b0;
            swap_buffers <= 1'b0;
            cache_a_wr_en <= 1'b0;
            cache_b_wr_en <= 1'b0;
            
            case (state)

                ST_INIT: begin
                    if (psram_ready && !psram_busy) begin
                        state <= ST_IDLE;
                    end
                end

                ST_IDLE: begin
                    if (!psram_busy && font_psram_wr_pulse_sync[1] && font_psram_ready) begin
                        psram_addr <= font_psram_wr_addr_sync;
                        psram_wr_data <= font_psram_wr_data_sync;
                        psram_write <= 1'b1;
                        cycle <= 5'h00;
                        state <= ST_WRITE;
                    end
                    else if (!psram_busy && !load_pending && (!bank_loaded || (font_bank_psram_sync[6:0] != loaded_bank))) begin

                        target_bank  <= font_bank_psram_sync[6:0];
                        load_cnt <= 10'd0;
                        load_pending <= 1'b1;
                        bank_loaded <= 1'b1;
                        psram_addr <= {font_bank_psram_sync[6:0], 11'd0};
                        psram_read <= 1'b1;
                        cycle <= 5'h00;
                        state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    cycle <= cycle + 1;
                    if (!psram_read && !psram_busy) begin
                        cycle <= 5'h00;

                        if (active_buffer == 1'b0) begin
                            cache_b_wr_en <= 1'b1;
                        end else begin
                            cache_a_wr_en <= 1'b1;
                        end

                        if (load_cnt < 1023) begin
                            load_cnt <= load_cnt + 10'd1;
                            psram_addr <= psram_addr + 22'd2;
                            psram_read <= 1'b1;
                        end else begin
                            loaded_bank <= target_bank;
                            swap_buffers <= 1'b1;
                            load_pending <= 1'b0;
                            state <= ST_IDLE;
                        end
                    end else if (cycle == 10+LATENCY*2) begin
                        state <= ST_ERROR;
                    end
                end
                
                ST_WRITE: begin
                    cycle <= cycle + 1;
                    if (!psram_write && !psram_busy) begin
                        cycle <= 5'h00;
                        state <= ST_IDLE;
                     end else if (cycle == 5+LATENCY*2) begin
                        state <= ST_ERROR;
                    end
                end

                ST_ERROR: begin
                    psram_error <= 1'b1;
                end

            endcase            
        end
    end

    //----------------------------------------------------------------------------
    // PRZEŁĄCZANIE BUFORA
    //----------------------------------------------------------------------------

    reg [1:0] swap_sync;

    always @(posedge clk_pixel or negedge reset_n_pixel) begin
        if (!reset_n_pixel) begin
            swap_sync <= 2'b00;
            active_buffer <= 1'b0;
        end else begin
            swap_sync <= {swap_sync[0] , swap_buffers};

            // Przełączamy tylko na zboczu (impuls)
            if (swap_sync[1] && !swap_sync[0]) begin
                active_buffer <= ~active_buffer;
            end
        end
    end


endmodule

`default_nettype wire