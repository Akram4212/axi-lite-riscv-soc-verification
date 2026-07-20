"""Standalone cocotb tests for rv32i_axi_lite_master.

The adapter serializes a core memory operation as:

    data transaction first
    instruction fetch second
    ihit and dhit asserted together

This matches the current RV32I core, which advances a memory
instruction only when both ihit and dhit are high in the same cycle.
"""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer


AXI_OKAY = 0b00
AXI_SLVERR = 0b10


def value(signal) -> int:
    """Return a signal as a Python integer."""
    return int(signal.value)


async def initialize(dut) -> None:
    """Start the clock, initialize inputs, and reset the DUT."""
    cocotb.start_soon(Clock(dut.CLK, 10, unit="ns").start())

    dut.nRST.value = 0

    dut.imemREN.value = 0
    dut.imemaddr.value = 0

    dut.dmemREN.value = 0
    dut.dmemWEN.value = 0
    dut.datomic.value = 0
    dut.dmemaddr.value = 0
    dut.dmemstore.value = 0
    dut.dmem_wstrb.value = 0

    dut.M_AXI_AWREADY.value = 0
    dut.M_AXI_WREADY.value = 0
    dut.M_AXI_BRESP.value = AXI_OKAY
    dut.M_AXI_BVALID.value = 0

    dut.M_AXI_ARREADY.value = 0
    dut.M_AXI_RDATA.value = 0
    dut.M_AXI_RRESP.value = AXI_OKAY
    dut.M_AXI_RVALID.value = 0

    await ClockCycles(dut.CLK, 3)

    dut.nRST.value = 1
    await RisingEdge(dut.CLK)
    await FallingEdge(dut.CLK)


async def wait_high(
    dut,
    signal,
    *,
    timeout_cycles: int = 30,
    name: str | None = None,
) -> None:
    """Wait until a signal is high, sampling on falling edges."""
    signal_name = name or getattr(signal, "_name", "signal")

    for _ in range(timeout_cycles):
        if value(signal) == 1:
            return

        await FallingEdge(dut.CLK)

    raise AssertionError(
        f"Timed out waiting for {signal_name} to become high"
    )


async def accept_read_address(
    dut,
    expected_addr: int,
    *,
    delay_cycles: int = 0,
) -> None:
    """Accept one AXI-Lite read-address transaction."""
    await wait_high(
        dut,
        dut.M_AXI_ARVALID,
        name="M_AXI_ARVALID",
    )

    assert value(dut.M_AXI_ARADDR) == expected_addr, (
        f"ARADDR was 0x{value(dut.M_AXI_ARADDR):08X}, "
        f"expected 0x{expected_addr:08X}"
    )

    for _ in range(delay_cycles):
        await RisingEdge(dut.CLK)
        await FallingEdge(dut.CLK)

        assert value(dut.M_AXI_ARVALID) == 1
        assert value(dut.M_AXI_ARADDR) == expected_addr

    dut.M_AXI_ARREADY.value = 1
    await RisingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    dut.M_AXI_ARREADY.value = 0


async def send_read_response(
    dut,
    data: int,
    *,
    response: int = AXI_OKAY,
    delay_cycles: int = 0,
) -> None:
    """Return one AXI-Lite read response."""
    await wait_high(
        dut,
        dut.M_AXI_RREADY,
        name="M_AXI_RREADY",
    )

    for _ in range(delay_cycles):
        await RisingEdge(dut.CLK)
        await FallingEdge(dut.CLK)

        assert value(dut.M_AXI_RREADY) == 1

    dut.M_AXI_RDATA.value = data
    dut.M_AXI_RRESP.value = response
    dut.M_AXI_RVALID.value = 1

    await Timer(1, unit="ns")
    assert value(dut.M_AXI_RREADY) == 1

    await RisingEdge(dut.CLK)
    await FallingEdge(dut.CLK)

    dut.M_AXI_RVALID.value = 0
    dut.M_AXI_RRESP.value = AXI_OKAY


