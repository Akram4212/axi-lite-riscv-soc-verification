# Project Documentation

This directory contains the design and verification documentation for the current AXI-Lite subsystem milestone.

## Documents

| Document | Purpose |
|---|---|
| [Address Map](address_map.md) | Global memory map, register definitions, reset values, and access behavior |
| [Architecture](architecture.md) | RTL hierarchy, transaction routing, interfaces, reset behavior, and current limitations |
| [Verification Plan](verification_plan.md) | Verification objectives, feature matrices, assertions, coverage goals, regression, and exit criteria |
| [Coverage Summary](coverage_summary.md) | Current functional-coverage result, hit bins, exclusions, and interpretation |

## Current Milestone

The implemented subsystem contains:

- A 4 KiB AXI-Lite RAM
- An AXI-Lite GPIO peripheral
- An AXI-Lite timer peripheral
- A one-master, three-target AXI-Lite interconnect
- External-interface AXI-Lite protocol assertions
- Directed and randomized cocotb verification
- Functional coverage
- Verilator lint and simulation
- GitHub Actions regression

The RV32I processor core and firmware-driven full-SoC verification are planned next-stage work.
