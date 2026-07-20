import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from axi_lite_master import reset_dut, axi_write, axi_read


# ============================================================
# AXI-Lite Response Codes
# ============================================================

AXI_OKAY = 0
AXI_SLVERR = 2


# ============================================================
# RAM Configuration
# ============================================================

RAM_BYTES = 4096
WORD_BYTES = 4
RAM_WORDS = RAM_BYTES // WORD_BYTES

LAST_VALID_WORD_ADDR = RAM_BYTES - WORD_BYTES

INVALID_OUT_OF_RANGE_ADDR = RAM_BYTES
INVALID_UNALIGNED_ADDR = 0x00000002


# ============================================================
# Tests
# ============================================================

@cocotb.test()
async def test_ram_reset(dut):
    """
    Verify AXI-Lite RAM interface resets cleanly.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    assert int(dut.S_AXI_BVALID.value) == 0
    assert int(dut.S_AXI_RVALID.value) == 0


@cocotb.test()
async def test_ram_basic_write_read(dut):
    """
    Verify a basic AXI-Lite write followed by read.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    addr = 0x00000010
    value = 0xAABBCCDD

    bresp = await axi_write(dut, addr, value)
    assert bresp == AXI_OKAY, f"Expected OKAY write response, got {bresp}"

    data, rresp = await axi_read(dut, addr)
    assert rresp == AXI_OKAY, f"Expected OKAY read response, got {rresp}"
    assert data == value, f"Expected {value:#010x}, got {data:#010x}"


@cocotb.test()
async def test_ram_multiple_locations(dut):
    """
    Verify several RAM locations can store independent values.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    test_values = {
        0x00000000: 0x11111111,
        0x00000004: 0x22222222,
        0x00000008: 0x33333333,
        0x0000000C: 0x44444444,
        0x00000020: 0x55555555,
        LAST_VALID_WORD_ADDR: 0xDEADBEEF,
    }

    for addr, value in test_values.items():
        bresp = await axi_write(dut, addr, value)
        assert bresp == AXI_OKAY, (
            f"Expected OKAY write response at addr {addr:#010x}, got {bresp}"
        )

    for addr, expected in test_values.items():
        data, rresp = await axi_read(dut, addr)
        assert rresp == AXI_OKAY, (
            f"Expected OKAY read response at addr {addr:#010x}, got {rresp}"
        )
        assert data == expected, (
            f"At addr {addr:#010x}, expected {expected:#010x}, got {data:#010x}"
        )


@cocotb.test()
async def test_ram_byte_strobe(dut):
    """
    Verify AXI-Lite WSTRB updates only selected bytes.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    addr = 0x00000040

    bresp = await axi_write(dut, addr, 0xAABBCCDD)
    assert bresp == AXI_OKAY

    data, rresp = await axi_read(dut, addr)
    assert rresp == AXI_OKAY
    assert data == 0xAABBCCDD, f"Expected 0xAABBCCDD, got {data:#010x}"

    # Update byte 0: DD -> 11
    bresp = await axi_write(dut, addr, 0x00000011, strobe=0b0001)
    assert bresp == AXI_OKAY

    data, rresp = await axi_read(dut, addr)
    assert rresp == AXI_OKAY
    assert data == 0xAABBCC11, f"Expected 0xAABBCC11, got {data:#010x}"

    # Update byte 1: CC -> 22
    bresp = await axi_write(dut, addr, 0x00002200, strobe=0b0010)
    assert bresp == AXI_OKAY

    data, rresp = await axi_read(dut, addr)
    assert rresp == AXI_OKAY
    assert data == 0xAABB2211, f"Expected 0xAABB2211, got {data:#010x}"

    # Update byte 2: BB -> 33
    bresp = await axi_write(dut, addr, 0x00330000, strobe=0b0100)
    assert bresp == AXI_OKAY

    data, rresp = await axi_read(dut, addr)
    assert rresp == AXI_OKAY
    assert data == 0xAA332211, f"Expected 0xAA332211, got {data:#010x}"

    # Update byte 3: AA -> 44
    bresp = await axi_write(dut, addr, 0x44000000, strobe=0b1000)
    assert bresp == AXI_OKAY

    data, rresp = await axi_read(dut, addr)
    assert rresp == AXI_OKAY
    assert data == 0x44332211, f"Expected 0x44332211, got {data:#010x}"


