import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from axi_lite_master import reset_dut, axi_write, axi_read


# ============================================================
# AXI-Lite Response Codes
# ============================================================

AXI_OKAY   = 0
AXI_SLVERR = 2


# ============================================================
# Subsystem Address Map
# ============================================================

GPIO_BASE  = 0x1000_0000
TIMER_BASE = 0x1000_1000

# GPIO local register offsets
GPIO_DATA_OUT     = GPIO_BASE + 0x00
GPIO_DATA_IN      = GPIO_BASE + 0x04
GPIO_DATA_DIR     = GPIO_BASE + 0x08
GPIO_DATA_OUT_SET = GPIO_BASE + 0x0C
GPIO_DATA_OUT_CLR = GPIO_BASE + 0x10

# Timer local register offsets
TIMER_CTRL    = TIMER_BASE + 0x00
TIMER_COUNT   = TIMER_BASE + 0x04
TIMER_COMPARE = TIMER_BASE + 0x08
TIMER_STATUS  = TIMER_BASE + 0x0C

# Invalid address outside mapped peripheral ranges
INVALID_ADDR = 0x2000_0000


# ============================================================
# Timer Bit Definitions
# ============================================================

CTRL_ENABLE = 1 << 0
CTRL_CLEAR  = 1 << 1
CTRL_IRQ_EN = 1 << 2

STATUS_MATCH = 1 << 0


# ============================================================
# Subsystem Reset Helper
# ============================================================

async def reset_subsystem(dut):
    """
    Reset subsystem and initialize subsystem-specific external inputs.
    """

    dut.gpio_i.value = 0
    await reset_dut(dut)


# ============================================================
# Tests
# ============================================================

@cocotb.test()
async def test_subsystem_reset(dut):
    """
    Verify GPIO and Timer registers are reset through the subsystem.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    data, resp = await axi_read(dut, GPIO_DATA_OUT)
    assert resp == AXI_OKAY
    assert data == 0, f"Expected GPIO DATA_OUT=0 after reset, got {data:#010x}"

    data, resp = await axi_read(dut, GPIO_DATA_DIR)
    assert resp == AXI_OKAY
    assert data == 0, f"Expected GPIO DATA_DIR=0 after reset, got {data:#010x}"

    data, resp = await axi_read(dut, TIMER_CTRL)
    assert resp == AXI_OKAY
    assert data == 0, f"Expected TIMER CTRL=0 after reset, got {data:#010x}"

    data, resp = await axi_read(dut, TIMER_COUNT)
    assert resp == AXI_OKAY
    assert data == 0, f"Expected TIMER COUNT=0 after reset, got {data:#010x}"

    data, resp = await axi_read(dut, TIMER_COMPARE)
    assert resp == AXI_OKAY
    assert data == 0, f"Expected TIMER COMPARE=0 after reset, got {data:#010x}"

    data, resp = await axi_read(dut, TIMER_STATUS)
    assert resp == AXI_OKAY
    assert data == 0, f"Expected TIMER STATUS=0 after reset, got {data:#010x}"

    assert int(dut.gpio_o.value) == 0
    assert int(dut.gpio_oe.value) == 0
    assert int(dut.timer_irq.value) == 0


@cocotb.test()
async def test_subsystem_gpio_access(dut):
    """
    Verify GPIO can be accessed through the subsystem address map.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    bresp = await axi_write(dut, GPIO_DATA_OUT, 0x000000A5)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, GPIO_DATA_OUT)
    assert resp == AXI_OKAY
    assert data == 0x000000A5, f"Expected GPIO DATA_OUT=0xA5, got {data:#010x}"
    assert int(dut.gpio_o.value) == 0x000000A5

    bresp = await axi_write(dut, GPIO_DATA_DIR, 0x000000FF)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, GPIO_DATA_DIR)
    assert resp == AXI_OKAY
    assert data == 0x000000FF, f"Expected GPIO DATA_DIR=0xFF, got {data:#010x}"
    assert int(dut.gpio_oe.value) == 0x000000FF


