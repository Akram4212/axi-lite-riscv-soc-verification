# SoC Address Map

## Overview

The current verified AXI-Lite subsystem contains:

- 4 KiB AXI-Lite RAM
- AXI-Lite GPIO peripheral
- AXI-Lite Timer peripheral

Each target occupies one 4 KiB address region. The interconnect converts the
global AXI-Lite address into a local peripheral offset before forwarding the
transaction.

## Global Address Regions

| Target | Base address | End address | Size | Description |
|---|---:|---:|---:|---|
| RAM | `0x0000_0000` | `0x0000_0FFF` | 4 KiB | AXI-Lite read/write memory |
| GPIO | `0x1000_0000` | `0x1000_0FFF` | 4 KiB | General-purpose input/output peripheral |
| Timer | `0x1000_1000` | `0x1000_1FFF` | 4 KiB | Counter, compare, status, and interrupt control |
| Unmapped space | — | — | — | Transactions return AXI-Lite `SLVERR` |

The SystemVerilog definitions are located in:

```text
include/soc_addr_map.vh
```

```systemverilog
`define RAM_BASE_ADDR   32'h0000_0000
`define GPIO_BASE_ADDR  32'h1000_0000
`define TIMER_BASE_ADDR 32'h1000_1000
`define ADDR_MASK       32'hFFFF_F000
```

## Access Rules

- The AXI-Lite data width is 32 bits.
- Register and RAM accesses must be 32-bit word aligned.
- An address is aligned when `address[1:0] == 2'b00`.
- Unaligned accesses return `SLVERR`.
- Unsupported register offsets return `SLVERR`.
- RAM accesses outside the 4 KiB RAM region return `SLVERR`.
- `WSTRB[3:0]` controls which byte lanes are modified during valid writes.
- Successful accesses return `OKAY`.

## RAM Address Map

| Global address range | Access | Description |
|---|---|---|
| `0x0000_0000`–`0x0000_0FFF` | Read/write | 4 KiB AXI-Lite RAM |

### RAM Organization

- Capacity: 4096 bytes
- Data width: 32 bits
- Number of words: 1024
- Word addresses: `0x0000_0000`, `0x0000_0004`, …, `0x0000_0FFC`
- Partial writes are supported through `WSTRB`.
- Reads return one aligned 32-bit word.

## GPIO Register Map

GPIO base address:

```text
0x1000_0000
```

| Offset | Global address | Register | Access | Reset | Description |
|---:|---:|---|---|---:|---|
| `0x00` | `0x1000_0000` | `DATA_OUT` | Read/write | `0x0000_0000` | GPIO output value |
| `0x04` | `0x1000_0004` | `DATA_IN` | Read-only | External input | Current GPIO input value |
| `0x08` | `0x1000_0008` | `DATA_DIR` | Read/write | `0x0000_0000` | Direction control; `1` = output, `0` = input |
| `0x0C` | `0x1000_000C` | `DATA_OUT_SET` | Write-only | — | Writing a `1` sets the corresponding `DATA_OUT` bit |
| `0x10` | `0x1000_0010` | `DATA_OUT_CLR` | Write-only | — | Writing a `1` clears the corresponding `DATA_OUT` bit |

### GPIO Behavior

#### `DATA_OUT`

The register directly drives `gpio_o`.

A normal write updates only byte lanes selected by `WSTRB`.

#### `DATA_IN`

A read returns the live `gpio_i` input.

Writes to `DATA_IN` return `SLVERR`.

#### `DATA_DIR`

The register directly drives `gpio_oe`.

```text
DATA_DIR[n] = 1  -> GPIO bit n is configured as an output
DATA_DIR[n] = 0  -> GPIO bit n is configured as an input
```

#### `DATA_OUT_SET`

For every written bit containing `1`:

```text
DATA_OUT = DATA_OUT | write_data
```

Only byte lanes enabled by `WSTRB` participate in the operation.

Reads return zero.

#### `DATA_OUT_CLR`

For every written bit containing `1`:

```text
DATA_OUT = DATA_OUT & ~write_data
```

Only byte lanes enabled by `WSTRB` participate in the operation.

Reads return zero.

## Timer Register Map

Timer base address:

```text
0x1000_1000
```

