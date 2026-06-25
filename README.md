# Cocotb-Based Verification of an AXI-Lite RISC-V SoC

## Overview
This project implements and verifies a small AXI-Lite based RISC-V SoC with memory-mapped GPIO and timer peripherals.

## Features
- RV32I-style simple processor core
- AXI-Lite interconnect
- GPIO peripheral
- timer peripheral
- RAM
- Python/cocotb verification environment
- Directed and randomized tests
- AXI-Lite protocol checks
- Regression script
- GTKWave waveform debug

## Verification Plan
| Test | Purpose | Status |
|---|---|---|
| GPIO read/write | Verify GPIO register access | PASS |
| GPIO reset | Verify reset clears registers | PASS |
| Timer count | Verify timer increments | PASS |
| AXI decode | Verify address mapping | PASS |
| Invalid address | Verify error response | PASS |
| SoC program | Verify RISC-V program controls GPIO | PASS |

## How to Run
make test_gpio
make test_timer
make regression

## Tools
- VS Code
- WSL Ubuntu
- Verilator
- cocotb
- GTKWave
- Yosys