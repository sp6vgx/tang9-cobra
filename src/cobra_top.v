//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Cobra 1 Top Module
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************


`timescale 1ns/1ps
`default_nettype none

module cobra_top (
    input   wire        clk_27M,         // Zegar wejściowy z oscylatora (Pin 52)
    input   wire        key_reset_n,     // Przycisk Reset (S1 - Pin 4)
    input   wire        key_switch_rom,  // Przycisk Przełączajacy ROM-y (S2 - Pin 3)

    // Diody LED (Diagnostics)
    output  wire [5:0]  led,

    // Klawiatura USB
    inout   wire        usb_dm,         // Pin 25
    inout   wire        usb_dp,         // Pin 26
    
    // Tape signal
    input   wire        tape_in,        // Pin 30
    output  wire        tape_out,       // Pin 33    

    // Fizyczny interfejs PSRAM (Tang Nano 9K - Wbudowany układ)
    output  wire [1:0]  O_psram_ck,
    output  wire [1:0]  O_psram_ck_n,
    inout   wire [15:0] IO_psram_dq,
    inout   wire [1:0]  IO_psram_rwds,
    output  wire [1:0]  O_psram_cs_n,
    output  wire [1:0]  O_psram_reset_n,

    // SPI Flash (P25Q32U) - na płytce Tang Nano 9K
    output  wire        spi_flash_cs_n,
    output  wire        spi_flash_sclk,
    output  wire        spi_flash_mosi,
    input   wire        spi_flash_miso,    

    // Wyjście HDMI
    output  wire        tmds_clk_p,
    output  wire        tmds_clk_n,
    output  wire [2:0]  tmds_data_p,
    output  wire [2:0]  tmds_data_n
);

    //----------------------------------------------------------------------------
    // GENERACJA ZEGARÓW (PLL)
    //----------------------------------------------------------------------------
    
    // PLL1: Zegar dla wyjścia HDMI (Serial x5) oraz taktowanie CPU (3.25 MHz)
    wire pll1_locked;
    wire clk_pixel_x5; // Dla DVI/HDMI TX
    wire clk_cpu;      // Główny zegar systemu Cobra
    
    Gowin_rPLL1 rPLL1_Inst (
        .lock   (pll1_locked),
        .clkin  (clk_27M),
        .clkout (clk_pixel_x5),
        .clkoutd(clk_cpu) 
    );

    wire clk_pixel;

    CLKDIV clkdiv_pc_Inst
    (
        .RESETN(infra_reset_n),
        .HCLKIN(clk_pixel_x5),
        .CLKOUT(clk_pixel),  // 74.25MHz
        .CALIB(1'b0)
    );

    defparam clkdiv_pc_Inst.DIV_MODE = "5";
    defparam clkdiv_pc_Inst.GSREN = "false"; 

    // PLL2: Zegar dla magistrali PSRAM (192 MHz) oraz USB (12 MHz)
    wire pll2_locked;
    wire clk_psram;
    wire clk_psram_p;
    wire clk_usb;

    Gowin_rPLL2 rPLL2_Inst (
        .lock   (pll2_locked),
        .clkin  (clk_27M),
        .clkout (clk_psram),
        .clkoutp(clk_psram_p),
        .clkoutd(clk_usb)
    );

    //----------------------------------------------------------------------------
    // LOGIKA RESETU KASKADOWEGO
    //----------------------------------------------------------------------------
    wire rom_loder_end_copy;
    
    // Etap 1: Reset infrastruktury (tylko PLL i przycisk)
    // Kontroler PSRAM potrzebuje resetu, aby zacząć kalibrację
    wire infra_ready = key_reset_n && pll1_locked && pll2_locked;
    wire infra_reset_n = infra_ready; 

    // Etap 2: Reset procesora (Z80 rusza dopiero, gdy RAM/ROM (PSRAM) i Video jest gotowe)
    wire video_ready;
    wire ram_rom_ready;

    reg [1:0] ram_rom_ready_sync;
    reg [1:0] video_ready_sync;
    reg [1:0] rom_loder_end_copy_sync;

    // Synchronizacja sygnału gotowości RAM/ROM (PSRAM) do domeny zegara CPU
    always @(posedge clk_cpu) begin
        ram_rom_ready_sync <= {ram_rom_ready_sync[0], ram_rom_ready};
        video_ready_sync <= {video_ready_sync[0], video_ready};
        rom_loder_end_copy_sync <= {rom_loder_end_copy_sync[0], rom_loder_end_copy};
    end
    
    wire cpu_ready = infra_ready && ram_rom_ready_sync[1] && video_ready_sync[1] && rom_loder_end_copy_sync[1];
    
    // Generator resetu synchronicznego dla Z80
    reg [1:0] cpu_reset_sync;
    always @(posedge clk_cpu or negedge cpu_ready) begin
        if (!cpu_ready)
            cpu_reset_sync <= 2'b00;
        else
            cpu_reset_sync <= {cpu_reset_sync[0], 1'b1};
    end
    
    wire cpu_reset_n = cpu_reset_sync[1]; // Główny sygnał resetu dla logiki użytkownika

    //----------------------------------------------------------------------------
    // PROCESOR Z80 (T80as Core)
    //----------------------------------------------------------------------------

    wire [15:0] cpu_addr;
    wire [7:0] cpu_din;
    wire [7:0] cpu_dout;
    wire cpu_wait_n;
    wire cpu_mreq_n;
    wire cpu_iorq_n; 
    wire cpu_rd_n;
    wire cpu_wr_n;
    wire cpu_int_n;

    
    T80as T80as_Inst (
        .CLK_n   (clk_cpu),
        .RESET_n (cpu_reset_n),
        .A       (cpu_addr),
        .DI      (cpu_din),
        .DO      (cpu_dout),
        .WAIT_n  (cpu_wait_n),
        .MREQ_n  (cpu_mreq_n),
        .IORQ_n  (cpu_iorq_n),
        .RD_n    (cpu_rd_n),
        .WR_n    (cpu_wr_n),
        .INT_n   (cpu_int_n), 
        .NMI_n   (1'b1),
        .BUSRQ_n (1'b1)
    );

    //----------------------------------------------------------------------------
    // INT 20ms 
    //----------------------------------------------------------------------------
    
    int_20ms int_20ms_Inst (
        .clk_cpu(clk_cpu),
        .reset_n(cpu_reset_n),
        .int_n(cpu_int_n)
    );

    //----------------------------------------------------------------------------
    // RAM/ROM (PSRAM)
    //----------------------------------------------------------------------------

    wire [21:0] ram_rom_addr;
    wire [7:0] ram_rom_din;
    wire [7:0] ram_rom_dout;
    wire ram_rom_rd;
    wire ram_rom_wr;
    wire ram_rom_busy;
    wire ram_rom_error;

    ram_rom_controller  ram_rom_controller_Inst (
        .clk            (clk_27M),
        .clk_psram      (clk_psram),
        .clk_psram_p    (clk_psram_p),
        .pll_lock       (pll2_locked),
        .reset_n        (infra_reset_n),

        .addr           (ram_rom_addr),
        .din            (ram_rom_din),
        .dout           (ram_rom_dout),
        .wr             (ram_rom_wr),
        .rd             (ram_rom_rd),

        .psram_ready    (ram_rom_ready),
        .psram_busy     (ram_rom_busy),
        .psram_error    (ram_rom_error),

        // Fizyczne połączenia
        .psram_ck       (O_psram_ck[0]),
        .psram_ck_n     (O_psram_ck_n[0]),
        .psram_dq       (IO_psram_dq[7:0]),
        .psram_rwds     (IO_psram_rwds[0]),
        .psram_cs_n     (O_psram_cs_n[0]),
        .psram_reset_n  (O_psram_reset_n[0])
    );

    //----------------------------------------------------------------------------
    // FONT CACHE + FONT BANKS (PSRAM)
    //----------------------------------------------------------------------------
    
    wire [7:0] font_bank_addr;
    wire [10:0] font_addr;
    wire [7:0] font_data_out;

    wire use_font_vram;

    wire font_psram_wr_pulse;
    wire [21:0] font_psram_wr_addr;
    wire [15:0] font_psram_wr_data;
    wire font_psram_ready;

    video_font_cache video_font_cache_Inst (
        .clk(clk_27M),
        
        .clk_pixel(clk_pixel),
        .reset_n_pixel(infra_reset_n),

        .clk_psram(clk_psram),
        .clk_psram_p(clk_psram_p),
        .pll_lock(pll2_locked),
        .reset_n_psram(infra_reset_n),

        .font_bank_addr(font_bank_addr),

        .font_addr(font_addr),
        .font_data_out(font_data_out),

        .use_font_vram(use_font_vram),

        .font_psram_wr_pulse(font_psram_wr_pulse),
        .font_psram_wr_addr(font_psram_wr_addr),
        .font_psram_wr_data(font_psram_wr_data),
        .font_psram_ready(font_psram_ready),

        .psram_ck(O_psram_ck[1]),
        .psram_ck_n(O_psram_ck_n[1]),
        .psram_dq(IO_psram_dq[15:8]),
        .psram_rwds(IO_psram_rwds[1]),
        .psram_cs_n(O_psram_cs_n[1]),
        .psram_reset_n(O_psram_reset_n[1])
    );

    //----------------------------------------------------------------------------
    // AUDIO
    //----------------------------------------------------------------------------

    // Clock Generator
    wire clk_audio;
    wire signed [15:0] audio_pcm_l;
    wire signed [15:0] audio_pcm_r;    

    audio_clock_generator audio_clock_generator_Inst (
        .clk_pixel(clk_pixel),
        .clk_div(12'd773),
        
        .clk_audio(clk_audio)
    );

    // Beep
    wire beep_enable;
    wire signed [15:0] beep_pcm;

    audio_beep audio_beep_Inst (
        .clk_audio(clk_audio),
        
        .clk_cpu(clk_cpu),
        .reset_n(cpu_reset_n),
        
        .enable(beep_enable),
        .volume(4'd12),
        
        .sample_out(beep_pcm)
    );

    // Katarynka
    wire katarynka_clk1;
    wire katarynka_clk2;
    wire katarynka_data;
    wire signed [15:0] katarynka_pcm;

    audio_katarynka audio_katarynka_Inst (
        .clk_audio(clk_audio),
        
        .clk_cpu(clk_cpu),        
        .reset_n(cpu_reset_n),
        
        .katarynka_clk1(katarynka_clk1),
        .katarynka_clk2(katarynka_clk2),
        .katarynka_data(katarynka_data),
        
        .volume(6'd6),
        
        .sample_out(katarynka_pcm)
    );

    // AY3-8910
    wire ay_bc;
    wire [7:0] ay_dout;
    wire signed [15:0] ay_pcm;
 
    //wire ay_bidir = ~cpu_iorq_n && ~cpu_wr_n && ~cpu_addr[1];

    wire ay_bidir = (!cpu_iorq_n && !cpu_wr_n && (cpu_addr == 16'hFFFD || cpu_addr ==  16'hBFFD)) ? 1'b1 : 1'b0;
 
    audio_ay3_8910 audio_ay3_8910_Inst (
        .clk_audio(clk_audio),

        .clk_cpu(clk_cpu),
        .reset_n(cpu_reset_n),

        .ay_bc(cpu_addr[14]),
        .ay_bidir(ay_bidir),
        .ay_din(cpu_dout),

        .sample_out(ay_pcm)
    );


    // Audio Mixer
    audio_mixer audio_mixer_Inst (
        .clk(clk_audio),
        .reset_n(cpu_reset_n),
        
        .mono_katarynka(katarynka_pcm),
        
        .mono_beep(beep_pcm),

        .mono_ay(ay_pcm),

        .audio_left(audio_pcm_l),
        .audio_right(audio_pcm_r)
    );

    //----------------------------------------------------------------------------
    // VIDEO & AUDIO HDMI OUT
    //----------------------------------------------------------------------------

    wire [10:0] vram_addr;
    wire [7:0] vram_din;
    wire [7:0] vram_fonts_dout;
    wire [7:0] vram_characters_dout;
    wire [7:0] vram_colors_dout;
    wire vram_fonts_we;
    wire vram_characters_we;
    wire vram_colors_we;
    wire cobra_dual_ram_enable;

    audio_video_hdmi_out audio_video_hdmi_out_Inst (
        .clk_pixel(clk_pixel),
        .clk_pixel_x5(clk_pixel_x5),
        .reset_n(infra_reset_n),

        .clk_cpu(clk_cpu),
        .cpu_reset_n(cpu_reset_n),

        .vram_addr(vram_addr),
        .vram_din(vram_din),
        .vram_fonts_dout(vram_fonts_dout),
        .vram_characters_dout(vram_characters_dout),
        .vram_colors_dout(vram_colors_dout),
        .vram_fonts_we(vram_fonts_we),
        .vram_characters_we(vram_characters_we),
        .vram_colors_we(vram_colors_we),

        .tape_mig(tape_in),

        .clk_audio(clk_audio),
        .audio_pcm_l(audio_pcm_l),
        .audio_pcm_r(audio_pcm_r),

        .font_addr(font_addr),
        .font_data(font_data_out),
        .use_font_vram(use_font_vram),

        .ready(video_ready),

        .cobra_dual_ram_enable(cobra_dual_ram_enable),

        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_data_p),
        .tmds_data_n(tmds_data_n)
    );

    //----------------------------------------------------------------------------
    // HOST USB HID
    //----------------------------------------------------------------------------

    wire usb_con_error;
    wire [1:0] usb_hid_type;
    wire [7:0] usb_key_modifiers;
    wire [7:0] usb_key1;
    wire [7:0] usb_key2;
    wire [7:0] usb_key3;
    wire [7:0] usb_key4;

    usb_hid_host usb_hid_host_Inst (
        .usbclk(clk_usb),
        .usbrst_n(infra_reset_n),
        
        .usb_dm(usb_dm),
        .usb_dp(usb_dp),
         
        .typ(usb_hid_type),

        .key_modifiers(usb_key_modifiers),
        .key1(usb_key1),
        .key2(usb_key2),
        .key3(usb_key3),
        .key4(usb_key4),

        .conerr(usb_con_error)
    );

    //----------------------------------------------------------------------------
    // KEYBOARD USB TO COBRA 
    //----------------------------------------------------------------------------

    wire [6:0] keyboard_data;

    keyboard_usb_to_cobra keyboard_usb_to_cobra_Inst (
        .clk_cpu(clk_cpu),
        .cpu_addr(cpu_addr),

        .clk_usb(clk_usb),
        .usb_hid_type(usb_hid_type),

        .key_modifiers(usb_key_modifiers),
        .key1(usb_key1),
        .key2(usb_key2),
        .key3(usb_key3),
        .key4(usb_key4),
        
        .keyboard_data(keyboard_data)
    );

    //----------------------------------------------------------------------------
    // TAPE INTERFACE
    //----------------------------------------------------------------------------
    
    wire tape_in_data;
    wire tape_in_data_n;  
    wire tape_out_data;

    tape_interface tape_interface_Inst (
        .clk_cpu(clk_cpu),
        .reset_n(cpu_reset_n),

        .tape_in(tape_in),
        .tape_in_data(tape_in_data),
        .tape_in_data_n(tape_in_data_n),

        .tape_out_data(tape_out_data),
        .tape_out(tape_out)
    );

    //----------------------------------------------------------------------------
    // IO MANAGER
    //----------------------------------------------------------------------------

    wire [7:0] io_dout;
    wire rom_remap;
    wire [4:0] cardridge_bank_addr;

    io_manager io_manager_Inst (
        .clk_cpu(clk_cpu),
        .cpu_reset_n(cpu_reset_n),
        
        .cpu_addr(cpu_addr),
        .cpu_dout(cpu_dout),
        .cpu_iorq_n(cpu_iorq_n),
        .cpu_rd_n(cpu_rd_n),
        .cpu_wr_n(cpu_wr_n),

        .keyboard_data(keyboard_data),

        .tape_in_data(tape_in_data),
        .tape_in_data_n(tape_in_data_n),
        
        .io_dout(io_dout),

        .rom_remap(rom_remap),
        .tape_out_data(tape_out_data),
        .beep_enable(beep_enable),
        .katarynka_clk1(katarynka_clk1),
        .katarynka_clk2(katarynka_clk2),
        .katarynka_data(katarynka_data),
        .cardridge_bank_addr(cardridge_bank_addr),
        .font_bank_addr(font_bank_addr)
    );

    //----------------------------------------------------------------------------
    // MEMORY MANAGER
    //----------------------------------------------------------------------------

    wire [2:0] cardridge_no;
    wire ext_ram_rom_req;
    wire ext_ram_rom_rd;
    wire ext_ram_rom_wr;
    wire [21:0] ext_ram_rom_addr;
    wire [7:0] ext_ram_rom_din;
    wire [7:0] ext_ram_rom_dout;
    wire ext_ram_rom_busy;
    wire cobra_color_enable;
    
    memory_manager memory_manager_Inst (
        .clk_cpu(clk_cpu),
        .cpu_reset_n(cpu_reset_n),
        
        .cpu_addr(cpu_addr),
        .cpu_dout(cpu_dout),
        .cpu_din(cpu_din),
        .cpu_mreq_n(cpu_mreq_n),
        .cpu_iorq_n(cpu_iorq_n),
        .cpu_rd_n(cpu_rd_n),
        .cpu_wr_n(cpu_wr_n),
        .cpu_wait_n(cpu_wait_n),
        .io_dout(io_dout),

        .ram_rom_addr(ram_rom_addr),
        .ram_rom_din(ram_rom_din),
        .ram_rom_dout(ram_rom_dout),
        
        .ram_rom_rd(ram_rom_rd),
        .ram_rom_wr(ram_rom_wr),
        .ram_rom_busy(ram_rom_busy),

        .vram_addr(vram_addr),
        .vram_din(vram_din),
        .vram_fonts_dout(vram_fonts_dout),
        .vram_characters_dout(vram_characters_dout),
        .vram_colors_dout(vram_colors_dout),
        .vram_fonts_we(vram_fonts_we),
        .vram_characters_we(vram_characters_we),
        .vram_colors_we(vram_colors_we),

        .rom_remap(rom_remap),
        .cardridge_bank_addr(cardridge_bank_addr),
        .cardridge_no(cardridge_no),

        .ext_ram_rom_req(ext_ram_rom_req),
        .ext_ram_rom_rd(ext_ram_rom_rd),
        .ext_ram_rom_wr(ext_ram_rom_wr),
        .ext_ram_rom_addr(ext_ram_rom_addr),
        .ext_ram_rom_din(ext_ram_rom_din),
        .ext_ram_rom_dout(ext_ram_rom_dout),
        .ext_ram_rom_busy(ext_ram_rom_busy),

        .cobra_color_enable(cobra_color_enable),
        .cobra_dual_ram_enable(cobra_dual_ram_enable)
    );

    //----------------------------------------------------------------------------
    // ROM LOADER
    //----------------------------------------------------------------------------

    wire rom_loder_error;

    rom_loader rom_loader_Inst (
        .clk(clk_27M),
        .reset_n(infra_reset_n),
         
        .key_switch_rom(key_switch_rom),
        .usb_key1(usb_key1),

        .end_copy(rom_loder_end_copy),
        .error(rom_loder_error),
            
        .ram_rom_req(ext_ram_rom_req),
        .ram_rom_wr(ext_ram_rom_wr),
        .ram_rom_addr(ext_ram_rom_addr),
        .ram_rom_din(ext_ram_rom_din),
        .ram_rom_busy(ext_ram_rom_busy),

        .font_psram_wr_pulse(font_psram_wr_pulse),
        .font_psram_wr_addr(font_psram_wr_addr),
        .font_psram_wr_data(font_psram_wr_data),
        .font_psram_ready(font_psram_ready),

        .spi_flash_cs_n(spi_flash_cs_n),
        .spi_flash_sclk(spi_flash_sclk),
        .spi_flash_mosi(spi_flash_mosi),
        .spi_flash_miso(spi_flash_miso),

        .cobra_dual_ram_enable(cobra_dual_ram_enable),
        .cobra_color_enable(cobra_color_enable),
        .cardridge_no(cardridge_no)
    );

    //----------------------------------------------------------------------------
    // DIAGNOSTYKA (LED & TIMERS)
    //----------------------------------------------------------------------------

    reg [19:0] cpu_iorq_timer;
    reg [19:0] cpu_mreq_timer;
    always @(posedge clk_cpu or negedge cpu_reset_n) begin
        if (!cpu_reset_n) begin
            cpu_iorq_timer <= 0; 
            cpu_mreq_timer <= 0;
        end else begin
            if (!cpu_iorq_n) cpu_iorq_timer <= 20'hFFFFF;
            else if (cpu_iorq_timer > 0) cpu_iorq_timer <= cpu_iorq_timer - 1;

            if (!cpu_mreq_n) cpu_mreq_timer <= 20'hFFFFF;
            else if (cpu_mreq_timer > 0) cpu_mreq_timer <= cpu_mreq_timer - 1;
        end
    end

    reg [22:0] heartbeat;
    always @(posedge clk_cpu) heartbeat <= heartbeat + 1'b1;

    assign led[0] = cpu_reset_n;
    assign led[1] = !ram_rom_error;
    assign led[2] = !rom_loder_error;
    assign led[3] = !(cpu_iorq_timer > 0);  // Mruga przy dostępie do I/O
    assign led[4] = !(cpu_mreq_timer > 0);  // Mruga przy dostępie do Pamięci
    assign led[5] = !heartbeat[22];     // Heartbeat

endmodule

`default_nettype wire
