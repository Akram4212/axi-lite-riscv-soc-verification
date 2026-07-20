# Architecture

## 1. System Overview

The platform integrates a five-stage RV32I processor with an AXI4-Lite memory-mapped subsystem.

```text
+--------------------------+
| Five-stage RV32I Core    |
|                          |
| IF -> ID -> EX -> MEM -> WB
+-------------+------------+
              |
              | instruction and data requests
              v
+--------------------------+
| RV32I AXI-Lite Master    |
| Adapter                  |
+-------------+------------+
              |
              | AXI4-Lite
              v
+--------------------------+
| AXI-Lite Interconnect    |
+------+-----------+-------+
       |           |
       |           +-------------------+
       |                               |
       v                               v
+-------------+                +---------------+
| 4 KiB RAM   |                | GPIO          |
| 0x00000000  |                | 0x10000000    |
+-------------+                +---------------+
                                       |
                                       +-------------------+
                                                           |
                                                           v
                                                   +---------------+
                                                   | Timer         |
                                                   | 0x10001000    |
                                                   +---------------+
```

The processor starts fetching from `0x0000_0000`. Firmware is compiled externally and loaded into RAM before reset is released.

## 2. Top-Level Hierarchy

```text
soc_top_wrapper
└── soc_top
    ├── rv32i_core
    │   ├── rv32i_pc
    │   ├── if_id_latch
    │   ├── rv32i_decoder
    │   ├── rv32i_regfile
    │   ├── id_ex_latch
    │   ├── forwarding_unit
    │   ├── rv32i_alu
    │   ├── ex_mem_latch
    │   ├── hazard_unit
    │   └── mem_wb_latch
    ├── rv32i_axi_lite_master
    └── axi_lite_subsystem
        ├── axi_lite_interconnect
        ├── axi_lite_ram
        ├── gpio
        ├── timer
        └── axi_lite_assertions
```

## 3. RV32I Processor

### 3.1 Pipeline

The processor uses the conventional five-stage organization:

| Stage | Responsibility |
|---|---|
| IF | Fetch instruction and update the program counter |
| ID | Decode instruction and read register operands |
| EX | Execute ALU operation, branch comparison, or address calculation |
| MEM | Perform data-memory access and propagate branch/control results |
| WB | Write results to the register file and retire halt conditions |

Pipeline state is held in:

- `if_id_latch`
- `id_ex_latch`
- `ex_mem_latch`
- `mem_wb_latch`

### 3.2 Register File

The register file contains 32 integer registers. Register `x0` is hardwired to zero.

Writeback-to-decode bypassing is implemented so an instruction in the decode stage can observe a value being written in the same cycle.

### 3.3 Forwarding and Hazards

The forwarding unit resolves common read-after-write dependencies using values from later pipeline stages.

The hazard unit supports:

- Load-use detection
- Decode and fetch freezing
- Bubble insertion
- Pipeline flushing after control-flow redirection

A load-use dependency stalls the front of the pipeline until the loaded value is available.

### 3.4 Branches and Jumps

The implemented control-flow instructions include:

- `BEQ`
- `BNE`
- `BLT`
- `BGE`
- `BLTU`
- `BGEU`
- `JAL`
- `JALR`

Taken branches and jumps redirect the program counter and flush younger instructions.

### 3.5 Halt and Illegal Instructions

`EBREAK` is used by firmware tests as the successful halt mechanism. Halt becomes visible when the instruction reaches the writeback stage.

Unsupported or invalid encodings assert the `illegal` output. Illegal instructions suppress architectural side effects.

### 3.6 Supported ISA

The processor targets the RV32I base integer instruction set. The implemented groups include:

- Integer register-register operations
- Integer immediate operations
- Upper-immediate operations
- Loads and stores
- Conditional branches
- `JAL` and `JALR`
- `FENCE`
- `EBREAK`

Atomic operations are not supported. The AXI-Lite master asserts if an unsupported atomic request is generated.

## 4. RV32I-to-AXI-Lite Master Adapter

The core presents separate instruction and data request interfaces. The adapter serializes these requests onto one AXI4-Lite master interface.

### 4.1 Arbitration

The adapter uses this priority:

1. Data write
2. Data read
3. Instruction read

Only one AXI-Lite transaction is outstanding at a time.

### 4.2 Write Transactions

