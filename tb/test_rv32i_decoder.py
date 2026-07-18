"""Coverage-focused cocotb tests for the integrated RV32I decoder.

Expected top level:
    rv32i_decoder_wrapper

The wrapper is expected to expose these decoder signals as ordinary ports:

Input:
    instruction

Decoded fields:
    opcode, wsel, funct3, rsel1, rsel2, funct7

Immediate / ALU:
    immediate, aluop

Control:
    WEN, AluSrcA, AluSrcB
    MemtoReg, PCtoReg
    PCsrc, PCj
    dmemREN, dmemWEN
    CareIfZero, CareIfNotZero
    fence, ecall, ebreak, halt, sync, illegal

The suite covers:
    * Every valid instruction form implemented by rv32i_decoder.sv
    * Every illegal/default decode path
    * Positive and negative immediate generation
    * Illegal-instruction side-effect suppression
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

import cocotb
from cocotb.triggers import Timer


# =============================================================================
# RV32I opcodes
# =============================================================================

OP_LOAD = 0b0000011
OP_MISC_MEM = 0b0001111
OP_IMM = 0b0010011
OP_AUIPC = 0b0010111
OP_STORE = 0b0100011
OP_REG = 0b0110011
OP_LUI = 0b0110111
OP_BRANCH = 0b1100011
OP_JALR = 0b1100111
OP_JAL = 0b1101111
OP_SYSTEM = 0b1110011


# =============================================================================
# ALU operation encodings from rv32i_pkg.sv
# =============================================================================

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


def u32(value: int) -> int:
    return value & MASK_32


def sign_extend(value: int, width: int) -> int:
    value &= (1 << width) - 1
    sign_bit = 1 << (width - 1)

    if value & sign_bit:
        value -= 1 << width

    return u32(value)


# =============================================================================
# Generic RV32I instruction encoders
# =============================================================================


def encode_r(
    *,
    funct7: int,
    rs2: int,
    rs1: int,
    funct3: int,
    rd: int,
    opcode: int = OP_REG,
) -> int:
    return u32(
        ((funct7 & 0x7F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def encode_i(
    *,
    immediate: int,
    rs1: int,
    funct3: int,
    rd: int,
    opcode: int = OP_IMM,
) -> int:
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
    opcode: int = OP_STORE,
) -> int:
    immediate_bits = immediate & 0xFFF

    return u32(
        (((immediate_bits >> 5) & 0x7F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((immediate_bits & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def encode_b(
    *,
    immediate: int,
    rs2: int,
    rs1: int,
    funct3: int,
    opcode: int = OP_BRANCH,
) -> int:
    assert immediate % 2 == 0
    assert -4096 <= immediate <= 4094

    immediate_bits = immediate & 0x1FFF

    return u32(
        (((immediate_bits >> 12) & 0x1) << 31)
        | (((immediate_bits >> 5) & 0x3F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | (((immediate_bits >> 1) & 0xF) << 8)
        | (((immediate_bits >> 11) & 0x1) << 7)
        | (opcode & 0x7F)
    )


def encode_u(
    *,
    upper_immediate: int,
    rd: int,
    opcode: int,
) -> int:
    return u32(
        ((upper_immediate & 0xFFFFF) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def encode_j(
    *,
    immediate: int,
    rd: int,
    opcode: int = OP_JAL,
) -> int:
    assert immediate % 2 == 0
    assert -(1 << 20) <= immediate <= (1 << 20) - 2

    immediate_bits = immediate & 0x1F_FFFF

    return u32(
        (((immediate_bits >> 20) & 0x1) << 31)
        | (((immediate_bits >> 1) & 0x3FF) << 21)
        | (((immediate_bits >> 11) & 0x1) << 20)
        | (((immediate_bits >> 12) & 0xFF) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


# =============================================================================
# DUT access and checking helpers
# =============================================================================


_SIGNAL_ALIASES: dict[str, tuple[str, ...]] = {
    "WEN": ("WEN", "wen"),
    "AluSrcA": ("AluSrcA", "alu_src_a", "alusrca"),
    "AluSrcB": ("AluSrcB", "alu_src_b", "alusrcb"),
    "MemtoReg": ("MemtoReg", "mem_to_reg", "memtoreg"),
    "PCtoReg": ("PCtoReg", "pc_to_reg", "pctoreg"),
    "PCsrc": ("PCsrc", "pc_src", "pcsrc"),
    "PCj": ("PCj", "pc_j", "pcj"),
    "CareIfZero": ("CareIfZero", "care_if_zero", "careifzero"),
    "CareIfNotZero": (
        "CareIfNotZero",
        "care_if_not_zero",
        "careifnotzero",
    ),
}


def get_signal(dut: Any, name: str) -> Any:
    candidates = _SIGNAL_ALIASES.get(name, (name, name.lower()))

    for candidate in candidates:
        if hasattr(dut, candidate):
            return getattr(dut, candidate)

    available = sorted(
        item
        for item in dir(dut)
        if not item.startswith("_")
    )

    raise AttributeError(
        f"Decoder wrapper does not expose signal '{name}'.\n"
        f"Tried aliases: {candidates}\n"
        f"Available handles: {available}"
    )


def signal_value(dut: Any, name: str) -> int:
    return int(get_signal(dut, name).value)


def common_fields(instruction: int) -> dict[str, int]:
    return {
        "opcode": instruction & 0x7F,
        "funct3": (instruction >> 12) & 0x7,
        "funct7": (instruction >> 25) & 0x7F,
    }


CONTROL_DEFAULTS: dict[str, int] = {
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


async def apply_instruction(dut: Any, instruction: int) -> None:
    get_signal(dut, "instruction").value = u32(instruction)
    await Timer(1, unit="ns")


async def check_decode(
    dut: Any,
    *,
    name: str,
    instruction: int,
    expected: Mapping[str, int],
    check_control_defaults: bool = True,
) -> None:
    await apply_instruction(dut, instruction)

    complete_expected: dict[str, int] = {}

    if check_control_defaults:
        complete_expected.update(CONTROL_DEFAULTS)

    complete_expected.update(common_fields(instruction))
    complete_expected.update(expected)

    errors: list[str] = []

    for signal_name, expected_value in complete_expected.items():
        actual_value = signal_value(dut, signal_name)

        if actual_value != expected_value:
            errors.append(
                f"  {signal_name}: "
                f"expected 0x{expected_value:X}, "
                f"actual 0x{actual_value:X}"
            )

    assert not errors, (
        f"{name} decode mismatch\n"
        f"  instruction: 0x{instruction:08X}\n"
        + "\n".join(errors)
    )


async def check_illegal(
    dut: Any,
    *,
    name: str,
    instruction: int,
) -> None:
    """Check the decoder's mandatory illegal side-effect suppression."""
    await apply_instruction(dut, instruction)

    expected = {
        **common_fields(instruction),
        "illegal": 1,
        "WEN": 0,
        "dmemREN": 0,
        "dmemWEN": 0,
        "PCsrc": 0,
        "PCj": 0,
        "CareIfZero": 0,
        "CareIfNotZero": 0,
        "fence": 0,
        "ecall": 0,
        "ebreak": 0,
        "halt": 0,
        "sync": 0,
    }

    errors: list[str] = []

    for signal_name, expected_value in expected.items():
        actual_value = signal_value(dut, signal_name)

        if actual_value != expected_value:
            errors.append(
                f"  {signal_name}: "
                f"expected 0x{expected_value:X}, "
                f"actual 0x{actual_value:X}"
            )

    assert not errors, (
        f"{name} illegal-decode mismatch\n"
        f"  instruction: 0x{instruction:08X}\n"
        + "\n".join(errors)
    )


