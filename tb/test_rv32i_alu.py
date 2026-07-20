"""cocotb verification for the RV32I combinational ALU."""

from __future__ import annotations

import random

import cocotb
from cocotb.handle import SimHandleBase
from cocotb.triggers import Timer


# ============================================================
# ALU operation encodings
# These values must match the enum in alu.sv.
# ============================================================

SLL = 0b0000
SRL = 0b0001
SRA = 0b0010
ADD = 0b0011
SUB = 0b0100
AND = 0b0101
OR = 0b0110
XOR = 0b0111
SLT = 0b1010
SLTU = 0b1011

MASK_32 = 0xFFFF_FFFF
SIGN_BIT = 0x8000_0000


def u32(value: int) -> int:
    """Convert a Python integer to an unsigned 32-bit value."""
    return value & MASK_32


def s32(value: int) -> int:
    """Interpret a 32-bit value as a signed two's-complement integer."""
    value &= MASK_32

    if value & SIGN_BIT:
        return value - (1 << 32)

    return value


def add_overflow(a: int, b: int, result: int) -> int:
    """Return 1 when signed 32-bit addition overflow occurred."""
    a_sign = (a >> 31) & 1
    b_sign = (b >> 31) & 1
    result_sign = (result >> 31) & 1

    return int((a_sign == b_sign) and (result_sign != a_sign))


def sub_overflow(a: int, b: int, result: int) -> int:
    """Return 1 when signed 32-bit subtraction overflow occurred."""
    a_sign = (a >> 31) & 1
    b_sign = (b >> 31) & 1
    result_sign = (result >> 31) & 1

    return int((a_sign != b_sign) and (result_sign != a_sign))


def sll_overflow(a: int, shift_amount: int) -> int:
    """
    Match the current RTL interpretation of SLL overflow.

    Overflow is asserted when one or more nonzero bits are shifted
    out of the most-significant side.
    """
    shift_amount &= 0x1F

    if shift_amount == 0:
        return 0

    shifted_out_bits = a >> (32 - shift_amount)
    return int(shifted_out_bits != 0)


def reference_alu(
    operation: int,
    operand_a: int,
    operand_b: int,
) -> tuple[int, int]:
    """
    Return the expected result and overflow flag.

    Returns:
        tuple:
            expected_result
            expected_overflow
    """
    a = u32(operand_a)
    b = u32(operand_b)
    shift_amount = b & 0x1F

    overflow = 0

    if operation == ADD:
        result = u32(a + b)
        overflow = add_overflow(a, b, result)

    elif operation == SUB:
        result = u32(a - b)
        overflow = sub_overflow(a, b, result)

    elif operation == SLL:
        result = u32(a << shift_amount)
        overflow = sll_overflow(a, shift_amount)

    elif operation == SRL:
        result = a >> shift_amount

    elif operation == SRA:
        result = u32(s32(a) >> shift_amount)

    elif operation == AND:
        result = a & b

    elif operation == OR:
        result = a | b

    elif operation == XOR:
        result = a ^ b

    elif operation == SLT:
        result = int(s32(a) < s32(b))

    elif operation == SLTU:
        result = int(a < b)

    else:
        result = 0

    return u32(result), overflow


def resolve_signal(dut: SimHandleBase, signal_name: str):
    """
    Find a signal inside the alu_if interface.

    Different simulators may expose interface signals differently.
    The first form is the expected Verilator hierarchy:
        dut.aluif.portA
    """
    try:
        interface = getattr(dut, "aluif")
        return getattr(interface, signal_name)
    except AttributeError:
        pass

    possible_names = (
        signal_name,
        f"aluif_{signal_name}",
        f"aluif__DOT__{signal_name}",
    )

    for possible_name in possible_names:
        try:
            return getattr(dut, possible_name)
        except AttributeError:
            continue

    visible_objects = [obj._name for obj in dut]

    raise AttributeError(
        f"Could not find ALU signal '{signal_name}'. "
        f"Visible DUT objects: {visible_objects}"
    )


class AluInterface:
    """Cocotb handles for the Verilator-compatible ALU wrapper."""

    def __init__(self, dut) -> None:
        self.port_a = dut.portA
        self.port_b = dut.portB
        self.alu_op = dut.aluop

        self.output = dut.output_port
        self.zero = dut.zero
        self.negative = dut.negative
        self.overflow = dut.overflow
        

