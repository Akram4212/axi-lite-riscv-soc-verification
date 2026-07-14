import cocotb
import random
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
from axi_lite_master import reset_dut, axi_write, axi_read
#GPIO register offset
GPIO_DATA_OUT = 0x00
GPIO_DATA_IN = 0x04
GPIO_DATA_DIR = 0x08

GPIO_DATA_OUT_SET = 0x0C
GPIO_DATA_OUT_CLR = 0x10
# AXI RESPONSE VALUES
AXI_OKAY = 0
AXI_SLVERR = 2

@cocotb.test()
async def test_gpio_reset(dut):
    """
    Verify GPIO registers reset to zero.
    """
    # Start the clock
    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    # Reset the DUT
    await reset_dut(dut)

    # Read GPIO registers and check they are zero
    data_out, resp = await axi_read(dut, GPIO_DATA_OUT)
    assert resp == AXI_OKAY, f"Expected OKAY response, got {resp}"
    assert data_out == 0x00000000, f"DATA_OUT reset value incorrect: {data_out:#010x}"

    data_dir, resp = await axi_read(dut, GPIO_DATA_DIR)
    assert resp == AXI_OKAY, f"Expected OKAY response, got {resp}"
    assert data_dir == 0x00000000, f"DATA_DIR reset value incorrect: {data_dir:#010x}"

    assert int(dut.gpio_o.value) == 0x00000000, f"gpio_o should reset to 0, got {int(dut.gpio_o.value):#010x}"
    assert int(dut.gpio_oe.value) == 0x00000000, f"gpio_oe should reset to 0, got {int(dut.gpio_oe.value):#010x}"

@cocotb.test()
async def test_gpio_basic_read_write(dut):
    """
    Verify basic AXI-Lite writes and reads to GPIO registers.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    # Write DATA_OUT
    bresp = await axi_write(dut, GPIO_DATA_OUT, 0x000000A5)
    assert bresp == AXI_OKAY, f"Expected OKAY write response, got {bresp}"

    # Read DATA_OUT
    data, rresp = await axi_read(dut, GPIO_DATA_OUT)
    assert rresp == AXI_OKAY, f"Expected OKAY read response, got {rresp}"
    assert data == 0x000000A5, f"Expected DATA_OUT=0xA5, got {data:#010x}"

    # Check actual GPIO output
    assert int(dut.gpio_o.value) == 0x000000A5, f"gpio_o mismatch, got {int(dut.gpio_o.value):#010x}"

    # Write DATA_DIR
    bresp = await axi_write(dut, GPIO_DATA_DIR, 0x000000FF)
    assert bresp == AXI_OKAY, f"Expected OKAY write response, got {bresp}"

    # Read DATA_DIR
    data, rresp = await axi_read(dut, GPIO_DATA_DIR)
    assert rresp == AXI_OKAY, f"Expected OKAY read response, got {rresp}"
    assert data == 0x000000FF, f"Expected DATA_DIR=0xFF, got {data:#010x}"

    # Check actual GPIO output enable
    assert int(dut.gpio_oe.value) == 0x000000FF, f"gpio_oe mismatch, got {int(dut.gpio_oe.value):#010x}"

@cocotb.test()
async def test_gpio_input_read(dut):
    """
    Verify that DATA_IN reflects the extternal gpio_i input pins.
    """
    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    # Set gpio_i to a known value
    dut.gpio_i.value = 0x0000003C
    await ClockCycles(dut.ACLK, 2)

    # Read DATA_IN
    data, rresp = await axi_read(dut, GPIO_DATA_IN)

    assert rresp == AXI_OKAY, f"Expected OKAY read response, got {rresp}"
    assert data == 0x0000003C, f"Expected DATA_IN=0x3C, got {data:#010x}"

@cocotb.test()
async def test_gpio_set_clear(dut):
    """
    Verify that DATA_OUT_SET and DATA_OUT_CLR registers work as expected.
    """
    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    # Write initial value to DATA_OUT
    bresp = await axi_write(dut, GPIO_DATA_OUT, 0x00000000)
    assert bresp == AXI_OKAY, f"Expected OKAY write response, got {bresp}"

    # Set bits using DATA_OUT_SET
    bresp = await axi_write(dut, GPIO_DATA_OUT_SET, 0x0000000F)
    assert bresp == AXI_OKAY, f"Expected OKAY write response, got {bresp}"

    # Read back DATA_OUT
    data, rresp = await axi_read(dut, GPIO_DATA_OUT)
    assert rresp == AXI_OKAY, f"Expected OKAY read response, got {rresp}"
    assert data == 0x0000000F, f"Expected DATA_OUT=0x0F after set, got {data:#010x}"

    assert int(dut.gpio_o.value) == 0x0000000F, \
        f"gpio_o mismatch after set, got {int(dut.gpio_o.value):#010x}"

    # Clear bits 0 and 2: 0x0F & ~0x05 = 0x0A
    bresp = await axi_write(dut, GPIO_DATA_OUT_CLR, 0x00000005)
    assert bresp == AXI_OKAY, f"Expected OKAY write response, got {bresp}"

    data, rresp = await axi_read(dut, GPIO_DATA_OUT)
    assert rresp == AXI_OKAY, f"Expected OKAY read response, got {rresp}"
    assert data == 0x0000000A, f"Expected DATA_OUT=0x0A after clear, got {data:#010x}"

    assert int(dut.gpio_o.value) == 0x0000000A, \
        f"gpio_o mismatch after clear, got {int(dut.gpio_o.value):#010x}"

@cocotb.test()
async def test_gpio_invalid_write_to_input_register(dut):
    """
    Verify that writing to the DATA_IN register does not change its value.
    """
    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    bresp = await axi_write(dut, GPIO_DATA_IN, 0x00000012)
    assert bresp == AXI_SLVERR, \
        f"Expected SLVERR write response when writing to DATA_IN, got {bresp}"

@cocotb.test()
async def test_gpio_byte_strobe(dut):
    """
    Verify that WSTRB updates only the specified bytes in DATA_OUT.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    # Initial full write
    bresp = await axi_write(dut, GPIO_DATA_OUT, 0xAABBCCDD)
    assert bresp == AXI_OKAY, f"Expected OKAY write response, got {bresp}"

    await ClockCycles(dut.ACLK, 3)

    data, rresp = await axi_read(dut, GPIO_DATA_OUT)
    assert rresp == AXI_OKAY
    assert data == 0xAABBCCDD, f"Expected DATA_OUT=0xAABBCCDD, got {data:#010x}"
    assert int(dut.gpio_o.value) == 0xAABBCCDD

    # ------------------------------------------------------------
    # Update byte 0 only: DD -> 11
    # Expected: AABBCCDD -> AABBCC11
    # ------------------------------------------------------------
    bresp = await axi_write(dut, GPIO_DATA_OUT, 0x00000011, strobe=0b0001)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 5)

    gpio_value = int(dut.gpio_o.value)
    dut._log.info(f"After byte 0 write before read: gpio_o={gpio_value:#010x}")
    assert gpio_value == 0xAABBCC11, f"gpio_o expected 0xAABBCC11, got {gpio_value:#010x}"

    data, rresp = await axi_read(dut, GPIO_DATA_OUT)
    dut._log.info(f"After byte 0 read: DATA_OUT={data:#010x}, gpio_o={int(dut.gpio_o.value):#010x}")

    assert rresp == AXI_OKAY
    assert data == 0xAABBCC11, f"Expected DATA_OUT=0xAABBCC11 after byte 0 update, got {data:#010x}"

    # ------------------------------------------------------------
    # Update byte 1 only: CC -> 22
    # Expected: AABBCC11 -> AABB2211
    # ------------------------------------------------------------
    bresp = await axi_write(dut, GPIO_DATA_OUT, 0x00002200, strobe=0b0010)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 5)

    data, rresp = await axi_read(dut, GPIO_DATA_OUT)
    dut._log.info(f"After byte 1 read: DATA_OUT={data:#010x}, gpio_o={int(dut.gpio_o.value):#010x}")

    assert rresp == AXI_OKAY
    assert data == 0xAABB2211, f"Expected DATA_OUT=0xAABB2211 after byte 1 update, got {data:#010x}"

    # ------------------------------------------------------------
    # Update byte 2 only: BB -> 33
    # Expected: AABB2211 -> AA332211
    # ------------------------------------------------------------
    bresp = await axi_write(dut, GPIO_DATA_OUT, 0x00330000, strobe=0b0100)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 5)

    data, rresp = await axi_read(dut, GPIO_DATA_OUT)
    dut._log.info(f"After byte 2 read: DATA_OUT={data:#010x}, gpio_o={int(dut.gpio_o.value):#010x}")

    assert rresp == AXI_OKAY
    assert data == 0xAA332211, f"Expected DATA_OUT=0xAA332211 after byte 2 update, got {data:#010x}"

    # ------------------------------------------------------------
    # Update byte 3 only: AA -> 44
    # Expected: AA332211 -> 44332211
    # ------------------------------------------------------------
    bresp = await axi_write(dut, GPIO_DATA_OUT, 0x44000000, strobe=0b1000)
    assert bresp == AXI_OKAY

    await ClockCycles(dut.ACLK, 5)

    data, rresp = await axi_read(dut, GPIO_DATA_OUT)
    dut._log.info(f"After byte 3 read: DATA_OUT={data:#010x}, gpio_o={int(dut.gpio_o.value):#010x}")

    assert rresp == AXI_OKAY
    assert data == 0x44332211, f"Expected DATA_OUT=0x44332211 after byte 3 update, got {data:#010x}"

