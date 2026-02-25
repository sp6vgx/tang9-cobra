//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2026-02-23 07:16:14
create_clock -name clk_27M -period 37.037 -waveform {0 18.518} [get_ports {clk_27M}]
create_clock -name clk_psram -period 13.889 -waveform {0 2.604} [get_pins {rPLL2_Inst/rpll_inst/CLKOUT}]
create_clock -name clk_cpu -period 307.125 -waveform {0 200} [get_pins {rPLL1_Inst/rpll_inst/CLKOUTD}]
create_clock -name clk_pixel_x5 -period 2.694 -waveform {0 1.347} [get_pins {rPLL1_Inst/rpll_inst/CLKOUT}]
create_clock -name clk_pixel -period 13.468 -waveform {0 6.734} [get_pins {clkdiv_pc_Inst/CLKOUT}]
create_clock -name clk_usb -period 83.333 -waveform {0 41.666} [get_pins {rPLL2_Inst/rpll_inst/CLKOUTD}]