async def check_operation(
    alu: AluInterface,
    operation: int,
    operand_a: int,
    operand_b: int,
) -> None:
    """Drive one ALU transaction and verify all visible outputs."""
    operand_a = u32(operand_a)
    operand_b = u32(operand_b)

    expected_result, expected_overflow = reference_alu(
        operation,
        operand_a,
        operand_b,
    )

    expected_zero = int(expected_result == 0)
    expected_negative = (expected_result >> 31) & 1

    alu.port_a.value = operand_a
    alu.port_b.value = operand_b
    alu.alu_op.value = operation

    # The ALU is combinational, so no clock is required.
    await Timer(1, unit="ns")

    actual_result = int(alu.output.value)
    actual_zero = int(alu.zero.value)
    actual_negative = int(alu.negative.value)
    actual_overflow = int(alu.overflow.value)

    operation_name = {
        SLL: "SLL",
        SRL: "SRL",
        SRA: "SRA",
        ADD: "ADD",
        SUB: "SUB",
        AND: "AND",
        OR: "OR",
        XOR: "XOR",
        SLT: "SLT",
        SLTU: "SLTU",
    }.get(operation, f"UNKNOWN({operation:#x})")

    context = (
        f"{operation_name}: "
        f"A=0x{operand_a:08X}, "
        f"B=0x{operand_b:08X}"
    )

    assert actual_result == expected_result, (
        f"{context}: result mismatch: "
        f"expected 0x{expected_result:08X}, "
        f"received 0x{actual_result:08X}"
    )

    assert actual_zero == expected_zero, (
        f"{context}: zero mismatch: "
        f"expected {expected_zero}, received {actual_zero}"
    )

    assert actual_negative == expected_negative, (
        f"{context}: negative mismatch: "
        f"expected {expected_negative}, received {actual_negative}"
    )

    assert actual_overflow == expected_overflow, (
        f"{context}: overflow mismatch: "
        f"expected {expected_overflow}, "
        f"received {actual_overflow}"
    )


@cocotb.test()
async def test_basic_arithmetic(dut: SimHandleBase) -> None:
    """Verify representative ADD and SUB operations."""
    alu = AluInterface(dut)

    test_vectors = (
        (ADD, 10, 20),
        (ADD, 0, 0),
        (ADD, 0xFFFF_FFFF, 1),
        (ADD, 0x1234_5678, 0x1111_1111),
        (SUB, 20, 10),
        (SUB, 10, 20),
        (SUB, 0, 0),
        (SUB, 0, 1),
        (SUB, 0x8000_0000, 1),
    )

    for operation, operand_a, operand_b in test_vectors:
        await check_operation(
            alu,
            operation,
            operand_a,
            operand_b,
        )


@cocotb.test()
async def test_logic_operations(dut: SimHandleBase) -> None:
    """Verify AND, OR, and XOR."""
    alu = AluInterface(dut)

    test_vectors = (
        (AND, 0xFFFF_0000, 0x0F0F_0F0F),
        (AND, 0xFFFF_FFFF, 0x0000_0000),
        (OR, 0xFFFF_0000, 0x0000_FFFF),
        (OR, 0x0000_0000, 0x0000_0000),
        (XOR, 0xAAAA_AAAA, 0x5555_5555),
        (XOR, 0x1234_5678, 0x1234_5678),
    )

    for operation, operand_a, operand_b in test_vectors:
        await check_operation(
            alu,
            operation,
            operand_a,
            operand_b,
        )


@cocotb.test()
async def test_shift_operations(dut: SimHandleBase) -> None:
    """Verify logical and arithmetic shifts."""
    alu = AluInterface(dut)

    test_vectors = (
        (SLL, 0x0000_0001, 1),
        (SLL, 0x0000_0001, 31),
        (SLL, 0x8000_0000, 1),
        (SRL, 0x8000_0000, 1),
        (SRL, 0xFFFF_FFFF, 4),
        (SRA, 0x8000_0000, 1),
        (SRA, 0xFFFF_FFF0, 4),
        (SRA, 0x7FFF_FFFF, 4),
    )

    for operation, operand_a, operand_b in test_vectors:
        await check_operation(
            alu,
            operation,
            operand_a,
            operand_b,
        )


