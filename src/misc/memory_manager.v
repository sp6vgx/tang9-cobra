// ************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Memory Manager
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************

`timescale 1ns/1ps
`default_nettype none

module memory_manager (
    // Global
    input   wire        clk_cpu,
    input   wire        cpu_reset_n,

    // Z80
    input   wire [15:0] cpu_addr,
    input   wire [7:0]  cpu_dout,
    output  reg [7:0]   cpu_din,
    input   wire        cpu_mreq_n,
    input   wire        cpu_iorq_n,
    input   wire        cpu_rd_n,
    input   wire        cpu_wr_n,
    output  wire        cpu_wait_n,

    // IO
    input   wire [7:0]  io_dout,

    // RAM/ROM (PSRAM)
    output  wire [21:0] ram_rom_addr,
    output  wire [7:0]  ram_rom_din,
    input   wire [7:0]  ram_rom_dout,
    output  wire        ram_rom_rd,
    output  wire        ram_rom_wr,
    input   wire        ram_rom_busy,

    // VRAM
    output  wire [10:0] vram_addr,
    output  wire [7:0]  vram_din,
    input   wire [7:0]  vram_fonts_dout,
    input   wire [7:0]  vram_characters_dout,
    input   wire [7:0]  vram_colors_dout,
    output  wire        vram_fonts_we,
    output  wire        vram_characters_we,
    output  wire        vram_colors_we,

    // IO
    input   wire        rom_remap,
    input   wire [4:0]  cardridge_bank_addr,
    input   wire [2:0]  cardridge_no,

    // Zewnętrzny dostęp do RAM/ROM (PSRAM)
    input   wire        ext_ram_rom_req,
    input   wire        ext_ram_rom_rd,
    input   wire        ext_ram_rom_wr,
    input   wire [21:0] ext_ram_rom_addr,
    input   wire [7:0]  ext_ram_rom_din,
    output  wire [7:0]  ext_ram_rom_dout,
    output  wire        ext_ram_rom_busy,

    // Parametry
    input   wire        cobra_color_enable,
    input   wire        cobra_dual_ram_enable
);


    // -----------------------------------------------------------------------
    // Synchronizacja
    // -----------------------------------------------------------------------

    reg [1:0] ext_ram_rom_req_sync;
    reg [1:0] cobra_color_enable_sync;
    reg [1:0] cobra_dual_ram_enable_sync;

    always @(posedge clk_cpu) begin
        ext_ram_rom_req_sync = { ext_ram_rom_req_sync[0], ext_ram_rom_req };
        cobra_color_enable_sync = { cobra_color_enable_sync[0], cobra_color_enable};
        cobra_dual_ram_enable_sync <= {cobra_dual_ram_enable_sync[0], cobra_dual_ram_enable};
    end

    // Mapa Pamięci Cobra1 
    // 0000 - BFFF      48K RAM
    // C000 - F7FF      ROM (Banki)
    // F800 - FBFF      1K VRAM Characters
    
    // Mapa Pamięci Cobra Kolor 
    // 0000 - BFFF      48K RAM
    // C000 - F7FF      ROM (Banki)
    // F800 - FBFF      1K VRAM Characters
    // FC00 - FFFF      1K VRAM Colors

    // Mapa Pamięci Cobra & Cobra Kolor Dual RAM
    // 0000 - BFFF      48K RAM
    // C000 - EFFF      ROM (Banki)
    // F000 - F7FF      2K VRAM Fonts
    // F800 - FBFF      1K VRAM Characters
    // FC00 - FFFF      1K VRAM Colors


    // -----------------------------------------------------------------------
    // Dekodowanie obszarów
    // -----------------------------------------------------------------------

    // 0000-BFFF
    wire is_low_ram = (cpu_addr < 16'hC000);
 
    // C000-EFFF lub C000-F7FF
    wire is_high_ram_rom = (cpu_addr >= 16'hC000) && (cpu_addr <= (cobra_dual_ram_enable_sync[1] ? 16'hEFFF : 16'hF7FF));

    // F000-F7FF (Cobra Dual RAM)
    wire is_vram_fonts = cobra_dual_ram_enable_sync[1] && (cpu_addr >= 16'hF000) && (cpu_addr < 16'hF800);

    // F800 - FBFF
    wire is_vram_characters = (cpu_addr >= 16'hF800) && (cpu_addr < 16'hFC00);

    // FC00 - FFFF (Cobra Kolor)
    wire is_vram_colors = cobra_color_enable_sync[1] && (cpu_addr >= 16'hFC00);

    // Czy pamiec to ram_rom ?
    wire is_ram_rom_area = is_low_ram || is_high_ram_rom;

    // -----------------------------------------------------------------------
    // Adres do RAM/ROM
    // -----------------------------------------------------------------------;
    
    wire [21:0] ram_rom_addr_cpu = is_low_ram ?
        (rom_remap && cpu_addr < 16'h4000) ? (22'h00_0C000 + cpu_addr[13:0])
                                           : {6'b0, cpu_addr[15:0]}
        :
        22'h00_0C000 + ({19'b0, cardridge_no} << 19)
                     + ({14'b0, cardridge_bank_addr} << 14)
                     + cpu_addr[13:0];


    // Sygnały dostępu CPU
    wire ram_rom_rd_cpu = is_ram_rom_area && !cpu_mreq_n && !cpu_rd_n;
    wire ram_rom_wr_cpu = is_ram_rom_area && !cpu_mreq_n && !cpu_wr_n;

    // -----------------------------------------------------------------------
    // ARBITER (priorytet zewnętrzny)
    // -----------------------------------------------------------------------

    wire ram_rom_access_ext = ext_ram_rom_req_sync[1];
    wire ram_rom_access_cpu = ram_rom_rd_cpu || ram_rom_wr_cpu;

    assign ram_rom_addr = ram_rom_access_ext ? ext_ram_rom_addr : ram_rom_addr_cpu;
    assign ram_rom_din = ram_rom_access_ext ? ext_ram_rom_din : cpu_dout;
    assign ram_rom_rd = ram_rom_access_ext ? ext_ram_rom_rd : ram_rom_rd_cpu;
    assign ram_rom_wr = ram_rom_access_ext ? ext_ram_rom_wr : (ram_rom_wr_cpu && is_low_ram && ((rom_remap == 1'b0) || (cpu_addr >= 16'h4000)));

    // WAIT dla Z80
    assign cpu_wait_n = ram_rom_access_ext ? !cpu_reset_n : (ram_rom_access_cpu && ram_rom_busy && cpu_reset_n) ? 1'b0 : 1'b1;

    // Zewnętrzny interfejs
    assign ext_ram_rom_dout = ram_rom_dout;
    assign ext_ram_rom_busy = ram_rom_busy;

    // -----------------------------------------------------------------------
    // VRAM
    // -----------------------------------------------------------------------

    assign vram_addr = cpu_addr[10:0];
    assign vram_din = cpu_dout;
    assign vram_fonts_we = is_vram_fonts && !cpu_mreq_n && !cpu_wr_n;
    assign vram_characters_we = is_vram_characters && !cpu_mreq_n && !cpu_wr_n;
    assign vram_colors_we = is_vram_colors && !cpu_mreq_n && !cpu_wr_n;

    // -----------------------------------------------------------------------
    // MUX danych do Z80
    // -----------------------------------------------------------------------

    always @(*) begin
        if (!cpu_mreq_n && !cpu_rd_n) begin
            if (is_ram_rom_area) cpu_din = ram_rom_dout;
            else if (is_vram_fonts) cpu_din = vram_fonts_dout; 
            else if (is_vram_characters) cpu_din = vram_characters_dout;
            else if (is_vram_colors) cpu_din = vram_colors_dout;
        end else if (!cpu_iorq_n && !cpu_rd_n) begin
            cpu_din = io_dout;
        end else begin
            cpu_din = 8'hFF;
        end
    end

endmodule

`default_nettype wire
