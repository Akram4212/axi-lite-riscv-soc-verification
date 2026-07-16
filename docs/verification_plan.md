# Verification Plan

## Overview

This document describes the verification strategy for the AXI-Lite RISC-V SoC Verification Platform.

The project uses:

* SystemVerilog RTL
* cocotb Python testbenches
* Verilator simulation
* AXI-Lite protocol assertions
* Functional coverage tracking
* GitHub Actions regression automation

The current verification scope includes:

* AXI-Lite GPIO peripheral
* AXI-Lite Timer peripheral
* AXI-Lite RAM
* AXI-Lite Interconnect
* AXI-Lite RAM + GPIO + Timer subsystem

---

## Verification Goals

The main goals are:

1. Verify that each AXI-Lite peripheral behaves correctly in isolation.
2. Verify that the interconnect routes transactions to the correct target.
3. Verify that invalid and unaligned accesses return correct error responses.
4. Verify that byte strobes modify only selected bytes.
5. Verify that subsystem peripherals do not corrupt each other.
6. Verify that randomized transactions behave correctly.
7. Verify AXI-Lite protocol stability rules using assertions.
8. Track functional coverage for important verification scenarios.
9. Run all tests automatically through regression and CI.

---

## Testbench Architecture

The verification environment uses a reusable AXI-Lite master driver.

```text
tb/
├── axi_lite_master.py
├── axi_lite_coverage.py
├── test_gpio.py
├── test_timer.py
├── test_axi_lite_ram.py
└── test_axi_lite_subsystem.py