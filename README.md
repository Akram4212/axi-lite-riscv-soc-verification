# AXI-Lite RISC-V SoC Verification Platform

A modular SystemVerilog and cocotb project for implementing and verifying a
five-stage RV32I processor core and an AXI-Lite peripheral subsystem.

## Current Status

### Five-Stage RV32I Core

- ✅ Five-stage in-order pipeline: IF, ID, EX, MEM, WB
- ✅ Integrated RV32I instruction decoder
- ✅ RV32I integer ALU
- ✅ 32-register integer register file
- ✅ MEM-to-EX and WB-to-EX forwarding
- ✅ WB-to-ID same-cycle bypass
- ✅ Load-use hazard detection and bubble insertion
- ✅ Branch, JAL, and JALR flushing and redirection
- ✅ JALR target bit-zero clearing
- ✅ Byte, halfword, and word loads and stores
- ✅ Signed and unsigned load extension
- ✅ Store byte strobes
- ✅ Instruction- and data-memory backpressure
- ✅ Illegal-instruction side-effect suppression
- ✅ Verilator lint with zero warnings
- ✅ 13/13 end-to-end RV32I core tests passing

### AXI-Lite Subsystem

- ✅ 4 KiB AXI-Lite RAM
- ✅ AXI-Lite GPIO peripheral
- ✅ AXI-Lite Timer peripheral
- ✅ AXI-Lite interconnect
- ✅ Integrated AXI-Lite subsystem
- ✅ Protocol assertions
- ✅ Directed and randomized cocotb tests
- ✅ Functional coverage
- ✅ GitHub Actions regression flow

### Planned Integration

- ⏳ RV32I-to-AXI-Lite master adapter
- ⏳ Full `soc_top.sv` integration
- ⏳ Firmware loading into AXI-Lite RAM
- ⏳ Firmware-driven GPIO and Timer verification
- ⏳ Full-SoC assertions and coverage

## Verification Results

| Verification Area | Result |
|---|---:|
| RV32I core tests | 13/13 PASS |
| Core regression overall line coverage | 92.0% |
| Core regression overall branch coverage | 82.9% |
| Core RTL line coverage | 91.2% |
| Core RTL branch coverage | 96.8% |
| `rv32i_core.sv` line coverage | 93.5% |
| `rv32i_core.sv` branch coverage | 99.4% |
| Decoder RTL line coverage | 98.4% |
| Decoder RTL branch coverage | 100.0% |
| AXI-Lite functional coverage | 96% |

The overall Verilator report includes RTL, SystemVerilog interfaces, and the
cocotb wrapper. RTL-only coverage includes processor source files under `rtl/`.

## RV32I Core Hierarchy

```text
rv32i_core
├── rv32i_pc
├── if_id_latch
├── rv32i_decoder
├── rv32i_regfile
├── id_ex_latch
├── forwarding_unit
├── rv32i_alu
├── ex_mem_latch
├── hazard_unit
└── mem_wb_latch