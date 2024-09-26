Wrapper to run the project on Pico-Ice
======================================
This directory contains code (in `ice/`) to run the RAM emulator example on the FPGA of a [Pico-Ice](https://pico-ice.tinyvision.ai/).
It expects to be paired with the RAM emulator from https://github.com/toivoh/pio-ram-emulator/tree/main/pico-ice/ram-emu

Assumptions
-----------
The design is made to be clocked at 50.4 MHz (VGA with 2 cycles per pixel).
[ice/julia.pcf](ice/julia.pcf) sets the clock frequency to 32 MHz, which means that the FPGA is overclocked a bit more than 1.5x, but it seems to work anyway.
If you have problems, you can try reducing the clock frequency from the RAM emulator.

The code makes assumptions about the pins used to communicate with the RP2040:
- The emulator's RX pins (the FPGAs TX pins) are RP0-1
- The emulator's TX pins (the FPGAs RX pins) are RP4-5
- The FPGA design has an active high RESET pin connected to RP14

The FPGA is started before the RAM emulator, but with the RESET pin held high until after the RAM emulator is started. The FPGA should hold its TX pins high (no start bit) during reset, so that the RAM emulator can be completely initialized before it needs to start handling traffic.

The FPGA design also assumes a [Pmod VGA](https://digilent.com/reference/pmod/pmodvga/start) connected to Pmods 1 and 2 (see https://pico-ice.tinyvision.ai/md_pinout.html) for VGA output.