# =============================================================================
# Valid R-type coverage
# =============================================================================


@cocotb.test()
async def test_all_valid_rtype_operations(dut: Any) -> None:
    rd = 7
    rs1 = 9
    rs2 = 11

    cases = [
        ("ADD", 0b0000000, 0b000, ALU_ADD),
        ("SUB", 0b0100000, 0b000, ALU_SUB),
        ("SLL", 0b0000000, 0b001, ALU_SLL),
        ("SLT", 0b0000000, 0b010, ALU_SLT),
        ("SLTU", 0b0000000, 0b011, ALU_SLTU),
        ("XOR", 0b0000000, 0b100, ALU_XOR),
        ("SRL", 0b0000000, 0b101, ALU_SRL),
        ("SRA", 0b0100000, 0b101, ALU_SRA),
        ("OR", 0b0000000, 0b110, ALU_OR),
        ("AND", 0b0000000, 0b111, ALU_AND),
    ]

    for name, funct7, funct3, aluop in cases:
        instruction = encode_r(
            funct7=funct7,
            rs2=rs2,
            rs1=rs1,
            funct3=funct3,
            rd=rd,
        )

        await check_decode(
            dut,
            name=name,
            instruction=instruction,
            expected={
                "wsel": rd,
                "rsel1": rs1,
                "rsel2": rs2,
                "immediate": 0,
                "aluop": aluop,
                "WEN": 1,
            },
        )


