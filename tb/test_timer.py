import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


# ============================================================
# Timer Register Map
# ============================================================

TIMER_CTRL    = 0x00
TIMER_COUNT   = 0x04
TIMER_COMPARE = 0x08
TIMER_STATUS  = 0x0C


# ============================================================
# Timer Bit Definitions
# ============================================================

CTRL_ENABLE = 1 << 0
CTRL_CLEAR  = 1 << 1
CTRL_IRQ_EN = 1 << 2

STATUS_MATCH = 1 << 0


# ============================================================
# AXI-Lite Response Codes
# ============================================================

AXI_OKAY   = 0
AXI_SLVERR = 2


# ============================================================
# Reset Helper
# ============================================================

async def reset_dut(dut):
    dut.ARESETn.value = 0

    dut.S_AXI_AWADDR.value  = 0
    dut.S_AXI_AWVALID.value = 0

    dut.S_AXI_WDATA.value   = 0
    dut.S_AXI_WSTRB.value   = 0
    dut.S_AXI_WVALID.value  = 0

    dut.S_AXI_BREADY.value  = 0

    dut.S_AXI_ARADDR.value  = 0
    dut.S_AXI_ARVALID.value = 0

    dut.S_AXI_RREADY.value  = 0

    await ClockCycles(dut.ACLK, 5)

    dut.ARESETn.value = 1

    await ClockCycles(dut.ACLK, 2)


# ============================================================
# AXI-Lite Write Helper
# ============================================================

async def axi_write(dut, addr, data, strobe=0xF):
    dut.S_AXI_AWADDR.value  = addr
    dut.S_AXI_AWVALID.value = 1

    dut.S_AXI_WDATA.value   = data
    dut.S_AXI_WSTRB.value   = strobe
    dut.S_AXI_WVALID.value  = 1

    dut.S_AXI_BREADY.value  = 1

    aw_done = False
    w_done  = False

    while not (aw_done and w_done):
        await RisingEdge(dut.ACLK)

        if int(dut.S_AXI_AWVALID.value) and int(dut.S_AXI_AWREADY.value):
            dut.S_AXI_AWVALID.value = 0
            aw_done = True

        if int(dut.S_AXI_WVALID.value) and int(dut.S_AXI_WREADY.value):
            dut.S_AXI_WVALID.value = 0
            w_done = True

    while not int(dut.S_AXI_BVALID.value):
        await RisingEdge(dut.ACLK)

    bresp = int(dut.S_AXI_BRESP.value)

    await RisingEdge(dut.ACLK)

    dut.S_AXI_BREADY.value = 0

    await ClockCycles(dut.ACLK, 2)

    return bresp


# ============================================================
# AXI-Lite Read Helper
# ============================================================

async def axi_read(dut, addr):
    # Clear any stale read response first
    dut.S_AXI_ARVALID.value = 0
    dut.S_AXI_RREADY.value  = 1

    await ClockCycles(dut.ACLK, 2)

    dut.S_AXI_RREADY.value = 0

    await ClockCycles(dut.ACLK, 1)

    # Issue read address
    dut.S_AXI_ARADDR.value  = addr
    dut.S_AXI_ARVALID.value = 1

    while True:
        await RisingEdge(dut.ACLK)

        if int(dut.S_AXI_ARREADY.value):
            dut.S_AXI_ARVALID.value = 0
            break

    while not int(dut.S_AXI_RVALID.value):
        await RisingEdge(dut.ACLK)

    data  = int(dut.S_AXI_RDATA.value)
    rresp = int(dut.S_AXI_RRESP.value)

    dut.S_AXI_RREADY.value = 1

    await RisingEdge(dut.ACLK)

    dut.S_AXI_RREADY.value = 0

    await ClockCycles(dut.ACLK, 2)

    return data, rresp


# ============================================================
# Tests
# ============================================================

