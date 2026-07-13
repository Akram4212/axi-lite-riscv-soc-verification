# AXI-Lite RISC-V SoC Verification Platform

## Overview

This project implements and verifies an AXI-Lite based RISC-V SoC using open-source EDA tools. The project focuses on RTL quality, AXI-Lite protocol behavior, verification automation, and reusable Python/cocotb test infrastructure.

---

## Current Progress

### Completed

* ✅ WSL/Linux development environment
* ✅ Git/GitHub workflow
* ✅ Verilator 5.038 installation
* ✅ cocotb environment setup
* ✅ Makefile-based lint and simulation flow
* ✅ AXI-Lite GPIO peripheral
* ✅ GPIO register map
* ✅ GPIO passes Verilator lint (`-Wall`)
* ✅ cocotb GPIO testbench
* ✅ GPIO reset test
* ✅ GPIO basic AXI-Lite read/write test
* ✅ GPIO input-read test
* ✅ GPIO set/clear register test
* ✅ GPIO invalid-access test
* ✅ GPIO byte-strobe test
* ✅ GPIO randomized read/write test
* ✅ AXI-Lite Timer peripheral
* ✅ Timer register map
* ✅ Timer passes Verilator lint (`-Wall`)
* ✅ cocotb Timer testbench
* ✅ Timer reset test
* ✅ Timer enable-count test
* ✅ Timer disable-hold test
* ✅ Timer clear test
* ✅ Timer compare-match test
* ✅ Timer IRQ test
* ✅ Timer status-clear test
* ✅ Timer byte-strobe test
* ✅ Timer invalid-access test
* ✅ Timer randomized compare test
* ✅ GPIO and Timer regression flow

### In Progress

* 🚧 AXI-Lite Interconnect planning
* 🚧 Project documentation cleanup

### Planned

* AXI-Lite Interconnect
* RAM model
* RV32I Processor Core
* SoC Top Module
* Directed verification expansion
* Randomized verification expansion
* Functional coverage
* GTKWave debug
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
Makefile
README.md
```

---

## Tools

* SystemVerilog
* Python
* cocotb
* Verilator
* GTKWave
* Yosys
* Git
* VS Code
* WSL Ubuntu

---

## Development Roadmap

| Milestone               | Status         |
| ----------------------- | -------------- |
| Development environment | ✅ Complete     |
| GPIO RTL                | ✅ Complete     |
| GPIO Verilator lint     | ✅ Complete     |
| GPIO cocotb testbench   | ✅ Complete     |
| GPIO directed tests     | ✅ Complete     |
| GPIO randomized tests   | ✅ Complete     |
| Timer RTL               | ✅ Complete     |
| Timer Verilator lint    | ✅ Complete     |
| Timer cocotb testbench  | ✅ Complete     |
| Timer directed tests    | ✅ Complete     |
| Timer randomized tests  | ✅ Complete     |
| AXI-Lite interconnect   | 🚧 In Progress |
| RAM model               | ⏳ Planned      |
| RISC-V Core             | ⏳ Planned      |
| Full SoC integration    | ⏳ Planned      |
| Functional coverage     | ⏳ Planned      |
| CI/CD regression        | ⏳ Planned      |

---

## Current Verification Status

| Check                   | Status              |
| ----------------------- | ------------------- |
| GPIO Verilator lint     | ✅ PASS              |
| Timer Verilator lint    | ✅ PASS              |
| GPIO cocotb simulation  | ✅ PASS              |
| Timer cocotb simulation | ✅ PASS              |
| GPIO directed tests     | ✅ PASS              |
| GPIO randomized tests   | ✅ PASS              |
| Timer directed tests    | ✅ PASS              |
| Timer randomized tests  | ✅ PASS              |
| GPIO test result        | ✅ 7/7 PASS          |
| Timer test result       | ✅ PASS              |
| Regression flow         | ✅ GPIO + Timer PASS |

---

## GPIO Verification Tests

| Test                                        | Purpose                                                      | Status |
| ------------------------------------------- | ------------------------------------------------------------ | ------ |
| `test_gpio_reset`                           | Verifies reset initializes GPIO registers and outputs        | ✅ PASS |
| `test_gpio_basic_read_write`                | Verifies AXI-Lite read/write access to GPIO registers        | ✅ PASS |
| `test_gpio_input_read`                      | Verifies `DATA_IN` reflects external GPIO input pins         | ✅ PASS |
| `test_gpio_set_clear`                       | Verifies `DATA_OUT_SET` and `DATA_OUT_CLR` behavior          | ✅ PASS |
| `test_gpio_invalid_write_to_input_register` | Verifies invalid write handling for read-only input register | ✅ PASS |
| `test_gpio_byte_strobe`                     | Verifies AXI-Lite `WSTRB` byte-level write behavior          | ✅ PASS |
| `test_gpio_random_read_write`               | Verifies randomized GPIO register read/write behavior        | ✅ PASS |

---

## Timer Verification Tests

| Test                             | Purpose                                                                | Status |
| -------------------------------- | ---------------------------------------------------------------------- | ------ |
| `test_timer_reset`               | Verifies timer registers and IRQ reset correctly                       | ✅ PASS |
| `test_timer_enable_count`        | Verifies counter increments when enabled                               | ✅ PASS |
| `test_timer_disable_holds_count` | Verifies counter holds value when disabled                             | ✅ PASS |
| `test_timer_clear`               | Verifies clear control bit resets count and status                     | ✅ PASS |
| `test_timer_compare_match`       | Verifies status flag sets when count reaches compare value             | ✅ PASS |
| `test_timer_irq`                 | Verifies interrupt output asserts on compare match when IRQ is enabled | ✅ PASS |
| `test_timer_status_clear`        | Verifies write-one-to-clear behavior for status register               | ✅ PASS |
| `test_timer_byte_strobe`         | Verifies AXI-Lite `WSTRB` byte-level write behavior                    | ✅ PASS |
| `test_timer_invalid_access`      | Verifies invalid and unaligned accesses return `SLVERR`                | ✅ PASS |
| `test_timer_random_compare`      | Verifies randomized compare values trigger match correctly             | ✅ PASS |

---

## How to Run

Activate the Python virtual environment:

```bash
source .venv/bin/activate
```

Run GPIO lint:

```bash
make lint_gpio
```

Run GPIO cocotb tests:

```bash
make test_gpio
```

Run Timer lint:

```bash
make lint_timer
```

Run Timer cocotb tests:

```bash
make test_timer
```

Run all implemented checks:

```bash
make regression
```

Clean generated files:

```bash
make clean
```

---

## Current Milestone

The AXI-Lite GPIO and Timer peripherals are implemented, lint-clean with Verilator, and verified using cocotb. The verification environment includes directed tests, randomized tests, byte-strobe checks, invalid-access handling, timer compare-match testing, interrupt verification, and Makefile-based regression automation.

---

## Next Milestone

The next development stage is the AXI-Lite Interconnect. The interconnect will connect one AXI-Lite master to multiple AXI-Lite slaves, including the GPIO and Timer peripherals.

Planned address map:

| Peripheral | Base Address  |
| ---------- | ------------- |
| GPIO       | `0x1000_0000` |
| Timer      | `0x1000_1000` |

The interconnect verification plan will check address decoding, GPIO access, Timer access, invalid-address handling, and back-to-back AXI-Lite transactions.
