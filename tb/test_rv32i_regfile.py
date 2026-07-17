"""cocotb verification for the RV32I register file."""

from __future__ import annotations

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer


CLOCK_PERIOD_NS = 10
MASK_32 = 0xFFFF_FFFF
NUM_REGISTERS = 32


def u32(value: int) -> int:
    """Limit a Python integer to 32 bits."""
    return value & MASK_32


async def initialize_dut(dut) -> None:
    """Start the clock, initialize inputs, and reset the register file."""
    dut.CLK.value = 0
    dut.nRST.value = 0

    dut.WEN.value = 0
    dut.wsel.value = 0
    dut.wdat.value = 0
    dut.rsel1.value = 0
    dut.rsel2.value = 0

    clock = Clock(dut.CLK, CLOCK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    # The reset is asynchronous and active low.
    await Timer(2, unit="ns")

    dut.nRST.value = 1

    # Wait for one active clock edge after releasing reset.
    await RisingEdge(dut.CLK)
    await Timer(1, unit="ns")


async def read_registers(
    dut,
    register_1: int,
    register_2: int,
) -> tuple[int, int]:
    """Read two registers through the asynchronous read ports."""
    assert 0 <= register_1 < NUM_REGISTERS
    assert 0 <= register_2 < NUM_REGISTERS

    dut.rsel1.value = register_1
    dut.rsel2.value = register_2

    # Allow combinational read logic to settle.
    await Timer(1, unit="ns")

    value_1 = int(dut.rdat1.value)
    value_2 = int(dut.rdat2.value)

    return value_1, value_2


async def read_register(dut, register: int) -> int:
    """Read one register through read port 1."""
    value, _ = await read_registers(dut, register, 0)
    return value


async def write_register(
    dut,
    register: int,
    value: int,
    *,
    enable: bool = True,
) -> None:
    """Perform one synchronous register-file write."""
    assert 0 <= register < NUM_REGISTERS

    # Drive write inputs away from the active rising edge.
    await FallingEdge(dut.CLK)

    dut.WEN.value = int(enable)
    dut.wsel.value = register
    dut.wdat.value = u32(value)

    # The write must occur here.
    await RisingEdge(dut.CLK)
    await Timer(1, unit="ns")

    dut.WEN.value = 0


@cocotb.test()
async def test_reset_clears_all_registers(dut) -> None:
    """Verify that reset clears x0 through x31."""
    await initialize_dut(dut)

    for register in range(NUM_REGISTERS):
        actual = await read_register(dut, register)

        assert actual == 0, (
            f"x{register} was not zero after reset: "
            f"received 0x{actual:08X}"
        )


@cocotb.test()
async def test_basic_write_and_read(dut) -> None:
    """Write a register and read the value back."""
    await initialize_dut(dut)

    await write_register(
        dut,
        register=5,
        value=0x1234_5678,
    )

    actual = await read_register(dut, 5)

    assert actual == 0x1234_5678, (
        "Basic write/read failed for x5: "
        f"expected 0x12345678, received 0x{actual:08X}"
    )


@cocotb.test()
async def test_two_asynchronous_read_ports(dut) -> None:
    """Verify that two different registers can be read simultaneously."""
    await initialize_dut(dut)

    await write_register(dut, 7, 0x1111_2222)
    await write_register(dut, 18, 0xAAAA_5555)

    value_1, value_2 = await read_registers(dut, 7, 18)

    assert value_1 == 0x1111_2222, (
        f"Read port 1 failed: received 0x{value_1:08X}"
    )

    assert value_2 == 0xAAAA_5555, (
        f"Read port 2 failed: received 0x{value_2:08X}"
    )

    # Swap the selectors to verify that the ports are independent.
    value_1, value_2 = await read_registers(dut, 18, 7)

    assert value_1 == 0xAAAA_5555
    assert value_2 == 0x1111_2222


@cocotb.test()
async def test_asynchronous_read_behavior(dut) -> None:
    """Verify that changing a selector updates the output without a clock."""
    await initialize_dut(dut)

    await write_register(dut, 3, 0x0303_0303)
    await write_register(dut, 4, 0x0404_0404)

    dut.rsel1.value = 3
    await Timer(1, unit="ns")

    assert int(dut.rdat1.value) == 0x0303_0303

    # Change the selector without waiting for another clock edge.
    dut.rsel1.value = 4
    await Timer(1, unit="ns")

    assert int(dut.rdat1.value) == 0x0404_0404


@cocotb.test()
async def test_register_x0_is_constant_zero(dut) -> None:
    """Verify that writes to x0 are ignored."""
    await initialize_dut(dut)

    test_values = (
        0xFFFF_FFFF,
        0x1234_5678,
        0x8000_0000,
        0x0000_0001,
    )

    for value in test_values:
        await write_register(
            dut,
            register=0,
            value=value,
        )

        actual = await read_register(dut, 0)

        assert actual == 0, (
            "x0 changed after a write: "
            f"wrote 0x{value:08X}, read 0x{actual:08X}"
        )


@cocotb.test()
async def test_write_enable(dut) -> None:
    """Verify that no write occurs when WEN is deasserted."""
    await initialize_dut(dut)

    await write_register(
        dut,
        register=12,
        value=0xCAFE_BABE,
        enable=True,
    )

    await write_register(
        dut,
        register=12,
        value=0xDEAD_BEEF,
        enable=False,
    )

    actual = await read_register(dut, 12)

    assert actual == 0xCAFE_BABE, (
        "Register changed while WEN was zero: "
        f"expected 0xCAFEBABE, received 0x{actual:08X}"
    )


@cocotb.test()
async def test_register_overwrite(dut) -> None:
    """Verify that a register can be overwritten."""
    await initialize_dut(dut)

    await write_register(dut, 9, 0x1111_1111)

    first_value = await read_register(dut, 9)
    assert first_value == 0x1111_1111

    await write_register(dut, 9, 0x2222_2222)

    second_value = await read_register(dut, 9)

    assert second_value == 0x2222_2222, (
        "Register overwrite failed: "
        f"received 0x{second_value:08X}"
    )


@cocotb.test()
async def test_write_occurs_only_on_rising_edge(dut) -> None:
    """Verify that a write does not occur before the rising clock edge."""
    await initialize_dut(dut)

    register = 15
    value = 0xA5A5_5A5A

    await FallingEdge(dut.CLK)

    dut.WEN.value = 1
    dut.wsel.value = register
    dut.wdat.value = value

    # We are between clock edges, so the register must still be zero.
    await Timer(1, unit="ns")

    before_edge = await read_register(dut, register)

    assert before_edge == 0, (
        "Register changed before the rising edge: "
        f"received 0x{before_edge:08X}"
    )

    await RisingEdge(dut.CLK)
    await Timer(1, unit="ns")

    after_edge = await read_register(dut, register)

    assert after_edge == value, (
        "Register did not update on the rising edge: "
        f"expected 0x{value:08X}, received 0x{after_edge:08X}"
    )

    dut.WEN.value = 0


@cocotb.test()
async def test_register_independence(dut) -> None:
    """Verify that writing one register does not modify other registers."""
    await initialize_dut(dut)

    expected = [0] * NUM_REGISTERS

    for register in range(1, NUM_REGISTERS):
        value = u32(register * 0x0101_0101)

        await write_register(
            dut,
            register,
            value,
        )

        expected[register] = value

    for register in range(NUM_REGISTERS):
        actual = await read_register(dut, register)

        assert actual == expected[register], (
            f"x{register} changed unexpectedly: "
            f"expected 0x{expected[register]:08X}, "
            f"received 0x{actual:08X}"
        )


@cocotb.test()
async def test_reset_after_register_writes(dut) -> None:
    """Verify that asserting reset clears previously written values."""
    await initialize_dut(dut)

    await write_register(dut, 1, 0x1111_1111)
    await write_register(dut, 10, 0xAAAA_AAAA)
    await write_register(dut, 31, 0xFFFF_FFFF)

    # Assert asynchronous reset between clock edges.
    await FallingEdge(dut.CLK)
    dut.nRST.value = 0

    await Timer(1, unit="ns")

    for register in range(NUM_REGISTERS):
        actual = await read_register(dut, register)

        assert actual == 0, (
            f"x{register} was not cleared by reset: "
            f"received 0x{actual:08X}"
        )

    dut.nRST.value = 1

    await RisingEdge(dut.CLK)
    await Timer(1, unit="ns")


@cocotb.test()
async def test_randomized_register_file(dut) -> None:
    """Compare randomized register operations with a Python model."""
    await initialize_dut(dut)

    rng = random.Random(0x32_1F_11E)
    model = [0] * NUM_REGISTERS

    number_of_operations = 250

    for operation_number in range(number_of_operations):
        write_enable = bool(rng.getrandbits(1))
        write_register_index = rng.randrange(NUM_REGISTERS)
        write_data = rng.getrandbits(32)

        await FallingEdge(dut.CLK)

        dut.WEN.value = int(write_enable)
        dut.wsel.value = write_register_index
        dut.wdat.value = write_data

        await RisingEdge(dut.CLK)
        await Timer(1, unit="ns")

        if write_enable and write_register_index != 0:
            model[write_register_index] = u32(write_data)

        # x0 must always remain zero.
        model[0] = 0

        read_register_1 = rng.randrange(NUM_REGISTERS)
        read_register_2 = rng.randrange(NUM_REGISTERS)

        actual_1, actual_2 = await read_registers(
            dut,
            read_register_1,
            read_register_2,
        )

        expected_1 = model[read_register_1]
        expected_2 = model[read_register_2]

        assert actual_1 == expected_1, (
            f"Random operation {operation_number}: "
            f"x{read_register_1} mismatch: "
            f"expected 0x{expected_1:08X}, "
            f"received 0x{actual_1:08X}"
        )

        assert actual_2 == expected_2, (
            f"Random operation {operation_number}: "
            f"x{read_register_2} mismatch: "
            f"expected 0x{expected_2:08X}, "
            f"received 0x{actual_2:08X}"
        )

    dut.WEN.value = 0
    