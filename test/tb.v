/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

	// Dump the signals to a VCD file. You can view it with gtkwave.
	initial begin
		$dumpfile("tb.vcd");
		$dumpvars(0, tb);
		#1;
	end

	// Wire up the inputs and outputs:
	reg clk;
	reg rst_n;
	reg ena;
	reg [7:0] ui_in;
	reg [7:0] uio_in;
	wire [7:0] uo_out;
	wire [7:0] uio_out;
	wire [7:0] uio_oe;
`ifdef GL_TEST
	wire VPWR = 1'b1;
	wire VGND = 1'b0;
`endif


	// Connect TX and RX pins to the design under test
	localparam IO_BITS = 2;

	wire [IO_BITS-1:0] tx_pins;
	wire [IO_BITS-1:0] rx_pins;

	assign tx_pins = uio_out[5:4]; // Change if your design uses other pins for tx_pins. Note that they have to be consecutive to the RP2040!

	// Replace uio_in[7:6] with rx_pins coming from the RAM emulator model.
	// Change if your design uses other pins for rx_pins. Note that they have to be consecutive to the RP2040!
	wire [7:0] uio_in_actual;
	assign uio_in_actual[5:0] = uio_in[5:0];
	assign uio_in_actual[7:6] = rx_pins;


	// Replace tt_um_example with your module name:
	tt_um_toivoh_pio_ram_emu_example user_project (

		// Include power ports for the Gate Level test:
`ifdef GL_TEST
		.VPWR(VPWR),
		.VGND(VGND),
`endif

		.ui_in  (ui_in),    // Dedicated inputs
		.uo_out (uo_out),   // Dedicated outputs
		.uio_in (uio_in_actual),   // IOs: Input path. uio_in_actual[7:6] have been hardwired to rx_pins coming from the RAM emulator model.
		.uio_out(uio_out),  // IOs: Output path
		.uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
		.ena    (ena),      // enable - goes high when design is selected
		.clk    (clk),      // clock
		.rst_n  (rst_n)     // not reset
	);

	// Instantiate RAM emulator model
	// Gives a 22 cycle latency from start bit of read message to start bit of first reply, given that tx_pins and rx_pins are registered in the design
	pio_ram_emulator_model #(.READ_LATENCY(22), .ERROR_RESPONSE(1)) ram_emu(
		.clk(clk), .reset(!rst_n),
		.rx_pins(tx_pins), .tx_pins(rx_pins)
	);

	// Running counter to make it easier to inspect the vcd file
	int running_counter = 0;
	always @(posedge clk) running_counter <= running_counter + 1;
endmodule
