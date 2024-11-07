`default_nettype none
`timescale 1ns/1ps

module vtop(
		input wire clk, rst_n,

		output wire [1:0] r, g, b,
		output wire hsync, vsync,
		output wire [7:0] error_status,

		input wire [5:0] buttons,
		input wire use_both_button_dirs
	);
	localparam IO_BITS = 2;
	localparam DEBOUNCE_DELAY_BITS = 19;
	//localparam DEBOUNCE_DELAY_BITS = 24;


	wire [IO_BITS-1:0] rx_pins;
	wire [IO_BITS-1:0] tx_pins;

	wire [7:0] uio_in, uio_out, uo_out;
	tt_um_toivoh_pio_ram_emu_example #(.DEBOUNCE_DELAY_BITS(DEBOUNCE_DELAY_BITS)) project(
		.clk(clk), .rst_n(rst_n), .ena(1),
		.uio_in(uio_in), .uio_out(uio_out), .uo_out(uo_out),
		.ui_in({use_both_button_dirs, 1'b0, buttons})
	);

	pio_ram_emulator_model ram_emu(
		.clk(clk), .reset(!rst_n),
		.rx_pins(tx_pins), .tx_pins(rx_pins),
		.error_status(error_status)
	);

	assign uio_in[7:6] = rx_pins;
	assign uio_in[5:0] = '0;
	assign tx_pins = uio_out[5:4];

	assign {
		hsync,
		b[0],
		g[0],
		r[0],
		vsync,
		b[1],
		g[1],
		r[1]
	} = uo_out;
endmodule