@cocotb.test()
async def test_gpio_random_read_write(dut):
    """
    Verify DATA_OUT and DATA_DIR using multiple randomized write/read checks.
    """

    cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())

    await reset_dut(dut)

    random.seed(42)

    for i in range(50):
        value = random.getrandbits(32)

        bresp = await axi_write(dut, GPIO_DATA_OUT, value)
        assert bresp == AXI_OKAY, f"Iteration {i}: DATA_OUT write response was not OKAY"

        data, rresp = await axi_read(dut, GPIO_DATA_OUT)
        assert rresp == AXI_OKAY, f"Iteration {i}: DATA_OUT read response was not OKAY"
        assert data == value, \
            f"Iteration {i}: DATA_OUT expected {value:#010x}, got {data:#010x}"

        assert int(dut.gpio_o.value) == value, \
            f"Iteration {i}: gpio_o expected {value:#010x}, got {int(dut.gpio_o.value):#010x}"

    for i in range(50):
        value = random.getrandbits(32)

        bresp = await axi_write(dut, GPIO_DATA_DIR, value)
        assert bresp == AXI_OKAY, f"Iteration {i}: DATA_DIR write response was not OKAY"

        data, rresp = await axi_read(dut, GPIO_DATA_DIR)
        assert rresp == AXI_OKAY, f"Iteration {i}: DATA_DIR read response was not OKAY"
        assert data == value, \
            f"Iteration {i}: DATA_DIR expected {value:#010x}, got {data:#010x}"

        assert int(dut.gpio_oe.value) == value, \
            f"Iteration {i}: gpio_oe expected {value:#010x}, got {int(dut.gpio_oe.value):#010x}"