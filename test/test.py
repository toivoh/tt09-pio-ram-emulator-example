# Copyright (c) 2024 Toivo Henningsson
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test(dut):
	dut._log.info("start")
	clock = Clock(dut.clk, 2, units="us")
	cocotb.start_soon(clock.start())

	top = dut.top
	ram_emu = dut.ram_emu
	ram = ram_emu.RAM

	for i in range(256):
		value = 0x0100 + 0x0202*(i & 7) + 0x1010*((~i >> 3) & 15)
		ram[i].value = value
		#print(i, ":", hex(value), ",", end="")

	# reset
	dut._log.info("reset")
	dut.rst_n.value = 0
	await ClockCycles(dut.clk, 10)
	dut.rst_n.value = 1

	await ClockCycles(dut.clk, 800*2)
