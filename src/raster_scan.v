/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none


module raster_scan(
		input wire clk, reset,

		output wire signed [11:0] x,
		output wire [9:0] y,
		output wire active, hsync, vsync, new_line, new_frame
	);

	localparam X_BITS = 12;
	localparam BP_W = 48*2;
	localparam ACTIVE_W = 640*2;
	localparam FP_W = 16*2;
	localparam SYNC_W = 96*2;

	localparam BP_X0 = -BP_W;
	localparam ACTIVE_X0 = 0;
	localparam FP_X0 = ACTIVE_W;
	localparam SYNC_X0 = FP_X0 + FP_W;
	localparam SYNC_X1 = SYNC_X0 + SYNC_W;


	localparam Y_BITS = 10;
	localparam ACTIVE_H = 480;
	localparam FP_H = 10;
	localparam SYNC_H = 2;
	localparam BP_H = 33;

	localparam ACTIVE_Y0 = 0;
	localparam FP_Y0 = ACTIVE_H;
	localparam SYNC_Y0 = FP_Y0 + FP_H;
	localparam BP_Y0 = SYNC_Y0 + SYNC_H;
	localparam BP_Y1 = BP_Y0 + BP_H;


	reg signed [X_BITS-1:0] x_reg;
	reg [Y_BITS-1:0] y_reg;

	assign new_line = (x_reg == SYNC_X1-1);
	assign new_frame = (y_reg == BP_Y1-1) && new_line;
	always @(posedge clk) begin
		if (reset || new_line) x_reg <= BP_X0;
		else x_reg <= x_reg + 1;

		if (reset || new_frame) y_reg <= ACTIVE_Y0;
		else y_reg <= y_reg + new_line;
	end

	wire x_active = (0 <= x_reg && x_reg < FP_X0);
	wire y_active = (y_reg < FP_Y0);

	assign active = x_active && y_active;
	assign hsync  = (SYNC_X0 <= x_reg && x_reg < SYNC_X1);
	assign vsync  = (SYNC_Y0 <= y_reg && y_reg < BP_Y0);

	assign x = x_reg;
	assign y = y_reg;
endmodule
