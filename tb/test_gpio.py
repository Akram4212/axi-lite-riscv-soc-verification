import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


#GPIO register offset
GPIO_DATA_OUT = 0x00
GPIO_DATA_IN = 0x04
GPIO_DATA_DIR = 0x08

# AXI RESPONSE VALUES
AXI_OKAY = 0
AXI_SLVERR = 2

async def reset_dut(dut):
    """
    Reset the GPIO DUT and initialize all AXI/input signals.
    """
    dut.ARESETn.value = 0
    # write address channel
    dut.S_AXI_AWADDR.value = 0
    dut.S_AXI_AWVALID.value = 0

    #Write data channel
    dut.S_AXI_WDATA.value = 0
    dut.S_AXI_WSTRB.value = 0
    dut.S_AXI_WVALID.value = 0

    #write response channel
    dut.S_AXI_BREADY.value = 0

    #read address channel
    dut.S_AXI_ARADDR.value = 0
    dut.S_AXI_ARVALID.value = 0

    #read data channel
    dut.S_AXI_RREADY.value = 0

    #GPIO input
    dut.gpio_i.value = 0

    #hold reset for 5 clock cycles
    await ClockCycles(dut.ACLK, 5)

    #release reset
    dut.ARESETn.value = 1

    await ClockCycles(dut.ACLK, 2)

async def axi_write(dut, addr, data, strobe=0xF):
    """
    Perform an AXI write transaction to the GPIO DUT.
    """
    # Set up the write address channel
    dut.S_AXI_AWADDR.value = addr
    dut.S_AXI_AWVALID.value = 1

    # Set up the write data channel
    dut.S_AXI_WDATA.value = data
    dut.S_AXI_WSTRB.value = strobe
    dut.S_AXI_WVALID.value = 1

    dut.S_AXI_BREADY.value = 1
    
    aw_done = False
    w_done = False

    # Wait for the DUT to accept the write address and data
    while not (dut.S_AXI_AWREADY.value and dut.S_AXI_WREADY.value):
        await RisingEdge(dut.ACLK)

        if dut.S_AXI_AWVALID.value and dut.S_AXI_AWREADY.value:
            dut.S_AXI_AWVALID.value = 0  # Deassert AWVALID after address is accepted
            aw_done = True
        
        if dut.S_AXI_WVALID.value and dut.S_AXI_WREADY.value:
            dut.S_AXI_WVALID.value = 0  # Deassert WVALID after data is accepted
            w_done = True

    #wait for write response
    while not dut.S_AXI_BVALID.value:
        await RisingEdge(dut.ACLK)

    bresp = int(dut.S_AXI_BRESP.value)

    #complete B channel handshake
    await RisingEdge(dut.ACLK)
    dut.S_AXI_BREADY.value = 0

    return bresp
async def axi_read(dut, addr):
    """
    Perform one AXI-Lite read transaction.

    Returns:
        data, RRESP value
    """
    # Set up the read address channel
    dut.S_AXI_ARADDR.value = addr
    dut.S_AXI_ARVALID.value = 1

    dut.S_AXI_RREADY.value = 1

    # Wait for the DUT to accept the read address
    while not dut.S_AXI_ARREADY.value:
        await RisingEdge(dut.ACLK)

    # Deassert ARVALID after address is accepted
    await RisingEdge(dut.ACLK)
    dut.S_AXI_ARVALID.value = 0

    # Wait for the read data to be valid
    while not dut.S_AXI_RVALID.value:
        await RisingEdge(dut.ACLK)

    data = int(dut.S_AXI_RDATA.value)
    rresp = int(dut.S_AXI_RRESP.value)

    # Complete R channel handshake
    await RisingEdge(dut.ACLK)
    dut.S_AXI_RREADY.value = 0

    return data, rresp

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