@cocotb.test()
async def test_subsystem_gpio_input_read(dut):
    """
    Verify GPIO DATA_IN reads external gpio_i through the subsystem.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    dut.gpio_i.value = 0x0000003C
    await ClockCycles(dut.ACLK, 2)

    data, resp = await axi_read(dut, GPIO_DATA_IN)
    assert resp == AXI_OKAY
    assert data == 0x0000003C, f"Expected GPIO DATA_IN=0x3C, got {data:#010x}"


@cocotb.test()
async def test_subsystem_gpio_set_clear(dut):
    """
    Verify GPIO SET/CLEAR registers work through the subsystem.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    bresp = await axi_write(dut, GPIO_DATA_OUT, 0x00000000)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, GPIO_DATA_OUT_SET, 0x0000000F)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, GPIO_DATA_OUT)
    assert resp == AXI_OKAY
    assert data == 0x0000000F, f"Expected GPIO DATA_OUT=0xF, got {data:#010x}"

    bresp = await axi_write(dut, GPIO_DATA_OUT_CLR, 0x00000005)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, GPIO_DATA_OUT)
    assert resp == AXI_OKAY
    assert data == 0x0000000A, f"Expected GPIO DATA_OUT=0xA, got {data:#010x}"


@cocotb.test()
async def test_subsystem_timer_access(dut):
    """
    Verify Timer can be accessed through the subsystem address map.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    bresp = await axi_write(dut, TIMER_COMPARE, 10)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, TIMER_COMPARE)
    assert resp == AXI_OKAY
    assert data == 10, f"Expected TIMER COMPARE=10, got {data}"

    bresp = await axi_write(dut, TIMER_CTRL, CTRL_ENABLE)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 12)

    count, resp = await axi_read(dut, TIMER_COUNT)
    assert resp == AXI_OKAY
    assert count > 0, f"Expected TIMER COUNT to increment, got {count}"

    status, resp = await axi_read(dut, TIMER_STATUS)
    assert resp == AXI_OKAY
    assert status & STATUS_MATCH, f"Expected TIMER STATUS[MATCH]=1, got {status:#010x}"


@cocotb.test()
async def test_subsystem_timer_irq(dut):
    """
    Verify Timer IRQ works through the subsystem.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    bresp = await axi_write(dut, TIMER_COMPARE, 6)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, TIMER_CTRL, CTRL_ENABLE | CTRL_IRQ_EN)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 12)

    status, resp = await axi_read(dut, TIMER_STATUS)
    assert resp == AXI_OKAY
    assert status & STATUS_MATCH, "Expected TIMER STATUS[MATCH]=1"

    await ClockCycles(dut.ACLK, 2)

    assert int(dut.timer_irq.value) == 1, "Expected timer_irq=1"


@cocotb.test()
async def test_subsystem_gpio_timer_isolation(dut):
    """
    Verify GPIO writes do not corrupt Timer registers and Timer writes do not corrupt GPIO.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    bresp = await axi_write(dut, GPIO_DATA_OUT, 0xDEADBEEF)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, TIMER_COMPARE, 0x0000002A)
    assert bresp == AXI_OKAY

    gpio_data, resp = await axi_read(dut, GPIO_DATA_OUT)
    assert resp == AXI_OKAY
    assert gpio_data == 0xDEADBEEF, (
        f"Expected GPIO DATA_OUT=0xDEADBEEF, got {gpio_data:#010x}"
    )

    timer_compare, resp = await axi_read(dut, TIMER_COMPARE)
    assert resp == AXI_OKAY
    assert timer_compare == 0x0000002A, (
        f"Expected TIMER COMPARE=0x2A, got {timer_compare:#010x}"
    )

    assert int(dut.gpio_o.value) == 0xDEADBEEF


@cocotb.test()
async def test_subsystem_invalid_write(dut):
    """
    Verify writes to unmapped addresses return SLVERR.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    bresp = await axi_write(dut, INVALID_ADDR, 0x12345678)
    assert bresp == AXI_SLVERR, f"Expected SLVERR for invalid write, got {bresp}"


