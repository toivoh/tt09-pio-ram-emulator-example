/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module julia #(parameter C_BITS = 12, ITER_BITS = 4, PIXEL_BITS = 4, LOG2_PIXELS_PER_WORD = 2, DEST_WIDTH = 160, DEST_HEIGHT = 480) (
		input wire clk, reset,

		input wire signed [C_BITS-1:0] c_x, c_y,

		output wire write_en,
		output wire write_mode_data, // 0 if sending write address, 1 if sending write data
		output wire [15:0] w_addr,
		output wire [15:0] w_data,

		input wire write_accepted
	);

	localparam VX_BITS = $clog2(DEST_WIDTH);
	localparam VY_BITS = $clog2(DEST_HEIGHT);


	// Position for updating
	// =====================
	wire move_dest;
	reg [VX_BITS-1:0] dest_x;
	reg [VY_BITS-1:0] dest_y;

	wire dest_new_line = (dest_x == DEST_WIDTH - 1) && move_dest;
	wire dest_new_frame = (dest_y == DEST_HEIGHT - 1) && dest_new_line;
	always @(posedge clk) begin
		if (reset) begin
			dest_x <= 0;
			dest_y <= 0;
		end else begin
			if (reset || dest_new_line) dest_x <= 0;
			else if (move_dest) dest_x <= dest_x + 1;

			if (reset || dest_new_frame) dest_y <= 0;
			else dest_y <= dest_y + dest_new_line;
		end
	end

	wire new_pixel_group = move_dest && (dest_x[LOG2_PIXELS_PER_WORD-1:0] == '1);
	reg new_pixel_group1;
	always @(posedge clk) new_pixel_group1 <= new_pixel_group;


	// Julia calculation
	// =================
	wire signed [VX_BITS-1:0] sdx = dest_x - DEST_WIDTH/2;
	wire signed [VY_BITS-1:0] sdy = dest_y - DEST_HEIGHT/2;

	wire signed [C_BITS-1:0] z0_x = sdx << (C_BITS - VX_BITS);
	wire signed [C_BITS-1:0] z0_y = sdy << (C_BITS - VY_BITS);


//	wire signed [C_BITS-1:0] c_x = -5734 >> (16 - C_BITS);
//	wire signed [C_BITS-1:0] c_y = 10158 >> (16 - C_BITS);

	reg signed [C_BITS-1:0] z_x, z_y;
	reg signed [C_BITS:0] z_x2, z_y2, z_xy;

	wire signed [C_BITS+1-1:0] z_x_next = z_x2 - z_y2 + c_x;
	wire signed [C_BITS+1-1:0] z_xy_x2 = z_xy << 1;
	wire signed [C_BITS+1-1:0] z_y_next = z_xy_x2 + c_y;
	wire far_outside = (z_x_next[C_BITS] != z_x_next[C_BITS-1]) || (z_y_next[C_BITS] != z_y_next[C_BITS-1]);

	reg [1:0] phase;

	reg [ITER_BITS-1:0] iter;

	wire restart_iter;

	reg signed [C_BITS-1:0] f1, f2; // not registers
	always @* begin
		case (phase)
			0: begin f1 = z_x; f2 = z_x; end
			1: begin f1 = z_y; f2 = z_y; end
			2: begin f1 = z_x; f2 = z_y; end
			default: begin f1 = 'X; f2 = 'X; end
		endcase
	end

	wire signed [2*C_BITS-1:0] full_prod = f1*f2;
	wire signed [C_BITS:0] prod = full_prod >> (C_BITS - 2);

	reg far_outside_reg;

	wire [C_BITS:0] z2 = z_x2 + z_y2;
	//wire outside = z2[C_BITS-1];
	wire outside = z2[C_BITS] || far_outside_reg;
	//wire outside = z2[C_BITS-1] || (z_x[C_BITS-1] != z_x[C_BITS-2]) || (z_y[C_BITS-1] != z_y[C_BITS-2]);
	wire iter_done = outside || iter[ITER_BITS-1];
	assign move_dest = (phase == 2) && iter_done;

	reg iter_done_reg;
	assign restart_iter = iter_done_reg;

	wire iterate;
	always @(posedge clk) begin
		if (reset) phase <= 3;
		else phase <= phase + iterate;

		case (phase)
			0: z_x2 <= prod;
			1: z_y2 <= prod;
			2: z_xy <= prod;
		endcase

		if (reset) iter_done_reg <= 1;
		else if (phase == 2) iter_done_reg <= iter_done;

		if (reset) begin
			iter <= 0;
			far_outside_reg <= 0;
		end else begin
			if (phase == 3) begin
				if (restart_iter) begin
					z_x <= z0_x;
					z_y <= z0_y;
					iter <= 0;
					far_outside_reg <= 0;
				end else begin
					z_x <= z_x_next;
					z_y <= z_y_next;
					iter <= iter + 1;
					far_outside_reg <= far_outside;
				end
			end
		end
	end


	reg [15:0] pixel_sreg;
	wire pixel_done = iter_done_reg && (phase == 3) && iterate;
	wire [PIXEL_BITS-1:0] new_pixel = iter;
	always @(posedge clk) if (pixel_done) pixel_sreg <= {new_pixel, pixel_sreg[15:PIXEL_BITS]};

	reg write_phase;
	reg [15:0] write_address;
	reg write_addr_available;
	reg write_data_available;
	assign iterate = !write_data_available;

	assign write_mode_data = write_phase;
	assign w_data = pixel_sreg;
	assign w_addr = write_address;

	always @(posedge clk) begin
		if (reset) begin
			write_phase <= 0;
			write_addr_available <= 0;
			write_data_available <= 0;
		end else begin
			if (write_accepted) write_phase <= !write_phase;

			write_addr_available <= (write_addr_available & !(write_phase == 0 && write_accepted)) | new_pixel_group;
			write_data_available <= (write_data_available & !(write_phase == 1 && write_accepted)) | new_pixel_group1;
		end

		if (new_pixel_group) write_address <= {dest_y, dest_x[VX_BITS-1:LOG2_PIXELS_PER_WORD]};
	end

	assign write_en = write_phase == 0 ? write_addr_available : write_data_available;
endmodule : julia
