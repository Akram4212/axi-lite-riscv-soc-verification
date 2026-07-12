# AXI-Lite RISC-V SoC Verification Platform

## Overview

This project implements and verifies an AXI-Lite based RISC-V SoC using open-source EDA tools. The project focuses on RTL quality, AXI-Lite protocol behavior, verification automation, and reusable Python/cocotb test infrastructure.

---

## Current Progress

### Completed

- ✅ WSL/Linux development environment
- ✅ Git/GitHub workflow
- ✅ Verilator 5.038 installation
- ✅ cocotb environment setup
- ✅ Makefile-based lint and simulation flow
- ✅ AXI-Lite GPIO peripheral
- ✅ GPIO register map
- ✅ GPIO passes Verilator lint (`-Wall`)
- ✅ cocotb GPIO testbench
- ✅ GPIO reset test
- ✅ GPIO basic AXI-Lite read/write test
- ✅ GPIO input-read test
- ✅ GPIO set/clear register test
- ✅ GPIO invalid-access test
- ✅ GPIO byte-strobe test
- ✅ GPIO randomized read/write test

### In Progress

- 🚧 AXI-Lite Timer peripheral planning
- 🚧 Project documentation cleanup

### Planned

- AXI-Lite Timer peripheral
- AXI-Lite Interconnect
- RAM model
- RV32I Processor Core
- SoC Top Module
- Directed verification expansion
- Randomized verification expansion
- Regression testing
- Functional coverage
- GTKWave debug
- CI/CD with GitHub Actions

---

## Repository Structure

```text
rtl/
include/
tb/
firmware/
scripts/
docs/
Makefile
README.md