YOSYS = $(OSS_CAD_SUITE)/bin/yosys
NEXTPNR = $(OSS_CAD_SUITE)/bin/nextpnr-ice40
ICEPACK = $(OSS_CAD_SUITE)/bin/icepack
DFU_UTIL = $(OSS_CAD_SUITE)/bin/dfu-util
BIN2UF2 = bin2uf2

RTL = top.v ../../src/julia_top.v ../../src/pio_ram_emulator.v ../../src/sb_io.v ../../src/raster_scan.v ../../src/julia.v
PCF = julia.pcf

all: ice40.bin ice40.uf2

clean:
	$(RM) *.json *.asc *.bin *.uf2

prog: ice40.bin
	$(DFU_UTIL) -d 1209:b1c0 -a 1 -D ice40.bin -R

ice40.bin: $(RTL) $(PCF) Makefile
	$(YOSYS) -q -p "read_verilog -sv $(RTL); synth_ice40 -dsp -top top -json $*.json"
	$(NEXTPNR) -q --randomize-seed --up5k --package sg48 --pcf $(PCF) --json $*.json --asc $*.asc -l nextpnr.log
	$(ICEPACK) $*.asc $@

.bin.uf2:
	$(BIN2UF2) -o $@ $<

.SUFFIXES: .v .sv .asc .bin .uf2
