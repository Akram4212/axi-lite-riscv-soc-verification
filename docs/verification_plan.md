# Verification Plan

## 1. Purpose

This document defines the verification scope, strategy, test matrix, coverage model, assertion plan, regression flow, exit criteria, and known gaps for the current AXI-Lite subsystem milestone.

---

## 2. Design Under Test

The verification scope includes:

- `gpio`
- `timer`
- `axi_lite_ram`
- `axi_lite_interconnect`
- `axi_lite_subsystem`
- `axi_lite_assertions`

The current subsystem exposes one external AXI-Lite interface and routes transactions to:

- 4 KiB RAM
- GPIO
- Timer
- Internal error-response path for unmapped addresses

The RV32I processor core, firmware, interrupts at the CPU level, and full SoC top are outside the current verification scope.

---

## 3. Verification Objectives

The verification environment must demonstrate that:

1. Every implemented target resets and responds according to its specification.
2. Valid reads and writes return `OKAY`.
3. Invalid, unsupported, unaligned, and out-of-range accesses return `SLVERR`.
4. Read data matches the selected target's state.
5. `WSTRB` updates only selected byte lanes.
6. GPIO set/clear behavior is correct.
7. Timer count, compare, status, clear, and interrupt behavior is correct.
8. RAM stores independent values across its valid address range.
9. The interconnect selects the correct target and preserves target isolation.
10. Back-to-back and randomized accesses do not corrupt state.
11. External AXI-Lite signals remain stable under backpressure.
12. All required functional-coverage bins are exercised.
13. The full regression runs locally and in GitHub Actions.

---

## 4. Verification Environment

| Item | Implementation |
|---|---|
| RTL language | SystemVerilog |
| Testbench language | Python |
| Test framework | cocotb |
| Simulator | Verilator 5.038 |
| Waveform format | VCD through Verilator trace |
| Waveform viewer | GTKWave |
| Assertions | Clocked SystemVerilog immediate assertions |
| Coverage | Custom Python functional coverage |
| Automation | GNU Make |
| CI | GitHub Actions |
| Primary development environment | WSL Ubuntu |

### Reusable Driver

`tb/axi_lite_master.py` provides:

- DUT reset initialization
- AXI-Lite write transactions
- AXI-Lite read transactions
- Response collection

The current driver presents write address and write data together, matching the current RTL implementation.

---

## 5. Verification Levels

### 5.1 Static RTL Checks

Each implemented RTL block is linted with Verilator and `-Wall`.

Goals:

- No syntax errors
- No fatal warnings
- No unintended width mismatches
- No missing module references
- Correct include paths

### 5.2 Block-Level Simulation

GPIO, Timer, and RAM are verified independently.

Benefits:

- Faster debug
- Clear ownership of failures
- Direct access to local register offsets
- Easier corner-case testing

### 5.3 Subsystem-Level Simulation

The subsystem testbench verifies:

- Global address decoding
- Address translation
- Response routing
- Error path
- Peripheral isolation
- Mixed target accesses
- Assertions
- Functional coverage

### 5.4 Regression and CI

The complete implemented test set is run through:

```bash
make regression
```

GitHub Actions executes the same regression for repository changes.

---

## 6. GPIO Verification Matrix

| Feature | Stimulus | Expected result | Status |
|---|---|---|---|
| Reset | Assert and release `ARESETn` | `DATA_OUT=0`, `DATA_DIR=0`, outputs zero | Verified |
| Basic output write/read | Write `DATA_OUT`, then read | Readback and `gpio_o` match | Verified |
| Direction write/read | Write `DATA_DIR`, then read | Readback and `gpio_oe` match | Verified |
| Input read | Drive `gpio_i`, read `DATA_IN` | Read data matches external input | Verified |
| Set register | Write one bits to `DATA_OUT_SET` | Corresponding output bits set | Verified |
| Clear register | Write one bits to `DATA_OUT_CLR` | Corresponding output bits clear | Verified |
| Read-only protection | Write `DATA_IN` | `SLVERR` | Verified |
| Byte strobes | Partial register writes | Only enabled bytes change | Verified |
| Invalid register | Access unsupported offset | `SLVERR` | Verified |
| Unaligned access | Use non-word-aligned offset | `SLVERR` | Verified |
| Random data | Repeated random writes/readbacks | Readback matches reference | Verified |

