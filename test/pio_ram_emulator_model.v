/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`include "../src/pio_ram_emulator.vh"

// ERROR_RESPONSE: What to do with tx_pins if error status is nonzero: 0: ones (stop bits), 1: x, 3: keep trying to respond anyway
module pio_ram_emulator_model #(parameter READ_LATENCY = 22, ERROR_RESPONSE = 0) (
		input wire clk,
		input wire reset,

		input wire [1:0] rx_pins,
		output wire [1:0] tx_pins,

		output wire [7:0] error_status
	);

	localparam IO_BITS = 2;
	localparam HEADER_CYCLES = 2;
	localparam DATA_CYCLES = 8;
	localparam PAYLOAD_CYCLES = HEADER_CYCLES + DATA_CYCLES;

	localparam HEADER_BITS = HEADER_CYCLES*IO_BITS;
	localparam DATA_BITS = DATA_CYCLES*IO_BITS;
	localparam PAYLOAD_BITS = PAYLOAD_CYCLES*IO_BITS;

	localparam ADDR_BITS = DATA_BITS;

	// Decompose header into read and write channel
	localparam HEADER_SET_COUNT = (`PIO_RAM_EMU_HEADER_SET_READ_WRITE_COUNT & 1) | ((`PIO_RAM_EMU_HEADER_SET_READ_WRITE_COUNT & 4) >> 1);
	localparam HEADER_SEND_ADDR = (`PIO_RAM_EMU_HEADER_SEND_READ_WRITE_ADDR & 1) | ((`PIO_RAM_EMU_HEADER_SEND_READ_WRITE_ADDR & 4) >> 1);
	localparam HEADER_SEND_DATA = (`PIO_RAM_EMU_HEADER_SEND_WRITE_DATA & 1) | ((`PIO_RAM_EMU_HEADER_SEND_WRITE_DATA & 4) >> 1);


	localparam ERROR_BITS = 3;
	localparam ERR_BIT_EARLY_READ_ADDR = 0;
	localparam ERR_BIT_EARLY_WRITE_ADDR = 1;
	localparam ERR_BIT_TOO_MUCH_WRITE_DATA = 2;


	// State
	// =====
	reg [DATA_BITS-1:0] read_count, write_count, curr_read_count, curr_write_count;
	reg [ADDR_BITS+1-1:0] read_addr, write_addr; // Additional address bit to model cases where the address overflows
	reg [DATA_BITS-1:0] RAM[2**ADDR_BITS];


	// Reciever
	// ========
	wire message_received;
	wire [PAYLOAD_BITS-1:0] rx_payload;
	sbio_receiver #(.IO_BITS(IO_BITS), .SKIP_CYCLES(0), .PAYLOAD_CYCLES(PAYLOAD_CYCLES)) receiver(
		.clk(clk), .reset(reset),
		.rx_pins(rx_pins),
		.payload_received(message_received), .payload(rx_payload)
	);
	wire [HEADER_BITS-1:0] rx_header;
	wire [DATA_BITS-1:0] rx_data;
	assign {rx_data, rx_header} = rx_payload;

	// Decompose header into read and write channel
	wire [1:0] r_header, w_header;
	assign {r_header[1], w_header[1], r_header[0], w_header[0]} = rx_header;


	// Transmitter
	// ===========
	wire [IO_BITS-1:0] tx_pins0;
	wire tx_valid, tx_ready, tx_accepted;
	wire [DATA_BITS-1:0] tx_data;
	// Add a final payload cycle with tx_pins = 2'b11 to make sure that we get stop bits
	sbio_transmitter #(.IO_BITS(IO_BITS), .PAYLOAD_CYCLES(PAYLOAD_CYCLES+1)) transmitter(
		.clk(clk), .reset(reset),
		.ready(tx_ready),
		.payload_valid(tx_valid), .payload({2'b11, tx_data, {HEADER_BITS{1'b0}} }), .payload_accepted(tx_accepted),
		.tx_pins(tx_pins0)
	);


	// Message handling
	// ===================
	assign tx_data = RAM[read_addr];
	assign tx_valid = curr_read_count != 0;

	wire read_count_received = message_received && (r_header == HEADER_SET_COUNT);
	wire write_count_received = message_received && (w_header == HEADER_SET_COUNT);

	wire read_addr_received = message_received && (r_header == HEADER_SEND_ADDR);
	wire write_addr_received = message_received && (w_header == HEADER_SEND_ADDR);

	wire write_data_received = message_received && (w_header == HEADER_SEND_DATA);

	reg [ERROR_BITS-1:0] error_flags;

	always @(posedge clk) begin
		if (reset) begin
			read_count <= 1;
			write_count <= 1;
			curr_read_count <= 0;
			curr_write_count <= 0;
			read_addr <= 'X;
			write_addr <= 'X;
			error_flags <= '0;
		end else begin
			if (read_count_received) read_count <= rx_data;
			if (write_count_received) write_count <= rx_data;

			if (tx_accepted) begin
				read_addr <= read_addr + 1;
				curr_read_count <= curr_read_count - 1;
				if (read_addr_received) error_flags[ERR_BIT_EARLY_READ_ADDR] <= 1;
			end else if (read_addr_received) begin
				if (curr_read_count != 0) error_flags[ERR_BIT_EARLY_READ_ADDR] <= 1;
				else begin
					read_addr <= rx_data;
					curr_read_count <= read_count;
				end
			end

			if (write_addr_received) begin
				if (curr_write_count != 0) error_flags[ERR_BIT_EARLY_WRITE_ADDR] <= 1;
				else begin
					write_addr <= rx_data;
					curr_write_count <= write_count;
				end
			end

			if (write_data_received) begin
				if (curr_write_count == 0) error_flags[ERR_BIT_TOO_MUCH_WRITE_DATA] <= 1;
				else begin
					RAM[write_addr] <= rx_data;
					write_addr <= write_addr + 1;
					curr_write_count <= curr_write_count - 1;
				end
			end
		end
	end

	assign error_status = error_flags;


	reg [IO_BITS-1:0] tx_pins1; // not a register
	always @(*) begin
		tx_pins1 = tx_pins0;
		if (error_status !== 0) begin
			if (ERROR_RESPONSE == 0) tx_pins1 = '1; // All stop bits. TODO: Finish the current message first?
			if (ERROR_RESPONSE == 1) tx_pins1 = 'X;
			if (ERROR_RESPONSE == 3) tx_pins1 = tx_pins0; // Keep trying to respond anyway
		end
	end

	// Delay model
	// ===========
	localparam DELAY = READ_LATENCY - 11;

	reg [IO_BITS*DELAY-1:0] delay_sreg;

	always @(posedge clk) begin
		if (reset) delay_sreg <= '1;
		else delay_sreg <= {tx_pins1, delay_sreg[IO_BITS*DELAY-1:IO_BITS]};
	end
	assign tx_pins = delay_sreg[IO_BITS-1:0];


	wire unused = &{tx_ready};
endmodule : pio_ram_emulator_model
