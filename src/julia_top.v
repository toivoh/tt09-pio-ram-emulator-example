/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "pio_ram_emulator.vh"


module julia_top #(parameter C_BITS = 12, ITER_BITS = 9) (
		input wire clk, reset,

		output wire [11:0] rgb,
		output wire hsync, vsync, new_frame,

		input wire [1:0] rx_pins,
		output wire [1:0] tx_pins
	);

	localparam DEST_WIDTH = 320;
	localparam DEST_HEIGHT = 480;

	localparam X_BITS = 12;
	localparam Y_BITS = 10;

	localparam READ_HEAD_START = 48; // When adjusting this, the reset value of rx_index may need to be updated too
	localparam LOG2_CYCLES_PER_PIXEL = 2;
	localparam LOG2_PIXELS_PER_WORD = 3;

	localparam VX_BITS = X_BITS-1 - LOG2_CYCLES_PER_PIXEL;
	localparam VY_BITS = 9;

	localparam PIXEL_BITS = 2**(4 - LOG2_PIXELS_PER_WORD);
	localparam LOG2_CYCLES_PER_READ = LOG2_CYCLES_PER_PIXEL + LOG2_PIXELS_PER_WORD;


	genvar i;


	// Raster scan
	// ===========
	wire signed [X_BITS-1:0] x;
	wire signed [Y_BITS-1:0] y;
	wire active;
	raster_scan rs(
		.clk(clk), .reset(reset),
		.x(x), .y(y),
		.active(active), .hsync(hsync), .vsync(vsync), .new_frame(new_frame)
	);
	wire x_reset = hsync;


	// Julia calculation
	// =================
	wire want_write, write_mode_data;
	wire [15:0] write_addr, write_data;
	wire write_accepted;
	julia #(.C_BITS(C_BITS), .ITER_BITS(ITER_BITS), .PIXEL_BITS(PIXEL_BITS), .LOG2_PIXELS_PER_WORD(LOG2_PIXELS_PER_WORD), .DEST_WIDTH(DEST_WIDTH), .DEST_HEIGHT(DEST_HEIGHT)) julia_calc(
		.clk(clk), .reset(reset),
		.write_en(want_write), .write_mode_data(write_mode_data),
		.w_addr(write_addr), .w_data(write_data),
		.write_accepted(write_accepted)
	);


	// RAM-emu transmitter
	// ===================
	wire tx_ready, tx_valid, tx_accepted;
	wire [3:0] tx_header;
	wire [15:0] tx_data;
	pio_ram_emu_transmitter transmitter(
		.clk(clk), .reset(reset),
		.ready(tx_ready),
		.message_valid(tx_valid), .header(tx_header), .data(tx_data), .message_accepted(tx_accepted),
		.tx_pins(tx_pins)
	);


	wire [X_BITS-1:0] early_x = x + READ_HEAD_START;
	wire [15:0] next_read_addr = {y[VY_BITS-1:0], early_x[VX_BITS+LOG2_CYCLES_PER_PIXEL-1 -: VX_BITS-LOG2_PIXELS_PER_WORD]};

	wire do_read  = (early_x[LOG2_CYCLES_PER_READ-1:0] == 0);
	wire can_write = (early_x[LOG2_CYCLES_PER_READ-1:0] == 2**(LOG2_CYCLES_PER_READ-1));

	wire do_write = can_write && want_write;

	assign tx_header = do_read ? `PIO_RAM_EMU_HEADER_SEND_READ_ADDR : (write_mode_data == 0 ? `PIO_RAM_EMU_HEADER_SEND_WRITE_ADDR : `PIO_RAM_EMU_HEADER_SEND_WRITE_DATA);
	assign tx_data   = do_read ? next_read_addr                     : (write_mode_data == 0 ? write_addr : write_data);

	assign tx_valid = do_read || do_write;

	assign write_accepted = do_write;


	// RAM-emu receiver
	// ================
	wire data_received;
	wire [15:0] rx_data;
	pio_ram_emu_receiver receiver(
		.clk(clk), .reset(reset),
		.rx_pins(rx_pins),
		.data_received(data_received), .data(rx_data)
	);


	reg [31:0] rx_buffer;
	wire rx_index = !next_read_addr[0]; // Might need to be inverted if READ_HEAD_START is changed?

	always @(posedge clk) begin
		if (data_received) begin
			if (rx_index == 0) rx_buffer[15:0] <= rx_data;
			if (rx_index == 1) rx_buffer[31:16] <= rx_data;
		end
	end

	wire [PIXEL_BITS-1:0] pixel_buffer[2*2**LOG2_PIXELS_PER_WORD];
	generate
		for (i = 0; i < 2*2**LOG2_PIXELS_PER_WORD; i++) assign pixel_buffer[i] = rx_buffer[(i+1)*PIXEL_BITS-1 -: PIXEL_BITS];
	endgenerate

	wire [PIXEL_BITS-1:0] curr_pixel = pixel_buffer[x[LOG2_CYCLES_PER_READ+1-1 -: LOG2_PIXELS_PER_WORD+1]];
	wire [3:0] curr_pixel2 = {curr_pixel, curr_pixel};

	assign rgb = active ? {curr_pixel2, curr_pixel2, curr_pixel2} : '0;
endmodule : julia_top
