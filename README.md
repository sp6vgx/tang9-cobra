tang9k-cobra
============

Cobra computer in FPGA

Cobra is DIY home computer published around 1985 in Audio-Video magazine.

Z80 processor clocked at 3.25MHz
16KB RAM + 1KB video RAM
2KB ROM with monitor (no build-in Basic)

FPGA Board: Sipeed Tang Nano 9K (GW1NR-9 FPGA chip)

Link to the Cobra 1 topic on the "Elektroda" forum: https://www.elektroda.pl/rtvforum/topic2564143.html


![image](https://raw.githubusercontent.com/sp6vgx/tang9-cobra/master/docs/cobra1_pic1.jpg)

![image](https://raw.githubusercontent.com/sp6vgx/tang9-cobra/master/docs/cobra1_pic2.jpg)

![image](https://raw.githubusercontent.com/sp6vgx/tang9-cobra/master/docs/cobra1_pic3.jpg)

## Implemented hardware

- Cobra 1, Cobra Kolor, Cobra Dual RAM (48kB)
- HDMI output at 1280x720 (60Hz)
- HDMI output sound (PCM 48kHz)
- USB Keyboard
- Z80 Soft CPU (T80a)
- Tape storage In/Out
- Sound: Beep, Katarynka, AY3-8910

## How-to make it running

1. Install openFpgaLoader tool
2. Upload ROM image ROM/cobra_rom.bin into the external SPI flash by ```openFPGALoader -b tangnano9k --external-flash ROM/cobra_rom.bin```
3. Upload bitstream into the internal flash ```openFPGALoader -b tangnano9k -f impl/pnr/tang9k-cobra.fs```

## HDMI tips

Some monitors and TVs do not show a picture over the Tang Nano HDMI connector.
In this case you need to add a solder bridge instead of R1 (https://www.eevblog.com/forum/fpga/fpga-to-hdmi-variants/msg4613152/#msg4613152).

### Controls

- F11 - Switch ROM
- F12 - Reset

## Pinout (WIP)

```
               -----------------
              | S2    USB    S1 |
              |                 |
 (SD CS)  ----| 38     T     63 |---- x
 (SD SI)  ----| 37     A     86 |---- x
 (SD SCK) ----| 36     N     85 |---- x
 (SD SO)  ----| 39     G     84 |---- x
 USBK D-  ----| 25           83 |---- x
 USBK D+  ----| 26     N     82 |---- x
         x----| 27     A     81 |---- x
         x----| 28     N     80 |---- x
         x----| 29     O     79 |---- x
 Tape IN  ----| 30           77 |---- x
 Tape OUT ----| 33     9     76 |---- x
         x----| 34     K     75 |---- HDMI D2P
         x----| 40           74 |---- HDMI D2N
         x----| 35           73 |---- HDMI D1P
         x----| 41           72 |---- HDMI D1N
         x----| 42           71 |---- HDMI D0P
         x----| 51           70 |---- HDMI D0N
         x----| 53           5V |---- 5V
         x----| 54           48 |---- x
         x----| 55           49 |---- x
         x----| 56           31 |---- x
         x----| 57           32 |---- x
 HDMI CKN ----| 68          GND |---- GND
 HDMI CKP ----| 69          3V3 |---- 3V3
              |                 |
              |       HDMI      |
               _________________


```