@cocotb.test()
async def test_ram_zero_strobe_write(dut):
    """
    Verify WSTRB=0 does not modify memory.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    addr = 0x00000080

    bresp = await axi_write(dut, addr, 0x12345678)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, addr, 0xFFFFFFFF, strobe=0b0000)
    assert bresp == AXI_OKAY

    data, rresp = await axi_read(dut, addr)
    assert rresp == AXI_OKAY
    assert data == 0x12345678, (
        f"Expected memory unchanged at 0x12345678, got {data:#010x}"
    )


@cocotb.test()
async def test_ram_unaligned_access(dut):
    """
    Verify unaligned addresses return SLVERR.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    bresp = await axi_write(dut, INVALID_UNALIGNED_ADDR, 0x12345678)
    assert bresp == AXI_SLVERR, (
        f"Expected SLVERR for unaligned write, got {bresp}"
    )

    data, rresp = await axi_read(dut, INVALID_UNALIGNED_ADDR)
    assert rresp == AXI_SLVERR, (
        f"Expected SLVERR for unaligned read, got {rresp}"
    )
    assert data == 0, f"Expected data=0 for invalid read, got {data:#010x}"


@cocotb.test()
async def test_ram_out_of_range_access(dut):
    """
    Verify addresses outside 4 KB RAM return SLVERR.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    bresp = await axi_write(dut, INVALID_OUT_OF_RANGE_ADDR, 0xCAFEBABE)
    assert bresp == AXI_SLVERR, (
        f"Expected SLVERR for out-of-range write, got {bresp}"
    )

    data, rresp = await axi_read(dut, INVALID_OUT_OF_RANGE_ADDR)
    assert rresp == AXI_SLVERR, (
        f"Expected SLVERR for out-of-range read, got {rresp}"
    )
    assert data == 0, f"Expected data=0 for invalid read, got {data:#010x}"


@cocotb.test()
async def test_ram_boundary_access(dut):
    """
    Verify first and last valid RAM words are accessible.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    first_addr = 0x00000000
    last_addr = LAST_VALID_WORD_ADDR

    bresp = await axi_write(dut, first_addr, 0x11112222)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, last_addr, 0x33334444)
    assert bresp == AXI_OKAY

    data, rresp = await axi_read(dut, first_addr)
    assert rresp == AXI_OKAY
    assert data == 0x11112222, f"Expected first word 0x11112222, got {data:#010x}"

    data, rresp = await axi_read(dut, last_addr)
    assert rresp == AXI_OKAY
    assert data == 0x33334444, f"Expected last word 0x33334444, got {data:#010x}"


@cocotb.test()
async def test_ram_back_to_back_access(dut):
    """
    Verify back-to-back write/read accesses work correctly.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    for i in range(16):
        addr = i * WORD_BYTES
        value = 0x10000000 + i

        bresp = await axi_write(dut, addr, value)
        assert bresp == AXI_OKAY

        data, rresp = await axi_read(dut, addr)
        assert rresp == AXI_OKAY
        assert data == value, (
            f"Iteration {i}: expected {value:#010x}, got {data:#010x}"
        )


@cocotb.test()
async def test_ram_random_access(dut):
    """
    Verify randomized writes and reads across RAM.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    random.seed(42)

    expected = {}

    for _ in range(100):
        word_index = random.randint(0, RAM_WORDS - 1)
        addr = word_index * WORD_BYTES
        value = random.getrandbits(32)

        bresp = await axi_write(dut, addr, value)
        assert bresp == AXI_OKAY

        expected[addr] = value

    for addr, value in expected.items():
        data, rresp = await axi_read(dut, addr)
        assert rresp == AXI_OKAY
        assert data == value, (
            f"Random read at addr {addr:#010x}: expected {value:#010x}, got {data:#010x}"
        )


@cocotb.test()
async def test_ram_random_byte_strobes(dut):
    """
    Verify randomized byte-strobe writes using a Python reference model.

    Each address is initialized before partial writes because RAM contents are
    not guaranteed to reset to zero.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    random.seed(123)

    reference = {}

    def apply_wstrb_ref(old_value, new_value, strobe):
        result = old_value

        for byte in range(4):
            if (strobe >> byte) & 1:
                mask = 0xFF << (byte * 8)
                result = (result & ~mask) | (new_value & mask)

        return result & 0xFFFFFFFF

    for i in range(100):
        word_index = random.randint(0, RAM_WORDS - 1)
        addr = word_index * WORD_BYTES

        # If this address has not been used before in this test,
        # initialize it to zero first.
        if addr not in reference:
            bresp = await axi_write(dut, addr, 0x00000000, strobe=0b1111)
            assert bresp == AXI_OKAY
            reference[addr] = 0x00000000

        old_value = reference[addr]

        new_value = random.getrandbits(32)
        strobe = random.randint(0, 0xF)

        expected_value = apply_wstrb_ref(old_value, new_value, strobe)

        bresp = await axi_write(dut, addr, new_value, strobe=strobe)
        assert bresp == AXI_OKAY

        reference[addr] = expected_value

        data, rresp = await axi_read(dut, addr)
        assert rresp == AXI_OKAY

        assert data == expected_value, (
            f"iter={i}, addr={addr:#010x}, old={old_value:#010x}, "
            f"new={new_value:#010x}, strobe={strobe:04b}, "
            f"expected={expected_value:#010x}, got={data:#010x}"
        )