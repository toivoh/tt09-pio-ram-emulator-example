/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

// Message header values

`define PIO_RAM_EMU_HEADER_SET_READ_COUNT       4'b0101  // Set read count to be used from next read transaction onwards
`define PIO_RAM_EMU_HEADER_SET_WRITE_COUNT      4'b1010  // Set write count to be used from next write transaction onwards
`define PIO_RAM_EMU_HEADER_SET_READ_WRITE_COUNT 4'b0000  // Set both read and write count to the same value

`define PIO_RAM_EMU_HEADER_SEND_READ_ADDR       4'b0111  // Send read address, start a read transaction with current read count
`define PIO_RAM_EMU_HEADER_SEND_WRITE_ADDR      4'b1011  // Send write address, start a write transaction with current write count
`define PIO_RAM_EMU_HEADER_SEND_READ_WRITE_ADDR 4'b0011  // Start both a read and write transaction from the address sent

`define PIO_RAM_EMU_HEADER_SEND_WRITE_DATA      4'b1110  // Send one 16 bit word of write data
