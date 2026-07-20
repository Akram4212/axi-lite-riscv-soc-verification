# AXI-Lite RV32I SoC Verification Platform

A verification-focused SystemVerilog project that integrates a five-stage RV32I processor with an AXI4-Lite memory-mapped subsystem containing RAM, GPIO, and Timer peripherals.

The project includes block-level cocotb verification, full-SoC firmware execution, Verilator assertions and coverage, and a reproducible RISC-V firmware build flow.

## Project Status

The first complete platform milestone includes:

- Five-stage RV32I processor core
- RV32I-to-AXI4-Lite master adapter
- AXI4-Lite interconnect and subsystem
- 4 KiB AXI-Lite RAM
- Memory-mapped GPIO peripheral
- Memory-mapped Timer peripheral
- SystemVerilog AXI-Lite assertions
- Cocotb unit, subsystem, processor, and full-SoC tests
- External RV32I firmware build and RAM initialization
- Five firmware-driven integration workloads
- Merged full-SoC Verilator coverage
- GitHub Actions regression

## Architecture

```text
                         +----------------------+
                         |   Five-stage RV32I   |
                         |      CPU Core        |
                         +----------+-----------+
                                    |
                         Instruction/Data request
                                    |
                         +----------v-----------+
                         | RV32I AXI-Lite       |
                         | Master Adapter       |
                         +----------+-----------+
                                    |
                              AXI4-Lite bus
                                    |
                    +---------------v---------------+
                    |      AXI-Lite Subsystem       |
                    |                               |
                    |  +---------+  +------------+  |
                    |  | 4 KiB   |  |    GPIO    |  |
                    |  |  RAM    |  | Peripheral |  |
                    |  +---------+  +------------+  |
                    |                               |
                    |       +----------------+      |
                    |       | Timer/IRQ      |      |
                    |       | Peripheral     |      |
                    |       +----------------+      |
                    +-------------------------------+
```

See [`docs/architecture.md`](docs/architecture.md) for the detailed hierarchy, pipeline behavior, memory map, and firmware-loading flow.

## Memory Map

| Region | Address range |
|---|---|
| RAM | `0x0000_0000`–`0x0000_0FFF` |
| GPIO | `0x1000_0000`–`0x1000_0FFF` |
| Timer | `0x1000_1000`–`0x1000_1FFF` |

### GPIO Registers

| Offset | Register | Access | Description |
|---:|---|---|---|
| `0x00` | `DATA_OUT` | RW | Output value |
| `0x04` | `DATA_IN` | RO | Live input value |
| `0x08` | `DATA_DIR` | RW | Direction; `1` selects output |
| `0x0C` | `DATA_OUT_SET` | WO | Set selected output bits |
| `0x10` | `DATA_OUT_CLR` | WO | Clear selected output bits |

### Timer Registers

| Offset | Register | Access | Description |
|---:|---|---|---|
| `0x00` | `CTRL` | RW | Enable, clear, and IRQ enable |
| `0x04` | `COUNT` | RW | Current count |
| `0x08` | `COMPARE` | RW | Match value |
| `0x0C` | `STATUS` | R/W1C | Match status |

`CTRL` bits:

- Bit 0: `ENABLE`
- Bit 1: `CLEAR`
- Bit 2: `IRQ_EN`

## Firmware Workloads

The full-SoC regression builds and executes five RV32I assembly programs:

| Firmware | Main purpose |
|---|---|
| `start` | Basic GPIO and Timer smoke test |
| `memory_test` | Word, byte, and halfword RAM accesses |
| `branch_test` | Branches, loops, `JAL`, and `JALR` |
| `gpio_test` | GPIO direction, output, set, clear, and readback |
| `timer_test` | Timer count, compare, clear, status, and IRQ behavior |

Firmware source is assembled and linked into an ELF file, converted to a raw binary, converted to a Verilog hexadecimal image, and loaded into AXI-Lite RAM with `$readmemh`.

```text
firmware/<program>.S
        |
        v
RISC-V assembler/linker
        |
        v
firmware/<program>.elf
        |
        v
firmware/<program>.bin
        |
        v
scripts/bin_to_hex.py
        |
        v
firmware/selected.hex
        |
        v
AXI-Lite RAM -> RV32I execution
```

## Requirements

The tested environment uses:

- Ubuntu or WSL
- GNU Make
- Python 3
- cocotb 2.0.1
- Verilator 5.038
- `riscv64-unknown-elf-gcc`
- `riscv64-unknown-elf-objcopy`
- LCOV and `genhtml` for HTML coverage reports

On Ubuntu 24.04, install the RISC-V toolchain and coverage utilities with:

```bash
sudo apt-get update
sudo apt-get install -y \
  gcc-riscv64-unknown-elf \
  binutils-riscv64-unknown-elf \
  lcov
```

Create the Python environment:

```bash
python3 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
python -m pip install cocotb==2.0.1 pytest
```

## Common Commands

Run the complete regression:

```bash
make clean
make regression_all
```

Run every firmware workload:

```bash
make clean
make test_firmware_suite
```

Run one firmware image:

```bash
make test_soc FIRMWARE=memory_test
```

Build one firmware image without simulation:

```bash
make firmware FIRMWARE=branch_test
```

Run RV32I core tests with coverage:

```bash
make coverage_rv32i_core
```

Generate merged full-SoC firmware coverage:

```bash
make coverage_soc
```

Open the generated HTML report:

```bash
xdg-open coverage_soc/html/index.html
```

## Verification Results

### RV32I Core

| Metric | Result |
|---|---:|
| Core tests | 13/13 PASS |
| Overall line coverage | 92.0% — 923/1003 |
| Overall branch coverage | 82.9% — 1940/2339 |
| RTL line coverage | 91.2% — 665/729 |
| RTL branch coverage | 96.8% — 448/463 |
| `rv32i_core.sv` line coverage | 93.5% — 174/186 |
| `rv32i_core.sv` branch coverage | 99.4% — 335/337 |

### RV32I Decoder

| Metric | Result |
|---|---:|
| Overall line coverage | 98.2% — 332/338 |
| Overall branch coverage | 100.0% — 220/220 |
| Decoder RTL line coverage | 98.4% — 254/258 |
| Decoder RTL branch coverage | 100.0% — 20/20 |

### AXI-Lite Functional Coverage

```text
96%
```

### Merged Full-SoC Firmware Coverage

| Metric | Covered | Total | Rate |
|---|---:|---:|---:|
| Lines | 1,533 | 1,770 | 86.6% |
| Branches | 3,528 | 5,165 | 68.3% |

The merged integration report includes RTL, SystemVerilog interfaces, and the simulation wrapper. Block-level regressions provide more exhaustive coverage for individual components such as the decoder.

See [`docs/coverage_summary.md`](docs/coverage_summary.md) for details.

## Repository Structure

```text
.
├── .github/workflows/       GitHub Actions regression
├── docs/                    Architecture, verification, and coverage
├── firmware/                RV32I assembly workloads and linker script
├── include/                 SystemVerilog interfaces and shared headers
├── rtl/                     Processor and AXI-Lite RTL
├── scripts/                 Firmware and verification utilities
├── tb/                      Cocotb tests and simulation wrappers
└── Makefile                 Build, lint, test, regression, and coverage flow
```

## Documentation

- [`docs/architecture.md`](docs/architecture.md)
- [`docs/verification_plan.md`](docs/verification_plan.md)
- [`docs/coverage_summary.md`](docs/coverage_summary.md)

## License

Add the repository's selected license in a root-level `LICENSE` file before public release if one is not already present.
