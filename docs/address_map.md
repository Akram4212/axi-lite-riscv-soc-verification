# AXI-Lite SoC Address Map

## Overview

This document defines the memory map for the AXI-Lite RISC-V SoC Verification Platform.

The subsystem currently contains:

* AXI-Lite RAM
* AXI-Lite GPIO peripheral
* AXI-Lite Timer peripheral
* AXI-Lite interconnect

The AXI-Lite interconnect decodes the upper address bits and routes each transaction to the correct peripheral.

---

## Address Map

| Peripheral | Base Address | End Address | Size | Description |
|-----------|--------------|-------------|------|-------------|
| RAM | `0x0000_0000` | `0x0000_0FFF` | 4 KB | AXI-Lite memory region |
| GPIO | `0x1000_0000` | `0x1000_0FFF` | 4 KB | GPIO peripheral |
| Timer | `0x1000_1000` | `0x1000_1FFF` | 4 KB | Timer peripheral |

---

## RAM Region

| Address Range | Description |
|---------------|-------------|
| `0x0000_0000` - `0x0000_0FFF` | 4 KB AXI-Lite RAM |

The RAM supports:

* 32-bit read/write accesses
* Byte-level write strobes through `WSTRB`
* Boundary access checking
* Unaligned access error response
* Out-of-range access error response

Valid accesses return:

```text
AXI OKAY = 2'b00

Invalid accesses return:

AXI SLVERR = 2'b10