### GPIO Tests

The standalone GPIO suite includes reset, basic read/write, input read, set/clear, invalid write, byte-strobe, and randomized behavior tests.

---

## 7. Timer Verification Matrix

| Feature | Stimulus | Expected result | Status |
|---|---|---|---|
| Reset | Assert and release reset | All registers and IRQ zero | Verified |
| Enable | Set `CTRL.ENABLE` | `COUNT` increments | Verified |
| Disable | Clear `CTRL.ENABLE` | `COUNT` holds | Verified |
| Software count write | Write `COUNT` | Selected bytes update | Implemented; basic register path covered |
| Clear | Set `CTRL.CLEAR` | Count and match clear; bit self-clears | Verified |
| Compare | Program `COMPARE`, enable timer | `STATUS.MATCH` sets | Verified |
| Compare zero | Leave `COMPARE=0` | Match is not generated by compare logic | Covered indirectly by reset/normal operation |
| IRQ | Enable timer and IRQ | `timer_irq` asserts after match | Verified |
| W1C status | Write one to `STATUS.MATCH` | Match and IRQ clear | Verified |
| Byte strobes | Partial write to `COMPARE` | Only selected bytes change | Verified |
| Invalid register | Access unsupported offset | `SLVERR` | Verified |
| Unaligned access | Non-word-aligned address | `SLVERR` | Verified |
| Random compare | Multiple seeded compare values | Every value produces match | Verified |

### Timer Tests

```text
test_timer_reset
test_timer_enable_count
test_timer_disable_holds_count
test_timer_clear
test_timer_compare_match
test_timer_irq
test_timer_status_clear
test_timer_byte_strobe
test_timer_invalid_access
test_timer_random_compare
```

---

## 8. RAM Verification Matrix

| Feature | Stimulus | Expected result | Status |
|---|---|---|---|
| Interface reset | Reset DUT | `BVALID=0`, `RVALID=0` | Verified |
| Basic write/read | Write and read one word | Exact data returned | Verified |
| Independent locations | Write several addresses | No cross-address corruption | Verified |
| Byte strobes | Update individual bytes | Only enabled bytes change | Verified |
| Zero strobe | Write with `WSTRB=0000` | Stored word unchanged | Verified |
| First address | Access `0x000` | `OKAY` | Verified |
| Last valid word | Access `0xFFC` | `OKAY` | Verified |
| Unaligned address | Access `0x002` | `SLVERR`, zero read data | Verified |
| Out-of-range address | Access `0x1000` | `SLVERR`, zero read data | Verified |
| Back-to-back traffic | Repeated write/read pairs | Correct data every iteration | Verified |
| Random address/data | Seeded random operations | Python reference matches RTL | Verified |
| Random strobes | Seeded random partial writes | Byte-level reference matches RTL | Verified |
| Uninitialized memory handling | Initialize before partial writes | No assumption that reset clears RAM | Verified by test methodology |

### RAM Tests

```text
test_ram_reset
test_ram_basic_write_read
test_ram_multiple_locations
test_ram_byte_strobe
test_ram_zero_strobe_write
test_ram_unaligned_access
test_ram_out_of_range_access
test_ram_boundary_access
test_ram_back_to_back_access
test_ram_random_access
test_ram_random_byte_strobes
```

---

## 9. Interconnect and Subsystem Verification Matrix

