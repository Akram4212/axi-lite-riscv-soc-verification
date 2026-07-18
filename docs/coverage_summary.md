# AXI-Lite RISC-V SoC Architecture

## Overview

The project currently contains two independently verified subsystems:

1. A five-stage RV32I processor core with instruction and data memory handshakes.
2. An AXI-Lite subsystem containing RAM, GPIO, Timer, interconnect logic, and protocol assertions.

The processor-to-AXI-Lite adapter and final `soc_top.sv` integration remain planned work.

## Current Verified RV32I Core

```text
+----------------------------------------------------------+
|                  Cocotb Core Testbench                   |
|                                                          |
|  +----------------------+  +---------------------------+ |
|  | Instruction Memory   |  | Data Memory Model         | |
|  +----------+-----------+  +-------------+-------------+ |
+-------------|-----------------------------|---------------+
              | imem request/response       | dmem request/response
              v                             v
+----------------------------------------------------------+
|                     Five-Stage RV32I Core                |
|                                                          |
|   IF  --->  ID  --->  EX  --->  MEM  --->  WB           |
|                                                          |
|   PC       Decoder    ALU      Load/Store   Writeback     |
|            Regfile    Forward  Branch/Jump                |
|                       Hazard                              |
+----------------------------------------------------------+
```

## Current Verified AXI-Lite Subsystem

```text
                    +----------------------+
                    | Cocotb AXI-Lite      |
                    | Master Driver        |
                    +----------+-----------+
                               |
                               | AXI-Lite
                               v
                    +----------+-----------+
                    | AXI-Lite Interconnect|
                    +----+----------+------+
                         |          |
              +----------+          +----------------+
              |                                      |
      +-------v------+  +------------v---+  +--------v-------+
      | AXI-Lite RAM |  | AXI-Lite GPIO |  | AXI-Lite Timer |
      | 4 KiB        |  | Peripheral     |  | Peripheral     |
      +--------------+  +----------------+  +----------------+
```

## Planned Full SoC

```text
+----------------+
| Five-Stage     |
| RV32I Core     |
+-------+--------+
        |
        | Instruction and data memory requests
        v
+-------+----------------+
| RV32I AXI-Lite Master |
| Adapter               |
+-------+----------------+
        |
        | AXI-Lite
        v
+-------+----------------+
| AXI-Lite Interconnect |
+----+-----------+------+
     |           |
+----v-----+ +---v------+ +------v------+
| AXI RAM | | AXI GPIO | | AXI Timer   |
+----------+ +----------+ +-------------+
```

## RV32I Pipeline

The processor uses a five-stage, single-issue, in-order pipeline:

1. **IF — Instruction Fetch**
   - Holds the program counter.
   - Requests the next instruction.
   - Supports instruction-memory backpressure.

2. **ID — Instruction Decode**
   - Extracts opcode and instruction fields.
   - Generates immediates and control signals.
   - Reads the register file.
   - Detects load-use hazards.
   - Applies WB-to-ID same-cycle bypassing.

3. **EX — Execute**
   - Selects forwarded operands.
   - Performs ALU operations.
   - Computes load/store addresses.
   - Computes JALR targets.

4. **MEM — Memory and Control-Flow Resolution**
   - Issues data-memory requests.
   - Formats stores and byte strobes.
   - Extends load results.
   - Resolves conditional branches, JAL, and JALR.

5. **WB — Writeback**
   - Selects ALU, load, or PC+4 data.
   - Writes the destination register.
   - Commits EBREAK halt after older instructions retire.

## Pipeline Registers

```text
IF/ID  -> instruction and instruction PC
ID/EX  -> decoded controls, operands, immediate, register selectors
EX/MEM -> ALU result, store data, branch controls, memory controls
MEM/WB -> final memory/ALU result and writeback controls
```

Each latch supports the controls required for its stage, including reset, pipeline advancement, bubble insertion, and redirect flushing where applicable.

## Data Hazard Handling

### MEM-to-EX Forwarding

A result in MEM may be forwarded directly to an instruction in EX when:

- The MEM instruction writes a nonzero destination register.
- The destination matches an EX source register.
- The MEM result is available without waiting for a load response.

### WB-to-EX Forwarding

A result in WB may be forwarded to EX when the destination register matches an EX source and no newer MEM result has priority.

### WB-to-ID Bypass

The register file write and ID/EX capture occur on the same active clock edge. A decode-stage bypass supplies the WB value directly to ID so that the ID/EX latch does not capture a stale register value.

### Load-Use Stall

When a load is in EX and the following instruction consumes the load destination:

- The PC and IF/ID register are frozen.
- A bubble is inserted into ID/EX.
- The load advances toward MEM/WB.

## Control Hazards

Branches and jumps are resolved in MEM.

A taken branch, JAL, or JALR:

- Selects the redirect target.
- Flushes younger instructions.
- Updates the PC.
- Preserves older instructions so they can retire.

JALR clears target address bit zero as required by RV32I.

Resolving control flow in MEM simplifies the datapath but creates a larger taken-branch penalty than an earlier-stage implementation.

## Memory Interface

The core exposes separate instruction and data interfaces.

### Instruction Interface

```text
imemREN
imemaddr
ihit
imemload
```

### Data Interface

```text
dmemREN
dmemWEN
dmemaddr
dmemstore
dmem_wstrb
dhit
dmemload
```

A memory operation advances only when its required response is available. This supports instruction- and data-memory backpressure in verification.

## Loads and Stores

### Supported Loads

- `LB`
- `LH`
- `LW`
- `LBU`
- `LHU`

The MEM stage selects the requested byte or halfword and applies signed or unsigned extension.

### Supported Stores

- `SB`
- `SH`
- `SW`

The MEM stage shifts store data and generates four-bit write strobes.

## Illegal Instructions

Unsupported or malformed instructions set `illegal` and are forced to be side-effect free:

- No register write
- No data-memory read or write
- No branch or jump redirect
- No branch-condition controls
- No FENCE, ECALL, EBREAK, or halt side effects

The core records that an illegal instruction was observed and stops it through the controlled halt path after older instructions can retire.

## AXI-Lite Subsystem

The AXI-Lite interconnect decodes the address and routes transactions to RAM, GPIO, or Timer. Invalid and unaligned accesses are verified to return appropriate error responses.

The final SoC will use an adapter between the processor's Harvard-style request interfaces and the shared AXI-Lite subsystem.

## Known Architectural Limitations

- No CSR implementation
- No privileged ISA
- No trap handler
- No interrupts
- No RV32M multiplication or division
- No RV32A atomics
- No cache implementation in the current core
- No branch prediction
- Branches and jumps are resolved in MEM
- AXI-Lite processor adapter is not integrated yet
- Firmware-driven full-SoC verification is not implemented yet
