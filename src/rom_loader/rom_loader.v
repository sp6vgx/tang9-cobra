//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// ROM Loader
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************

`timescale 1ns/1ps
`default_nettype none

module rom_loader (
    input   wire        clk,
    input   wire        reset_n,

    input   wire        key_switch_rom,
    input   wire [7:0]  usb_key1,

    output  reg         end_copy,
    output  reg         error,

    // SPI Flash (Puya P25Q32U)
    output  reg         spi_flash_cs_n,
    output  reg         spi_flash_sclk,
    output  reg         spi_flash_mosi,
    input   wire        spi_flash_miso,

    // 8-bit PSRAM dla cartridge'ów
    output  reg         ram_rom_req,
    output  reg         ram_rom_wr,
    output  reg [21:0]  ram_rom_addr,
    output  reg [7:0]   ram_rom_din,
    input   wire        ram_rom_busy,

    // 16-bit PSRAM dla ROM-u ze znakami
    output  reg         font_psram_wr_pulse,
    output  reg [21:0]  font_psram_wr_addr,
    output  reg [15:0]  font_psram_wr_data,
    input   wire        font_psram_ready,

    output  reg         cobra_dual_ram_enable,
    output  reg         cobra_color_enable,
    output  reg [2:0]   cardridge_no
);

    localparam [31:0] MAGIC                 = 32'h434F4252; // COBR
    localparam [23:0] HEADER_SIZE           = 24'd16;
    localparam [23:0] FLASH_START_ADDR      = 24'h000000;
    localparam [21:0] RAM_ROM_START_ADDR    = 22'h00C000;

    localparam [7:0] HID_F11   = 8'h44;
    localparam [7:0] HID_F12   = 8'h45;

    reg [4:0] state;

    reg [8:0] bit_cnt;
    reg [7:0] rx_shift;
    reg [23:0] tx_shift;
    reg [23:0] flash_byte_cnt;
    
    reg [7:0] rx_byte;
    reg [7:0] prev_rx_byte;
    reg [127:0] header_reg;
    reg [23:0] rom_size;
    reg [23:0] font_size;

    reg [7:0] number_of_roms;
    reg [2:0] current_rom;
    reg [7:0] rom_info;

    localparam
        S_INIT                  = 0,
        S_WAIT                  = 1,
        S_SPI_CMD               = 2,
        S_SPI_ADDR              = 3,
        S_SPI_READ_BYTE         = 4,
        S_READ_FLASH            = 5,
        S_WRITE_ROM             = 6,
        S_WRITE_ROM_WAIT        = 7,
        S_WRITE_FONT            = 8,
        S_WRITE_FONT_WAIT       = 9,
        S_GET_ROM_INFO          = 10,
        S_INIT_COBRA            = 11,
        S_RUN_COBRA             = 12,
        S_WAIT_KEY              = 13,
        S_CHANGE_ROM            = 14,
        S_COBRA_RESET           = 15,
        S_PARSE_HEADER          = 16,
        S_READ_ERROR            = 17;

    //----------------------------------------------------------------------------
    // Synchronizacja
    //----------------------------------------------------------------------------

    reg [1:0] font_psram_ready_sync;
    reg [1:0] ram_rom_busy_sync;
    reg [1:0] key_switch_rom_sync;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            font_psram_ready_sync <= 2'b00;
            ram_rom_busy_sync <= 2'b00;
            key_switch_rom_sync <=2'b11;
        end else begin
            font_psram_ready_sync <= {font_psram_ready_sync[0], font_psram_ready};
            
            ram_rom_busy_sync <= {ram_rom_busy_sync[0], ram_rom_busy};
            
            key_switch_rom_sync <= {key_switch_rom_sync[0], key_switch_rom};            
        end
    end

    //----------------------------------------------------------------------------
    // Logika loadera i przełączania ROM
    //----------------------------------------------------------------------------

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= S_INIT;
            spi_flash_cs_n <= 1'b1;
            spi_flash_sclk <= 1'b0;
            spi_flash_mosi <= 1'b0;
            ram_rom_req <= 1'b1;
            ram_rom_wr <= 1'b0;
            font_psram_wr_pulse <= 1'b0;
            flash_byte_cnt <= 24'h00;
            bit_cnt <= 0;
            header_reg <= 128'h00;
            rom_size <= 24'h00;
            font_size <= 24'h00;
            number_of_roms <= 3'd0;
            end_copy <= 1'b0;
            error <= 1'b0;
            cobra_dual_ram_enable <= 1'b0;
            cobra_color_enable <= 1'b1;
            cardridge_no <= 3'd0;
            current_rom <= 3'd0;
        end
        else begin
            font_psram_wr_pulse <= 1'b0;

            case (state)
                
                S_INIT: begin
                    ram_rom_req <= 1;
                    spi_flash_cs_n <= 1;
                    flash_byte_cnt <= 24'h00;
                    state <= S_WAIT;
                end

                S_WAIT: begin
                if (!ram_rom_busy_sync[1])
                    state <= S_SPI_CMD;
                end

                S_SPI_CMD: begin
                    spi_flash_cs_n <= 0;
                    if (bit_cnt == 0) begin
                        tx_shift[23-:8] <= 8'h03; // Cmd Read
                        bit_cnt <= 8;
                    end else begin
                        spi_flash_sclk <= ~spi_flash_sclk;

                        if (spi_flash_sclk == 0) begin
                            spi_flash_mosi <= tx_shift[23];
                            tx_shift <= {tx_shift[22:0], 1'b0};
                            bit_cnt <= bit_cnt - 1;
                            if (bit_cnt == 1) state <= S_SPI_ADDR;
                        end
                    end 
                end

                S_SPI_ADDR: begin
                    if (bit_cnt == 0) begin
                        tx_shift <= FLASH_START_ADDR;
                        bit_cnt <= 24;
                    end else begin
                        spi_flash_sclk <= ~spi_flash_sclk;

                        if (spi_flash_sclk == 0) begin
                            spi_flash_mosi <= tx_shift[23];
                            tx_shift <= {tx_shift[22:0], 1'b0};
                            bit_cnt <= bit_cnt - 1;
                            if (bit_cnt == 1) begin
                                bit_cnt <= 8;
                                state <= S_SPI_READ_BYTE;
                            end
                        end
                    end
                end
                
                S_SPI_READ_BYTE: begin
                    spi_flash_sclk <= ~spi_flash_sclk;

                    if (spi_flash_sclk == 0) begin
                        rx_shift <= {rx_shift[6:0], spi_flash_miso};
                        bit_cnt <= bit_cnt - 1;

                        if (bit_cnt == 1) begin
                            flash_byte_cnt <= flash_byte_cnt + 1;
                            rx_byte <= {rx_shift[6:0], spi_flash_miso};
                            state <= S_READ_FLASH;
                        end
                    end
                end

                S_READ_FLASH: begin
                    if (flash_byte_cnt < HEADER_SIZE + 1) begin  // Header
                        header_reg <= {header_reg[119:0], rx_byte};
                        if (flash_byte_cnt == HEADER_SIZE) begin
                            state <= S_PARSE_HEADER;
                        end else begin
                            bit_cnt <= 8;
                            state <= S_SPI_READ_BYTE;
                        end
                    end else begin
                        if (flash_byte_cnt <= (rom_size + HEADER_SIZE)) begin // Copy ROMs
                            state <= S_WRITE_ROM;
                        end else if (flash_byte_cnt <= (font_size + rom_size + HEADER_SIZE)) begin // Copy Fonts
                            if ((flash_byte_cnt - 1) % 2) begin                                
                                state <= S_WRITE_FONT;
                            end else begin
                                prev_rx_byte <= rx_byte;
                                bit_cnt <= 8;
                                state <= S_SPI_READ_BYTE;
                            end
                        end else begin
                            state <= S_GET_ROM_INFO;
                        end
                    end
                end

                S_WRITE_ROM: begin
                    ram_rom_addr <= RAM_ROM_START_ADDR + ((flash_byte_cnt - HEADER_SIZE) - 1);
                    ram_rom_din <= rx_byte;
                    ram_rom_wr <= 1;
                    if (ram_rom_busy_sync[1]) begin
                        state <= S_WRITE_ROM_WAIT;
                    end
                end

                S_WRITE_ROM_WAIT: begin
                    if (!ram_rom_busy) begin
                        ram_rom_wr <= 0;
                        bit_cnt <= 8;
                        state <= S_SPI_READ_BYTE;
                    end        
                end
                
                S_WRITE_FONT: begin
                    if (font_psram_ready_sync[1]) begin
                        font_psram_wr_addr <=(flash_byte_cnt - (rom_size + HEADER_SIZE)) - 2;
                        font_psram_wr_data <= {rx_byte , prev_rx_byte};
                        font_psram_wr_pulse <= 1'b1;
                        state <= S_WRITE_FONT_WAIT;
                    end
                end

                S_WRITE_FONT_WAIT: begin
                    if (font_psram_ready_sync[1]) begin
                        bit_cnt <= 8;
                        state <= S_SPI_READ_BYTE;                        
                    end
                end

                S_GET_ROM_INFO: begin
                    rom_info = header_reg[55 - (current_rom * 8) -: 8];
                    cobra_color_enable <= 1'b0;
                    cobra_dual_ram_enable <= 1'b0;
                    flash_byte_cnt <= 24'h00;
                    state <= S_INIT_COBRA;
                end

                S_INIT_COBRA: begin
                    // Clear RAM
                    if (flash_byte_cnt == 0) begin
                        if (!ram_rom_busy_sync[1]) begin
                            ram_rom_din <= 0;
                            ram_rom_addr <= 0;
                            ram_rom_wr <= 1;
                            flash_byte_cnt <= 1;
                        end
                    end else if(ram_rom_wr && ram_rom_busy_sync[1]) begin
                         ram_rom_wr <= 0;
                    end else if (!ram_rom_wr && !ram_rom_busy_sync[1]) begin 
                        if (flash_byte_cnt < RAM_ROM_START_ADDR) begin
                            ram_rom_addr <= flash_byte_cnt;
                            ram_rom_din <= 0;
                            ram_rom_wr <= 1;
                            flash_byte_cnt <= flash_byte_cnt + 1;
                        end else begin
                            if (rom_info[0])
                                cobra_color_enable <= 1'b1;
                            if (rom_info[1])
                                cobra_dual_ram_enable <= 1'b1;
                            state <= S_RUN_COBRA;
                        end
                    end
                end

                S_RUN_COBRA: begin
                    cardridge_no <= current_rom[2:0];
                    ram_rom_req <= 1'b0;
                    end_copy <= 1'b1;
                    state <= S_WAIT_KEY;
                end

                S_WAIT_KEY: begin
                    if (!key_switch_rom_sync[1] || usb_key1 == HID_F11) begin
                        state <= S_CHANGE_ROM;
                    end else if (usb_key1 == HID_F12) begin
                        state <= S_COBRA_RESET;                    
                    end
                end

                S_CHANGE_ROM: begin
                    if (key_switch_rom_sync[1] && usb_key1 != HID_F11) begin
                        ram_rom_req <= 1'b1;
                        end_copy <= 1'b0;
                        if (current_rom + 1 >= number_of_roms) begin
                            current_rom <= 0;
                        end else begin
                            current_rom <= current_rom + 1;
                        end 
                        flash_byte_cnt <= 24'h00;
                        state <= S_GET_ROM_INFO;
                    end
                end

                S_COBRA_RESET: begin
                    if (usb_key1 != HID_F12) begin
                        ram_rom_req <= 1'b1;
                        end_copy <= 1'b0;
                        flash_byte_cnt <= 24'h00;
                        state <= S_GET_ROM_INFO;
                    end
                end

                S_PARSE_HEADER: begin
                    if (header_reg[127:96] == MAGIC && header_reg[95:88] > 8'd0 && header_reg[95:88] < 8'd7) begin
                        number_of_roms <= header_reg[95:88];
                        rom_size <= (header_reg[95:88] << 19);
                        font_size <= {header_reg[71:64] , header_reg[79:72] , header_reg[87:80]};  
                        bit_cnt <= 8;
                        state <= S_SPI_READ_BYTE;
                    end else begin
                        state <= S_READ_ERROR;
                    end
                end
               
                S_READ_ERROR: begin
                    error <= 1'b1;
                end

            endcase
        end
    end

endmodule

`default_nettype wire