@cocotb.test()
async def test_subsystem_invalid_read(dut):
    """
    Verify reads from unmapped addresses return SLVERR.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    data, rresp = await axi_read(dut, INVALID_ADDR)
    assert rresp == AXI_SLVERR, f"Expected SLVERR for invalid read, got {rresp}"
    assert data == 0, f"Expected invalid read data=0, got {data:#010x}"


@cocotb.test()
async def test_subsystem_unaligned_access(dut):
    """
    Verify unaligned accesses inside valid peripheral ranges return SLVERR.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    bresp = await axi_write(dut, GPIO_BASE + 0x02, 0x12345678)
    assert bresp == AXI_SLVERR, f"Expected SLVERR for unaligned GPIO write, got {bresp}"

    data, rresp = await axi_read(dut, TIMER_BASE + 0x02)
    assert rresp == AXI_SLVERR, f"Expected SLVERR for unaligned Timer read, got {rresp}"


@cocotb.test()
async def test_subsystem_byte_strobe(dut):
    """
    Verify WSTRB behavior through the subsystem.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    bresp = await axi_write(dut, GPIO_DATA_OUT, 0xAABBCCDD)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, GPIO_DATA_OUT, 0x00000011, strobe=0b0001)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, GPIO_DATA_OUT)
    assert resp == AXI_OKAY
    assert data == 0xAABBCC11, f"Expected GPIO DATA_OUT=0xAABBCC11, got {data:#010x}"

    bresp = await axi_write(dut, TIMER_COMPARE, 0x11223344)
    assert bresp == AXI_OKAY

    bresp = await axi_write(dut, TIMER_COMPARE, 0x000000AA, strobe=0b0001)
    assert bresp == AXI_OKAY

    data, resp = await axi_read(dut, TIMER_COMPARE)
    assert resp == AXI_OKAY
    assert data == 0x112233AA, f"Expected TIMER COMPARE=0x112233AA, got {data:#010x}"


@cocotb.test()
async def test_subsystem_back_to_back_access(dut):
    """
    Verify alternating GPIO and Timer accesses work correctly.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    for i in range(10):
        gpio_value = 0x1000 + i
        timer_value = 20 + i

        bresp = await axi_write(dut, GPIO_DATA_OUT, gpio_value)
        assert bresp == AXI_OKAY

        bresp = await axi_write(dut, TIMER_COMPARE, timer_value)
        assert bresp == AXI_OKAY

        gpio_read, resp = await axi_read(dut, GPIO_DATA_OUT)
        assert resp == AXI_OKAY
        assert gpio_read == gpio_value, (
            f"Iteration {i}: expected GPIO={gpio_value:#010x}, got {gpio_read:#010x}"
        )

        timer_read, resp = await axi_read(dut, TIMER_COMPARE)
        assert resp == AXI_OKAY
        assert timer_read == timer_value, (
            f"Iteration {i}: expected TIMER_COMPARE={timer_value:#010x}, got {timer_read:#010x}"
        )


@cocotb.test()
async def test_subsystem_randomized_gpio_timer_access(dut):
    """
    Randomized register access test across GPIO and Timer mapped regions.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_subsystem(dut)

    random.seed(42)

    for i in range(25):
        gpio_value = random.getrandbits(32)
        timer_value = random.randint(1, 1000)

        bresp = await axi_write(dut, GPIO_DATA_OUT, gpio_value)
        assert bresp == AXI_OKAY

        bresp = await axi_write(dut, TIMER_COMPARE, timer_value)
        assert bresp == AXI_OKAY

        gpio_read, resp = await axi_read(dut, GPIO_DATA_OUT)
        assert resp == AXI_OKAY
        assert gpio_read == gpio_value, (
            f"Random iter {i}: expected GPIO={gpio_value:#010x}, got {gpio_read:#010x}"
        )

        timer_read, resp = await axi_read(dut, TIMER_COMPARE)
        assert resp == AXI_OKAY
        assert timer_read == timer_value, (
            f"Random iter {i}: expected TIMER_COMPARE={timer_value:#010x}, got {timer_read:#010x}"
        )