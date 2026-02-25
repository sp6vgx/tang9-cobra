//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12 (64-bit)
//Part Number: GW1NR-LV9QN88PC6/I5
//Device: GW1NR-9
//Device Version: C
//Created Time: Tue Feb 24 19:58:46 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    Gowin_DPB_2K your_instance_name(
        .douta(douta), //output [7:0] douta
        .doutb(doutb), //output [7:0] doutb
        .clka(clka), //input clka
        .ocea(ocea), //input ocea
        .cea(cea), //input cea
        .reseta(reseta), //input reseta
        .wrea(wrea), //input wrea
        .clkb(clkb), //input clkb
        .oceb(oceb), //input oceb
        .ceb(ceb), //input ceb
        .resetb(resetb), //input resetb
        .wreb(wreb), //input wreb
        .ada(ada), //input [10:0] ada
        .dina(dina), //input [7:0] dina
        .adb(adb), //input [10:0] adb
        .dinb(dinb) //input [7:0] dinb
    );

//--------Copy end-------------------
