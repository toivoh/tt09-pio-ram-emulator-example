/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none


module sbio_monitor #(parameter IO_BITS=2, SENS_BITS=1, COUNTER_BITS=4, INACTIVE_COUNTER_VALUE=16-3) (
		input wire clk, reset,

		input wire [IO_BITS-1:0] pins,

		output wire start, // Goes high when receving a start bit
		output wire active, // High during message except start bit
		output reg [COUNTER_BITS-1:0] counter, // INACTIVE_COUNTER_VALUE when inavtive and during start bit, then counts up
		input wire done // Put high during the the last cycle of the message
	);

	assign active = (counter != INACTIVE_COUNTER_VALUE);
	wire start_present = |(~pins[SENS_BITS-1:0]);

	assign start = !active && start_present;
	wire reset_counter = (!active && !start_present) || done;

	wire [COUNTER_BITS-1:0] next_counter = reset_counter ? INACTIVE_COUNTER_VALUE : counter + {{(COUNTER_BITS-1){1'b0}}, 1'b1};

	always @(posedge clk) begin
		if (reset) begin
			counter <= INACTIVE_COUNTER_VALUE;
		end else begin
			counter <= next_counter;
		end
	end
endmodule : sbio_monitor


module sbio_transmitter #(parameter IO_BITS=2, PAYLOAD_CYCLES=10) (
		input wire clk, reset,

		output wire ready,
		input wire payload_valid,
		input wire [IO_BITS*PAYLOAD_CYCLES-1:0] payload,
		output wire payload_accepted,  // When this goes high, the message will be sent. Only goes high when ready && payload_valid.

		output wire [IO_BITS-1:0] tx_pins
	);

	localparam PAYLOAD_BITS = IO_BITS*PAYLOAD_CYCLES;
	localparam COUNTER_BITS = $clog2(PAYLOAD_CYCLES + 2);

	reg [PAYLOAD_BITS-1:0] tx_sreg;

	wire started, active;
	wire [COUNTER_BITS-1:0] counter;
	wire tx_done;
	sbio_monitor #(.IO_BITS(IO_BITS), .SENS_BITS(1), .COUNTER_BITS(COUNTER_BITS), .INACTIVE_COUNTER_VALUE(2**COUNTER_BITS-1)) tx_monitor(
		.clk(clk), .reset(reset),
		.pins(tx_pins),
		.start(started), .active(active), .counter(counter),
		.done(tx_done)
	);

	assign ready = !active;
	wire start_tx = !reset && ready && payload_valid;
	assign payload_accepted = start_tx;

	assign tx_done = (counter == PAYLOAD_CYCLES-1);
	assign tx_pins = active ? tx_sreg[IO_BITS-1:0] : (start_tx ? '0 : '1);

	always @(posedge clk) begin
		if (start_tx) tx_sreg <= payload;
		else tx_sreg <= tx_sreg >> IO_BITS;
	end

	wire unused = &{started};
endmodule : sbio_transmitter


module sbio_receiver #(parameter IO_BITS=2, SKIP_CYCLES=2, PAYLOAD_CYCLES=8) (
		input wire clk, reset,

		input wire [IO_BITS-1:0] rx_pins,

		output wire payload_received,  // High during one cycle for each received message
		output wire [IO_BITS*PAYLOAD_CYCLES-1:0] payload  // Only guaranteed to be valid when payload_received is high
	);

	localparam COUNTER_BITS = $clog2(SKIP_CYCLES + PAYLOAD_CYCLES + 2);
	localparam PAYLOAD_BITS = IO_BITS*PAYLOAD_CYCLES;

	wire started, active;
	wire [COUNTER_BITS-1:0] counter;
	wire done;
	sbio_monitor #(.IO_BITS(IO_BITS), .SENS_BITS(1), .COUNTER_BITS(COUNTER_BITS), .INACTIVE_COUNTER_VALUE(2**COUNTER_BITS-1-SKIP_CYCLES)) rx_monitor(
		.clk(clk), .reset(reset),
		.pins(rx_pins),
		.start(started), .active(active), .counter(counter),
		.done(done)
	);
	assign done = (counter == PAYLOAD_CYCLES-1);

	reg [PAYLOAD_BITS-1:0] rx_sreg;
	wire [PAYLOAD_BITS-1:0] rx_sreg_next = {rx_pins, rx_sreg[PAYLOAD_BITS-1:IO_BITS]};
	always @(posedge clk) begin
		rx_sreg <= rx_sreg_next;
	end

	assign payload_received = done;
	assign payload = rx_sreg_next;

	wire unused = &{started, rx_sreg[IO_BITS-1:0]};
endmodule : sbio_receiver
