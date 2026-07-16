# AXI-Lite SoC Architecture

## Overview

This project implements an AXI-Lite based SoC subsystem using SystemVerilog RTL and verifies it using cocotb, Verilator, assertions, and functional coverage.

The current subsystem includes:

* AXI-Lite interconnect
* AXI-Lite RAM
* AXI-Lite GPIO peripheral
* AXI-Lite Timer peripheral
* AXI-Lite protocol assertion module

The long-term goal is to connect a simple RV32I processor core to this subsystem and build a small firmware-driven SoC verification platform.

---

## High-Level Architecture

```text
                +----------------------+
                |  cocotb AXI-Lite     |
                |  Master Driver       |
                +----------+-----------+
                           |
                           | AXI-Lite
                           |
                +----------v-----------+
                | AXI-Lite Subsystem   |
                |                      |
                |  +----------------+  |
                |  | Interconnect   |  |
                |  +---+--------+---+  |
                |      |        |      |
        +-------+      |        +-------+
        |              |                |
+-------v------+ +-----v------+ +-------v------+
| AXI RAM      | | AXI GPIO   | | AXI Timer    |
| 4 KB         | | Peripheral | | Peripheral   |
+--------------+ +------------+ +--------------+