| Feature | Stimulus | Expected result | Status |
|---|---|---|---|
| RAM decode | Access `0x0000_0000` region | Request reaches RAM | Verified |
| GPIO decode | Access `0x1000_0000` region | Request reaches GPIO | Verified |
| Timer decode | Access `0x1000_1000` region | Request reaches Timer | Verified |
| Local address conversion | Access target registers through global address | Correct local offset used | Verified |
| Invalid global address | Access `0x2000_0000` | Internal `SLVERR`, zero read data | Verified |
| Unaligned target access | Use valid window with bad alignment | `SLVERR` | Verified |
| RAM boundary | Access first/last valid word | Correct response and data | Verified |
| RAM out of range | Access first address after RAM | `SLVERR` | Verified |
| GPIO/Timer isolation | Write both targets | Each retains its own value | Verified |
| RAM/GPIO/Timer isolation | Write all targets | No cross-target corruption | Verified |
| Back-to-back accesses | Alternate target transactions | Correct response/data | Verified |
| Random GPIO/Timer | Seeded mixed accesses | Reference values match | Verified |
| Random RAM | Seeded RAM accesses | Reference values match | Verified |
| Random all-target | Seeded RAM/GPIO/Timer traffic | Every operation matches | Verified |
| Timer IRQ through subsystem | Configure timer globally | External IRQ asserts | Verified |
| Required `WSTRB` bins | Exercise selected strobe patterns | Coverage bins hit | Verified |
| Coverage reporting | Run summary after sampling tests | Raw coverage reported and threshold enforced | Verified |

### Subsystem Tests

```text
test_subsystem_reset
test_subsystem_gpio_access
test_subsystem_gpio_input_read
test_subsystem_gpio_set_clear
test_subsystem_timer_access
test_subsystem_timer_irq
test_subsystem_gpio_timer_isolation
test_subsystem_invalid_write
test_subsystem_invalid_read
test_subsystem_unaligned_access
test_subsystem_byte_strobe
test_subsystem_back_to_back_access
test_subsystem_randomized_gpio_timer_access
test_subsystem_ram_access
test_subsystem_ram_multiple_locations
test_subsystem_ram_byte_strobe
test_subsystem_ram_boundary_access
test_subsystem_ram_unaligned_access
test_subsystem_ram_out_of_range_access
test_subsystem_ram_gpio_timer_isolation
test_subsystem_randomized_ram_access
test_subsystem_randomized_ram_gpio_timer_access
test_subsystem_extra_wstrb_coverage
test_functional_coverage_summary
```

Current subsystem suite size:

```text
24 cocotb tests
```

---

## 10. Assertion Plan

The current assertion module monitors the external subsystem interface.

| ID | Channel | Property |
|---|---|---|
| AXI-AW-01 | AW | If `AWVALID && !AWREADY`, `AWVALID` remains high on the next cycle |
| AXI-AW-02 | AW | If `AWVALID && !AWREADY`, `AWADDR` remains stable |
| AXI-W-01 | W | If `WVALID && !WREADY`, `WVALID` remains high |
| AXI-W-02 | W | If `WVALID && !WREADY`, `WDATA` remains stable |
| AXI-W-03 | W | If `WVALID && !WREADY`, `WSTRB` remains stable |
| AXI-B-01 | B | If `BVALID && !BREADY`, `BVALID` remains high |
| AXI-B-02 | B | If `BVALID && !BREADY`, `BRESP` remains stable |
| AXI-AR-01 | AR | If `ARVALID && !ARREADY`, `ARVALID` remains high |
| AXI-AR-02 | AR | If `ARVALID && !ARREADY`, `ARADDR` remains stable |
| AXI-R-01 | R | If `RVALID && !RREADY`, `RVALID` remains high |
| AXI-R-02 | R | If `RVALID && !RREADY`, `RDATA` remains stable |
| AXI-R-03 | R | If `RVALID && !RREADY`, `RRESP` remains stable |

### Planned Assertion Expansion

- No unknown (`X`) control signals after reset
- Response only after a corresponding request
- No duplicate response for one request
- Address alignment assumptions/checks
- Eventual response under ready/valid fairness assumptions
- Separate AW and W channel buffering rules after protocol-hardening

---

## 11. Functional Coverage Plan

The current Python coverage model samples every subsystem-level read and write.

### Coverage Groups

| Group | Bins |
|---|---|
| Address region | RAM, GPIO, Timer, Invalid |
| Access type | Read, Write |
| AXI response | OKAY, SLVERR, OTHER |
| Write strobe | `0000`, `0001`, `0010`, `0011`, `0100`, `0101`, `1000`, `1010`, `1100`, `1111` |
| Error case | Unaligned, Invalid region, Out of range |
| Target/access cross | RAM/GPIO/Timer/Invalid × Read/Write |

### Coverage Goal

- Raw model coverage target: at least 95%
- Required-bin coverage target: 100%
- `OTHER` response is not required because the current RTL only specifies `OKAY` and `SLVERR`