async def accept_write_address(
    dut,
    expected_addr: int,
    *,
    delay_cycles: int = 0,
) -> None:
    """Accept the AXI-Lite write-address channel."""
    await wait_high(
        dut,
        dut.M_AXI_AWVALID,
        name="M_AXI_AWVALID",
    )

    assert value(dut.M_AXI_AWADDR) == expected_addr

    for _ in range(delay_cycles):
        await RisingEdge(dut.CLK)
        await FallingEdge(dut.CLK)

        assert value(dut.M_AXI_AWVALID) == 1
        assert value(dut.M_AXI_AWADDR) == expected_addr

    dut.M_AXI_AWREADY.value = 1
    await RisingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    dut.M_AXI_AWREADY.value = 0


async def accept_write_data(
    dut,
    expected_data: int,
    expected_strobe: int,
    *,
    delay_cycles: int = 0,
) -> None:
    """Accept the AXI-Lite write-data channel."""
    await wait_high(
        dut,
        dut.M_AXI_WVALID,
        name="M_AXI_WVALID",
    )

    assert value(dut.M_AXI_WDATA) == expected_data
    assert value(dut.M_AXI_WSTRB) == expected_strobe

    for _ in range(delay_cycles):
        await RisingEdge(dut.CLK)
        await FallingEdge(dut.CLK)

        assert value(dut.M_AXI_WVALID) == 1
        assert value(dut.M_AXI_WDATA) == expected_data
        assert value(dut.M_AXI_WSTRB) == expected_strobe

    dut.M_AXI_WREADY.value = 1
    await RisingEdge(dut.CLK)
    await FallingEdge(dut.CLK)
    dut.M_AXI_WREADY.value = 0


async def send_write_response(
    dut,
    *,
    response: int = AXI_OKAY,
    delay_cycles: int = 0,
) -> None:
    """Return one AXI-Lite write response."""
    await wait_high(
        dut,
        dut.M_AXI_BREADY,
        name="M_AXI_BREADY",
    )

    for _ in range(delay_cycles):
        await RisingEdge(dut.CLK)
        await FallingEdge(dut.CLK)

        assert value(dut.M_AXI_BREADY) == 1

    dut.M_AXI_BRESP.value = response
    dut.M_AXI_BVALID.value = 1

    await Timer(1, unit="ns")
    assert value(dut.M_AXI_BREADY) == 1

    await RisingEdge(dut.CLK)
    await FallingEdge(dut.CLK)

    dut.M_AXI_BVALID.value = 0
    dut.M_AXI_BRESP.value = AXI_OKAY


async def consume_completion(dut) -> None:
    """Advance through the adapter's completion state."""
    await RisingEdge(dut.CLK)
    await FallingEdge(dut.CLK)

    assert value(dut.ihit) == 0
    assert value(dut.dhit) == 0


@cocotb.test()
async def test_reset_outputs(dut) -> None:
    await initialize(dut)

    assert value(dut.ihit) == 0
    assert value(dut.dhit) == 0
    assert value(dut.bus_error) == 0

    assert value(dut.M_AXI_AWVALID) == 0
    assert value(dut.M_AXI_WVALID) == 0
    assert value(dut.M_AXI_BREADY) == 0
    assert value(dut.M_AXI_ARVALID) == 0
    assert value(dut.M_AXI_RREADY) == 0


@cocotb.test()
async def test_instruction_read_with_backpressure(dut) -> None:
    await initialize(dut)

    instruction_addr = 0x0000_0040
    instruction = 0x0050_0093

    dut.imemREN.value = 1
    dut.imemaddr.value = instruction_addr

    await accept_read_address(
        dut,
        instruction_addr,
        delay_cycles=3,
    )

    await send_read_response(
        dut,
        instruction,
        delay_cycles=2,
    )

    assert value(dut.ihit) == 1
    assert value(dut.dhit) == 0
    assert value(dut.imemload) == instruction

    dut.imemREN.value = 0
    await consume_completion(dut)


