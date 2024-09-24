/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none


module pio_ram_emu_transmitter(
		input wire clk, reset,

		output wire ready,
		input wire message_valid,
		input wire [3:0] header,
		input wire [15:0] data,
		output wire message_accepted,  // When this goes high, the message will be sent. Only goes high when ready && message_valid.

		output wire [1:0] tx_pins
	);

	// Add a final payload cycle with tx_pins = 2'b11 to make sure that we get stop bits
	sbio_transmitter #(.IO_BITS(2), .PAYLOAD_CYCLES(11)) transmitter(
		.clk(clk), .reset(reset),
		.ready(ready),
		.payload_valid(message_valid), .payload({2'b11, data, header}), .payload_accepted(message_accepted),
		.tx_pins(tx_pins)
	);
endmodule : pio_ram_emu_transmitter


module pio_ram_emu_receiver(
		input wire clk, reset,

		input wire [1:0] rx_pins,

		output wire data_received,  // High during one cycle for each received message
		output wire [15:0] data  // Only guaranteed to be valid when data_received is high
	);

	sbio_receiver #(.IO_BITS(2), .SKIP_CYCLES(2), .PAYLOAD_CYCLES(8)) receiver(
		.clk(clk), .reset(reset),
		.rx_pins(rx_pins),
		.payload_received(data_received), .payload(data)
	);
endmodule
