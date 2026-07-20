"""End-to-end cocotb verification for the five-stage RV32I core.

Expected top level:
    rv32i_core_wrapper

Expected top-level ports:
    CLK, nRST
    ihit, imemload
    dhit, dmemload
    imemREN, imemaddr
    dmemREN, dmemWEN, datomic
    dmemaddr, dmemstore, dmem_wstrb
    halt, illegal
    debug_pc, debug_instruction
    debug_pipeline_enable, debug_redirect, debug_bubble
    debug_wb_wen, debug_wb_rd, debug_wb_data

The testbench provides independent instruction and data memory models. Memory
responses are presented at the falling edge and are captured by the core at
the following rising edge.
"""

from __future__ import annotations

from collections.abc import Callable, Iterable
from dataclasses import dataclass, field

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge, Timer


# =============================================================================
# RV32I constants
# =============================================================================

MASK_32 = 0xFFFF_FFFF

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

NOP = 0x0000_0013
EBREAK = 0x0010_0073
ECALL = 0x0000_0073
FENCE = 0x0000_000F


def u32(value: int) -> int:
    """Return value modulo 2**32."""
    return value & MASK_32


# =============================================================================
# Generic instruction encoders
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
    assert immediate % 2 == 0, "Branch offset must be 2-byte aligned"
    assert -4096 <= immediate <= 4094, "Branch offset is out of range"

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
    assert immediate % 2 == 0, "Jump offset must be 2-byte aligned"
    assert -(1 << 20) <= immediate <= (1 << 20) - 2, (
        "Jump offset is out of range"
    )

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
# Named RV32I instruction helpers
# =============================================================================


def add(rd: int, rs1: int, rs2: int) -> int:
    return encode_r(funct7=0b0000000, rs2=rs2, rs1=rs1, funct3=0b000, rd=rd)


def sub(rd: int, rs1: int, rs2: int) -> int:
    return encode_r(funct7=0b0100000, rs2=rs2, rs1=rs1, funct3=0b000, rd=rd)


def sll(rd: int, rs1: int, rs2: int) -> int:
    return encode_r(funct7=0b0000000, rs2=rs2, rs1=rs1, funct3=0b001, rd=rd)


def slt(rd: int, rs1: int, rs2: int) -> int:
    return encode_r(funct7=0b0000000, rs2=rs2, rs1=rs1, funct3=0b010, rd=rd)


def sltu(rd: int, rs1: int, rs2: int) -> int:
    return encode_r(funct7=0b0000000, rs2=rs2, rs1=rs1, funct3=0b011, rd=rd)


def xor_(rd: int, rs1: int, rs2: int) -> int:
    return encode_r(funct7=0b0000000, rs2=rs2, rs1=rs1, funct3=0b100, rd=rd)


def srl(rd: int, rs1: int, rs2: int) -> int:
    return encode_r(funct7=0b0000000, rs2=rs2, rs1=rs1, funct3=0b101, rd=rd)


def sra(rd: int, rs1: int, rs2: int) -> int:
    return encode_r(funct7=0b0100000, rs2=rs2, rs1=rs1, funct3=0b101, rd=rd)


def or_(rd: int, rs1: int, rs2: int) -> int:
    return encode_r(funct7=0b0000000, rs2=rs2, rs1=rs1, funct3=0b110, rd=rd)


def and_(rd: int, rs1: int, rs2: int) -> int:
    return encode_r(funct7=0b0000000, rs2=rs2, rs1=rs1, funct3=0b111, rd=rd)


