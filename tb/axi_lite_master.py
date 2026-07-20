from cocotb.triggers import RisingEdge, ClockCycles


# ============================================================
# Generic AXI-Lite Reset Helper
# ============================================================

async def reset_dut(dut, cycles=5):
    """
    Reset DUT and initialize AXI-Lite master-side signals.

    Works for GPIO, Timer, and future AXI-Lite peripherals as long as
    they use the same AXI-Lite signal names.
    """

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

    await ClockCycles(dut.ACLK, cycles)

    dut.ARESETn.value = 1

    await ClockCycles(dut.ACLK, 2)


# ============================================================
# AXI-Lite Write Helper
# ============================================================

async def axi_write(dut, addr, data, strobe=0xF):
    """
    Perform one AXI-Lite write transaction.

    Returns:
        bresp: AXI write response
    """

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
    """
    Perform one AXI-Lite read transaction.

    Returns:
        data:  AXI read data
        rresp: AXI read response
    """

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