/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "pio_ram_emulator.vh"


module julia_top #(parameter C_BITS = 12, ITER_BITS = 9, DEBOUNCE_DELAY_BITS = 19) (
		input wire clk, reset,

		output wire [11:0] rgb,
		output wire hsync, vsync, new_frame,

		input wire [1:0] rx_pins,
		output wire [1:0] tx_pins,

		input wire [5:0] buttons,
		input wire use_both_button_dirs
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


	// Buttons
	// =======
	wire buttons_stable;
	wire [5:0] stable_buttons;

	debouncer #(.BITS(6), .DELAY_BITS(DEBOUNCE_DELAY_BITS)) debouncer_inst(
		.clk(clk), .reset(reset),
		.data(buttons),
		.stable(buttons_stable), .stable_data(stable_buttons)
	);

	reg [5:0] last_stable_buttons;
	always @(posedge clk) if (reset || buttons_stable) last_stable_buttons <= stable_buttons;

	wire [5:0] buttons_to_high = buttons_stable ? (stable_buttons & (~last_stable_buttons)) : '0;
	wire [5:0] buttons_to_low  = buttons_stable ? ((~stable_buttons) & last_stable_buttons) : '0;

	wire [5:0] buttons_active = buttons_to_low | (use_both_button_dirs ? buttons_to_high : '0);

	localparam STEP_SIZE_BITS = $clog2(C_BITS);
	localparam MAX_STEP_SIZE = C_BITS - 2;
	//wire [STEP_SIZE_BITS-1:0] step_size = C_BITS - 4;
	reg [STEP_SIZE_BITS-1:0] step_size;

	wire signed [C_BITS-1:0] delta_c_x = buttons_active[3] - buttons_active[2];
	wire signed [C_BITS-1:0] delta_c_y = buttons_active[0] - buttons_active[1];
	wire signed [STEP_SIZE_BITS-1:0] delta_step_size = (buttons_active[4] && step_size != MAX_STEP_SIZE) - (buttons_active[5] && step_size != '0);

	reg signed [C_BITS-1:0] c_x, c_y;
	always @(posedge clk) begin
		if (reset) begin
			c_x <= -5734 >>> (16 - C_BITS);
			c_y <= 10158 >> (16 - C_BITS);
			step_size <= C_BITS - 8;
		end else begin
			c_x <= c_x + (delta_c_x << step_size);
			c_y <= c_y + (delta_c_y << step_size);
			step_size <= step_size + delta_step_size;
		end
	end


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
		.c_x(c_x), .c_y(c_y),
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

	// Simple color palette
	// --------------------
	wire [PIXEL_BITS:0] curr_pixel_p1 = curr_pixel + 1;
	wire [PIXEL_BITS:0] curr_pixel_m1 = curr_pixel - 1;

	//wire [PIXEL_BITS-1:0] curr_pixel_p1s = curr_pixel_p1[PIXEL_BITS] ? '1 : curr_pixel_p1[PIXEL_BITS-1:0];
	wire [PIXEL_BITS-1:0] curr_pixel_p1s = curr_pixel_m1[PIXEL_BITS] ? '0 : (curr_pixel_p1[PIXEL_BITS] ? '1 : curr_pixel_p1[PIXEL_BITS-1:0]);
	wire [PIXEL_BITS-1:0] curr_pixel_m1s = curr_pixel_m1[PIXEL_BITS] ? '0 : curr_pixel_m1[PIXEL_BITS-1:0];

	wire [3:0] curr_pixel2 = {curr_pixel, curr_pixel};
	wire [3:0] curr_pixel2_p1 = {curr_pixel_p1s, curr_pixel_p1s};
	wire [3:0] curr_pixel2_m1 = {curr_pixel_m1s, curr_pixel_m1s};

	assign rgb = active ? {curr_pixel2, curr_pixel2_m1, curr_pixel2_p1} : '0;

	/*
	wire [3:0] curr_pixel2 = {curr_pixel, curr_pixel};

	assign rgb = active ? {curr_pixel2, curr_pixel2, curr_pixel2} : '0;
	*/
endmodule : julia_top


module debouncer #(parameter BITS = 1, DELAY_BITS = 19) (
		input wire clk, reset,

		input wire [BITS-1:0] data,
		output wire stable,
		output wire [BITS-1:0] stable_data
	);

	reg [BITS-1:0] last_data;
	always @(posedge clk) last_data <= data;

	wire same = (last_data == data);

	reg [DELAY_BITS:0] timer;
	assign stable = timer[DELAY_BITS];

	always @(posedge clk) begin
		if (reset || !same) timer <= 0;
		else timer <= timer + !stable;
	end

	assign stable_data = last_data;
endmodule
