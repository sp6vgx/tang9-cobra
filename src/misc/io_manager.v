// ************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// IO Manager
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************


`timescale 1ns/1ps
`default_nettype none

module io_manager (
    // Z80
    input   wire        clk_cpu,
    input   wire        cpu_reset_n,
    input   wire [15:0] cpu_addr,
    input   wire [7:0]  cpu_dout,
    input   wire        cpu_iorq_n,
    input   wire        cpu_rd_n,
    input   wire        cpu_wr_n,

    // Klawiatura
    input   wire [6:0]  keyboard_data,

    // Tape
    input   wire        tape_in_data,
    input   wire        tape_in_data_n,

    // IO Data Out
    output  reg [7:0]   io_dout,

    output  reg         rom_remap,
    output  reg         tape_out_data,
    output  reg         beep_enable,
    output  reg         katarynka_clk1,
    output  reg         katarynka_clk2,
    output  reg         katarynka_data,
    output  reg [4:0]   cardridge_bank_addr,
    output  reg [7:0]   font_bank_addr
);



    always @(posedge clk_cpu or negedge cpu_reset_n) begin
        if (!cpu_reset_n) begin 
            rom_remap <= 1'b1;
            tape_out_data <= 1'b0;
            katarynka_clk1 <= 1'b0;
            katarynka_clk2 <= 1'b0;
            katarynka_data <= 1'b0;
            beep_enable <= 1'b0;
            cardridge_bank_addr <= 5'h00;
            font_bank_addr <= 8'h00;
        end else begin

            io_dout <= 8'hff;
            tape_out_data <= 1'b0;
            beep_enable <= 1'b0;
            katarynka_clk1 <= 1'b0;
            katarynka_clk2 <= 1'b0;

            if (!cpu_iorq_n && !cpu_rd_n && cpu_addr[7]) begin // IO Read
                io_dout <= {tape_in_data, tape_in_data_n, 1'b1, keyboard_data[4:0]};
            end 
            else if (!cpu_iorq_n && !cpu_wr_n && !cpu_addr[7]) begin // IO Write 
                case (cpu_addr[4:2])

                    // Port 00h (Katarynka 1)
                    3'd0: begin
                        katarynka_clk1 <= 1'b1;
                        katarynka_data <= cpu_dout[0];
                    end
                    
                    // Port 00h (Katarynka 2)
                    3'd2: begin
                        katarynka_clk2 <= 1'b1;
                        katarynka_data <= cpu_dout[0];
                    end

                    // Port 0Ch (D0-D6 Addr Gen... D7 Enable VRAM - Cobra Dual RAM)
                    3'd3: begin
                        font_bank_addr <= cpu_dout;
                    end

                    // Port 10h (Cardridge Memory Switch)
                    3'd4: begin
                        cardridge_bank_addr <= cpu_dout[4:0];
                    end

                    // Port 18h (Beep)
                    3'd6: begin
                        beep_enable <= 1'b1;
                    end

                    // Port 1Ch (Tape/Remap)
                    3'd7: begin
                        rom_remap <= 1'b0;
                        tape_out_data <= 1'b1;
                    end

                endcase            
            end            
        end
    end

endmodule

`default_nettype wire
