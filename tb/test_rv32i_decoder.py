"""cocotb verification for the RV32I immediate decoder."""

from __future__ import annotations

import random

import cocotb
from cocotb.triggers import Timer


# ============================================================
# Immediate-type encodings
#
# These values must match imm_type_t in rv32i_pkg.sv.
# ============================================================

IMM_I = 0b000
IMM_S = 0b001
IMM_B = 0b010
IMM_U = 0b011
IMM_J = 0b100
IMM_NONE = 0b111


MASK_32 = 0xFFFF_FFFF


def u32(value: int) -> int:
    """Convert a Python integer to an unsigned 32-bit value."""
    return value & MASK_32


def sign_extend(value: int, width: int) -> int:
    """Sign-extend a value of the supplied width to 32 bits."""
    mask = (1 << width) - 1
    value &= mask

    sign_bit = 1 << (width - 1)

    if value & sign_bit:
        value -= 1 << width

    return u32(value)


# ============================================================
# Instruction encoding helpers
# ============================================================


def encode_i_type(immediate: int) -> int:
    """
    Encode a 12-bit I-type immediate.

    The lower instruction fields are filled with a representative
    ADDI instruction encoding.
    """
    immediate_bits = immediate & 0xFFF

    rd = 1
    funct3 = 0b000
    rs1 = 2
    opcode = 0b0010011

    return u32(
        (immediate_bits << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | opcode
    )


def encode_s_type(immediate: int) -> int:
    """Encode a 12-bit S-type immediate."""
    immediate_bits = immediate & 0xFFF

    immediate_11_5 = (immediate_bits >> 5) & 0x7F
    immediate_4_0 = immediate_bits & 0x1F

    rs2 = 3
    rs1 = 4
    funct3 = 0b010
    opcode = 0b0100011

    return u32(
        (immediate_11_5 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (immediate_4_0 << 7)
        | opcode
    )


def encode_b_type(immediate: int) -> int:
    """
    Encode a signed 13-bit B-type immediate.

    Branch offsets must be aligned to two bytes, so bit 0 is zero.
    """
    assert immediate % 2 == 0, "B-type immediate must be even"
    assert -4096 <= immediate <= 4094, (
        "B-type immediate must fit in signed 13 bits"
    )

    immediate_bits = immediate & 0x1FFF

    immediate_12 = (immediate_bits >> 12) & 0x1
    immediate_11 = (immediate_bits >> 11) & 0x1
    immediate_10_5 = (immediate_bits >> 5) & 0x3F
    immediate_4_1 = (immediate_bits >> 1) & 0xF

    rs2 = 5
    rs1 = 6
    funct3 = 0b000
    opcode = 0b1100011

    return u32(
        (immediate_12 << 31)
        | (immediate_10_5 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (immediate_4_1 << 8)
        | (immediate_11 << 7)
        | opcode
    )


def encode_u_type(upper_immediate: int) -> int:
    """
    Encode the 20-bit immediate field of a U-type instruction.

    Example:
        upper_immediate=0x12345 produces immediate 0x12345000.
    """
    assert 0 <= upper_immediate <= 0xFFFFF

    rd = 7
    opcode = 0b0110111

    return u32(
        (upper_immediate << 12)
        | (rd << 7)
        | opcode
    )


def encode_j_type(immediate: int) -> int:
    """
    Encode a signed 21-bit J-type immediate.

    Jump offsets must be aligned to two bytes, so bit 0 is zero.
    """
    assert immediate % 2 == 0, "J-type immediate must be even"
    assert -(1 << 20) <= immediate <= (1 << 20) - 2, (
        "J-type immediate must fit in signed 21 bits"
    )

    immediate_bits = immediate & 0x1F_FFFF

    immediate_20 = (immediate_bits >> 20) & 0x1
    immediate_19_12 = (immediate_bits >> 12) & 0xFF
    immediate_11 = (immediate_bits >> 11) & 0x1
    immediate_10_1 = (immediate_bits >> 1) & 0x3FF

    rd = 8
    opcode = 0b1101111

    return u32(
        (immediate_20 << 31)
        | (immediate_10_1 << 21)
        | (immediate_11 << 20)
        | (immediate_19_12 << 12)
        | (rd << 7)
        | opcode
    )


# ============================================================
# Reference decoder
# ============================================================


def reference_immediate(instruction: int, immediate_type: int) -> int:
    """Generate the expected immediate from an instruction."""
    instruction = u32(instruction)

    if immediate_type == IMM_I:
        raw_immediate = (instruction >> 20) & 0xFFF
        return sign_extend(raw_immediate, 12)

    if immediate_type == IMM_S:
        raw_immediate = (
            (((instruction >> 25) & 0x7F) << 5)
            | ((instruction >> 7) & 0x1F)
        )
        return sign_extend(raw_immediate, 12)

    if immediate_type == IMM_B:
        raw_immediate = (
            (((instruction >> 31) & 0x1) << 12)
            | (((instruction >> 7) & 0x1) << 11)
            | (((instruction >> 25) & 0x3F) << 5)
            | (((instruction >> 8) & 0xF) << 1)
        )
        return sign_extend(raw_immediate, 13)

    if immediate_type == IMM_U:
        return instruction & 0xFFFF_F000

    if immediate_type == IMM_J:
        raw_immediate = (
            (((instruction >> 31) & 0x1) << 20)
            | (((instruction >> 12) & 0xFF) << 12)
            | (((instruction >> 20) & 0x1) << 11)
            | (((instruction >> 21) & 0x3FF) << 1)
        )
        return sign_extend(raw_immediate, 21)

    return 0


async def check_immediate(
    dut,
    immediate_type: int,
    instruction: int,
    expected: int | None = None,
) -> None:
    """Drive one instruction and verify the generated immediate."""
    instruction = u32(instruction)

    if expected is None:
        expected = reference_immediate(
            instruction,
            immediate_type,
        )

    expected = u32(expected)

    dut.imm_type.value = immediate_type
    dut.instruction.value = instruction

    # The decoder is combinational.
    await Timer(1, unit="ns")

    actual = int(dut.immediate.value)

    assert actual == expected, (
        "Immediate mismatch:\n"
        f"  immediate type: {immediate_type:03b}\n"
        f"  instruction:    0x{instruction:08X}\n"
        f"  expected:       0x{expected:08X}\n"
        f"  actual:         0x{actual:08X}"
    )


# ============================================================
# Directed tests
# ============================================================


@cocotb.test()
async def test_i_type_positive_immediates(dut) -> None:
    """Verify positive I-type immediates."""
    test_values = (
        0,
        1,
        2,
        15,
        127,
        255,
        1024,
        2047,
    )

    for immediate in test_values:
        instruction = encode_i_type(immediate)

        await check_immediate(
            dut,
            IMM_I,
            instruction,
            immediate,
        )


@cocotb.test()
async def test_i_type_negative_immediates(dut) -> None:
    """Verify sign extension of negative I-type immediates."""
    test_values = (
        -1,
        -2,
        -16,
        -128,
        -256,
        -1024,
        -2048,
    )

    for immediate in test_values:
        instruction = encode_i_type(immediate)

        await check_immediate(
            dut,
            IMM_I,
            instruction,
            immediate,
        )


@cocotb.test()
async def test_s_type_immediates(dut) -> None:
    """Verify positive and negative S-type immediates."""
    test_values = (
        0,
        1,
        4,
        31,
        32,
        255,
        1024,
        2047,
        -1,
        -4,
        -32,
        -256,
        -2048,
    )

    for immediate in test_values:
        instruction = encode_s_type(immediate)

        await check_immediate(
            dut,
            IMM_S,
            instruction,
            immediate,
        )


@cocotb.test()
async def test_b_type_forward_offsets(dut) -> None:
    """Verify positive branch offsets."""
    test_values = (
        0,
        2,
        4,
        8,
        16,
        32,
        256,
        1024,
        2048,
        4094,
    )

    for immediate in test_values:
        instruction = encode_b_type(immediate)

        await check_immediate(
            dut,
            IMM_B,
            instruction,
            immediate,
        )


@cocotb.test()
async def test_b_type_backward_offsets(dut) -> None:
    """Verify negative branch offsets."""
    test_values = (
        -2,
        -4,
        -8,
        -16,
        -32,
        -256,
        -1024,
        -2048,
        -4096,
    )

    for immediate in test_values:
        instruction = encode_b_type(immediate)

        await check_immediate(
            dut,
            IMM_B,
            instruction,
            immediate,
        )


@cocotb.test()
async def test_u_type_immediates(dut) -> None:
    """Verify LUI/AUIPC-style upper immediates."""
    test_values = (
        0x00000,
        0x00001,
        0x12345,
        0x7FFFF,
        0x80000,
        0xABCDE,
        0xFFFFF,
    )

    for upper_immediate in test_values:
        instruction = encode_u_type(upper_immediate)
        expected = upper_immediate << 12

        await check_immediate(
            dut,
            IMM_U,
            instruction,
            expected,
        )


@cocotb.test()
async def test_j_type_forward_offsets(dut) -> None:
    """Verify positive JAL offsets."""
    test_values = (
        0,
        2,
        4,
        8,
        32,
        256,
        2048,
        65536,
        524288,
        1_048_574,
    )

    for immediate in test_values:
        instruction = encode_j_type(immediate)

        await check_immediate(
            dut,
            IMM_J,
            instruction,
            immediate,
        )


@cocotb.test()
async def test_j_type_backward_offsets(dut) -> None:
    """Verify negative JAL offsets."""
    test_values = (
        -2,
        -4,
        -8,
        -32,
        -256,
        -2048,
        -65536,
        -524288,
        -1_048_576,
    )

    for immediate in test_values:
        instruction = encode_j_type(immediate)

        await check_immediate(
            dut,
            IMM_J,
            instruction,
            immediate,
        )


@cocotb.test()
async def test_default_immediate_type(dut) -> None:
    """Verify that IMM_NONE produces zero."""
    test_instructions = (
        0x0000_0000,
        0xFFFF_FFFF,
        0x1234_5678,
        0x8000_0000,
    )

    for instruction in test_instructions:
        await check_immediate(
            dut,
            IMM_NONE,
            instruction,
            0,
        )


@cocotb.test()
async def test_unsupported_immediate_types(dut) -> None:
    """Verify that currently unsupported type values produce zero."""
    for immediate_type in (0b101, 0b110):
        await check_immediate(
            dut,
            immediate_type,
            0xFFFF_FFFF,
            0,
        )


@cocotb.test()
async def test_combinational_behavior(dut) -> None:
    """Verify that output changes without requiring a clock."""
    dut.imm_type.value = IMM_I
    dut.instruction.value = encode_i_type(10)

    await Timer(1, unit="ns")

    assert int(dut.immediate.value) == 10

    # Change the instruction without a clock edge.
    dut.instruction.value = encode_i_type(-25)

    await Timer(1, unit="ns")

    assert int(dut.immediate.value) == u32(-25)

    # Change both the instruction and the immediate format.
    dut.imm_type.value = IMM_U
    dut.instruction.value = encode_u_type(0xABCDE)

    await Timer(1, unit="ns")

    assert int(dut.immediate.value) == 0xABCDE000


# ============================================================
# Randomized tests
# ============================================================


@cocotb.test()
async def test_randomized_i_type(dut) -> None:
    """Randomized verification of signed 12-bit I immediates."""
    rng = random.Random(0x1_7A11)

    for _ in range(200):
        immediate = rng.randint(-2048, 2047)
        instruction = encode_i_type(immediate)

        await check_immediate(
            dut,
            IMM_I,
            instruction,
            immediate,
        )


@cocotb.test()
async def test_randomized_s_type(dut) -> None:
    """Randomized verification of signed 12-bit S immediates."""
    rng = random.Random(0x5_70AE)

    for _ in range(200):
        immediate = rng.randint(-2048, 2047)
        instruction = encode_s_type(immediate)

        await check_immediate(
            dut,
            IMM_S,
            instruction,
            immediate,
        )


@cocotb.test()
async def test_randomized_b_type(dut) -> None:
    """Randomized verification of signed branch offsets."""
    rng = random.Random(0xB_2A4C)

    for _ in range(200):
        # Generate an even value in the signed 13-bit range.
        immediate = rng.randrange(-4096, 4096, 2)
        instruction = encode_b_type(immediate)

        await check_immediate(
            dut,
            IMM_B,
            instruction,
            immediate,
        )


@cocotb.test()
async def test_randomized_u_type(dut) -> None:
    """Randomized verification of 20-bit upper immediates."""
    rng = random.Random(0xA_0C11)

    for _ in range(200):
        upper_immediate = rng.getrandbits(20)
        instruction = encode_u_type(upper_immediate)

        await check_immediate(
            dut,
            IMM_U,
            instruction,
            upper_immediate << 12,
        )


@cocotb.test()
async def test_randomized_j_type(dut) -> None:
    """Randomized verification of signed JAL offsets."""
    rng = random.Random(0x7_A1E5)

    for _ in range(200):
        immediate = rng.randrange(
            -(1 << 20),
            1 << 20,
            2,
        )

        instruction = encode_j_type(immediate)

        await check_immediate(
            dut,
            IMM_J,
            instruction,
            immediate,
        )