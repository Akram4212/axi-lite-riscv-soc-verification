# AXI-Lite SoC Address Map

## 1. Purpose

This document defines the current memory map and software-visible register behavior of the AXI-Lite subsystem.

The subsystem uses:

- 32-bit addresses
- 32-bit data
- Four byte-enable bits in `WSTRB`
- 4-byte word alignment
- `OKAY` for successful transactions
- `SLVERR` for invalid, unsupported, unaligned, or out-of-range transactions

The current design maps one RAM region and two memory-mapped peripherals.

---

## 2. Global Address Map

| Target | Base Address | End Address | Window Size | Local Address |
|---|---:|---:|---:|---|
| AXI-Lite RAM | `0x0000_0000` | `0x0000_0FFF` | 4 KiB | Global address minus `0x0000_0000` |
| GPIO | `0x1000_0000` | `0x1000_0FFF` | 4 KiB | Global address minus `0x1000_0000` |
| Timer | `0x1000_1000` | `0x1000_1FFF` | 4 KiB | Global address minus `0x1000_1000` |
| Unmapped space | All other addresses | — | — | Generates an error response |

Address-window decoding uses a 4 KiB mask:

```systemverilog
ADDR_MASK = 32'hFFFF_F000;
```

The interconnect subtracts the selected target's base address before forwarding the request to that target.

---

## 3. Common Access Rules

### 3.1 Alignment

All implemented registers and RAM words use 32-bit word-aligned addresses.

A valid word address must satisfy:

```text
address[1:0] == 2'b00
```

An unaligned read or write returns:

```text
SLVERR = 2'b10
```

Invalid reads return zero data together with `SLVERR`.

### 3.2 Write Strobes

For a 32-bit write:

| `WSTRB` bit | Updated data bits |
|---|---|
| `WSTRB[0]` | `WDATA[7:0]` |
| `WSTRB[1]` | `WDATA[15:8]` |
| `WSTRB[2]` | `WDATA[23:16]` |
| `WSTRB[3]` | `WDATA[31:24]` |

A zero strobe (`4'b0000`) performs no byte update but is accepted as a successful write when the address and register are otherwise valid.

### 3.3 AXI Response Codes

| Response | Encoding | Current use |
|---|---:|---|
| `OKAY` | `2'b00` | Valid, supported transaction |
| `SLVERR` | `2'b10` | Invalid region, invalid register, unaligned access, read-only write, or out-of-range access |
| `EXOKAY` | `2'b01` | Not generated |
| `DECERR` | `2'b11` | Not generated |

---

## 4. AXI-Lite RAM

### 4.1 Region

| Property | Value |
|---|---|
| Base address | `0x0000_0000` |
| End address | `0x0000_0FFF` |
| Size | 4096 bytes |
| Data width | 32 bits |
| Word count | 1024 |
| First valid word | `0x0000_0000` |
| Last valid word | `0x0000_0FFC` |

### 4.2 Behavior

The RAM supports:

- Aligned 32-bit reads
- Aligned 32-bit writes
- Partial writes using `WSTRB`
- Back-to-back transactions through the reusable AXI-Lite driver
- Error responses for unaligned or out-of-range local addresses

The internal memory array is not cleared by reset. Reset clears the AXI response state, but previously stored RAM contents are not guaranteed to become zero. Tests that depend on a known initial value initialize the addressed word before applying partial writes.

### 4.3 RAM Access Results

| Operation | Condition | Response |
|---|---|---|
| Read | Aligned address from `0x0000_0000` through `0x0000_0FFC` | `OKAY`, stored data |
| Write | Aligned address from `0x0000_0000` through `0x0000_0FFC` | `OKAY`, selected bytes updated |
| Read/write | Address inside the window but not word-aligned | `SLVERR` |
| Read/write | Address at or above local `0x0000_1000` | `SLVERR` |

---

## 5. GPIO Peripheral

### 5.1 Region

| Property | Value |
|---|---|
| Base address | `0x1000_0000` |
| End address | `0x1000_0FFF` |
| Register decode width | Local offsets `[5:0]` |
| External input | `gpio_i[31:0]` |
| External output | `gpio_o[31:0]` |
| Output enable | `gpio_oe[31:0]` |

### 5.2 Register Map

| Global Address | Offset | Register | Access | Reset | Description |
|---:|---:|---|---|---:|---|
| `0x1000_0000` | `0x00` | `DATA_OUT` | R/W | `0x0000_0000` | GPIO output data |
| `0x1000_0004` | `0x04` | `DATA_IN` | R | External value | Reads `gpio_i`; writes return `SLVERR` |
| `0x1000_0008` | `0x08` | `DATA_DIR` | R/W | `0x0000_0000` | GPIO output-enable/direction value |
| `0x1000_000C` | `0x0C` | `DATA_OUT_SET` | W; reads return zero | — | Sets selected `DATA_OUT` bits |
| `0x1000_0010` | `0x10` | `DATA_OUT_CLR` | W; reads return zero | — | Clears selected `DATA_OUT` bits |

