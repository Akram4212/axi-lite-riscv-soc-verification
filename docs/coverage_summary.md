# Functional Coverage Summary

## 1. Summary

The current subsystem-level functional coverage result is:

```text
Raw model coverage:      96.67%
Hit model bins:          29 of 30
Required-bin coverage:   100%
Hit required bins:       29 of 29
```

The only unhit model bin is the generic AXI response category `OTHER`. That bin is not required by the current design specification because the RTL intentionally generates only:

- `OKAY`
- `SLVERR`

All address, access-type, strobe, error-case, and target/access bins are hit.

---

## 2. Coverage Implementation

Coverage is implemented in:

```text
tb/axi_lite_coverage.py
```

Coverage-aware wrappers in:

```text
tb/test_axi_lite_subsystem.py
```

sample transactions after the reusable master completes them:

```python
coverage.sample_write(addr, bresp, strobe)
coverage.sample_read(addr, rresp)
```

The final report and threshold check are produced by:

```text
test_functional_coverage_summary
```

The current minimum assertion in the coverage model is configurable through:

```python
coverage.assert_minimum_coverage(...)
```

---

## 3. Coverage Model

The model contains 30 raw bins across six groups.

| Coverage group | Bin count |
|---|---:|
| Address regions | 4 |
| Access types | 2 |
| AXI responses | 3 |
| `WSTRB` patterns | 10 |
| Error cases | 3 |
| Peripheral/access combinations | 8 |
| **Total** | **30** |

Required bins exclude the unsupported `OTHER` response:

```text
Required bins = 29
```

---

## 4. Address Region Coverage

| Bin | Status | Evidence |
|---|---|---|
| RAM | Hit | Direct, boundary, randomized, and mixed RAM tests |
| GPIO | Hit | GPIO data, input, direction, set, clear, and mixed tests |
| Timer | Hit | Timer control, count, compare, status, IRQ, and mixed tests |
| Invalid | Hit | Invalid global read/write and out-of-range tests |

Result:

```text
4/4 hit
```

---

## 5. Access Type Coverage

| Bin | Status |
|---|---|
| Read | Hit |
| Write | Hit |

Result:

```text
2/2 hit
```

---

## 6. AXI Response Coverage

| Bin | Status | Requirement |
|---|---|---|
| `OKAY` | Hit | Required |
| `SLVERR` | Hit | Required |
| `OTHER` | Miss | Not required |

Result:

```text
2/3 raw bins hit
2/2 required bins hit
```

### Interpretation

`OTHER` represents any response other than `OKAY` or `SLVERR`. The current subsystem does not specify `EXOKAY` or `DECERR`, so forcing this bin would require behavior outside the current design specification.

For reporting, retain the raw 96.67% result but also report 100% required-bin coverage.

A future improvement may mark `OTHER` as ignored rather than counting it in the raw denominator.

---

## 7. Write-Strobe Coverage

The coverage model tracks ten representative patterns.

| Pattern | Meaning | Status |
|---:|---|---|
| `0000` | No bytes enabled | Hit |
| `0001` | Byte 0 | Hit |
| `0010` | Byte 1 | Hit |
| `0011` | Bytes 1:0 | Hit |
| `0100` | Byte 2 | Hit |
| `0101` | Bytes 2 and 0 | Hit |
| `1000` | Byte 3 | Hit |
| `1010` | Bytes 3 and 1 | Hit |
| `1100` | Bytes 3:2 | Hit |
| `1111` | All bytes | Hit |

Result:

```text
10/10 hit
```

Coverage comes from standalone and subsystem byte-strobe tests, including the dedicated extra-strobe coverage test.

---

## 8. Error-Case Coverage

| Bin | Status | Example |
|---|---|---|
| Unaligned access | Hit | Address ending in `0x2` |
| Invalid region | Hit | `0x2000_0000` |
| Out of range | Hit | First address after the 4 KiB RAM |

Result:

```text
3/3 hit
```

### Model Note

The current lightweight tracker classifies an invalid region with a `SLVERR` as both `INVALID_REGION` and `OUT_OF_RANGE`. The tests separately exercise the RAM boundary and the globally invalid region, but the coverage model could be refined later to distinguish:

- RAM-local out of range
- Globally unmapped address
- Unsupported peripheral register

---

## 9. Peripheral/Access Cross Coverage

| Bin | Status |
|---|---|
| RAM read | Hit |
| RAM write | Hit |
| GPIO read | Hit |
| GPIO write | Hit |
| Timer read | Hit |
| Timer write | Hit |
| Invalid read | Hit |
| Invalid write | Hit |

Result:

```text
8/8 hit
```

This group demonstrates that each valid target and the error path were exercised through both transaction directions.

---

## 10. Coverage-Producing Tests

Major contributing subsystem tests include:

```text
test_subsystem_gpio_access
test_subsystem_gpio_input_read
test_subsystem_gpio_set_clear
test_subsystem_timer_access
test_subsystem_timer_irq
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
```

The suite ends with:

```text
test_functional_coverage_summary
```

Current subsystem suite:

```text
24 tests, all passing
```

---

## 11. Coverage Gate

Recommended project reporting:

```text
Raw coverage must be >= 95%
Required-bin coverage must be 100%
```

The current design meets both conditions.

The code currently calls a minimum-coverage assertion. It is recommended to set the raw threshold to at least 95% now that the stable result is 96.67%.

Example:

```python
coverage.assert_minimum_coverage(95.0)
```

A stronger future implementation should explicitly define ignored bins and independently fail on any missing required bin.

---

## 12. Limitations of the Current Coverage Model

The lightweight Python model is intentionally simple. Current limitations include:

1. Coverage is in-memory and is not merged across separate simulator processes.
2. The final summary depends on the summary test running after the sampling tests.
3. The model records hit/miss, not occurrence counts per bin.
4. It has no cross coverage between address region, response, alignment, and strobe.
5. The `OUT_OF_RANGE` classification is broader than the name suggests.
6. No UCIS database or HTML report is generated.
7. Protocol timing and backpressure are primarily handled by assertions, not functional coverage.

These limitations are acceptable for the current milestone and are clearly documented.

---

## 13. Recommended Next Coverage Improvements

Before or during CPU integration:

- Track per-bin hit counts.
- Add a required/ignored-bin mechanism.
- Add crosses:
  - target × read/write
  - target × response
  - target × `WSTRB`
  - aligned/unaligned × response
- Add dedicated backpressure scenario coverage.
- Add CPU-generated versus cocotb-generated transaction coverage.
- Export JSON or Markdown coverage artifacts from CI.
- Preserve random seeds and operation counts in the report.

---

## 14. Conclusion

The current coverage result demonstrates that all specified functional scenarios in the lightweight coverage plan have been exercised.

```text
Raw model coverage:     96.67%
Required-bin coverage: 100%
Regression status:      PASS
```

The remaining raw miss is an intentionally unsupported response category, not an unverified required feature. The subsystem is ready to serve as the verified bus-and-peripheral foundation for the next processor-integration stage.