Current result:

```text
Raw coverage:       96.67% (29/30 model bins)
Required coverage: 100%   (29/29 required bins)
```

### Coverage Collection Constraint

The coverage object is shared by tests in one simulator process. The summary test must remain after the sampling tests in the source file so the final report observes the accumulated bins.

---

## 12. Randomization and Reproducibility

Random tests use fixed seeds, including values such as:

```text
42
123
777
2026
```

Fixed seeds make regressions reproducible. Future stress regression may add a CI-provided seed matrix while always printing the selected seed in the log.

---

## 13. Negative Testing

The following negative scenarios are required:

- Invalid global read
- Invalid global write
- Unaligned read
- Unaligned write
- Unsupported GPIO register access
- Write to GPIO `DATA_IN`
- Unsupported Timer register access
- RAM address immediately outside the valid range

Expected behavior:

```text
Response = SLVERR
Invalid read data = 0
No unrelated target state changes
```

---

## 14. Backpressure Testing

The assertion module checks signal stability when backpressure occurs. However, the current transaction helpers usually assert `BREADY` and `RREADY` promptly.

A future enhancement should add dedicated tests that deliberately hold:

- `BREADY=0` for several cycles
- `RREADY=0` for several cycles
- Target-ready signals low through a configurable test wrapper

This will create direct assertion activation rather than relying only on incidental waits.

---

## 15. Regression Plan

### Local Commands

```bash
source .venv/bin/activate
make clean
make regression
```

Individual targets:

```bash
make lint_gpio
make lint_timer
make lint_ram
make lint_subsystem

make test_gpio
make test_timer
make test_ram
make test_subsystem
```

Waveform debug:

```bash
make clean
make test_subsystem WAVES=1
gtkwave dump.vcd
```

### Regression Contents

The full regression must include:

- GPIO lint and tests
- Timer lint and tests
- RAM lint and tests
- Subsystem lint and tests
- AXI-Lite assertions enabled in Verilator
- Functional-coverage report and threshold check

---

## 16. Continuous Integration Plan

The GitHub Actions workflow must:

1. Check out the repository.
2. Install required build dependencies.
3. Install Verilator 5.038.
4. Create a Python virtual environment.
5. Install cocotb and supporting packages.
6. Run `make clean`.
7. Run `make regression`.
8. Fail the workflow on lint, compile, simulation, assertion, test, or coverage-gate failure.

The CI and local flow should invoke the same Makefile targets to minimize environment-specific behavior.

---

## 17. Pass/Fail Criteria

A test passes only when:

- Every expected response matches.
- Every expected read value matches.
- No unrelated target state changes.
- No SystemVerilog assertion reports an error.
- The cocotb test completes without timeout or exception.

The regression passes only when:

- All required lint targets pass.
- All cocotb suites pass.
- No assertion fails.
- Raw functional coverage meets the configured threshold.
- Required coverage bins are all hit.
- GitHub Actions completes successfully.

---

## 18. Current Exit Criteria

| Criterion | Result |
|---|---|
| GPIO block verified | Complete |
| Timer block verified | Complete |
| RAM block verified | Complete |
| Interconnect/subsystem verified | Complete |
| Directed tests pass | Complete |
| Randomized tests pass | Complete |
| Error-path tests pass | Complete |
| Assertions pass | Complete |
| Raw coverage above 95% | Complete |
| All required bins hit | Complete |
| Local regression passes | Complete |
| GitHub Actions regression passes | Complete |
| Documentation completed | Complete after these files are committed |

The current AXI-Lite subsystem milestone is ready to be frozen and used as the foundation for the processor-integration stage.

---

## 19. Known Gaps and Deferred Work

These items are not claimed as verified in the current milestone:

- Independent arrival of `AW` and `W`
- Multiple outstanding reads or writes
- Multi-master arbitration
- Complete AXI-Lite compliance proof
- Formal verification
- Clock-domain crossing
- Asynchronous reset behavior
- RAM firmware/image loading
- RV32I instruction execution
- CPU exceptions, interrupts, and privilege modes
- Full-SoC firmware-driven verification

The next development stage should not remove the current block-level regression. New CPU and SoC tests should be added on top of the existing suites.
