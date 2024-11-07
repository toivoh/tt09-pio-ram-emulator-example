# Copyright (c) 2024 Toivo Henningsson
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test_project(dut):
	dut._log.info("Start")

	clock = Clock(dut.clk, 10, units="us")
	cocotb.start_soon(clock.start())

	# Initialize part of the RAM emulator's RAM.
	ram_emu = dut.ram_emu
	ram = ram_emu.RAM
	for i in range(256):
		#value = 0x0100 + 0x0202*(i & 7) + 0x1010*((~i >> 3) & 15)
		value = 0 # RAM is initialized to zero by the RAM emulator, unless customized
		ram[i].value = value
		#print(i, ":", hex(value), ",", end="")

	# Reset
	dut._log.info("Reset")
	dut.ena.value = 1
	dut.ui_in.value = 0
	dut.uio_in.value = 0xff
	dut.rst_n.value = 0
	await ClockCycles(dut.clk, 10)
	dut.rst_n.value = 1

	#await ClockCycles(dut.clk, (800*5+1)*2)
	for i in range(800*5+1):
		dut.ui_in.value = 0
		await ClockCycles(dut.clk, 1)
		dut.ui_in.value = 1
		await ClockCycles(dut.clk, 1)


	# Print RAM values that have been updated
	last_addr = ram_emu.write_addr.value.integer - 1 # The write address gets incremented by one by the RAM emulator after a successful write, compensate

	print("initialized_ram = [", end="")
	for i in range(last_addr):
		print(ram[i].value.integer, end=", ")
	print("]")

	# Compare against expected result,
	# taken from earlier printout
	initialized_ram = [0, 0, 0, 0, 0, 0, 0, 0, 16384, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 21504, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 21845, 85, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 21840, 21845, 21845, 21845, 21845, 21845, 21845, ]

	assert last_addr == len(initialized_ram)
	for (i, data) in enumerate(initialized_ram):
		assert ram[i].value.integer == data