@cocotb.test()
async def test_timer_reset(dut):
    """
    Verify timer registers and IRQ reset to zero.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    data, resp = await axi_read(dut, TIMER_CTRL)
    assert resp == AXI_OKAY
    assert data == 0, f"Expected CTRL=0 after reset, got {data:#010x}"

    data, resp = await axi_read(dut, TIMER_COUNT)
    assert resp == AXI_OKAY
    assert data == 0, f"Expected COUNT=0 after reset, got {data:#010x}"

    data, resp = await axi_read(dut, TIMER_COMPARE)
    assert resp == AXI_OKAY
    assert data == 0, f"Expected COMPARE=0 after reset, got {data:#010x}"

    data, resp = await axi_read(dut, TIMER_STATUS)
    assert resp == AXI_OKAY
    assert data == 0, f"Expected STATUS=0 after reset, got {data:#010x}"

    assert int(dut.timer_irq.value) == 0, "Expected timer_irq=0 after reset"


@cocotb.test()
async def test_timer_enable_count(dut):
    """
    Verify COUNT increments when ENABLE is set.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    bresp = await axi_write(dut, TIMER_CTRL, CTRL_ENABLE)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 10)

    data, resp = await axi_read(dut, TIMER_COUNT)
    assert resp == AXI_OKAY
    assert data > 0, f"Expected COUNT to increment, got {data}"


@cocotb.test()
async def test_timer_disable_holds_count(dut):
    """
    Verify COUNT holds its value when ENABLE is cleared.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    bresp = await axi_write(dut, TIMER_CTRL, CTRL_ENABLE)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 10)

    bresp = await axi_write(dut, TIMER_CTRL, 0)
    assert bresp == AXI_OKAY

    count_1, resp = await axi_read(dut, TIMER_COUNT)
    assert resp == AXI_OKAY

    await ClockCycles(dut.ACLK, 10)

    count_2, resp = await axi_read(dut, TIMER_COUNT)
    assert resp == AXI_OKAY

    assert count_2 == count_1, (
        f"Expected COUNT to hold when disabled, "
        f"count_1={count_1}, count_2={count_2}"
    )


@cocotb.test()
async def test_timer_clear(dut):
    """
    Verify CLEAR resets COUNT and clears STATUS[MATCH].
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    bresp = await axi_write(dut, TIMER_COMPARE, 5)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, TIMER_CTRL, CTRL_ENABLE)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 10)

    status, resp = await axi_read(dut, TIMER_STATUS)
    assert resp == AXI_OKAY
    assert status & STATUS_MATCH, "Expected STATUS[MATCH] to be set before clear"

    bresp = await axi_write(dut, TIMER_CTRL, CTRL_CLEAR)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 5)

    count, resp = await axi_read(dut, TIMER_COUNT)
    assert resp == AXI_OKAY
    assert count == 0, f"Expected COUNT=0 after clear, got {count}"

    status, resp = await axi_read(dut, TIMER_STATUS)
    assert resp == AXI_OKAY
    assert (status & STATUS_MATCH) == 0, (
        f"Expected STATUS[MATCH]=0 after clear, got {status:#010x}"
    )


@cocotb.test()
async def test_timer_compare_match(dut):
    """
    Verify STATUS[MATCH] sets when COUNT reaches COMPARE.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    bresp = await axi_write(dut, TIMER_COMPARE, 8)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, TIMER_CTRL, CTRL_ENABLE)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 12)

    status, resp = await axi_read(dut, TIMER_STATUS)
    assert resp == AXI_OKAY

    assert status & STATUS_MATCH, (
        f"Expected STATUS[MATCH]=1 when count reaches compare, got {status:#010x}"
    )


@cocotb.test()
async def test_timer_irq(dut):
    """
    Verify timer_irq asserts when STATUS[MATCH] is set and IRQ_EN is enabled.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    bresp = await axi_write(dut, TIMER_COMPARE, 6)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, TIMER_CTRL, CTRL_ENABLE | CTRL_IRQ_EN)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 12)

    status, resp = await axi_read(dut, TIMER_STATUS)
    assert resp == AXI_OKAY
    assert status & STATUS_MATCH, "Expected STATUS[MATCH]=1 before checking IRQ"

    await ClockCycles(dut.ACLK, 2)

    assert int(dut.timer_irq.value) == 1, "Expected timer_irq=1 after compare match"


