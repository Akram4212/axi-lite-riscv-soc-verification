Replace it with this cleaner updated version:

````markdown
# AXI-Lite RISC-V SoC Verification Platform

![AXI-Lite SoC Regression](https://github.com/Akram4212/axi-lite-riscv-soc-verification/actions/workflows/regression.yml/badge.svg)

## Overview

This project implements and verifies an AXI-Lite based RISC-V SoC subsystem using open-source EDA tools. The project focuses on RTL quality, AXI-Lite protocol behavior, reusable Python/cocotb verification infrastructure, subsystem-level integration, assertions, functional coverage, waveform debug, and CI-based regression automation.

---

## Current Progress

### Completed

* ✅ WSL/Linux development environment
* ✅ Git/GitHub workflow
* ✅ GitHub Actions CI regression workflow
* ✅ Verilator 5.038 installation
* ✅ cocotb environment setup
* ✅ Makefile-based lint, simulation, waveform, and regression flow
* ✅ Reusable cocotb AXI-Lite master driver

### Completed RTL Blocks

* ✅ AXI-Lite GPIO peripheral
* ✅ AXI-Lite Timer peripheral
* ✅ AXI-Lite RAM model
* ✅ AXI-Lite Interconnect
* ✅ AXI-Lite RAM + GPIO + Timer subsystem
* ✅ Subsystem address map

### Completed Verification

* ✅ GPIO passes Verilator lint (`-Wall`)
* ✅ Timer passes Verilator lint (`-Wall`)
* ✅ RAM passes Verilator lint (`-Wall`)
* ✅ Subsystem passes Verilator lint (`-Wall`)
* ✅ cocotb GPIO testbench
* ✅ cocotb Timer testbench
* ✅ cocotb RAM testbench
* ✅ cocotb Subsystem testbench
* ✅ Directed tests
* ✅ Randomized tests
* ✅ Byte-strobe verification
* ✅ Invalid-address verification
* ✅ Unaligned-access verification
* ✅ Out-of-range access verification
* ✅ RAM/GPIO/Timer isolation verification
* ✅ Back-to-back subsystem access tests
* ✅ Timer interrupt verification
* ✅ AXI-Lite protocol assertions
* ✅ Functional coverage tracking
* ✅ Subsystem functional coverage: **96%**
* ✅ Full regression flow with GPIO, Timer, RAM, and Subsystem tests

### In Progress

* 🚧 Project documentation cleanup
* 🚧 Expanded verification documentation

### Planned

* Additional AXI-Lite protocol assertion coverage
* Formal-style protocol checks
* RV32I Processor Core
* SoC Top Module
* Firmware-driven verification
* Full SoC integration

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
.github/workflows/
Makefile
README.md
````

---

## Tools Used

* SystemVerilog
* Python
* cocotb
* Verilator
* GTKWave
* Yosys
* Git
* GitHub Actions
* WSL Ubuntu
* VS Code

---

## Address Map

| Peripheral | Base Address  | Address Range                 | Description               |
| ---------- | ------------- | ----------------------------- | ------------------------- |
| RAM        | `0x0000_0000` | `0x0000_0000` - `0x0000_0FFF` | 4 KB AXI-Lite RAM         |
| GPIO       | `0x1000_0000` | `0x1000_0000` - `0x1000_0FFF` | AXI-Lite GPIO peripheral  |
| Timer      | `0x1000_1000` | `0x1000_1000` - `0x1000_1FFF` | AXI-Lite Timer peripheral |

---

## Verification Status

| Block/Test Area              | Status |
| ---------------------------- | ------ |
| GPIO lint                    | ✅ PASS |
| Timer lint                   | ✅ PASS |
| RAM lint                     | ✅ PASS |
| Subsystem lint               | ✅ PASS |
| GPIO cocotb tests            | ✅ PASS |
| Timer cocotb tests           | ✅ PASS |
| RAM cocotb tests             | ✅ PASS |
| Subsystem cocotb tests       | ✅ PASS |
| Directed tests               | ✅ PASS |
| Randomized tests             | ✅ PASS |
| AXI-Lite protocol assertions | ✅ PASS |
| Functional coverage          | ✅ 96%  |
| GitHub Actions regression    | ✅ PASS |

---

## Functional Coverage

The subsystem verification environment includes a lightweight Python functional coverage tracker for AXI-Lite transactions.

Current coverage areas include:

* Address regions: RAM, GPIO, Timer, and invalid regions
* Access types: read and write
* AXI response types: OKAY and SLVERR
* WSTRB byte-enable patterns
* Error cases: unaligned access, invalid region, and out-of-range access
* Peripheral access coverage: RAM, GPIO, Timer, and invalid accesses

Current subsystem functional coverage: **96%**

---

## AXI-Lite Protocol Assertions

The subsystem includes an AXI-Lite assertion module that monitors the external AXI-Lite interface.

Current assertion checks include:

* `AWADDR` remains stable while `AWVALID` is asserted and `AWREADY` is low
* `WDATA` and `WSTRB` remain stable while `WVALID` is asserted and `WREADY` is low
* `BRESP` remains stable while `BVALID` is asserted and `BREADY` is low
* `ARADDR` remains stable while `ARVALID` is asserted and `ARREADY` is low
* `RDATA` and `RRESP` remain stable while `RVALID` is asserted and `RREADY` is low

---

## How to Run

Activate the Python virtual environment:

```bash
source .venv/bin/activate
```

Run GPIO lint and tests:

```bash
make lint_gpio
make test_gpio
```

Run Timer lint and tests:

```bash
make lint_timer
make test_timer
```

Run RAM lint and tests:

```bash
make lint_ram
make test_ram
```

Run Subsystem lint and tests:

```bash
make lint_subsystem
make test_subsystem
```

Run full regression:

```bash
make regression
```

Clean generated files:

```bash
make clean
```

View waveforms:

```bash
make test_subsystem WAVES=1
gtkwave dump.vcd
```

---

## Current Milestone

The project currently contains a verified AXI-Lite subsystem with RAM, GPIO, and Timer peripherals connected through an AXI-Lite interconnect.

The verification environment includes:

* Reusable cocotb AXI-Lite driver utilities
* Directed tests
* Randomized tests
* Byte-strobe testing
* Invalid and unaligned access testing
* Peripheral isolation testing
* Timer interrupt testing
* AXI-Lite protocol assertions
* Functional coverage tracking
* Waveform debug support
* GitHub Actions regression automation

---

## Next Milestone

The next stage is documentation polish and expanded verification documentation.

Planned documentation files:

```text
docs/
├── address_map.md
├── architecture.md
├── verification_plan.md
└── coverage_summary.md
```

After documentation cleanup, the next design milestone is a simple RV32I processor core that can access RAM, GPIO, and Timer through the AXI-Lite subsystem.

````

Then run:

```bash
git add README.md
git commit -m "Update README with RAM coverage and assertions"
git push
````