@cocotb.test()
async def test_data_read_precedes_instruction_and_completes_together(
    dut,
) -> None:
    await initialize(dut)

    data_addr = 0x0000_1003
    aligned_data_addr = 0x0000_1000
    instruction_addr = 0x0000_0080

    read_word = 0xA1B2_C3D4
    instruction = 0x0000_0013

    dut.imemREN.value = 1
    dut.imemaddr.value = instruction_addr

    dut.dmemREN.value = 1
    dut.dmemaddr.value = data_addr

    # Data read has priority and is word-aligned by the adapter.
    await accept_read_address(dut, aligned_data_addr)
    await send_read_response(dut, read_word)

    # The core requires ihit and dhit together, so neither pulse
    # is issued until the instruction fetch also completes.
    assert value(dut.ihit) == 0
    assert value(dut.dhit) == 0
    assert value(dut.dmemload) == read_word

    await accept_read_address(dut, instruction_addr)
    await send_read_response(dut, instruction)

    assert value(dut.ihit) == 1
    assert value(dut.dhit) == 1
    assert value(dut.imemload) == instruction
    assert value(dut.dmemload) == read_word

    dut.imemREN.value = 0
    dut.dmemREN.value = 0
    await consume_completion(dut)


@cocotb.test()
async def test_write_data_can_handshake_before_address(dut) -> None:
    await initialize(dut)

    data_addr = 0x1000_0003
    aligned_data_addr = 0x1000_0000
    write_data = 0xAA00_0000
    write_strobe = 0b1000

    instruction_addr = 0x0000_0100
    instruction = 0x0000_0013

    dut.imemREN.value = 1
    dut.imemaddr.value = instruction_addr

    dut.dmemWEN.value = 1
    dut.dmemaddr.value = data_addr
    dut.dmemstore.value = write_data
    dut.dmem_wstrb.value = write_strobe

    # AXI-Lite AW and W channels are independent.
    await accept_write_data(
        dut,
        write_data,
        write_strobe,
    )

    assert value(dut.M_AXI_AWVALID) == 1

    await accept_write_address(
        dut,
        aligned_data_addr,
        delay_cycles=2,
    )

    await send_write_response(
        dut,
        delay_cycles=2,
    )

    assert value(dut.ihit) == 0
    assert value(dut.dhit) == 0

    await accept_read_address(dut, instruction_addr)
    await send_read_response(dut, instruction)

    assert value(dut.ihit) == 1
    assert value(dut.dhit) == 1
    assert value(dut.imemload) == instruction

    dut.imemREN.value = 0
    dut.dmemWEN.value = 0
    await consume_completion(dut)


@cocotb.test()
async def test_write_address_can_handshake_before_data(dut) -> None:
    await initialize(dut)

    data_addr = 0x0000_2002
    aligned_data_addr = 0x0000_2000
    write_data = 0xBEEF_0000
    write_strobe = 0b1100

    instruction_addr = 0x0000_0140
    instruction = 0x0010_0093

    dut.imemREN.value = 1
    dut.imemaddr.value = instruction_addr

    dut.dmemWEN.value = 1
    dut.dmemaddr.value = data_addr
    dut.dmemstore.value = write_data
    dut.dmem_wstrb.value = write_strobe

    await accept_write_address(
        dut,
        aligned_data_addr,
    )

    assert value(dut.M_AXI_WVALID) == 1

    await accept_write_data(
        dut,
        write_data,
        write_strobe,
        delay_cycles=3,
    )

    await send_write_response(dut)

    await accept_read_address(dut, instruction_addr)
    await send_read_response(dut, instruction)

    assert value(dut.ihit) == 1
    assert value(dut.dhit) == 1

    dut.imemREN.value = 0
    dut.dmemWEN.value = 0
    await consume_completion(dut)