@cocotb.test()
async def test_timer_status_clear(dut):
    """
    Verify STATUS[MATCH] uses write-one-to-clear behavior.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    bresp = await axi_write(dut, TIMER_COMPARE, 5)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, TIMER_CTRL, CTRL_ENABLE | CTRL_IRQ_EN)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 10)

    status, resp = await axi_read(dut, TIMER_STATUS)
    assert resp == AXI_OKAY
    assert status & STATUS_MATCH, "Expected STATUS[MATCH]=1 before clearing"

    assert int(dut.timer_irq.value) == 1, "Expected timer_irq=1 before clearing status"

    # Disable timer first so MATCH does not immediately set again
    bresp = await axi_write(dut, TIMER_CTRL, 0)
    assert bresp == AXI_OKAY

    # Write-one-to-clear STATUS[MATCH]
    bresp = await axi_write(dut, TIMER_STATUS, STATUS_MATCH)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 4)

    status, resp = await axi_read(dut, TIMER_STATUS)
    assert resp == AXI_OKAY
    assert (status & STATUS_MATCH) == 0, (
        f"Expected STATUS[MATCH]=0 after W1C clear, got {status:#010x}"
    )

    await ClockCycles(dut.ACLK, 2)

    assert int(dut.timer_irq.value) == 0, "Expected timer_irq=0 after status clear"


@cocotb.test()
async def test_timer_byte_strobe(dut):
    """
    Verify WSTRB updates only selected bytes in TIMER_COMPARE.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    bresp = await axi_write(dut, TIMER_COMPARE, 0xAABBCCDD)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, TIMER_COMPARE)
    assert resp == AXI_OKAY
    assert data == 0xAABBCCDD, f"Expected COMPARE=0xAABBCCDD, got {data:#010x}"

    bresp = await axi_write(dut, TIMER_COMPARE, 0x00000011, strobe=0b0001)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, TIMER_COMPARE)
    assert resp == AXI_OKAY
    assert data == 0xAABBCC11, f"Expected COMPARE=0xAABBCC11, got {data:#010x}"

    bresp = await axi_write(dut, TIMER_COMPARE, 0x00002200, strobe=0b0010)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, TIMER_COMPARE)
    assert resp == AXI_OKAY
    assert data == 0xAABB2211, f"Expected COMPARE=0xAABB2211, got {data:#010x}"

    bresp = await axi_write(dut, TIMER_COMPARE, 0x00330000, strobe=0b0100)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, TIMER_COMPARE)
    assert resp == AXI_OKAY
    assert data == 0xAA332211, f"Expected COMPARE=0xAA332211, got {data:#010x}"

    bresp = await axi_write(dut, TIMER_COMPARE, 0x44000000, strobe=0b1000)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, TIMER_COMPARE)
    assert resp == AXI_OKAY
    assert data == 0x44332211, f"Expected COMPARE=0x44332211, got {data:#010x}"


@cocotb.test()
async def test_timer_invalid_access(dut):
    """
    Verify invalid and unaligned addresses return SLVERR.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    # Unaligned write
    bresp = await axi_write(dut, 0x02, 0x12345678)
    assert bresp == AXI_SLVERR, f"Expected SLVERR for unaligned write, got {bresp}"

    # Unknown register write
    bresp = await axi_write(dut, 0x20, 0x12345678)
    assert bresp == AXI_SLVERR, f"Expected SLVERR for invalid write, got {bresp}"

    # Unaligned read
    data, rresp = await axi_read(dut, 0x02)
    assert rresp == AXI_SLVERR, f"Expected SLVERR for unaligned read, got {rresp}"

    # Unknown register read
    data, rresp = await axi_read(dut, 0x20)
    assert rresp == AXI_SLVERR, f"Expected SLVERR for invalid read, got {rresp}"


@cocotb.test()
async def test_timer_random_compare(dut):
    """
    Verify randomized compare values eventually set STATUS[MATCH].
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    random.seed(42)

    for _ in range(10):
        compare_value = random.randint(3, 25)

        await reset_dut(dut)

        bresp = await axi_write(dut, TIMER_COMPARE, compare_value)
        assert bresp == AXI_OKAY

        bresp = await axi_write(dut, TIMER_CTRL, CTRL_ENABLE)
        assert bresp == AXI_OKAY

        await ClockCycles(dut.ACLK, compare_value + 5)

        status, resp = await axi_read(dut, TIMER_STATUS)
        assert resp == AXI_OKAY

        assert status & STATUS_MATCH, (
            f"Expected STATUS[MATCH]=1 for compare={compare_value}, "
            f"got STATUS={status:#010x}"
        )