# =============================================================================
# Valid I-type ALU coverage
# =============================================================================


@cocotb.test()
async def test_all_valid_itype_alu_operations(dut: Any) -> None:
    rd = 5
    rs1 = 13

    regular_cases = [
        ("ADDI", 0b000, -17, ALU_ADD),
        ("SLTI", 0b010, -5, ALU_SLT),
        ("SLTIU", 0b011, 21, ALU_SLTU),
        ("XORI", 0b100, 0x155, ALU_XOR),
        ("ORI", 0b110, 0x2A5, ALU_OR),
        ("ANDI", 0b111, -32, ALU_AND),
    ]

    for name, funct3, immediate, aluop in regular_cases:
        instruction = encode_i(
            immediate=immediate,
            rs1=rs1,
            funct3=funct3,
            rd=rd,
        )

        await check_decode(
            dut,
            name=name,
            instruction=instruction,
            expected={
                "wsel": rd,
                "rsel1": rs1,
                "rsel2": 0,
                "immediate": sign_extend(immediate, 12),
                "aluop": aluop,
                "WEN": 1,
                "AluSrcB": 1,
            },
        )

    shift_cases = [
        ("SLLI", 0b0000000, 0b001, 7, ALU_SLL),
        ("SRLI", 0b0000000, 0b101, 9, ALU_SRL),
        ("SRAI", 0b0100000, 0b101, 12, ALU_SRA),
    ]

    for name, funct7, funct3, shamt, aluop in shift_cases:
        immediate_field = (funct7 << 5) | shamt

        instruction = encode_i(
            immediate=immediate_field,
            rs1=rs1,
            funct3=funct3,
            rd=rd,
        )

        await check_decode(
            dut,
            name=name,
            instruction=instruction,
            expected={
                "wsel": rd,
                "rsel1": rs1,
                "rsel2": 0,
                "immediate": sign_extend(immediate_field, 12),
                "aluop": aluop,
                "WEN": 1,
                "AluSrcB": 1,
            },
        )


# =============================================================================
# Valid loads and stores
# =============================================================================


@cocotb.test()
async def test_all_valid_load_and_store_forms(dut: Any) -> None:
    load_cases = [
        ("LB", 0b000),
        ("LH", 0b001),
        ("LW", 0b010),
        ("LBU", 0b100),
        ("LHU", 0b101),
    ]

    for name, funct3 in load_cases:
        instruction = encode_i(
            immediate=-20,
            rs1=8,
            funct3=funct3,
            rd=6,
            opcode=OP_LOAD,
        )

        await check_decode(
            dut,
            name=name,
            instruction=instruction,
            expected={
                "wsel": 6,
                "rsel1": 8,
                "rsel2": 0,
                "immediate": sign_extend(-20, 12),
                "aluop": ALU_ADD,
                "WEN": 1,
                "AluSrcB": 1,
                "MemtoReg": 1,
                "dmemREN": 1,
            },
        )

    store_cases = [
        ("SB", 0b000),
        ("SH", 0b001),
        ("SW", 0b010),
    ]

    for name, funct3 in store_cases:
        instruction = encode_s(
            immediate=-24,
            rs2=10,
            rs1=8,
            funct3=funct3,
        )

        await check_decode(
            dut,
            name=name,
            instruction=instruction,
            expected={
                "wsel": 0,
                "rsel1": 8,
                "rsel2": 10,
                "immediate": sign_extend(-24, 12),
                "aluop": ALU_ADD,
                "AluSrcB": 1,
                "dmemWEN": 1,
            },
        )