@cocotb.test()
async def test_stale_instruction_response_is_discarded(dut) -> None:
    await initialize(dut)

    old_addr = 0x0000_0200
    new_addr = 0x0000_0300

    old_instruction = 0x1111_1111
    new_instruction = 0x2222_2222

    dut.imemREN.value = 1
    dut.imemaddr.value = old_addr

    await accept_read_address(dut, old_addr)

    # Model a branch/jump redirect while the old read is pending.
    dut.imemaddr.value = new_addr

    await send_read_response(dut, old_instruction)

    assert value(dut.ihit) == 0
    assert value(dut.imemload) != old_instruction

    await accept_read_address(dut, new_addr)
    await send_read_response(dut, new_instruction)

    assert value(dut.ihit) == 1
    assert value(dut.imemload) == new_instruction

    dut.imemREN.value = 0
    await consume_completion(dut)


@cocotb.test()
async def test_read_slverr_sets_sticky_bus_error_and_completes(
    dut,
) -> None:
    await initialize(dut)

    instruction_addr = 0x0000_0400
    returned_data = 0xDEAD_BEEF

    dut.imemREN.value = 1
    dut.imemaddr.value = instruction_addr

    await accept_read_address(dut, instruction_addr)

    await send_read_response(
        dut,
        returned_data,
        response=AXI_SLVERR,
    )

    assert value(dut.ihit) == 1
    assert value(dut.imemload) == returned_data
    assert value(dut.bus_error) == 1

    dut.imemREN.value = 0
    await consume_completion(dut)

    # The error indication remains asserted until reset.
    assert value(dut.bus_error) == 1


@cocotb.test()
async def test_write_slverr_is_sticky_but_bundle_finishes(dut) -> None:
    await initialize(dut)

    instruction_addr = 0x0000_0500
    instruction = 0x0000_0013

    dut.imemREN.value = 1
    dut.imemaddr.value = instruction_addr

    dut.dmemWEN.value = 1
    dut.dmemaddr.value = 0x1000_0000
    dut.dmemstore.value = 0x0000_0005
    dut.dmem_wstrb.value = 0b1111

    await accept_write_address(dut, 0x1000_0000)
    await accept_write_data(
        dut,
        0x0000_0005,
        0b1111,
    )

    await send_write_response(
        dut,
        response=AXI_SLVERR,
    )

    assert value(dut.bus_error) == 1
    assert value(dut.ihit) == 0
    assert value(dut.dhit) == 0

    await accept_read_address(dut, instruction_addr)
    await send_read_response(dut, instruction)

    assert value(dut.ihit) == 1
    assert value(dut.dhit) == 1
    assert value(dut.bus_error) == 1

    dut.imemREN.value = 0
    dut.dmemWEN.value = 0
    await consume_completion(dut)


@cocotb.test()
async def test_held_request_does_not_duplicate_while_outstanding(
    dut,
) -> None:
    await initialize(dut)

    instruction_addr = 0x0000_0600
    next_addr = 0x0000_0604

    dut.imemREN.value = 1
    dut.imemaddr.value = instruction_addr

    await accept_read_address(dut, instruction_addr)

    # The request remains asserted while the response is delayed.
    # The adapter must not issue another address transaction.
    for _ in range(5):
        await RisingEdge(dut.CLK)
        await FallingEdge(dut.CLK)

        assert value(dut.M_AXI_ARVALID) == 0
        assert value(dut.M_AXI_RREADY) == 1

    await send_read_response(dut, 0x0000_0013)

    assert value(dut.ihit) == 1

    # Mimic the core consuming ihit and moving to the next PC.
    dut.imemaddr.value = next_addr
    await consume_completion(dut)

    await accept_read_address(dut, next_addr)
    await send_read_response(dut, 0x0010_0093)

    assert value(dut.ihit) == 1

    dut.imemREN.value = 0
    await consume_completion(dut)