| Offset | Global address | Register | Access | Reset | Description |
|---:|---:|---|---|---:|---|
| `0x00` | `0x1000_1000` | `CTRL` | Read/write | `0x0000_0000` | Enable, clear, and interrupt-enable controls |
| `0x04` | `0x1000_1004` | `COUNT` | Read/write | `0x0000_0000` | Current 32-bit counter value |
| `0x08` | `0x1000_1008` | `COMPARE` | Read/write | `0x0000_0000` | Compare threshold |
| `0x0C` | `0x1000_100C` | `STATUS` | Read / write-one-to-clear | `0x0000_0000` | Timer match status |

## Timer `CTRL` Register

| Bit | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| `0` | `ENABLE` | Read/write | `0` | Enables counter incrementing |
| `1` | `CLEAR` | Read/write, self-clearing | `0` | Clears `COUNT` and `STATUS.MATCH` |
| `2` | `IRQ_EN` | Read/write | `0` | Enables `timer_irq` when a match is pending |
| `31:3` | Reserved | — | `0` | Reserved |

### `ENABLE`

When `CTRL.ENABLE` is set:

```text
COUNT = COUNT + 1
```

on each timer clock cycle, unless a clear operation takes priority.

### `CLEAR`

Writing `1` to `CTRL.CLEAR`:

- Clears `COUNT` to zero.
- Clears `STATUS.MATCH`.
- Automatically clears the `CLEAR` bit.

## Timer `COUNT` Register

`COUNT` contains the current timer value.

Software may read or write the register. A write honors `WSTRB`.

## Timer `COMPARE` Register

When the timer is enabled and `COMPARE` is nonzero, the match flag is set when
the next counter value reaches or exceeds `COMPARE`.

Conceptually:

```text
if ENABLE && COMPARE != 0 && COUNT + 1 >= COMPARE:
    STATUS.MATCH = 1
```

A write honors `WSTRB`.

## Timer `STATUS` Register

| Bit | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| `0` | `MATCH` | Read / write-one-to-clear | `0` | Indicates that the compare threshold was reached |
| `31:1` | Reserved | — | `0` | Reserved |

To clear the pending match flag, write:

```text
WDATA[0] = 1
WSTRB[0] = 1
```

to `STATUS`.

## Timer Interrupt

The timer interrupt output is asserted when both conditions are true:

```text
timer_irq = STATUS.MATCH && CTRL.IRQ_EN
```

Clearing `STATUS.MATCH` or clearing `CTRL.IRQ_EN` deasserts the interrupt.

## AXI-Lite Responses

| Response | Encoding | Meaning |
|---|---:|---|
| `OKAY` | `2'b00` | Valid, successful transaction |
| `SLVERR` | `2'b10` | Invalid address, invalid register operation, unaligned access, or out-of-range access |

## Software Definitions

The following constants can be used by future firmware:

```c
#define RAM_BASE          0x00000000u

#define GPIO_BASE         0x10000000u
#define GPIO_DATA_OUT     (GPIO_BASE + 0x00u)
#define GPIO_DATA_IN      (GPIO_BASE + 0x04u)
#define GPIO_DATA_DIR     (GPIO_BASE + 0x08u)
#define GPIO_DATA_OUT_SET (GPIO_BASE + 0x0Cu)
#define GPIO_DATA_OUT_CLR (GPIO_BASE + 0x10u)

#define TIMER_BASE        0x10001000u
#define TIMER_CTRL        (TIMER_BASE + 0x00u)
#define TIMER_COUNT       (TIMER_BASE + 0x04u)
#define TIMER_COMPARE     (TIMER_BASE + 0x08u)
#define TIMER_STATUS      (TIMER_BASE + 0x0Cu)

#define TIMER_CTRL_ENABLE (1u << 0)
#define TIMER_CTRL_CLEAR  (1u << 1)
#define TIMER_CTRL_IRQ_EN (1u << 2)

#define TIMER_STATUS_MATCH (1u << 0)
```

## Current Integration Boundary

The RAM, GPIO, Timer, and AXI-Lite interconnect are verified as an independent
subsystem.

The five-stage RV32I core currently uses separate instruction and data memory
handshakes. The planned processor AXI-Lite adapter will use this address map
when connecting the core to RAM and memory-mapped peripherals.