def addi(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(immediate=immediate, rs1=rs1, funct3=0b000, rd=rd)


def slti(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(immediate=immediate, rs1=rs1, funct3=0b010, rd=rd)


def sltiu(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(immediate=immediate, rs1=rs1, funct3=0b011, rd=rd)


def xori(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(immediate=immediate, rs1=rs1, funct3=0b100, rd=rd)


def ori(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(immediate=immediate, rs1=rs1, funct3=0b110, rd=rd)


def andi(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(immediate=immediate, rs1=rs1, funct3=0b111, rd=rd)


def slli(rd: int, rs1: int, shamt: int) -> int:
    return encode_i(
        immediate=shamt & 0x1F,
        rs1=rs1,
        funct3=0b001,
        rd=rd,
    )


def srli(rd: int, rs1: int, shamt: int) -> int:
    return encode_i(
        immediate=shamt & 0x1F,
        rs1=rs1,
        funct3=0b101,
        rd=rd,
    )


def srai(rd: int, rs1: int, shamt: int) -> int:
    return encode_i(
        immediate=(0b0100000 << 5) | (shamt & 0x1F),
        rs1=rs1,
        funct3=0b101,
        rd=rd,
    )


def lb(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(
        immediate=immediate,
        rs1=rs1,
        funct3=0b000,
        rd=rd,
        opcode=OP_LOAD,
    )


def lh(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(
        immediate=immediate,
        rs1=rs1,
        funct3=0b001,
        rd=rd,
        opcode=OP_LOAD,
    )


def lw(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(
        immediate=immediate,
        rs1=rs1,
        funct3=0b010,
        rd=rd,
        opcode=OP_LOAD,
    )


def lbu(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(
        immediate=immediate,
        rs1=rs1,
        funct3=0b100,
        rd=rd,
        opcode=OP_LOAD,
    )


def lhu(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(
        immediate=immediate,
        rs1=rs1,
        funct3=0b101,
        rd=rd,
        opcode=OP_LOAD,
    )


def sb(rs2: int, rs1: int, immediate: int) -> int:
    return encode_s(immediate=immediate, rs2=rs2, rs1=rs1, funct3=0b000)


def sh(rs2: int, rs1: int, immediate: int) -> int:
    return encode_s(immediate=immediate, rs2=rs2, rs1=rs1, funct3=0b001)


def sw(rs2: int, rs1: int, immediate: int) -> int:
    return encode_s(immediate=immediate, rs2=rs2, rs1=rs1, funct3=0b010)


def beq(rs1: int, rs2: int, immediate: int) -> int:
    return encode_b(immediate=immediate, rs2=rs2, rs1=rs1, funct3=0b000)


def bne(rs1: int, rs2: int, immediate: int) -> int:
    return encode_b(immediate=immediate, rs2=rs2, rs1=rs1, funct3=0b001)


def blt(rs1: int, rs2: int, immediate: int) -> int:
    return encode_b(immediate=immediate, rs2=rs2, rs1=rs1, funct3=0b100)


def bge(rs1: int, rs2: int, immediate: int) -> int:
    return encode_b(immediate=immediate, rs2=rs2, rs1=rs1, funct3=0b101)


def bltu(rs1: int, rs2: int, immediate: int) -> int:
    return encode_b(immediate=immediate, rs2=rs2, rs1=rs1, funct3=0b110)


def bgeu(rs1: int, rs2: int, immediate: int) -> int:
    return encode_b(immediate=immediate, rs2=rs2, rs1=rs1, funct3=0b111)


def jal(rd: int, immediate: int) -> int:
    return encode_j(immediate=immediate, rd=rd)


def jalr(rd: int, rs1: int, immediate: int) -> int:
    return encode_i(
        immediate=immediate,
        rs1=rs1,
        funct3=0b000,
        rd=rd,
        opcode=OP_JALR,
    )


def lui(rd: int, upper_immediate: int) -> int:
    return encode_u(upper_immediate=upper_immediate, rd=rd, opcode=OP_LUI)


def auipc(rd: int, upper_immediate: int) -> int:
    return encode_u(upper_immediate=upper_immediate, rd=rd, opcode=OP_AUIPC)


# =============================================================================
# Memory and execution models
# =============================================================================


ReadyFunction = Callable[[int], bool]


def always_ready(_: int) -> bool:
    return True


@dataclass
class CoreMemory:
    """Simple Harvard-style instruction and data memory model."""

    program: dict[int, int]
    instruction_ready: ReadyFunction = always_ready
    data_ready: ReadyFunction = always_ready
    default_instruction: int = NOP

    data_bytes: dict[int, int] = field(default_factory=dict)
    store_count: int = 0
    load_count: int = 0

    @classmethod
    def from_program(
        cls,
        instructions: Iterable[int],
        *,
        base_address: int = 0,
        instruction_ready: ReadyFunction = always_ready,
        data_ready: ReadyFunction = always_ready,
    ) -> "CoreMemory":
        program = {
            base_address + 4 * index: u32(instruction)
            for index, instruction in enumerate(instructions)
        }

        return cls(
            program=program,
            instruction_ready=instruction_ready,
            data_ready=data_ready,
        )

    def read_instruction(self, address: int) -> int:
        return self.program.get(u32(address), self.default_instruction)

    def read_data_word(self, address: int) -> int:
        aligned_address = u32(address) & ~0x3

        return sum(
            (self.data_bytes.get(aligned_address + byte_index, 0) & 0xFF)
            << (8 * byte_index)
            for byte_index in range(4)
        )

    def write_data_word(
        self,
        address: int,
        write_data: int,
        write_strobe: int,
    ) -> None:
        aligned_address = u32(address) & ~0x3

        for byte_index in range(4):
            if write_strobe & (1 << byte_index):
                self.data_bytes[aligned_address + byte_index] = (
                    write_data >> (8 * byte_index)
                ) & 0xFF

        self.store_count += 1

    def preload_word(self, address: int, value: int) -> None:
        self.write_data_word(address, value, 0b1111)
        self.store_count = 0

    def service(self, dut, cycle: int) -> None:
        """Drive memory responses for the next rising edge."""
        dut.ihit.value = 0
        dut.dhit.value = 0

        instruction_request = bool(int(dut.imemREN.value))
        instruction_hit = (
            instruction_request
            and self.instruction_ready(cycle)
        )

        if instruction_request:
            instruction_address = int(dut.imemaddr.value)
            dut.imemload.value = self.read_instruction(
                instruction_address
            )
        else:
            dut.imemload.value = NOP

        dut.ihit.value = int(instruction_hit)

        data_read_request = bool(int(dut.dmemREN.value))
        data_write_request = bool(int(dut.dmemWEN.value))
        data_request = data_read_request or data_write_request

        # The current core advances a memory instruction only when both
        # instruction and data responses are ready. Requiring instruction_hit
        # here prevents a held store from being accepted repeatedly.
        data_hit = (
            data_request
            and instruction_hit
            and self.data_ready(cycle)
        )

        if data_read_request:
            data_address = int(dut.dmemaddr.value)
            dut.dmemload.value = self.read_data_word(data_address)
        else:
            dut.dmemload.value = 0

        dut.dhit.value = int(data_hit)

        if data_hit and data_read_request:
            self.load_count += 1

        if data_hit and data_write_request:
            self.write_data_word(
                address=int(dut.dmemaddr.value),
                write_data=int(dut.dmemstore.value),
                write_strobe=int(dut.dmem_wstrb.value),
            )


@dataclass
class RunResult:
    registers: list[int] = field(
        default_factory=lambda: [0 for _ in range(32)]
    )
    commits: list[tuple[int, int, int]] = field(default_factory=list)

    cycles: int = 0
    bubble_cycles: int = 0
    redirect_cycles: int = 0
    pipeline_advance_cycles: int = 0

    halted: bool = False
    illegal: bool = False


async def initialize_core(dut) -> None:
    """Start from a known reset state."""
    dut.nRST.value = 0

    dut.ihit.value = 0
    dut.imemload.value = NOP
    dut.dhit.value = 0
    dut.dmemload.value = 0

    await ClockCycles(dut.CLK, 3)
    await FallingEdge(dut.CLK)

    dut.nRST.value = 1


async def run_program(
    dut,
    memory: CoreMemory,
    *,
    max_cycles: int = 250,
    stop_on_illegal: bool = False,
) -> RunResult:
    """Execute until EBREAK/illegal halt or the cycle limit."""
    result = RunResult()

    await initialize_core(dut)

    # initialize_core returns on a falling edge. Each iteration drives memory
    # for the next rising edge, records the pending WB commit, and then lets
    # the pipeline advance.
    for cycle in range(max_cycles):
        if cycle != 0:
            await FallingEdge(dut.CLK)

        memory.service(dut, cycle)
        await Timer(1, unit="ns")

        pipeline_enable = bool(int(dut.debug_pipeline_enable.value))
        pending_wb_write = bool(int(dut.debug_wb_wen.value))

        if pipeline_enable:
            result.pipeline_advance_cycles += 1

        if bool(int(dut.debug_bubble.value)):
            result.bubble_cycles += 1

        if bool(int(dut.debug_redirect.value)):
            result.redirect_cycles += 1

        # debug_wb_wen represents the write that will occur at the following
        # rising edge. Register x0 remains hard-wired to zero.
        if pending_wb_write:
            rd = int(dut.debug_wb_rd.value)
            write_data = u32(int(dut.debug_wb_data.value))

            if rd != 0:
                result.registers[rd] = write_data

            result.commits.append((cycle, rd, write_data))

        await RisingEdge(dut.CLK)
        await ReadOnly()

        result.cycles = cycle + 1
        result.halted = bool(int(dut.halt.value))
        result.illegal = bool(int(dut.illegal.value))

        if result.halted:
            return result

        if stop_on_illegal and result.illegal:
            return result

    raise AssertionError(
        "Core did not halt within the cycle limit\n"
        f"  max_cycles: {max_cycles}\n"
        f"  debug_pc:   0x{int(dut.debug_pc.value):08X}\n"
        f"  instruction:0x{int(dut.debug_instruction.value):08X}\n"
        f"  illegal:    {int(dut.illegal.value)}"
    )


async def execute(
    dut,
    program: Iterable[int],
    *,
    max_cycles: int = 250,
    instruction_ready: ReadyFunction = always_ready,
    data_ready: ReadyFunction = always_ready,
) -> tuple[RunResult, CoreMemory]:
    """Start the clock, create memory, and execute one program."""
    cocotb.start_soon(Clock(dut.CLK, 10, unit="ns").start())

    memory = CoreMemory.from_program(
        program,
        instruction_ready=instruction_ready,
        data_ready=data_ready,
    )

    result = await run_program(
        dut,
        memory,
        max_cycles=max_cycles,
    )

    return result, memory


def assert_registers(result: RunResult, expected: dict[int, int]) -> None:
    for register_number, expected_value in expected.items():
        actual_value = result.registers[register_number]

        assert actual_value == u32(expected_value), (
            f"x{register_number} mismatch\n"
            f"  expected: 0x{u32(expected_value):08X}\n"
            f"  actual:   0x{actual_value:08X}\n"
            f"  commits:  {result.commits}"
        )

    assert result.registers[0] == 0, "x0 must remain zero"


# =============================================================================
# Core tests
# =============================================================================


@cocotb.test()
async def test_reset_and_basic_arithmetic(dut) -> None:
    """ADDI/ADD execute correctly with back-to-back dependencies."""
    program = [
        addi(1, 0, 5),
        addi(2, 0, 7),
        add(3, 1, 2),
        EBREAK,
    ]

    result, _ = await execute(dut, program)

    assert result.halted
    assert not result.illegal

    assert_registers(
        result,
        {
            1: 5,
            2: 7,
            3: 12,
        },
    )


@cocotb.test()
async def test_rtype_and_itype_operations(dut) -> None:
    """Verify representative arithmetic, logical, shift, and compare ops."""
    program = [
        addi(1, 0, 20),           # x1 = 20
        addi(2, 0, 6),            # x2 = 6
        sub(3, 1, 2),             # x3 = 14
        and_(4, 1, 2),            # x4 = 4
        or_(5, 1, 2),             # x5 = 22
        xor_(6, 1, 2),            # x6 = 18
        sll(7, 2, 2),             # x7 = 6 << 6 = 384
        srl(8, 7, 2),             # x8 = 384 >> 6 = 6
        addi(9, 0, -16),          # x9 = 0xFFFF_FFF0
        srai(10, 9, 2),           # x10 = -4
        slt(11, 9, 1),            # signed -16 < 20
        sltu(12, 9, 1),           # unsigned FFFFFFF0 < 20 is false
        andi(13, 5, 0xF),         # x13 = 6
        ori(14, 4, 0x20),         # x14 = 0x24
        xori(15, 6, 0x12),        # x15 = 0
        slti(16, 9, 0),           # signed -16 < 0
        sltiu(17, 1, 21),         # unsigned 20 < 21
        EBREAK,
    ]

    result, _ = await execute(dut, program, max_cycles=350)

    assert_registers(
        result,
        {
            3: 14,
            4: 4,
            5: 22,
            6: 18,
            7: 384,
            8: 6,
            9: 0xFFFF_FFF0,
            10: 0xFFFF_FFFC,
            11: 1,
            12: 0,
            13: 6,
            14: 0x24,
            15: 0,
            16: 1,
            17: 1,
        },
    )


@cocotb.test()
async def test_forwarding_priority(dut) -> None:
    """MEM forwarding must override an older WB value for the same register."""
    program = [
        addi(1, 0, 1),      # x1 = 1
        addi(1, 1, 1),      # x1 = 2, depends on prior result
        addi(2, 1, 1),      # x2 = 3, must see newest x1
        add(3, 2, 1),       # x3 = 5
        EBREAK,
    ]

    result, _ = await execute(dut, program)

    assert_registers(
        result,
        {
            1: 2,
            2: 3,
            3: 5,
        },
    )


@cocotb.test()
async def test_lw_sw_and_load_use_hazard(dut) -> None:
    """Verify store/load behavior and the one-cycle load-use bubble."""
    program = [
        addi(1, 0, 0x100),  # base address
        addi(2, 0, 0x5A),
        sw(2, 1, 0),
        lw(3, 1, 0),
        addi(4, 3, 1),      # immediate consumer of loaded x3
        EBREAK,
    ]

    result, memory = await execute(dut, program)

    assert_registers(
        result,
        {
            1: 0x100,
            2: 0x5A,
            3: 0x5A,
            4: 0x5B,
        },
    )

    assert memory.read_data_word(0x100) == 0x0000_005A
    assert memory.store_count == 1
    assert memory.load_count == 1
    assert result.bubble_cycles >= 1, (
        "Expected the load-use hazard unit to insert a bubble"
    )


@cocotb.test()
async def test_byte_and_halfword_memory_operations(dut) -> None:
    """Verify SB/SH and signed/unsigned byte/halfword loads."""
    program = [
        addi(1, 0, 0x100),
        addi(2, 0, -1),
        sb(2, 1, 1),
        lbu(3, 1, 1),
        lb(4, 1, 1),
        addi(5, 0, -2),
        sh(5, 1, 2),
        lhu(6, 1, 2),
        lh(7, 1, 2),
        EBREAK,
    ]

    result, memory = await execute(dut, program, max_cycles=350)

    assert_registers(
        result,
        {
            3: 0x0000_00FF,
            4: 0xFFFF_FFFF,
            6: 0x0000_FFFE,
            7: 0xFFFF_FFFE,
        },
    )

    assert memory.read_data_word(0x100) == 0xFFFE_FF00


@cocotb.test()
async def test_taken_and_not_taken_branches(dut) -> None:
    """A taken branch flushes wrong-path instructions; BNE remains untaken."""
    program = [
        addi(1, 0, 5),          # 0x00
        addi(2, 0, 5),          # 0x04
        beq(1, 2, 12),          # 0x08 -> 0x14
        addi(3, 0, 99),         # 0x0C, wrong path
        addi(4, 0, 88),         # 0x10, wrong path
        addi(3, 0, 7),          # 0x14, target
        bne(1, 2, 8),           # 0x18, not taken
        addi(4, 0, 9),          # 0x1C
        EBREAK,                  # 0x20
    ]

    result, _ = await execute(dut, program, max_cycles=300)

    assert_registers(
        result,
        {
            1: 5,
            2: 5,
            3: 7,
            4: 9,
        },
    )

    assert result.redirect_cycles >= 1


@cocotb.test()
async def test_signed_and_unsigned_branches(dut) -> None:
    """Verify BLT/BGE and BLTU/BGEU condition interpretation."""
    program = [
        addi(1, 0, -1),         # x1 = FFFFFFFF
        addi(2, 0, 1),          # x2 = 1

        blt(1, 2, 8),           # signed: taken
        addi(3, 0, 99),         # flushed
        addi(3, 0, 3),

        bltu(1, 2, 8),          # unsigned: not taken
        addi(4, 0, 4),

        bge(2, 1, 8),           # signed: taken
        addi(5, 0, 99),         # flushed
        addi(5, 0, 5),

        bgeu(1, 2, 8),          # unsigned: taken
        addi(6, 0, 99),         # flushed
        addi(6, 0, 6),

        EBREAK,
    ]

    result, _ = await execute(dut, program, max_cycles=400)

    assert_registers(
        result,
        {
            3: 3,
            4: 4,
            5: 5,
            6: 6,
        },
    )

    assert result.redirect_cycles >= 3


@cocotb.test()
async def test_jal_link_and_flush(dut) -> None:
    """JAL writes PC+4 and flushes sequential instructions."""
    program = [
        jal(1, 12),             # 0x00 -> 0x0C, x1 = 0x04
        addi(2, 0, 99),         # 0x04, wrong path
        addi(2, 0, 88),         # 0x08, wrong path
        addi(2, 0, 7),          # 0x0C, target
        EBREAK,
    ]

    result, _ = await execute(dut, program)

    assert_registers(
        result,
        {
            1: 4,
            2: 7,
        },
    )

    assert result.redirect_cycles >= 1


@cocotb.test()
async def test_jalr_forwarding_and_lsb_clear(dut) -> None:
    """JALR uses a forwarded base register and clears target bit zero."""
    program = [
        addi(5, 0, 17),         # target source is intentionally odd
        jalr(1, 5, 0),          # 0x04 -> 0x10, x1 = 0x08
        addi(2, 0, 99),         # 0x08, wrong path
        addi(2, 0, 88),         # 0x0C, wrong path
        addi(2, 0, 7),          # 0x10, target after bit-zero clear
        EBREAK,
    ]

    result, _ = await execute(dut, program)

    assert_registers(
        result,
        {
            1: 8,
            2: 7,
            5: 17,
        },
    )

    assert result.redirect_cycles >= 1


@cocotb.test()
async def test_lui_and_auipc(dut) -> None:
    """Verify upper-immediate execution and AUIPC PC selection."""
    program = [
        lui(1, 0x12345),        # x1 = 0x12345000
        auipc(2, 0x00001),      # at PC 4: x2 = 0x00001004
        EBREAK,
    ]

    result, _ = await execute(dut, program)

    assert_registers(
        result,
        {
            1: 0x1234_5000,
            2: 0x0000_1004,
        },
    )


@cocotb.test()
async def test_instruction_backpressure(dut) -> None:
    """The pipeline must preserve architectural behavior across ihit stalls."""

    def instruction_ready(cycle: int) -> bool:
        # Two ready cycles followed by one wait cycle.
        return cycle % 3 != 2

    program = [
        addi(1, 0, 5),
        addi(2, 1, 7),
        add(3, 1, 2),
        EBREAK,
    ]

    result, _ = await execute(
        dut,
        program,
        max_cycles=350,
        instruction_ready=instruction_ready,
    )

    assert_registers(
        result,
        {
            1: 5,
            2: 12,
            3: 17,
        },
    )

    assert result.cycles > result.pipeline_advance_cycles


@cocotb.test()
async def test_data_backpressure(dut) -> None:
    """A held load/store request must complete correctly after dhit stalls."""

    def data_ready(cycle: int) -> bool:
        return cycle % 4 == 0

    program = [
        addi(1, 0, 0x100),
        addi(2, 0, 0x123),
        sw(2, 1, 0),
        lw(3, 1, 0),
        addi(4, 3, 1),
        EBREAK,
    ]

    result, memory = await execute(
        dut,
        program,
        max_cycles=500,
        data_ready=data_ready,
    )

    assert_registers(
        result,
        {
            2: 0x123,
            3: 0x123,
            4: 0x124,
        },
    )

    assert memory.read_data_word(0x100) == 0x123


@cocotb.test()
async def test_illegal_instruction_has_no_side_effects(dut) -> None:
    """An unsupported instruction raises illegal and reaches the halt path."""
    program = [
        0xFFFF_FFFF,
        addi(1, 0, 99),
        EBREAK,
    ]

    result, memory = await execute(
        dut,
        program,
        max_cycles=100,
    )

    assert result.illegal
    assert result.halted
    assert result.registers[1] == 0
    assert memory.store_count == 0
