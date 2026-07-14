# AXI-Lite RISC-V SoC Verification Platform

![AXI-Lite SoC Regression](https://github.com/Akram4212/axi-lite-riscv-soc-verification/actions/workflows/regression.yml/badge.svg)

## Overview

This project implements and verifies an AXI-Lite based RISC-V SoC using open-source EDA tools. The project focuses on RTL quality, AXI-Lite protocol behavior, verification automation, reusable Python/cocotb test infrastructure, and subsystem-level integration.

---

## Current Progress

### Completed

* ✅ WSL/Linux development environment
* ✅ Git/GitHub workflow
* ✅ Verilator 5.038 installation
* ✅ cocotb environment setup
* ✅ Makefile-based lint and simulation flow
* ✅ Reusable cocotb AXI-Lite master driver
* ✅ AXI-Lite GPIO peripheral
* ✅ GPIO register map
* ✅ GPIO passes Verilator lint (`-Wall`)
* ✅ cocotb GPIO testbench
* ✅ GPIO reset, read/write, input-read, set/clear, invalid-access, byte-strobe, and randomized tests pass
* ✅ AXI-Lite Timer peripheral
* ✅ Timer register map
* ✅ Timer passes Verilator lint (`-Wall`)
* ✅ cocotb Timer testbench
* ✅ Timer reset, enable-count, disable-hold, clear, compare-match, IRQ, status-clear, byte-strobe, invalid-access, and randomized tests pass
* ✅ AXI-Lite Interconnect
* ✅ AXI-Lite GPIO + Timer subsystem
* ✅ Subsystem address map
* ✅ Subsystem passes Verilator lint (`-Wall`)
* ✅ cocotb subsystem testbench
* ✅ GPIO and Timer access through interconnect
* ✅ Address decoding verification
* ✅ Invalid-address and unaligned-access verification
* ✅ GPIO/Timer isolation verification
* ✅ Back-to-back and randomized subsystem tests
* ✅ GPIO, Timer, and Subsystem regression flow

### In Progress

* 🚧 AXI-Lite RAM model planning
* 🚧 Project documentation cleanup

### Planned

* AXI-Lite RAM model
* RV32I Processor Core
* SoC Top Module
* Directed verification expansion
* Randomized verification expansion
* Functional coverage
* GTKWave debug flow
* CI/CD with GitHub Actions

---

## Repository Structure

```text
rtl/
include/
tb/
firmware/
scripts/
docs/
waves/
Makefile
README.md