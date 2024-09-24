
all: obj_dir/Vvtop

obj_dir/Vvtop: main.cpp vtop.v ../src/julia.v ../src/julia_top.v ../src/pio_ram_emulator.v ../src/pio_ram_emulator.vh  ../src/project.v ../src/raster_scan.v ../src/sb_io.v ../test/pio_ram_emulator_model.v
	verilator -cc -j 0 -I../src -DFPGA --exe --build  -CFLAGS "-g -O3" --LDFLAGS "-lSDL2" --top-module vtop main.cpp -Wno-widthexpand -Wno-widthtrunc -Wno-PINMISSING vtop.v ../src/julia.v ../src/julia_top.v ../src/pio_ram_emulator.v ../src/project.v ../src/raster_scan.v ../src/sb_io.v ../test/pio_ram_emulator_model.v