# =============================================================================
# Valid branch coverage
# =============================================================================


@cocotb.test()
async def test_all_valid_branch_forms(dut: Any) -> None:
    cases = [
        ("BEQ", 0b000, ALU_SUB, 1, 0),
        ("BNE", 0b001, ALU_SUB, 0, 1),
        ("BLT", 0b100, ALU_SLT, 0, 1),
        ("BGE", 0b101, ALU_SLT, 1, 0),
        ("BLTU", 0b110, ALU_SLTU, 0, 1),
        ("BGEU", 0b111, ALU_SLTU, 1, 0),
    ]

    for name, funct3, aluop, care_zero, care_not_zero in cases:
        instruction = encode_b(
            immediate=-32,
            rs2=14,
            rs1=12,
            funct3=funct3,
        )

        await check_decode(
            dut,
            name=name,
            instruction=instruction,
            expected={
                "wsel": 0,
                "rsel1": 12,
                "rsel2": 14,
                "immediate": sign_extend(-32, 13),
                "aluop": aluop,
                "CareIfZero": care_zero,
                "CareIfNotZero": care_not_zero,
            },
        )


# =============================================================================
# Valid jumps, upper immediates, fence, and system instructions
# =============================================================================


@cocotb.test()
async def test_valid_control_and_system_instructions(dut: Any) -> None:
    jal_instruction = encode_j(
        immediate=-256,
        rd=3,
    )

    await check_decode(
        dut,
        name="JAL",
        instruction=jal_instruction,
        expected={
            "wsel": 3,
            "rsel1": 0,
            "rsel2": 0,
            "immediate": sign_extend(-256, 21),
            "aluop": ALU_ADD,
            "WEN": 1,
            "PCtoReg": 1,
            "PCsrc": 1,
        },
    )

    jalr_instruction = encode_i(
        immediate=-16,
        rs1=4,
        funct3=0b000,
        rd=3,
        opcode=OP_JALR,
    )

    await check_decode(
        dut,
        name="JALR",
        instruction=jalr_instruction,
        expected={
            "wsel": 3,
            "rsel1": 4,
            "rsel2": 0,
            "immediate": sign_extend(-16, 12),
            "aluop": ALU_ADD,
            "WEN": 1,
            "AluSrcB": 1,
            "PCtoReg": 1,
            "PCj": 1,
        },
    )

    lui_instruction = encode_u(
        upper_immediate=0xABCDE,
        rd=2,
        opcode=OP_LUI,
    )

    await check_decode(
        dut,
        name="LUI",
        instruction=lui_instruction,
        expected={
            "wsel": 2,
            "rsel1": 0,
            "rsel2": 0,
            "immediate": 0xABCDE000,
            "aluop": ALU_ADD,
            "WEN": 1,
            "AluSrcB": 1,
        },
    )

    auipc_instruction = encode_u(
        upper_immediate=0x12345,
        rd=2,
        opcode=OP_AUIPC,
    )

    await check_decode(
        dut,
        name="AUIPC",
        instruction=auipc_instruction,
        expected={
            "wsel": 2,
            "rsel1": 0,
            "rsel2": 0,
            "immediate": 0x12345000,
            "aluop": ALU_ADD,
            "WEN": 1,
            "AluSrcA": 1,
            "AluSrcB": 1,
        },
    )

    fence_instruction = encode_i(
        immediate=0x0FF,
        rs1=0,
        funct3=0b000,
        rd=0,
        opcode=OP_MISC_MEM,
    )

    await check_decode(
        dut,
        name="FENCE",
        instruction=fence_instruction,
        expected={
            "wsel": 0,
            "rsel1": 0,
            "rsel2": 0,
            "immediate": 0,
            "aluop": ALU_ADD,
            "fence": 1,
        },
    )

    await check_decode(
        dut,
        name="ECALL",
        instruction=0x0000_0073,
        expected={
            "wsel": 0,
            "rsel1": 0,
            "rsel2": 0,
            "immediate": 0,
            "aluop": ALU_ADD,
            "ecall": 1,
        },
    )

    await check_decode(
        dut,
        name="EBREAK",
        instruction=0x0010_0073,
        expected={
            "wsel": 0,
            "rsel1": 0,
            "rsel2": 0,
            "immediate": 0,
            "aluop": ALU_ADD,
            "ebreak": 1,
            "halt": 1,
        },
    )


