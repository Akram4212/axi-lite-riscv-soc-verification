"""cocotb verification for the integrated RV32I decoder."""

from __future__ import annotations

import random
from typing import Any

import cocotb
from cocotb.triggers import Timer


# ============================================================
# Constants from rv32i_pkg.sv
# ============================================================

# Opcodes
OP_RTYPE = 0b0110011
OP_ITYPE = 0b0010011
OP_LOAD = 0b0000011
OP_JALR = 0b1100111
OP_STORE = 0b0100011
OP_BRANCH = 0b1100011
OP_JAL = 0b1101111
OP_LUI = 0b0110111
OP_AUIPC = 0b0010111
OP_MISC_MEM = 0b0001111
OP_SYSTEM = 0b1110011

# ALU operations
ALU_SLL = 0b0000
ALU_SRL = 0b0001
ALU_SRA = 0b0010
ALU_ADD = 0b0011
ALU_SUB = 0b0100
ALU_AND = 0b0101
ALU_OR = 0b0110
ALU_XOR = 0b0111
ALU_SLT = 0b1010
ALU_SLTU = 0b1011

MASK_32 = 0xFFFF_FFFF


DECODER_OUTPUTS = (
    "rsel1",
    "rsel2",
    "wsel",
    "immediate",
    "aluop",
    "opcode",
    "funct3",
    "funct7",
    "WEN",
    "AluSrcA",
    "AluSrcB",
    "MemtoReg",
    "PCtoReg",
    "PCsrc",
    "PCj",
    "dmemREN",
    "dmemWEN",
    "CareIfZero",
    "CareIfNotZero",
    "fence",
    "ecall",
    "ebreak",
    "halt",
    "sync",
    "illegal",
)


def u32(value: int) -> int:
    """Limit a Python integer to 32 bits."""
    return value & MASK_32


def sign_extend(value: int, width: int) -> int:
    """Sign-extend a value to 32 bits."""
    value &= (1 << width) - 1
    sign_bit = 1 << (width - 1)

    if value & sign_bit:
        value -= 1 << width

    return u32(value)


# ============================================================
# Instruction encoders
# ============================================================


