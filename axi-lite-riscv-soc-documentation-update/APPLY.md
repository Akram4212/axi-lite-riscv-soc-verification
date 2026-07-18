# Verification Plan

## Overview

This document defines the verification strategy for the AXI-Lite RISC-V SoC Verification Platform.

The project uses:

- SystemVerilog RTL
- Verilator lint and simulation
- cocotb Python testbenches
- Directed and randomized testing
- AXI-Lite protocol assertions
- Python functional coverage
- Verilator RTL line and branch coverage
- LCOV HTML reporting
- GitHub Actions regression automation

## Verification Scope

### RV32I Processor

- ALU
- Register file
- Decoder
- Program counter
- Pipeline latches
- Forwarding unit
- Hazard unit
- Integrated five-stage core
- Instruction- and data-memory handshakes

### AXI-Lite Subsystem

- GPIO peripheral
- Timer peripheral
- RAM
- Interconnect
- Integrated RAM + GPIO + Timer subsystem
- Protocol assertions

## Verification Goals

1. Verify each RTL block independently before integration.
2. Verify the complete RV32I pipeline executes supported instructions correctly.
3. Verify all data-forwarding and load-use hazard paths.
4. Verify branch and jump redirection and wrong-path flushing.
5. Verify byte, halfword, and word memory behavior.
6. Verify instruction- and data-memory backpressure.
7. Verify illegal instructions cannot cause architectural side effects.
8. Verify AXI-Lite peripheral behavior and address routing.
9. Verify invalid and unaligned AXI-Lite accesses.
10. Track functional and structural coverage.
11. Run repeatable regressions locally and in CI.

## Testbench Architecture

```text
tb/
├── rv32i_alu_wrapper.sv
├── rv32i_regfile_wrapper.sv
├── rv32i_decoder_wrapper.sv
├── rv32i_core_wrapper.sv
├── test_rv32i_alu.py
├── test_rv32i_regfile.py
├── test_rv32i_decoder.py
├── test_rv32i_core.py
├── axi_lite_master.py
├── axi_lite_coverage.py
├── test_gpio.py
├── test_timer.py
├── test_axi_lite_ram.py
└── test_axi_lite_subsystem.py
```

SystemVerilog wrappers convert interface-based DUT ports into ordinary simulator-visible signals for cocotb and Verilator.

## RV32I Unit-Level Verification

| Block | Verification Areas |
|---|---|
| ALU | Arithmetic, logic, shifts, signed/unsigned comparisons, flags |
| Register file | Read ports, writes, x0 protection, reset |
| Decoder | Valid instructions, immediate generation, control outputs, illegal encodings |
| PC | Reset, normal increment, redirect, freeze |
| Forwarding unit | MEM forwarding, WB forwarding, priority, x0 exclusion |
| Hazard unit | Load-use stalls, bubble insertion, redirect flush |
| Pipeline latches | Reset, normal advance, bubble, freeze, flush |

## Decoder Verification Matrix

### Valid Instruction Forms

- R-type: `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`
- I-type ALU: `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI`
- Loads: `LB`, `LH`, `LW`, `LBU`, `LHU`
- Stores: `SB`, `SH`, `SW`
- Branches: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
- Control and upper-immediate: `JAL`, `JALR`, `LUI`, `AUIPC`
- System/memory ordering: `FENCE`, `ECALL`, `EBREAK`

### Illegal Decode Paths

- Invalid R-type `funct7`
- Invalid shift-immediate `funct7`
- Invalid load `funct3`
- Invalid store `funct3`
- Invalid branch `funct3`
- Invalid JALR `funct3`
- Invalid MISC-MEM encoding
- Unsupported CSR instruction
- Unknown opcode
- All-zero and all-one invalid words

### Illegal Side-Effect Checks

Every illegal encoding must result in:

```text
illegal       = 1
WEN           = 0
dmemREN       = 0
dmemWEN       = 0
PCsrc         = 0
PCj           = 0
CareIfZero    = 0
CareIfNotZero = 0
fence         = 0
ecall         = 0
ebreak        = 0
halt          = 0
```

## Core-Level Verification

The end-to-end core testbench supplies independent instruction and data memory models.

The core suite verifies:

- Reset and pipeline startup
- Back-to-back arithmetic dependencies
- R-type and I-type execution
- MEM-to-EX forwarding
- WB-to-EX forwarding
- Forwarding priority
- WB-to-ID same-cycle bypass
- `LW` and `SW`
- Load-use hazard bubbles
- `LB`, `LBU`, `LH`, `LHU`, `SB`, and `SH`
- Signed and unsigned load extension
- Store byte strobes
- Taken and untaken branches
- Signed and unsigned branches
- JAL and JALR
- JALR target bit-zero clearing
- LUI and AUIPC
- Instruction-memory backpressure
- Data-memory backpressure
- Illegal-instruction side-effect prevention

## AXI-Lite Verification

### Peripheral-Level Checks

- Register reset values
- Read and write behavior
- Byte strobes
- Read-only and write-only behavior
- Timer counting and control
- RAM data persistence
- Error response behavior

### Interconnect and Subsystem Checks

- Address decode
- Target selection
- RAM/GPIO/Timer isolation
- Backpressure
- Invalid address handling
- Unaligned access handling
- Randomized reads and writes
- AXI-Lite channel stability assertions

## Coverage Strategy

### Functional Coverage

Python functional coverage tracks important AXI-Lite transaction and peripheral scenarios.

### RTL Coverage

Verilator instrumentation records line and branch coverage for the RV32I hierarchy.

```bash
make clean
make test_rv32i_core HDL_COVERAGE=1

verilator_coverage \
    --write-info coverage.info \
    coverage.dat

lcov \
    --summary \
    --branch-coverage \
    coverage.info
```

## Regression Strategy

### RV32I

```bash
make regression_rv32i
```

### AXI-Lite

```bash
make regression
```

### Combined

```bash
make regression_all
```

## Verification Closure Criteria

The verified RV32I milestone is considered complete when:

- All RTL passes Verilator lint with zero errors.
- All unit and core tests pass.
- Decoder branch coverage reaches 100%.
- Decoder RTL line coverage exceeds 95%.
- Core RTL branch coverage exceeds 95%.
- All supported instruction categories are exercised.
- Forwarding, hazard, redirect, and backpressure paths are tested.
- Illegal instructions cannot cause architectural side effects.

The full-SoC milestone will require additional closure criteria after the AXI-Lite processor adapter and firmware execution path are implemented.
