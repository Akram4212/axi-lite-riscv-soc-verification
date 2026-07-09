# AXI-Lite RISC-V SoC Verification Platform

## Overview

This project implements and verifies an AXI-Lite based RISC-V SoC using open-source EDA tools. The project focuses on RTL quality, protocol verification, and verification automation using Python and cocotb.

---

## Current Progress

### Completed
- ✅ WSL/Linux development environment
- ✅ Git/GitHub workflow
- ✅ Verilator 5.038 installation
- ✅ cocotb environment setup
- ✅ AXI-Lite GPIO peripheral
- ✅ GPIO register map
- ✅ GPIO passes Verilator lint (`-Wall`)

### In Progress
- 🚧 cocotb GPIO testbench
- 🚧 Makefile automation

### Planned
- AXI-Lite Timer peripheral
- AXI-Lite Interconnect
- RAM model
- RV32I Processor Core
- SoC Top Module
- Directed verification
- Randomized verification
- Regression testing
- Functional coverage
- GTKWave debug
- CI/CD with GitHub Actions

---

## Repository Structure

```
rtl/
include/
tb/
firmware/
scripts/
docs/
```

---

## Tools

- SystemVerilog
- Python
- cocotb
- Verilator
- GTKWave
- Yosys
- Git
- VS Code
- WSL Ubuntu

---

## Development Roadmap

| Milestone | Status |
|-----------|--------|
| Development environment | ✅ Complete |
| GPIO RTL | ✅ Complete |
| GPIO Verilator lint | ✅ Complete |
| GPIO cocotb testbench | 🚧 In Progress |
| Timer peripheral | ⏳ Planned |
| AXI-Lite interconnect | ⏳ Planned |
| RISC-V Core | ⏳ Planned |
| Full SoC integration | ⏳ Planned |
| Regression suite | ⏳ Planned |

---

## Current Verification Status

| Check | Status |
|--------|--------|
| Verilator lint | ✅ PASS |
| cocotb simulation | 🚧 Not Started |
| Directed tests | ⏳ Planned |
| Random tests | ⏳ Planned |
| Regression | ⏳ Planned |