All other GPIO-local register offsets return `SLVERR`.

### 5.3 Register Behavior

#### `DATA_OUT`

A write updates only byte lanes selected by `WSTRB`.

```text
gpio_o = DATA_OUT
```

#### `DATA_IN`

A read returns the current external input:

```text
read_data = gpio_i
```

A write to `DATA_IN` is unsupported and returns `SLVERR`.

#### `DATA_DIR`

A write updates only selected byte lanes.

```text
gpio_oe = DATA_DIR
```

The current RTL exposes the direction value as an output-enable vector. External pin tri-state behavior is outside the scope of this subsystem.

#### `DATA_OUT_SET`

Selected one bits are ORed into `DATA_OUT`. `WSTRB` masks which bytes participate.

```text
DATA_OUT_next = DATA_OUT | strobe_mask(WDATA)
```

#### `DATA_OUT_CLR`

Selected one bits clear corresponding bits in `DATA_OUT`. `WSTRB` masks which bytes participate.

```text
DATA_OUT_next = DATA_OUT & ~strobe_mask(WDATA)
```

---

## 6. Timer Peripheral

### 6.1 Region

| Property | Value |
|---|---|
| Base address | `0x1000_1000` |
| End address | `0x1000_1FFF` |
| Register decode width | Local offsets `[5:0]` |
| Counter width | 32 bits |
| Interrupt output | `timer_irq` |

### 6.2 Register Map

| Global Address | Offset | Register | Access | Reset | Description |
|---:|---:|---|---|---:|---|
| `0x1000_1000` | `0x00` | `CTRL` | R/W | `0x0000_0000` | Enable, clear, and interrupt-enable control |
| `0x1000_1004` | `0x04` | `COUNT` | R/W | `0x0000_0000` | Current counter value |
| `0x1000_1008` | `0x08` | `COMPARE` | R/W | `0x0000_0000` | Compare threshold |
| `0x1000_100C` | `0x0C` | `STATUS` | R/W1C | `0x0000_0000` | Match status |

All other timer-local register offsets return `SLVERR`.

### 6.3 `CTRL` Register

| Bit | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0 | `ENABLE` | R/W | 0 | Counter increments when set |
| 1 | `CLEAR` | R/W, self-clearing | 0 | Clears `COUNT` and `STATUS.MATCH` |
| 2 | `IRQ_EN` | R/W | 0 | Enables `timer_irq` when a match is pending |
| 31:3 | Reserved | R/W in current storage | 0 | No defined timer function |

`CLEAR` has priority over counting and automatically returns to zero after the clear operation.

### 6.4 `COUNT` Register

`COUNT` increments once per `ACLK` cycle while `CTRL.ENABLE` is set.

The current RTL permits software writes to `COUNT`, with byte selection controlled by `WSTRB`.

### 6.5 `COMPARE` Register

When counting is enabled and `COMPARE` is nonzero, `STATUS.MATCH` is set when the next counter value reaches or exceeds the compare value:

```text
COMPARE != 0 and COUNT + 1 >= COMPARE
```

The status bit remains set until cleared.

### 6.6 `STATUS` Register

| Bit | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0 | `MATCH` | R/W1C | 0 | Set on compare match |
| 31:1 | Reserved | Read as stored zero | 0 | No defined function |

To clear `MATCH`, software writes a one to bit 0 while `WSTRB[0]` is enabled.

### 6.7 Interrupt

```text
timer_irq = STATUS.MATCH && CTRL.IRQ_EN
```

The interrupt deasserts after the match status is cleared or interrupt enable is removed.

---

## 7. Invalid and Unsupported Accesses

The subsystem returns `SLVERR` for:

- Addresses outside all mapped 4 KiB windows
- Unaligned accesses
- RAM local addresses outside the 4 KiB RAM
- Unsupported GPIO register offsets
- Writes to GPIO `DATA_IN`
- Unsupported timer register offsets

For invalid reads, `RDATA` is zero.

---

## 8. Source-of-Truth Files

The software-visible definitions are implemented in:

```text
include/soc_addr_map.vh
include/gpio_if.vh
include/timer_if.vh
rtl/axi_lite_interconnect.sv
rtl/axi_lite_ram.sv
rtl/gpio.sv
rtl/timer.sv
```

When RTL behavior changes, this document and the verification plan should be updated in the same pull request.
