//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// Video & Audio HDMI Out
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************


`timescale 1ns/1ps
`default_nettype none

module audio_video_hdmi_out (
    input   wire                clk_pixel,       // 74.25 MHz
    input   wire                clk_pixel_x5,    // 371.25 MHz
    input   wire                clk_audio,
    input   wire                reset_n,

    // Z80
    input   wire                clk_cpu,
    input   wire                cpu_reset_n,

    // VRAM
    input   wire [10:0]         vram_addr,
    input   wire [7:0]          vram_din,
    output  wire [7:0]          vram_fonts_dout,
    output  wire [7:0]          vram_characters_dout,
    output  wire [7:0]          vram_colors_dout,
    input   wire                vram_fonts_we,
    input   wire                vram_characters_we,
    input   wire                vram_colors_we,

    // Pasy przy wczytywaniu z tasmy
    input   wire                tape_mig,
    
    // Audio PCM
    input   wire signed [15:0]  audio_pcm_l,
    input   wire signed [15:0]  audio_pcm_r,

    // Fonts
    output  wire [10:0]         font_addr,
    input   wire [7:0]          font_data,
    input   wire                use_font_vram,
    
    // Video & Audio Out Ready
    output  reg                 ready,

    // Cobra Moede
    input   wire                cobra_dual_ram_enable,

    // HDMI/TMDS Signals
    output  wire                tmds_clk_n,
    output  wire                tmds_clk_p,
    output  wire [2:0]          tmds_data_n,
    output  wire [2:0]          tmds_data_p  
);

    // Sygnały z wnętrza HDMI IP
    wire [11:0] cx, cy;
    wire [11:0] screen_w, screen_h;
    wire [23:0] pixelRGB;

    // --- Instancja HDMI (hdl-util/hdmi) ---
    wire [2:0] tmds_internal;
    wire tmds_clock_internal;

    hdmi #(
        .VENDOR_NAME( {"SP6VGX", 16'd0} ),
        .PRODUCT_DESCRIPTION( {"COBRA1", 80'd0} ),
        .SOURCE_DEVICE_INFORMATION(9),
        
        .VIDEO_ID_CODE(4),          // 720p (1280x720)
        .IT_CONTENT(1'b1),
        .AUDIO_RATE(48000),         // Audio PCM 48kHz
        .AUDIO_BIT_WIDTH(16),
        .START_X(0),
        .START_Y(0)
    ) hdmi_inst (
        .clk_pixel_x5(clk_pixel_x5),
        .clk_pixel(clk_pixel),
        .clk_audio(clk_audio),
        .reset(!reset_n),
        .rgb(pixelRGB),
        .audio_sample_word('{audio_pcm_l, audio_pcm_r}),
        
        .tmds(tmds_internal),
        .tmds_clock(tmds_clock_internal),
        
        // Wyjścia współrzędnych
        .cx(cx), 
        .cy(cy),
        .screen_width(screen_w),
        .screen_height(screen_h)
    );

    //----------------------------------------------------------------------------
    // VIDEO RAM
    //----------------------------------------------------------------------------

    wire [7:0] hdmi_vram_fonts_dout;
    wire hdmi_vram_fonts_we;

    // VRAM FONTS 2K - Fonty F000 - F7FF (Cobra Dual RAM)
    Gowin_DPB_2K vram_fonts_Inst (
        .clka(clk_cpu),
        .reseta(!cpu_reset_n),
        .ada(vram_addr),
        .dina(vram_din),
        .douta(vram_fonts_dout),
        .ocea(1'b1),
        .cea(1'b1),
        .wrea(vram_fonts_we),

        .clkb(clk_pixel),
        .resetb(!reset_n),
        .adb(font_addr),
        .doutb(hdmi_vram_fonts_dout),
        .oceb(1'b1),
        .ceb(1'b1),
        .wreb(hdmi_vram_fonts_we)
    );

    // VRAM CHARACTERS 1K - Znaki F800 - FBFF
    wire [7:0] hdmi_vram_characters_dout;
    wire [9:0] hdmi_vram_characters_addr;

    Gowin_DPB_1K vram_characters_Inst (
        .clka(clk_cpu),
        .reseta(!cpu_reset_n),
        .ada(vram_addr[9:0]),
        .dina(vram_din),
        .douta(vram_characters_dout),
        .ocea(1'b1),
        .cea(1'b1),
        .wrea(vram_characters_we),

        .clkb(clk_pixel),
        .resetb(!reset_n),
        .adb(hdmi_vram_characters_addr),
        .doutb(hdmi_vram_characters_dout),
        .oceb(1'b1),
        .ceb(1'b1),
        .wreb(1'b0)
    );

    // VRAM COLORS 1K - Kolory FC00 - FFFF
    wire [7:0] hdmi_vram_colors_dout;
    wire [7:0] hdmi_vram_colors_din;
    wire [9:0] hdmi_vram_colors_addr;
    wire hdmi_vram_colors_we;

    Gowin_DPB_1K vram_colors_Inst (
        .clka(clk_cpu),
        .reseta(!cpu_reset_n),
        .ada(vram_addr[9:0]),
        .dina(vram_din),
        .douta(vram_colors_dout),
        .ocea(1'b1),
        .cea(1'b1),
        .wrea(vram_colors_we),

        .clkb(clk_pixel),
        .resetb(!reset_n),
        .adb(hdmi_vram_colors_addr),
        .dinb(hdmi_vram_colors_din),
        .doutb(hdmi_vram_colors_dout),
        .oceb(1'b1),
        .ceb(1'b1),
        .wreb(hdmi_vram_colors_we)
    );

    //----------------------------------------------------------------------------
    // LOGIKA UPSCALERA
    //----------------------------------------------------------------------------

    // --- 768x576 wewnątrz 1280x720 ---  
    // Obliczamy ramkę (Offsety: H=256, V=72)
    // Używamy bezpośrednio cx i cy dostarczonych przez IP
    // Offset CX -2px (opoznienie Pipeline)
    wire in_cobra_area = (cx >= 254 && cx < 254 + 768) && 
                         (cy >= 72  && cy < 72  + 576);

    wire [11:0] cobra_x_rel = in_cobra_area ? (cx - 254) : 12'd0;
    wire [11:0] cobra_y_rel = in_cobra_area ? (cy - 72)  : 12'd0;

    // Dzielenie przez 3 (Upscale x3)
    wire [7:0] cobraX = cobra_x_rel / 3;
    wire [7:0] cobraY = cobra_y_rel / 3;

    // --- Adresowanie Pamięci (VRAM i Font) ---
    assign hdmi_vram_characters_addr = (cobraX >> 3) + ((cobraY >> 3) << 5);

    //----------------------------------------------------------------------------
    // INICJALIZACJA VRAM COLORS - ZGODNOSC Z COBRA 1
    //----------------------------------------------------------------------------
    reg [9:0] init_counter;
    reg init_active;
    
    assign hdmi_vram_colors_addr = init_active ? init_counter : hdmi_vram_characters_addr;
    assign hdmi_vram_colors_we = init_active;
    assign hdmi_vram_colors_din = 8'h0F;  // Paper=0 (czarny), Ink=F (biały) - dla widoczności znaków w Cobra 1

    always @(posedge clk_pixel or negedge reset_n) begin
        if (!reset_n) begin
            init_counter <= 11'd0;
            init_active <= 1'b1;
            ready <= 1'b0;
        end else begin
            if (init_active) begin
                if (init_counter == 11'd1023) begin  // 1024 adresy (0-1023)
                    init_active <= 1'b0;
                    ready <= 1'b1;
                end else begin
                    init_counter <= init_counter + 11'd1;
                end
            end
        end
    end

    //----------------------------------------------------------------------------
    // PALETA KOLORÓW COBRA KOLOR
    //----------------------------------------------------------------------------

    function [23:0] cobra_to_rgb(input [3:0] c);
        case (c)
            4'h0: cobra_to_rgb = 24'h000000; 4'h1: cobra_to_rgb = 24'h000080;
            4'h2: cobra_to_rgb = 24'h800000; 4'h3: cobra_to_rgb = 24'h800080;
            4'h4: cobra_to_rgb = 24'h008000; 4'h5: cobra_to_rgb = 24'h008080;
            4'h6: cobra_to_rgb = 24'h808000; 4'h7: cobra_to_rgb = 24'h808080;
            4'h8: cobra_to_rgb = 24'h000000; 4'h9: cobra_to_rgb = 24'h0000FF;
            4'hA: cobra_to_rgb = 24'hFF0000; 4'hB: cobra_to_rgb = 24'hFF00FF;
            4'hC: cobra_to_rgb = 24'h00FF00; 4'hD: cobra_to_rgb = 24'h00FFFF;
            4'hE: cobra_to_rgb = 24'hFFFF00; 4'hF: cobra_to_rgb = 24'hFFFFFF;
        endcase
    endfunction

    //----------------------------------------------------------------------------
    // GENEROWANIE OBRAZU
    //----------------------------------------------------------------------------

    // --- Pipeline / Synchronizacja ---
    // Musimy opóźnić wybór bitu, bo font_pixels przychodzi z opóźnieniem względem cx
    
    reg [1:0] in_cobra_area_sync;
    reg [7:0] hdmi_vram_colors_dout_sync;
    reg [2:0] cobraX_meta;
    reg [2:0] cobraX_sync;
    
    always @(posedge clk_pixel or negedge reset_n) begin
        if (!reset_n) begin
            in_cobra_area_sync <= 2'b00;
            hdmi_vram_colors_dout_sync <= 8'h00;
            cobraX_meta <= 3'b00;
            cobraX_sync <= 3'b00;
        end else begin
            in_cobra_area_sync <= {in_cobra_area_sync[0], in_cobra_area};
            hdmi_vram_colors_dout_sync <= hdmi_vram_colors_dout;

            cobraX_meta <= cobraX[2:0];
            cobraX_sync <= cobraX_meta;

        end
    end

    reg [1:0] tape_mig_sync; 
    always @(posedge clk_pixel or negedge reset_n) begin
        if (!reset_n) begin
            tape_mig_sync <= 2'b00;
        end else begin
            tape_mig_sync <= {tape_mig_sync[0], tape_mig};
        end
    end

    reg [1:0] cobra_dual_ram_enable_sync; 
    always @(posedge clk_pixel or negedge reset_n) begin
        if (!reset_n) begin
            cobra_dual_ram_enable_sync <= 2'b00;
        end else begin
            cobra_dual_ram_enable_sync <= {cobra_dual_ram_enable_sync[0], cobra_dual_ram_enable};
        end
    end

    assign font_addr = {hdmi_vram_characters_dout, cobraY[2:0]};

    wire draw_ink = (cobra_dual_ram_enable_sync[1] && use_font_vram) ? hdmi_vram_fonts_dout[3'd7 - cobraX_sync] : font_data[3'd7 - cobraX_sync];

    wire [23:0] rgb_ink   = cobra_to_rgb(hdmi_vram_colors_dout_sync[3:0]);
    wire [23:0] rgb_paper = cobra_to_rgb(hdmi_vram_colors_dout_sync[7:4]);

    // Przypisanie koloru piksela
    assign pixelRGB = in_cobra_area_sync[1] ? 
                      (draw_ink ? rgb_ink : rgb_paper) : 
                      (tape_mig_sync[1] ? 24'h7f7F7F : 24'h000000);


    // --- Fizyczne bufory ELVDS ---
    ELVDS_OBUF tmds_bufds [3:0] (
        .I({tmds_clock_internal, tmds_internal}),
        .O({tmds_clk_p, tmds_data_p}),
        .OB({tmds_clk_n, tmds_data_n})
    );

endmodule

`default_nettype wire