# =============================================================================
# Illegal R-type and I-type encodings
# =============================================================================


@cocotb.test()
async def test_illegal_alu_encodings(dut: Any) -> None:
    illegal_rtype_cases = [
        ("invalid ADD/SUB funct7", 0b0000001, 0b000),
        ("invalid SLL funct7", 0b0100000, 0b001),
        ("invalid SLT funct7", 0b0100000, 0b010),
        ("invalid SLTU funct7", 0b0100000, 0b011),
        ("invalid XOR funct7", 0b0100000, 0b100),
        ("invalid SRL/SRA funct7", 0b0010000, 0b101),
        ("invalid OR funct7", 0b0100000, 0b110),
        ("invalid AND funct7", 0b0100000, 0b111),
    ]

    for name, funct7, funct3 in illegal_rtype_cases:
        instruction = encode_r(
            funct7=funct7,
            rs2=2,
            rs1=1,
            funct3=funct3,
            rd=3,
        )

        await check_illegal(
            dut,
            name=name,
            instruction=instruction,
        )

    illegal_itype_cases = [
        (
            "invalid SLLI funct7",
            encode_i(
                immediate=(0b0100000 << 5) | 3,
                rs1=1,
                funct3=0b001,
                rd=3,
            ),
        ),
        (
            "invalid SRLI/SRAI funct7",
            encode_i(
                immediate=(0b0010000 << 5) | 3,
                rs1=1,
                funct3=0b101,
                rd=3,
            ),
        ),
    ]

    for name, instruction in illegal_itype_cases:
        await check_illegal(
            dut,
            name=name,
            instruction=instruction,
        )


# =============================================================================
# Illegal memory and branch encodings
# =============================================================================


@cocotb.test()
async def test_illegal_memory_and_branch_encodings(dut: Any) -> None:
    for funct3 in (0b011, 0b110, 0b111):
        instruction = encode_i(
            immediate=4,
            rs1=1,
            funct3=funct3,
            rd=2,
            opcode=OP_LOAD,
        )

        await check_illegal(
            dut,
            name=f"invalid LOAD funct3={funct3:03b}",
            instruction=instruction,
        )

    for funct3 in (0b011, 0b100, 0b101, 0b110, 0b111):
        instruction = encode_s(
            immediate=4,
            rs2=2,
            rs1=1,
            funct3=funct3,
        )

        await check_illegal(
            dut,
            name=f"invalid STORE funct3={funct3:03b}",
            instruction=instruction,
        )

    for funct3 in (0b010, 0b011):
        instruction = encode_b(
            immediate=8,
            rs2=2,
            rs1=1,
            funct3=funct3,
        )

        await check_illegal(
            dut,
            name=f"invalid BRANCH funct3={funct3:03b}",
            instruction=instruction,
        )


# =============================================================================
# Illegal control/system/default encodings
# =============================================================================


@cocotb.test()
async def test_illegal_control_system_and_unknown_opcodes(dut: Any) -> None:
    invalid_jalr = encode_i(
        immediate=0,
        rs1=1,
        funct3=0b001,
        rd=2,
        opcode=OP_JALR,
    )

    await check_illegal(
        dut,
        name="invalid JALR funct3",
        instruction=invalid_jalr,
    )

    invalid_fence = encode_i(
        immediate=0,
        rs1=0,
        funct3=0b001,
        rd=0,
        opcode=OP_MISC_MEM,
    )

    await check_illegal(
        dut,
        name="invalid MISC-MEM funct3",
        instruction=invalid_fence,
    )

    # CSRRW x0, cycle, x0. CSR operations are intentionally unsupported.
    await check_illegal(
        dut,
        name="unsupported CSR instruction",
        instruction=0xC000_1073,
    )

    await check_illegal(
        dut,
        name="unknown all-ones instruction",
        instruction=0xFFFF_FFFF,
    )

    await check_illegal(
        dut,
        name="zero instruction / unknown opcode",
        instruction=0x0000_0000,
    )