AXI-Lite write address and write data channels may handshake independently. The adapter tracks both handshakes and waits for the write response before completing the core request.

Byte strobes are generated for:

- Byte stores
- Halfword stores
- Word stores

### 4.3 Read Transactions

Read responses are aligned and extended according to the requested operation:

- `LB`
- `LBU`
- `LH`
- `LHU`
- `LW`

The adapter distinguishes instruction and data responses and rejects stale instruction responses after a control-flow redirect.

### 4.4 Error Handling

Any non-`OKAY` AXI response sets the sticky `bus_error` output. Normal firmware workloads require `bus_error` to remain deasserted.

## 5. AXI-Lite Subsystem

### 5.1 Address Map

| Slave | Base address | End address |
|---|---:|---:|
| RAM | `0x0000_0000` | `0x0000_0FFF` |
| GPIO | `0x1000_0000` | `0x1000_0FFF` |
| Timer | `0x1000_1000` | `0x1000_1FFF` |

The interconnect decodes each request, routes it to one slave, and returns `SLVERR` for invalid or unmapped accesses.

### 5.2 AXI-Lite RAM

The RAM is 4 KiB by default:

```systemverilog
logic [31:0] mem [0:1023];
```

Features include:

- Word-aligned AXI-Lite accesses
- Byte write strobes
- Range checking
- `SLVERR` on invalid accesses
- Optional initialization with `INIT_FILE`

Initialization behavior:

```systemverilog
if (INIT_FILE != "") begin
    $readmemh(INIT_FILE, mem);
end
```

The initialization parameter is propagated through the hierarchy:

```text
soc_top_wrapper.RAM_INIT_FILE
    -> soc_top.RAM_INIT_FILE
    -> axi_lite_subsystem.RAM_INIT_FILE
    -> axi_lite_ram.INIT_FILE
```

### 5.3 GPIO Peripheral

| Offset | Register | Access | Description |
|---:|---|---|---|
| `0x00` | `DATA_OUT` | RW | Output data |
| `0x04` | `DATA_IN` | RO | Live GPIO input |
| `0x08` | `DATA_DIR` | RW | Output-enable direction |
| `0x0C` | `DATA_OUT_SET` | WO | Set selected output bits |
| `0x10` | `DATA_OUT_CLR` | WO | Clear selected output bits |

Writes to the read-only input register return `SLVERR`.

### 5.4 Timer Peripheral

| Offset | Register | Access | Description |
|---:|---|---|---|
| `0x00` | `CTRL` | RW | Control bits |
| `0x04` | `COUNT` | RW | Current timer count |
| `0x08` | `COMPARE` | RW | Compare threshold |
| `0x0C` | `STATUS` | R/W1C | Match status |

Control bits:

| Bit | Name | Description |
|---:|---|---|
| 0 | `ENABLE` | Enables counting |
| 1 | `CLEAR` | Clears count and match status |
| 2 | `IRQ_EN` | Enables interrupt output |

The interrupt equation is:

```text
timer_irq = STATUS.MATCH && CTRL.IRQ_EN
```

## 6. Firmware Flow

The build system supports selectable firmware:

```bash
make test_soc FIRMWARE=<program>
```

The source-to-execution flow is:

```text
firmware/<program>.S
        |
        v
riscv64-unknown-elf-gcc
        |
        v
firmware/<program>.elf
        |
        v
riscv64-unknown-elf-objcopy
        |
        v
firmware/<program>.bin
        |
        v
scripts/bin_to_hex.py
        |
        v
firmware/<program>.hex
        |
        v
firmware/selected.hex
        |
        v
$readmemh -> AXI-Lite RAM
```

The linker places `_start` at address `0x0000_0000`, matching the processor reset vector.

## 7. Debug Outputs

The SoC exposes debug signals for verification:

- Current program counter
- Current instruction
- Opcode
- `funct3`
- `funct7`
- Pipeline enable
- Redirect indication
- Bubble indication
- Writeback enable
- Writeback destination register
- Writeback data

These signals are used by cocotb failure messages and waveform debugging.

## 8. Clock and Reset

The simulation wrapper provides:

- `CLK`
- Active-low reset `nRST`

The core and peripheral subsystem use the same simulation clock. Reset implementation details differ among blocks, and the integrated Verilator target suppresses the resulting `SYNCASYNCNET` diagnostic after review.
