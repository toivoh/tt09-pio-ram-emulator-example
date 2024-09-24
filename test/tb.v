/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns/1ps

module tb();

	initial begin
		$dumpfile ("tb.vcd");
		$dumpvars (0, tb);
		#1;
	end

	localparam IO_BITS = 2;


	reg clk;
	reg rst_n = 0;
	wire reset = !rst_n;


	wire [IO_BITS-1:0] rx_pins;
	wire [IO_BITS-1:0] tx_pins;


	julia_top top(
		.clk(clk), .reset(reset),
		.rx_pins(rx_pins), .tx_pins(tx_pins)
	);

	// Gives a 22 cycle latency from start bit of read message to start bit of first reply, given that tx_pins and rx_pins are registered in the design
	pio_ram_emulator_model #(.READ_LATENCY(22), .ERROR_RESPONSE(1)) ram_emu(
		.clk(clk), .reset(reset),
		.rx_pins(tx_pins), .tx_pins(rx_pins)
	);


	int running_counter = 0;
	always @(posedge clk) running_counter <= running_counter + 1;
endmodule
