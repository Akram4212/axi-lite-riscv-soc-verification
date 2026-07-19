"""End-to-end cocotb test for the integrated RV32I AXI-Lite SoC."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge


CLOCK_PERIOD_NS = 10
MAX_EXECUTION_CYCLES = 2000


def signal_value(signal) -> int:
    """Convert a resolved cocotb signal value to int."""
    return int(signal.value)


async def reset_soc(dut) -> None:
    """Initialize external inputs and apply active-low reset."""
    dut.nRST.value = 0
    dut.gpio_i.value = 0xA5A5_5A5A

    await ClockCycles(dut.CLK, 5)

    dut.nRST.value = 1
    await RisingEdge(dut.CLK)
    await ReadOnly()


@cocotb.test()
async def test_soc_firmware_smoke(dut) -> None:
    """Execute firmware from AXI-Lite RAM and verify peripherals."""
    cocotb.start_soon(
        Clock(
            dut.CLK,
            CLOCK_PERIOD_NS,
            unit="ns",
        ).start()
    )

    await reset_soc(dut)

    assert signal_value(dut.halt) == 0
    assert signal_value(dut.illegal) == 0
    assert signal_value(dut.bus_error) == 0

    halt_cycle = None

    for cycle in range(1, MAX_EXECUTION_CYCLES + 1):
        await RisingEdge(dut.CLK)
        await ReadOnly()

        assert signal_value(dut.bus_error) == 0, (
            "AXI-Lite bus error at "
            f"cycle {cycle}, PC=0x{signal_value(dut.debug_pc):08X}"
        )

        assert signal_value(dut.illegal) == 0, (
            "Illegal instruction at "
            f"cycle {cycle}, "
            f"PC=0x{signal_value(dut.debug_pc):08X}, "
            "instruction="
            f"0x{signal_value(dut.debug_instruction):08X}"
        )

        if signal_value(dut.halt) == 1:
            halt_cycle = cycle
            break

    assert halt_cycle is not None, (
        "Firmware did not reach EBREAK within "
        f"{MAX_EXECUTION_CYCLES} cycles; "
        f"last PC=0x{signal_value(dut.debug_pc):08X}"
    )

    # The firmware configured GPIO[3:0] as outputs and wrote 0x5.
    assert signal_value(dut.gpio_oe) & 0xF == 0xF, (
        "GPIO direction mismatch: "
        f"gpio_oe=0x{signal_value(dut.gpio_oe):08X}"
    )

    assert signal_value(dut.gpio_o) & 0xF == 0x5, (
        "GPIO output mismatch: "
        f"gpio_o=0x{signal_value(dut.gpio_o):08X}"
    )

    # Firmware reaches EBREAK only after polling Timer STATUS.MATCH.
    assert signal_value(dut.timer_irq) == 1, (
        "Timer IRQ was not asserted before firmware halted"
    )

    assert signal_value(dut.bus_error) == 0
    assert signal_value(dut.illegal) == 0

    dut._log.info(
        "Firmware halted after %d cycles at PC=0x%08X",
        halt_cycle,
        signal_value(dut.debug_pc),
    )

    # Confirm the halted core does not modify peripheral outputs.
    gpio_o_before = signal_value(dut.gpio_o)
    gpio_oe_before = signal_value(dut.gpio_oe)

    await ClockCycles(dut.CLK, 10)
    await ReadOnly()

    assert signal_value(dut.halt) == 1
    assert signal_value(dut.gpio_o) == gpio_o_before
    assert signal_value(dut.gpio_oe) == gpio_oe_before
    assert signal_value(dut.bus_error) == 0
