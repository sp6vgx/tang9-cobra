//************************************************************************************
// COBRA1 FPGA Tang Nano 9k
// USB Keyboard to Cobra Keyboard
//
// Copyright (c)2023 - 2026 ToM tomek@sp6vgx.pl 
//
// This software is licensed under the PolyForm Noncommercial License 1.0.0.
// You may only use this software for noncommercial purposes.
// Full license text: https://polyformproject.org
//************************************************************************************

`timescale 1ns/1ps
`default_nettype none

module keyboard_usb_to_cobra (
    // Z80
    input  wire        clk_cpu,
    input  wire [15:0] cpu_addr,

    // USB
    input  wire        clk_usb,
    input  wire [1:0]  usb_hid_type,
    input  wire [7:0]  key_modifiers,
    input  wire [7:0]  key1,
    input  wire [7:0]  key2,
    input  wire [7:0]  key3,
    input  wire [7:0]  key4,

    // Klawiatura
    output reg [6:0]  keyboard_data
);
    //----------------------------------------------------------------------------
    // USB HID Keyboard Usage IDs (Page 0x07) – najpopularniejsze klawisze
    //----------------------------------------------------------------------------

    localparam [7:0] HID_A     = 8'h04;
    localparam [7:0] HID_B     = 8'h05;
    localparam [7:0] HID_C     = 8'h06;
    localparam [7:0] HID_D     = 8'h07;
    localparam [7:0] HID_E     = 8'h08;
    localparam [7:0] HID_F     = 8'h09;
    localparam [7:0] HID_G     = 8'h0A;
    localparam [7:0] HID_H     = 8'h0B;
    localparam [7:0] HID_I     = 8'h0C;
    localparam [7:0] HID_J     = 8'h0D;
    localparam [7:0] HID_K     = 8'h0E;
    localparam [7:0] HID_L     = 8'h0F;
    localparam [7:0] HID_M     = 8'h10;
    localparam [7:0] HID_N     = 8'h11;
    localparam [7:0] HID_O     = 8'h12;
    localparam [7:0] HID_P     = 8'h13;
    localparam [7:0] HID_Q     = 8'h14;
    localparam [7:0] HID_R     = 8'h15;
    localparam [7:0] HID_S     = 8'h16;
    localparam [7:0] HID_T     = 8'h17;
    localparam [7:0] HID_U     = 8'h18;
    localparam [7:0] HID_V     = 8'h19;
    localparam [7:0] HID_W     = 8'h1A;
    localparam [7:0] HID_X     = 8'h1B;
    localparam [7:0] HID_Y     = 8'h1C;
    localparam [7:0] HID_Z     = 8'h1D;

    localparam [7:0] HID_1     = 8'h1E;   // 1 / !
    localparam [7:0] HID_2     = 8'h1F;   // 2 / @
    localparam [7:0] HID_3     = 8'h20;   // 3 / #
    localparam [7:0] HID_4     = 8'h21;   // 4 / $
    localparam [7:0] HID_5     = 8'h22;   // 5 / %
    localparam [7:0] HID_6     = 8'h23;   // 6 / ^
    localparam [7:0] HID_7     = 8'h24;   // 7 / &
    localparam [7:0] HID_8     = 8'h25;   // 8 / *
    localparam [7:0] HID_9     = 8'h26;   // 9 / (
    localparam [7:0] HID_0     = 8'h27;   // 0 / )

    localparam [7:0] HID_ENTER     = 8'h28;
    localparam [7:0] HID_ESC       = 8'h29;
    localparam [7:0] HID_BACKSPACE = 8'h2A;   // ← Backspace
    localparam [7:0] HID_TAB       = 8'h2B;
    localparam [7:0] HID_SPACE     = 8'h2C;   // Spacja
    localparam [7:0] HID_MINUS     = 8'h2D;   // - / _
    localparam [7:0] HID_EQUAL     = 8'h2E;   // = / +
    localparam [7:0] HID_LBRACKET  = 8'h2F;   // [ / {
    localparam [7:0] HID_RBRACKET  = 8'h30;   // ] / }
    localparam [7:0] HID_BSLASH    = 8'h31;   // \ / |   (US layout)
    localparam [7:0] HID_SEMICOLON = 8'h33;   // ; / :
    localparam [7:0] HID_QUOTE     = 8'h34;   // ' / "
    localparam [7:0] HID_TILDE     = 8'h35;   // ` / ~
    localparam [7:0] HID_COMMA     = 8'h36;   // , / <
    localparam [7:0] HID_PERIOD    = 8'h37;   // . / >
    localparam [7:0] HID_SLASH     = 8'h38;   // / / ?

    localparam [7:0] HID_F1    = 8'h3A;
    localparam [7:0] HID_F2    = 8'h3B;
    localparam [7:0] HID_F3    = 8'h3C;
    localparam [7:0] HID_F4    = 8'h3D;
    localparam [7:0] HID_F5    = 8'h3E;
    localparam [7:0] HID_F6    = 8'h3F;
    localparam [7:0] HID_F7    = 8'h40;
    localparam [7:0] HID_F8    = 8'h41;
    localparam [7:0] HID_F9    = 8'h42;
    localparam [7:0] HID_F10   = 8'h43;
    localparam [7:0] HID_F11   = 8'h44;
    localparam [7:0] HID_F12   = 8'h45;

    localparam [7:0] HID_INS      = 8'h49;
    localparam [7:0] HID_HOME     = 8'h4A;
    localparam [7:0] HID_PGUP     = 8'h4B;
    localparam [7:0] HID_DEL      = 8'h4C;
    localparam [7:0] HID_END      = 8'h4D;
    localparam [7:0] HID_PGDN     = 8'h4E;
    localparam [7:0] HID_RIGHT    = 8'h4F;
    localparam [7:0] HID_LEFT     = 8'h50;
    localparam [7:0] HID_DOWN     = 8'h51;
    localparam [7:0] HID_UP       = 8'h52;

    localparam [7:0] HID_ARROW_UP    = 8'h52;
    localparam [7:0] HID_ARROW_DOWN  = 8'h51;
    localparam [7:0] HID_ARROW_LEFT  = 8'h50;
    localparam [7:0] HID_ARROW_RIGHT = 8'h4F;

    //----------------------------------------------------------------------------
    // COBRA Keyboard
    //----------------------------------------------------------------------------

    localparam integer CKEY_A      = 20;    // A / ARROW LEFT 
    localparam integer CKEY_B      = 35;    // B / ? 
    localparam integer CKEY_C      = 33;    // C / ; 
    localparam integer CKEY_D      = 22;    // D 
    localparam integer CKEY_E      = 12;    // E 
    localparam integer CKEY_F      = 23;    // F 
    localparam integer CKEY_G      = 24;    // G 
    localparam integer CKEY_H      = 25;    // H / + 
    localparam integer CKEY_I      = 17;    // I / ] 
    localparam integer CKEY_J      = 26;    // J / - 
    localparam integer CKEY_K      = 27;    // K / * 
    localparam integer CKEY_L      = 28;    // L / / 
    localparam integer CKEY_M      = 37;    // M / >
    localparam integer CKEY_N      = 36;    // N / <
    localparam integer CKEY_O      = 18;    // O / ^ 
    localparam integer CKEY_P      = 19;    // P / CLS (Clear Screen)
    localparam integer CKEY_Q      = 10;    // Q / ARROW UP     
    localparam integer CKEY_R      = 13;    // R 
    localparam integer CKEY_S      = 21;    // S / ARROW RIGHT  
    localparam integer CKEY_T      = 14;    // T 
    localparam integer CKEY_U      = 16;    // U / [ 
    localparam integer CKEY_V      = 34;    // V / = 
    localparam integer CKEY_W      = 11;    // W / CTR (Semigrafic Char Mode ON)
    localparam integer CKEY_X      = 32;    // X / : 
    localparam integer CKEY_Y      = 15;    // Y / @ 
    localparam integer CKEY_Z      = 31;    // Z / ARROW DOWN 
    
    localparam integer CKEY_1      = 0;     // 1 / !
    localparam integer CKEY_2      = 1;     // 2 / "
    localparam integer CKEY_3      = 2;     // 3 / #
    localparam integer CKEY_4      = 3;     // 4 / $
    localparam integer CKEY_5      = 4;     // 5 / %
    localparam integer CKEY_6      = 5;     // 6 / &
    localparam integer CKEY_7      = 6;     // 7 / '
    localparam integer CKEY_8      = 7;     // 8 / (
    localparam integer CKEY_9      = 8;     // 9 / )
    localparam integer CKEY_0      = 9;     // 0

    localparam integer CKEY_CR     = 29;    // CR (ENTER) 
    localparam integer CKEY_SPACE  = 39;    // Spacja
    localparam integer CKEY_COMMA  = 38;    // , / . 

    localparam integer CKEY_SH     = 30;    // SH (SHIFT) 

    //----------------------------------------------------------------------------
    // SYNCHRONIZACJA 
    //----------------------------------------------------------------------------

    // Rejestry w domenie USB
    reg [1:0]  usb_hid_type_usb;
    reg [7:0]  key_modifiers_usb;
    reg [7:0]  key1_usb;

    always @(posedge clk_usb) begin
        usb_hid_type_usb  <= usb_hid_type;
        key_modifiers_usb <= key_modifiers;
        key1_usb          <= key1;
    end

    // Double synchronizer – do domeny CPU
    reg [1:0]  usb_hid_type_r1,  usb_hid_type_r2;
    reg [7:0]  key_modifiers_r1, key_modifiers_r2;
    reg [7:0]  key1_r1, key1_r2;

    always @(posedge clk_cpu) begin
        // etap 1
        usb_hid_type_r1   <= usb_hid_type_usb;
        key_modifiers_r1  <= key_modifiers_usb;
        key1_r1           <= key1_usb;

        // etap 2 – te wartości są już bezpieczne do użycia
        usb_hid_type_r2   <= usb_hid_type_r1;
        key_modifiers_r2  <= key_modifiers_r1;
        key1_r2           <= key1_r1;
    end

    // Używamy zsynchronizowanych sygnałów
    wire [1:0]  hid_type   = usb_hid_type_r2;
    wire [7:0]  modifiers  = key_modifiers_r2;
    wire [7:0]  k1 = key1_r2;

    //----------------------------------------------------------------------------
    // Klawisze Shift, Alt itd.  
    //----------------------------------------------------------------------------

    wire left_shift   = key_modifiers[1];
    wire right_shift  = key_modifiers[5];
    wire any_shift    = key_modifiers[1] | key_modifiers[5];

    wire left_ctrl    = key_modifiers[0];
    wire right_ctrl   = key_modifiers[4];
    wire any_ctrl     = key_modifiers[0] | key_modifiers[4];

    wire left_alt     = key_modifiers[2];
    wire right_alt    = key_modifiers[6];
    wire any_alt      = key_modifiers[2] | key_modifiers[6];

    wire left_win     = key_modifiers[3];
    wire right_win    = key_modifiers[7];

    //----------------------------------------------------------------------------
    // Logika dekodowania klawiatury Cobra 
    //----------------------------------------------------------------------------

    reg [39:0] cobraKey;

    always @(posedge clk_cpu) begin
            
            cobraKey = 40'hffff_ffff_ff;
            
            if (hid_type == 2'd1) begin
                if (any_shift) begin // Shift + Key
                    case (k1)
                    
                        // !
                        HID_1: begin
                            cobraKey[CKEY_1] = 0; 
                            cobraKey[CKEY_SH] = 0;
                        end

                        // @
                        HID_2: begin
                            cobraKey[CKEY_Y] = 0; 
                            cobraKey[CKEY_SH] = 0;
                        end
                        
                        // #
                        HID_3: begin
                            cobraKey[CKEY_3] = 0; 
                            cobraKey[CKEY_SH] = 0;
                        end

                        // $
                        HID_4: begin
                            cobraKey[CKEY_4] = 0; 
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // %
                        HID_5: begin    
                            cobraKey[CKEY_5] = 0; 
                            cobraKey[CKEY_SH] = 0;
                        end

                        // &
                        HID_7: begin 
                            cobraKey[CKEY_6] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // *
                        HID_8: begin 
                            cobraKey[CKEY_K] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // (
                        HID_9: begin
                            cobraKey[CKEY_8] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // )
                        HID_0: begin
                            cobraKey[CKEY_9] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // ARROW LEFT
                        HID_A: begin
                            cobraKey[CKEY_A] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // B
                        HID_B: begin
                            cobraKey[CKEY_B] = 0;
                        end

                        // C
                        HID_C: begin
                            cobraKey[CKEY_C] = 0;
                        end

                        // D
                        HID_D: begin
                            cobraKey[CKEY_D] = 0;
                        end

                        // E
                        HID_E: begin
                            cobraKey[CKEY_E] = 0;
                        end

                        // F
                        HID_F: begin
                            cobraKey[CKEY_F] = 0;
                        end

                        // G
                        HID_G: begin 
                            cobraKey[CKEY_G] = 0;
                        end

                        // H
                        HID_H: begin
                            cobraKey[CKEY_H] = 0;
                        end

                        // I
                        HID_I: begin
                            cobraKey[CKEY_I] = 0;
                        end
                        
                        // J
                        HID_J: begin
                            cobraKey[CKEY_J] = 0;
                        end

                        // K
                        HID_K: begin
                            cobraKey[CKEY_K] = 0;
                        end

                        // L
                        HID_L: begin 
                            cobraKey[CKEY_L] = 0;
                        end

                        // M
                        HID_M: begin 
                            cobraKey[CKEY_M] = 0;
                        end

                        // N
                        HID_F: begin
                            cobraKey[CKEY_N] = 0;
                        end

                        // ^
                        HID_6: begin
                            cobraKey[CKEY_O] = 0; 
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // CLS
                        HID_P: begin 
                            cobraKey[CKEY_P] = 0; 
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // ARROW_UP
                        HID_Q: begin
                            cobraKey[CKEY_Q] = 0; 
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // R
                        HID_F: begin 
                            cobraKey[CKEY_R] = 0;
                        end

                        // ARROW RIGHT
                        HID_S: begin 
                            cobraKey[CKEY_S] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // T
                        HID_T: begin 
                            cobraKey[CKEY_T] = 0;
                        end

                        // U
                        HID_U: begin 
                            cobraKey[CKEY_U] = 0;
                        end

                        // V
                        HID_V: begin
                            cobraKey[CKEY_V] = 0;
                        end

                        // CTR
                        HID_W: begin 
                            cobraKey[CKEY_W] = 0;
                            cobraKey[CKEY_SH] = 0;
                        end

                        // X
                        HID_X: begin 
                            cobraKey[CKEY_X] = 0;
                        end

                        // Y
                        HID_Y: begin 
                            cobraKey[CKEY_Y]  = 0;
                        end

                        // ARROW DOWN
                        HID_Z: begin 
                            cobraKey[CKEY_Z] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // +
                        HID_EQUAL: begin
                            cobraKey[CKEY_H] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // :
                        HID_SEMICOLON: begin
                            cobraKey[CKEY_X] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // "
                        HID_QUOTE: begin 
                            cobraKey[CKEY_2] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end
    
                        // <
                        HID_COMMA: begin 
                            cobraKey[CKEY_N] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // >
                        HID_PERIOD: begin 
                            cobraKey[CKEY_M] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // ?
                        HID_SLASH: begin 
                            cobraKey[CKEY_B] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // Spacja
                        HID_SPACE: begin 
                            cobraKey[CKEY_SPACE] = 0;
                        end

                        // CR
                        HID_ENTER: begin
                            cobraKey[CKEY_CR] = 0;
                            cobraKey[CKEY_SH] = 0;
                        end

                    endcase
                end else begin
                    case (k1)

                        // 1
                        HID_1: begin 
                            cobraKey[CKEY_1] = 0;
                        end

                        // 2
                        HID_2: begin 
                            cobraKey[CKEY_2] = 0;
                        end

                        // 3
                        HID_3: begin 
                            cobraKey[CKEY_3] = 0;
                        end

                        // 4
                        HID_4: begin 
                            cobraKey[CKEY_4] = 0;
                        end

                        // 5
                        HID_5: begin 
                            cobraKey[CKEY_5] = 0;
                        end

                        // 6
                        HID_6: begin 
                            cobraKey[CKEY_6] = 0;
                        end

                        // 7
                        HID_7: begin 
                            cobraKey[CKEY_7] = 0;
                        end

                        // 8
                        HID_8: begin 
                            cobraKey[CKEY_8] = 0;
                        end

                        // 9
                        HID_9: begin 
                            cobraKey[CKEY_9] = 0;
                        end

                        // 0
                        HID_0: begin 
                            cobraKey[CKEY_0] = 0;
                        end

                        // A
                        HID_A: begin 
                            cobraKey[CKEY_A] = 0;
                        end

                        // B
                        HID_B: begin 
                            cobraKey[CKEY_B] = 0;
                        end

                        // C
                        HID_C: begin 
                            cobraKey[CKEY_C] = 0;
                        end

                        // D
                        HID_D: begin 
                            cobraKey[CKEY_D] = 0;
                        end

                        // E
                        HID_E: begin
                            cobraKey[CKEY_E] = 0;
                        end

                        // F
                        HID_F: begin 
                            cobraKey[CKEY_F] = 0;
                        end
    
                        // G
                        HID_G: begin 
                            cobraKey[CKEY_G] = 0;
                        end

                        // H
                        HID_H: begin 
                            cobraKey[CKEY_H] = 0;
                        end

                        // I
                        HID_I: begin 
                            cobraKey[CKEY_I] = 0;
                        end

                        // J
                        HID_J: begin 
                            cobraKey[CKEY_J] = 0;
                        end

                        // K
                        HID_K: begin 
                            cobraKey[CKEY_K] = 0;
                        end

                        // L
                        HID_L: begin 
                            cobraKey[CKEY_L] = 0;
                        end

                        // M
                        HID_M: begin 
                            cobraKey[CKEY_M] = 0;
                        end

                        // N
                        HID_N: begin 
                            cobraKey[CKEY_N] = 0;
                        end

                        // O
                        HID_O: begin 
                            cobraKey[CKEY_O] = 0;
                        end

                        // P
                        HID_P: begin 
                            cobraKey[CKEY_P] = 0;
                        end

                        // Q
                        HID_Q: begin 
                            cobraKey[CKEY_Q] = 0;
                        end

                        // R
                        HID_R: begin 
                            cobraKey[CKEY_R] = 0;
                        end

                        // S
                        HID_S: begin 
                            cobraKey[CKEY_S] = 0;
                        end
    
                        // T
                        HID_T: begin    
                            cobraKey[CKEY_T] = 0;
                        end

                        // U
                        HID_U: begin 
                            cobraKey[CKEY_U] = 0;
                        end

                        // V
                        HID_V: begin 
                            cobraKey[CKEY_V] = 0;
                        end

                        // W
                        HID_W: begin 
                            cobraKey[CKEY_W] = 0;
                        end

                        // X
                        HID_X: begin 
                            cobraKey[CKEY_X] = 0;
                        end

                        // Y
                        HID_Y: begin 
                            cobraKey[CKEY_Y] = 0;
                        end

                        // Z
                        HID_Z: begin 
                            cobraKey[CKEY_Z] = 0;
                        end

                        // -
                        HID_MINUS: begin
                            cobraKey[CKEY_J] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // =
                        HID_EQUAL: begin 
                            cobraKey[CKEY_V] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // [
                        HID_LBRACKET: begin 
                            cobraKey[CKEY_U] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // ]
                        HID_RBRACKET: begin 
                            cobraKey[CKEY_I] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // ;
                        HID_SEMICOLON: begin 
                            cobraKey[CKEY_C] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // '
                        HID_QUOTE: begin 
                            cobraKey[CKEY_7] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // ,
                        HID_COMMA: begin    
                            cobraKey[CKEY_COMMA] = 0;
                        end

                        // .
                        HID_PERIOD: begin
                            cobraKey[CKEY_COMMA] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end
                        // /
                        HID_SLASH: begin 
                            cobraKey[CKEY_L] = 0;
                            cobraKey[CKEY_SH] = 0; 
                        end

                        // Spacja
                        HID_SPACE: begin
                            cobraKey[CKEY_SPACE] = 0;
                        end

                        // CR
                        HID_ENTER: begin    
                            cobraKey[CKEY_CR] = 0;
                        end

                        // SH + CR
                        HID_ESC: begin
                            cobraKey[CKEY_SH] = 0; 
                            cobraKey[CKEY_CR] = 0;
                        end


                    endcase
                end
        end
           
            // |---------------------------------------------------------------------------|
            // |                        Matryca klawiatury COBRA 1                         |
            // +-----+---------+---------+---------+---------+---------+---------+---------+
            // |     |    D0   |    D1   |    D2   |    D3   |    D4   |    D5   |    D6   |              
            // +-----+---------+---------+---------+---------+---------+---------+---------+              
            // | A15 |  SPACE  |   , .   |   M >   |   N <   |   B ?   |         |         |
            // +-----+---------+---------+---------+---------+---------+---------+---------+ 
            // | A14 |   CR    |   L /   |   K *   |    j    |   H +   |         |         |
            // +-----+---------+---------+---------+---------+---------+---------+---------+             
            // | A13 |  P/CLS  |   O ^   |   I ]   |   U [   |   Y @   |         |         |
            // +-----+---------+---------+---------+---------+---------+---------+---------+ 
            // | A12 |    0    |   9 )   |   8 (   |   7 '   |   6 &   |         |         |
            // +-----+---------+---------+---------+---------+---------+---------+---------+ 
            // | A11 |   1 !   |   2 "   |   3 #   |   4 $   |   5 %   |         |         |
            // +-----+---------+---------+---------+---------+---------+---------+---------+ 
            // | A10 |  Q/UP   |  W/CTR  |    E    |    R    |    T    |         |         |
            // +-----+---------+---------+---------+---------+---------+---------+---------+ 
            // | A9  | A/LEFT  | S/RIGHT |    D    |    F    |    G    |         |         |
            // +-----+---------+---------+---------+---------+---------+---------+---------+ 
            // | A8  |  SHIFT  | Z/DOWN  |   X :   |   C ;   |   V =   |         |         |
            // +-----+---------+---------+---------+---------+---------+---------+---------+
            
            keyboard_data <= {

                  // D6 
                1'b1

                , // D5
                1'b1

                , // D4
                ((cpu_addr[15] | cobraKey[CKEY_B])      // B ?
                & (cpu_addr[14] | cobraKey[CKEY_H])     // H +
                & (cpu_addr[13] | cobraKey[CKEY_Y])     // Y @
                & (cpu_addr[12] | cobraKey[CKEY_6]))    // 6 &
                & (cpu_addr[11] | cobraKey[CKEY_5])     // 5 %
                & (cpu_addr[10] | cobraKey[CKEY_T])     // T
                & (cpu_addr[9] | cobraKey[CKEY_G])      // G
                & (cpu_addr[8] | cobraKey[CKEY_V])      // V =

                , // D3
                 ((cpu_addr[15] | cobraKey[CKEY_N])     // N <
                & (cpu_addr[14] | cobraKey[CKEY_J])     // J
                & (cpu_addr[13] | cobraKey[CKEY_U])     // U [
                & (cpu_addr[12] | cobraKey[CKEY_7]))    // 7 '
                & (cpu_addr[11] | cobraKey[CKEY_4])     // 4 $
                & (cpu_addr[10] | cobraKey[CKEY_R])     // R
                & (cpu_addr[9]  | cobraKey[CKEY_F])     // F
                & (cpu_addr[8] | cobraKey[CKEY_C])      // C ;

                , // D2
                 ((cpu_addr[15] | cobraKey[CKEY_M])     // M >
                & (cpu_addr[14] | cobraKey[CKEY_K])     // K *
                & (cpu_addr[13] | cobraKey[CKEY_I])     // I ]
                & (cpu_addr[12] | cobraKey[CKEY_8]))    // 8 (
                & (cpu_addr[11] | cobraKey[CKEY_3])     // 3 #
                & (cpu_addr[10] | cobraKey[CKEY_E])     // E
                & (cpu_addr[9] | cobraKey[CKEY_D])      // D
                & (cpu_addr[8] | cobraKey[CKEY_X])      // X :
                
                , // D1
                 ((cpu_addr[15] | cobraKey[CKEY_COMMA]) // , .
                & (cpu_addr[14] | cobraKey[CKEY_L])     // L /
                & (cpu_addr[13] | cobraKey[CKEY_O])     // O ^
                & (cpu_addr[12] | cobraKey[CKEY_9]))    // 9 )
                & (cpu_addr[11] | cobraKey[CKEY_2])     // 2 "
                & (cpu_addr[10] | cobraKey[CKEY_W])     // W CTR
                & (cpu_addr[9] | cobraKey[CKEY_S])      // S RIGHT
                & (cpu_addr[8] | cobraKey[CKEY_Z])      // Z DOWN

                , // D0
                 ((cpu_addr[15] | cobraKey[CKEY_SPACE]) // SPACE
                & (cpu_addr[14] | cobraKey[CKEY_CR])    // CR
                & (cpu_addr[13] | cobraKey[CKEY_P])     // P CLS
                & (cpu_addr[12] | cobraKey[CKEY_0]))    // 0
                & (cpu_addr[11] | cobraKey[CKEY_1])     // 1 ! 
                & (cpu_addr[10] | cobraKey[CKEY_Q])     // Q UP
                & (cpu_addr[9] | cobraKey[CKEY_A])      // A LEFT
                & (cpu_addr[8] | cobraKey[CKEY_SH])     // SHIFT 
            };
    end

endmodule

`default_nettype wire
