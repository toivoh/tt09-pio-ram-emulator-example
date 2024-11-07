`default_nettype none

module input_pins #( parameter BITS=1 ) (
		input wire clk,
		input wire [BITS-1:0] pins,
		output wire [BITS-1:0] data
	);

	generate
		genvar i;
		for (i = 0; i < BITS; i++) begin : pin
			// Registered input
			SB_IO #(.PIN_TYPE(6'b000000)) io_pin(
				.PACKAGE_PIN(pins[i]),
				.INPUT_CLK(clk),
				.OUTPUT_CLK(clk),
				.D_IN_0(data[i])
			);
		end
	endgenerate
endmodule

module output_pins #( parameter BITS=1 ) (
		input wire clk,
		input wire [BITS-1:0] data,
		output wire [BITS-1:0] pins
	);

	generate
		genvar i;
		for (i = 0; i < BITS; i++) begin : pin
			// Registered output
			SB_IO #(.PIN_TYPE(6'b010100)) io_pin(
				.PACKAGE_PIN(pins[i]),
				.INPUT_CLK(clk),
				.OUTPUT_CLK(clk),
				.D_OUT_0(data[i])
				//.D_OUT_1(data[i]) // Shouldn't be needed since this is not configured as a DDR pin? Gives timing problems when used.
			);
		end
	endgenerate
endmodule


module top(
		input wire clk,
		input wire RESET_PIN,

		output wire led_red,
		output wire led_green,
		output wire led_blue,

		output wire TX_PIN0, TX_PIN1,
		input  wire RX_PIN0, RX_PIN1,

		output wire VGA_R0, VGA_R1, VGA_R2, VGA_R3,
		output wire VGA_B0, VGA_B1, VGA_B2, VGA_B3,
		output wire VGA_G0, VGA_G1, VGA_G2, VGA_G3,
		output wire VGA_HS, VGA_VS
	);

	localparam IO_BITS = 2;

	wire reset;
	wire [IO_BITS-1:0] tx_pins, rx_pins;
	wire [11:0] vga_rgb;
	wire [1:0] vga_vhsync;
	input_pins  #(.BITS(1)) reset_input_pin( .clk(clk), .data(reset), .pins(RESET_PIN));
	output_pins #(.BITS(IO_BITS)) serial_output_pins(.clk(clk), .data(tx_pins),  .pins({TX_PIN1, TX_PIN0}));
	input_pins  #(.BITS(IO_BITS)) serial_input_pins( .clk(clk), .data(rx_pins),  .pins({RX_PIN1, RX_PIN0}));
	output_pins #(.BITS(12)) vga_output_pins( .clk(clk), .data(vga_rgb),       .pins({VGA_R3, VGA_R2, VGA_R1, VGA_R0, VGA_G3, VGA_G2, VGA_G1, VGA_G0, VGA_B3, VGA_B2, VGA_B1, VGA_B0}));
	output_pins #(.BITS(2))  sync_output_pins(.clk(clk), .data(vga_vhsync),    .pins({VGA_VS, VGA_HS}));

/*
	reg _reset = 1;
	always @(posedge clk) _reset <= 0;
	wire reset = _reset;
*/

	wire [11:0] rgb;
	wire hsync, vsync, new_frame;
	wire [IO_BITS-1:0] rx_pins, tx_pins;
	julia_top top(
		.clk(clk), .reset(reset),
		.rgb(rgb), .hsync(hsync), .vsync(vsync), .new_frame(new_frame),
		.rx_pins(rx_pins), .tx_pins(tx_pins),
		.buttons('0), .use_both_button_dirs(1'b0)
	);

/*
	reg [11:0] rgb2, rgb3;
	wire [23:0] rgb_prod = rgb2*rgb2;
	always @(posedge clk) begin
		rgb2 <= rgb;
		rgb3 <= rgb_prod[23:12];
	end
*/

	assign vga_rgb = rgb;
	//assign vga_rgb = rgb3;
	assign vga_vhsync = {!vsync, !hsync};

	// Count frames, update leds once per 60 frames
	reg [5:0] frame_counter = 0;
	reg [2:0] leds = 0;

	always @(posedge clk) begin
		if (new_frame) begin
			if (frame_counter == 59) begin
				frame_counter <= 0;
				leds <= leds + 1;
			end else begin
				frame_counter <= frame_counter + 1;
			end
		end
	end

	assign {led_blue, led_red, led_green} = ~leds;
endmodule : top
