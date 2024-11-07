/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_toivoh_pio_ram_emu_example #(parameter DEBOUNCE_DELAY_BITS = 19) (
	input  wire [7:0] ui_in,    // Dedicated inputs
	output wire [7:0] uo_out,   // Dedicated outputs
	input  wire [7:0] uio_in,   // IOs: Input path
	output wire [7:0] uio_out,  // IOs: Output path
	output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
	input  wire       ena,      // always 1 when the design is powered, so you can ignore it
	input  wire       clk,      // clock
	input  wire       rst_n     // reset_n - low to reset
);

	localparam IO_BITS  = 2;

	wire reset = !rst_n;

	wire [11:0] rgb;
	wire hsync, vsync, new_frame;
	wire [IO_BITS-1:0] rx_pins, tx_pins;
	julia_top #(.DEBOUNCE_DELAY_BITS(DEBOUNCE_DELAY_BITS)) top(
		.clk(clk), .reset(reset),
		.rgb(rgb), .hsync(hsync), .vsync(vsync), .new_frame(new_frame),
		.rx_pins(rx_pins), .tx_pins(tx_pins),
		.buttons(ui_in[5:0]), .use_both_button_dirs(ui_in[7])
	);

	wire [3:0] r, g, b;
	assign {r, g, b} = rgb;


	reg [7:0] uio_in_reg;
	wire [7:0] uo_out0, uio_out0;
	reg [7:0] uo_out1, uio_out1;

	assign uo_out0 = {
		!hsync,
		b[2],
		g[2],
		r[2],
		!vsync,
		b[3],
		g[3],
		r[3]
	};

	assign uio_out0[3:0] = 0;
	assign uio_out0[5:4] = reset ? rx_pins : tx_pins; // Loopback from rx_pins to tx_pins during reset to allow RAM emulator to calibrate delay
	assign uio_out0[7:6] = 0;
	assign uio_oe[3:0] = 0;
	assign uio_oe[5:4] = '1;
	assign uio_oe[7:6] = 0;

	assign rx_pins = uio_in_reg[7:6];

	always @(posedge clk) begin
		uo_out1 <= uo_out0;
		uio_out1 <= uio_out0;
		uio_in_reg <= uio_in;
	end
	assign uo_out = uo_out1;
	assign uio_out = uio_out1;

	// List all unused inputs to prevent warnings
	wire _unused = &{ena, rst_n, ui_in, ui_in, uio_in};
endmodule