def encode_r(
    *,
    funct7: int,
    rs2: int,
    rs1: int,
    funct3: int,
    rd: int,
) -> int:
    """Encode an R-type instruction."""
    return u32(
        ((funct7 & 0x7F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | OP_RTYPE
    )


def encode_i(
    *,
    immediate: int,
    rs1: int,
    funct3: int,
    rd: int,
    opcode: int = OP_ITYPE,
) -> int:
    """Encode an I-type instruction."""
    return u32(
        ((immediate & 0xFFF) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def encode_s(
    *,
    immediate: int,
    rs2: int,
    rs1: int,
    funct3: int,
) -> int:
    """Encode an S-type instruction."""
    immediate &= 0xFFF

    immediate_11_5 = (immediate >> 5) & 0x7F
    immediate_4_0 = immediate & 0x1F

    return u32(
        (immediate_11_5 << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | (immediate_4_0 << 7)
        | OP_STORE
    )


def encode_b(
    *,
    immediate: int,
    rs2: int,
    rs1: int,
    funct3: int,
) -> int:
    """Encode a B-type instruction."""
    assert immediate % 2 == 0
    assert -4096 <= immediate <= 4094

    immediate &= 0x1FFF

    imm12 = (immediate >> 12) & 0x1
    imm11 = (immediate >> 11) & 0x1
    imm10_5 = (immediate >> 5) & 0x3F
    imm4_1 = (immediate >> 1) & 0xF

    return u32(
        (imm12 << 31)
        | (imm10_5 << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | (imm4_1 << 8)
        | (imm11 << 7)
        | OP_BRANCH
    )


def encode_u(
    *,
    upper_immediate: int,
    rd: int,
    opcode: int,
) -> int:
    """Encode a U-type instruction."""
    return u32(
        ((upper_immediate & 0xFFFFF) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def encode_j(
    *,
    immediate: int,
    rd: int,
) -> int:
    """Encode a J-type instruction."""
    assert immediate % 2 == 0
    assert -(1 << 20) <= immediate <= (1 << 20) - 2

    immediate &= 0x1F_FFFF

    imm20 = (immediate >> 20) & 0x1
    imm19_12 = (immediate >> 12) & 0xFF
    imm11 = (immediate >> 11) & 0x1
    imm10_1 = (immediate >> 1) & 0x3FF

    return u32(
        (imm20 << 31)
        | (imm10_1 << 21)
        | (imm11 << 20)
        | (imm19_12 << 12)
        | ((rd & 0x1F) << 7)
        | OP_JAL
    )


# ============================================================
# Reference immediate generation
# ============================================================


def i_immediate(instruction: int) -> int:
    return sign_extend((instruction >> 20) & 0xFFF, 12)


def s_immediate(instruction: int) -> int:
    raw = (
        (((instruction >> 25) & 0x7F) << 5)
        | ((instruction >> 7) & 0x1F)
    )
    return sign_extend(raw, 12)


def b_immediate(instruction: int) -> int:
    raw = (
        (((instruction >> 31) & 0x1) << 12)
        | (((instruction >> 7) & 0x1) << 11)
        | (((instruction >> 25) & 0x3F) << 5)
        | (((instruction >> 8) & 0xF) << 1)
    )
    return sign_extend(raw, 13)


def u_immediate(instruction: int) -> int:
    return instruction & 0xFFFF_F000


def j_immediate(instruction: int) -> int:
    raw = (
        (((instruction >> 31) & 0x1) << 20)
        | (((instruction >> 12) & 0xFF) << 12)
        | (((instruction >> 20) & 0x1) << 11)
        | (((instruction >> 21) & 0x3FF) << 1)
    )
    return sign_extend(raw, 21)


# ============================================================
# Expected-output model
# ============================================================


def default_expected(instruction: int) -> dict[str, int]:
    """Return default decoder outputs based on raw fields."""
    instruction = u32(instruction)

    return {
        "rsel1": (instruction >> 15) & 0x1F,
        "rsel2": (instruction >> 20) & 0x1F,
        "wsel": (instruction >> 7) & 0x1F,
        "immediate": 0,
        "aluop": ALU_ADD,
        "opcode": instruction & 0x7F,
        "funct3": (instruction >> 12) & 0x7,
        "funct7": (instruction >> 25) & 0x7F,
        "WEN": 0,
        "AluSrcA": 0,
        "AluSrcB": 0,
        "MemtoReg": 0,
        "PCtoReg": 0,
        "PCsrc": 0,
        "PCj": 0,
        "dmemREN": 0,
        "dmemWEN": 0,
        "CareIfZero": 0,
        "CareIfNotZero": 0,
        "fence": 0,
        "ecall": 0,
        "ebreak": 0,
        "halt": 0,
        "sync": 0,
        "illegal": 0,
    }


async def check_decode(
    dut,
    instruction: int,
    expected_updates: dict[str, int],
    description: str,
) -> None:
    """Drive one instruction and verify every decoder output."""
    instruction = u32(instruction)

    expected = default_expected(instruction)
    expected.update(expected_updates)

    dut.instruction.value = instruction
    await Timer(1, unit="ns")

    for signal_name in DECODER_OUTPUTS:
        signal = getattr(dut, signal_name)
        actual = int(signal.value)
        expected_value = expected[signal_name]

        assert actual == expected_value, (
            f"{description}: {signal_name} mismatch\n"
            f"  instruction: 0x{instruction:08X}\n"
            f"  expected:    0x{expected_value:X}\n"
            f"  actual:      0x{actual:X}"
        )


# ============================================================
# R-type tests
# ============================================================


@cocotb.test()
async def test_rtype_instructions(dut) -> None:
    """Verify all base RV32I register-register operations."""
    vectors = (
        ("ADD", 0b000, 0b0000000, ALU_ADD),
        ("SUB", 0b000, 0b0100000, ALU_SUB),
        ("SLL", 0b001, 0b0000000, ALU_SLL),
        ("SLT", 0b010, 0b0000000, ALU_SLT),
        ("SLTU", 0b011, 0b0000000, ALU_SLTU),
        ("XOR", 0b100, 0b0000000, ALU_XOR),
        ("SRL", 0b101, 0b0000000, ALU_SRL),
        ("SRA", 0b101, 0b0100000, ALU_SRA),
        ("OR", 0b110, 0b0000000, ALU_OR),
        ("AND", 0b111, 0b0000000, ALU_AND),
    )

    for name, funct3, funct7, expected_aluop in vectors:
        instruction = encode_r(
            funct7=funct7,
            rs2=9,
            rs1=6,
            funct3=funct3,
            rd=11,
        )

        await check_decode(
            dut,
            instruction,
            {
                "WEN": 1,
                "aluop": expected_aluop,
            },
            name,
        )


# ============================================================
# I-type arithmetic tests
# ============================================================


@cocotb.test()
async def test_itype_arithmetic_instructions(dut) -> None:
    """Verify RV32I register-immediate ALU decoding."""
    vectors = (
        ("ADDI", 0b000, 0xFED, ALU_ADD),
        ("SLTI", 0b010, 0xFED, ALU_SLT),
        ("SLTIU", 0b011, 0x123, ALU_SLTU),
        ("XORI", 0b100, 0x123, ALU_XOR),
        ("ORI", 0b110, 0x123, ALU_OR),
        ("ANDI", 0b111, 0x123, ALU_AND),
        ("SLLI", 0b001, 0b0000000_00101, ALU_SLL),
        ("SRLI", 0b101, 0b0000000_00101, ALU_SRL),
        ("SRAI", 0b101, 0b0100000_00101, ALU_SRA),
    )

    for name, funct3, raw_immediate, expected_aluop in vectors:
        instruction = encode_i(
            immediate=raw_immediate,
            rs1=7,
            funct3=funct3,
            rd=12,
        )

        await check_decode(
            dut,
            instruction,
            {
                "rsel2": 0,
                "immediate": i_immediate(instruction),
                "aluop": expected_aluop,
                "WEN": 1,
                "AluSrcB": 1,
            },
            name,
        )


# ============================================================
# Load/store tests
# ============================================================


@cocotb.test()
async def test_load_instructions(dut) -> None:
    """Verify all supported RV32I load instruction controls."""
    loads = (
        ("LB", 0b000),
        ("LH", 0b001),
        ("LW", 0b010),
        ("LBU", 0b100),
        ("LHU", 0b101),
    )

    for name, funct3 in loads:
        instruction = encode_i(
            immediate=-16,
            rs1=8,
            funct3=funct3,
            rd=14,
            opcode=OP_LOAD,
        )

        await check_decode(
            dut,
            instruction,
            {
                "rsel2": 0,
                "immediate": i_immediate(instruction),
                "aluop": ALU_ADD,
                "WEN": 1,
                "AluSrcB": 1,
                "MemtoReg": 1,
                "dmemREN": 1,
            },
            name,
        )


@cocotb.test()
async def test_store_instructions(dut) -> None:
    """Verify all supported RV32I store instruction controls."""
    stores = (
        ("SB", 0b000),
        ("SH", 0b001),
        ("SW", 0b010),
    )

    for name, funct3 in stores:
        instruction = encode_s(
            immediate=-32,
            rs2=15,
            rs1=10,
            funct3=funct3,
        )

        await check_decode(
            dut,
            instruction,
            {
                "wsel": 0,
                "immediate": s_immediate(instruction),
                "aluop": ALU_ADD,
                "AluSrcB": 1,
                "dmemWEN": 1,
            },
            name,
        )


# ============================================================
# Branch tests
# ============================================================


@cocotb.test()
async def test_branch_instructions(dut) -> None:
    """Verify branch ALU operations and branch-result controls."""
    branches = (
        ("BEQ", 0b000, ALU_SUB, "CareIfZero"),
        ("BNE", 0b001, ALU_SUB, "CareIfNotZero"),
        ("BLT", 0b100, ALU_SLT, "CareIfNotZero"),
        ("BGE", 0b101, ALU_SLT, "CareIfZero"),
        ("BLTU", 0b110, ALU_SLTU, "CareIfNotZero"),
        ("BGEU", 0b111, ALU_SLTU, "CareIfZero"),
    )

    for name, funct3, expected_aluop, condition_signal in branches:
        instruction = encode_b(
            immediate=-64,
            rs2=4,
            rs1=3,
            funct3=funct3,
        )

        expected = {
            "wsel": 0,
            "immediate": b_immediate(instruction),
            "aluop": expected_aluop,
            condition_signal: 1,
        }

        await check_decode(
            dut,
            instruction,
            expected,
            name,
        )


# ============================================================
# Jump and upper-immediate tests
# ============================================================


@cocotb.test()
async def test_jal(dut) -> None:
    instruction = encode_j(
        immediate=-2048,
        rd=1,
    )

    await check_decode(
        dut,
        instruction,
        {
            "rsel1": 0,
            "rsel2": 0,
            "immediate": j_immediate(instruction),
            "WEN": 1,
            "PCtoReg": 1,
            "PCsrc": 1,
        },
        "JAL",
    )


@cocotb.test()
async def test_jalr(dut) -> None:
    instruction = encode_i(
        immediate=24,
        rs1=5,
        funct3=0b000,
        rd=1,
        opcode=OP_JALR,
    )

    await check_decode(
        dut,
        instruction,
        {
            "rsel2": 0,
            "immediate": i_immediate(instruction),
            "aluop": ALU_ADD,
            "WEN": 1,
            "AluSrcB": 1,
            "PCtoReg": 1,
            "PCj": 1,
        },
        "JALR",
    )


@cocotb.test()
async def test_lui_and_auipc(dut) -> None:
    lui_instruction = encode_u(
        upper_immediate=0xABCDE,
        rd=20,
        opcode=OP_LUI,
    )

    await check_decode(
        dut,
        lui_instruction,
        {
            "rsel1": 0,
            "rsel2": 0,
            "immediate": u_immediate(lui_instruction),
            "aluop": ALU_ADD,
            "WEN": 1,
            "AluSrcB": 1,
        },
        "LUI",
    )

    auipc_instruction = encode_u(
        upper_immediate=0x12345,
        rd=21,
        opcode=OP_AUIPC,
    )

    await check_decode(
        dut,
        auipc_instruction,
        {
            "rsel1": 0,
            "rsel2": 0,
            "immediate": u_immediate(auipc_instruction),
            "aluop": ALU_ADD,
            "WEN": 1,
            "AluSrcA": 1,
            "AluSrcB": 1,
        },
        "AUIPC",
    )


# ============================================================
# System instruction tests
# ============================================================


@cocotb.test()
async def test_fence(dut) -> None:
    instruction = encode_i(
        immediate=0,
        rs1=0,
        funct3=0,
        rd=0,
        opcode=OP_MISC_MEM,
    )

    await check_decode(
        dut,
        instruction,
        {
            "rsel1": 0,
            "rsel2": 0,
            "wsel": 0,
            "fence": 1,
        },
        "FENCE",
    )


@cocotb.test()
async def test_ecall_and_ebreak(dut) -> None:
    await check_decode(
        dut,
        0x0000_0073,
        {
            "rsel1": 0,
            "rsel2": 0,
            "wsel": 0,
            "ecall": 1,
        },
        "ECALL",
    )

    await check_decode(
        dut,
        0x0010_0073,
        {
            "rsel1": 0,
            "rsel2": 0,
            "wsel": 0,
            "ebreak": 1,
            "halt": 1,
        },
        "EBREAK",
    )


# ============================================================
# Illegal instruction tests
# ============================================================


@cocotb.test()
async def test_illegal_opcode(dut) -> None:
    instruction = 0xFFFF_FFFF

    await check_decode(
        dut,
        instruction,
        {
            "illegal": 1,
        },
        "illegal opcode",
    )


@cocotb.test()
async def test_illegal_rtype_funct7(dut) -> None:
    instruction = encode_r(
        funct7=0b1111111,
        rs2=2,
        rs1=1,
        funct3=0b000,
        rd=3,
    )

    await check_decode(
        dut,
        instruction,
        {
            "WEN": 0,
            "illegal": 1,
        },
        "illegal R-type funct7",
    )


@cocotb.test()
async def test_illegal_load_store_and_branch(dut) -> None:
    illegal_load = encode_i(
        immediate=4,
        rs1=1,
        funct3=0b111,
        rd=2,
        opcode=OP_LOAD,
    )

    await check_decode(
        dut,
        illegal_load,
        {
            "rsel2": 0,
            "immediate": i_immediate(illegal_load),
            "AluSrcB": 1,
            "MemtoReg": 1,
            "illegal": 1,
        },
        "illegal load",
    )

    illegal_store = encode_s(
        immediate=8,
        rs2=2,
        rs1=1,
        funct3=0b111,
    )

    await check_decode(
        dut,
        illegal_store,
        {
            "wsel": 0,
            "immediate": s_immediate(illegal_store),
            "AluSrcB": 1,
            "illegal": 1,
        },
        "illegal store",
    )

    illegal_branch = encode_b(
        immediate=16,
        rs2=2,
        rs1=1,
        funct3=0b010,
    )

    await check_decode(
        dut,
        illegal_branch,
        {
            "wsel": 0,
            "immediate": b_immediate(illegal_branch),
            "illegal": 1,
        },
        "illegal branch",
    )


@cocotb.test()
async def test_illegal_jalr_and_system(dut) -> None:
    illegal_jalr = encode_i(
        immediate=4,
        rs1=1,
        funct3=0b001,
        rd=2,
        opcode=OP_JALR,
    )

    await check_decode(
        dut,
        illegal_jalr,
        {
            "rsel2": 0,
            "immediate": i_immediate(illegal_jalr),
            "AluSrcB": 1,
            "PCtoReg": 1,
            "illegal": 1,
        },
        "illegal JALR",
    )

    unsupported_csr = 0x0010_1073

    await check_decode(
        dut,
        unsupported_csr,
        {
            "rsel1": 0,
            "rsel2": 0,
            "wsel": 0,
            "illegal": 1,
        },
        "unsupported CSR",
    )


# ============================================================
# Randomized field and immediate tests
# ============================================================


@cocotb.test()
async def test_randomized_itype_immediates(dut) -> None:
    rng = random.Random(0xDEC0_DE01)

    for operation_number in range(100):
        immediate = rng.randint(-2048, 2047)
        rs1 = rng.randrange(32)
        rd = rng.randrange(32)

        instruction = encode_i(
            immediate=immediate,
            rs1=rs1,
            funct3=0b000,
            rd=rd,
        )

        await check_decode(
            dut,
            instruction,
            {
                "rsel2": 0,
                "immediate": u32(immediate),
                "aluop": ALU_ADD,
                "WEN": 1,
                "AluSrcB": 1,
            },
            f"random ADDI operation {operation_number}",
        )


@cocotb.test()
async def test_randomized_branch_immediates(dut) -> None:
    rng = random.Random(0xB12A_C001)

    for operation_number in range(100):
        immediate = rng.randrange(-4096, 4096, 2)
        rs1 = rng.randrange(32)
        rs2 = rng.randrange(32)

        instruction = encode_b(
            immediate=immediate,
            rs2=rs2,
            rs1=rs1,
            funct3=0b000,
        )

        await check_decode(
            dut,
            instruction,
            {
                "wsel": 0,
                "immediate": u32(immediate),
                "aluop": ALU_SUB,
                "CareIfZero": 1,
            },
            f"random BEQ operation {operation_number}",
        )
        