@cocotb.test()
async def test_shift_amount_is_five_bits(dut: SimHandleBase) -> None:
    """
    Verify that only portB[4:0] controls the shift amount.

    A shift by 32 must behave like a shift by 0.
    A shift by 33 must behave like a shift by 1.
    """
    alu = AluInterface(dut)

    test_vectors = (
        (SLL, 0x1234_5678, 32),
        (SLL, 0x1234_5678, 33),
        (SRL, 0x8765_4321, 32),
        (SRL, 0x8765_4321, 33),
        (SRA, 0x8765_4321, 32),
        (SRA, 0x8765_4321, 33),
        (SLL, 0x0000_0001, 0xFFFF_FFFF),
    )

    for operation, operand_a, operand_b in test_vectors:
        await check_operation(
            alu,
            operation,
            operand_a,
            operand_b,
        )


@cocotb.test()
async def test_signed_and_unsigned_comparisons(
    dut: SimHandleBase,
) -> None:
    """Demonstrate the difference between SLT and SLTU."""
    alu = AluInterface(dut)

    test_vectors = (
        # -1 < 1 when interpreted as signed.
        (SLT, 0xFFFF_FFFF, 0x0000_0001),

        # 0xFFFFFFFF is greater than 1 when interpreted unsigned.
        (SLTU, 0xFFFF_FFFF, 0x0000_0001),

        # INT_MIN is less than zero in signed arithmetic.
        (SLT, 0x8000_0000, 0x0000_0000),

        # 0x80000000 is greater than zero as an unsigned number.
        (SLTU, 0x8000_0000, 0x0000_0000),

        (SLT, 5, 10),
        (SLTU, 5, 10),
        (SLT, 10, 5),
        (SLTU, 10, 5),
        (SLT, 10, 10),
        (SLTU, 10, 10),
    )

    for operation, operand_a, operand_b in test_vectors:
        await check_operation(
            alu,
            operation,
            operand_a,
            operand_b,
        )


@cocotb.test()
async def test_zero_and_negative_flags(dut: SimHandleBase) -> None:
    """Verify zero and negative flags using representative results."""
    alu = AluInterface(dut)

    test_vectors = (
        (ADD, 0, 0),
        (SUB, 1, 1),
        (XOR, 0xAAAA_AAAA, 0xAAAA_AAAA),
        (AND, 0xFFFF_0000, 0x0000_FFFF),
        (ADD, 0x7FFF_FFFF, 1),
        (SUB, 0, 1),
        (SLL, 1, 31),
    )

    for operation, operand_a, operand_b in test_vectors:
        await check_operation(
            alu,
            operation,
            operand_a,
            operand_b,
        )


@cocotb.test()
async def test_signed_overflow(dut: SimHandleBase) -> None:
    """Verify important signed ADD and SUB overflow cases."""
    alu = AluInterface(dut)

    test_vectors = (
        # Maximum positive integer + 1.
        (ADD, 0x7FFF_FFFF, 0x0000_0001),

        # Minimum negative integer + (-1).
        (ADD, 0x8000_0000, 0xFFFF_FFFF),

        # No signed overflow.
        (ADD, 0xFFFF_FFFF, 0x0000_0001),

        # Maximum positive integer - (-1).
        (SUB, 0x7FFF_FFFF, 0xFFFF_FFFF),

        # Minimum negative integer - 1.
        (SUB, 0x8000_0000, 0x0000_0001),

        # This catches the INT_MIN two's-complement corner case.
        (SUB, 0x0000_0000, 0x8000_0000),

        # No signed overflow.
        (SUB, 10, 5),
    )

    for operation, operand_a, operand_b in test_vectors:
        await check_operation(
            alu,
            operation,
            operand_a,
            operand_b,
        )


@cocotb.test()
async def test_default_operation(dut: SimHandleBase) -> None:
    """Verify that an unsupported ALU operation produces zero."""
    alu = AluInterface(dut)

    await check_operation(
        alu,
        operation=0b1111,
        operand_a=0x1234_5678,
        operand_b=0x8765_4321,
    )


@cocotb.test()
async def test_randomized_operations(dut: SimHandleBase) -> None:
    """Run randomized differential testing against the Python model."""
    alu = AluInterface(dut)

    rng = random.Random(0xA1_32_1A)

    operations = (
        SLL,
        SRL,
        SRA,
        ADD,
        SUB,
        AND,
        OR,
        XOR,
        SLT,
        SLTU,
    )

    iterations_per_operation = 100

    for operation in operations:
        for _ in range(iterations_per_operation):
            operand_a = rng.getrandbits(32)
            operand_b = rng.getrandbits(32)

            await check_operation(
                alu,
                operation,
                operand_a,
                operand_b,
            )