`timescale 1ns/1ps

module axi_lite_subsystem #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int RAM_BYTES  = 4096
)(
    input  logic                         ACLK,
    input  logic                         ARESETn,

    // ========================================================
    // External AXI-Lite Slave Interface
    // This is the interface seen by cocotb or a future CPU
    // ========================================================

    // Write address channel
    input  logic [ADDR_WIDTH-1:0]         S_AXI_AWADDR,
    input  logic                         S_AXI_AWVALID,
    output logic                         S_AXI_AWREADY,

    // Write data channel
    input  logic [DATA_WIDTH-1:0]         S_AXI_WDATA,
    input  logic [(DATA_WIDTH/8)-1:0]     S_AXI_WSTRB,
    input  logic                         S_AXI_WVALID,
    output logic                         S_AXI_WREADY,

    // Write response channel
    output logic [1:0]                   S_AXI_BRESP,
    output logic                         S_AXI_BVALID,
    input  logic                         S_AXI_BREADY,

    // Read address channel
    input  logic [ADDR_WIDTH-1:0]         S_AXI_ARADDR,
    input  logic                         S_AXI_ARVALID,
    output logic                         S_AXI_ARREADY,

    // Read data channel
    output logic [DATA_WIDTH-1:0]         S_AXI_RDATA,
    output logic [1:0]                   S_AXI_RRESP,
    output logic                         S_AXI_RVALID,
    input  logic                         S_AXI_RREADY,

    // ========================================================
    // GPIO external pins
    // ========================================================

    input  logic [DATA_WIDTH-1:0]         gpio_i,
    output logic [DATA_WIDTH-1:0]         gpio_o,
    output logic [DATA_WIDTH-1:0]         gpio_oe,

    // ========================================================
    // Timer interrupt output
    // ========================================================

    output logic                         timer_irq
);

    // ========================================================
    // Internal AXI-Lite wires: Interconnect -> RAM
    // ========================================================

    logic [ADDR_WIDTH-1:0]         ram_awaddr;
    logic                         ram_awvalid;
    logic                         ram_awready;

    logic [DATA_WIDTH-1:0]         ram_wdata;
    logic [(DATA_WIDTH/8)-1:0]     ram_wstrb;
    logic                         ram_wvalid;
    logic                         ram_wready;

    logic [1:0]                   ram_bresp;
    logic                         ram_bvalid;
    logic                         ram_bready;

    logic [ADDR_WIDTH-1:0]         ram_araddr;
    logic                         ram_arvalid;
    logic                         ram_arready;

    logic [DATA_WIDTH-1:0]         ram_rdata;
    logic [1:0]                   ram_rresp;
    logic                         ram_rvalid;
    logic                         ram_rready;

    // ========================================================
    // Internal AXI-Lite wires: Interconnect -> GPIO
    // ========================================================

    logic [ADDR_WIDTH-1:0]         gpio_awaddr;
    logic                         gpio_awvalid;
    logic                         gpio_awready;

    logic [DATA_WIDTH-1:0]         gpio_wdata;
    logic [(DATA_WIDTH/8)-1:0]     gpio_wstrb;
    logic                         gpio_wvalid;
    logic                         gpio_wready;

    logic [1:0]                   gpio_bresp;
    logic                         gpio_bvalid;
    logic                         gpio_bready;

    logic [ADDR_WIDTH-1:0]         gpio_araddr;
    logic                         gpio_arvalid;
    logic                         gpio_arready;

    logic [DATA_WIDTH-1:0]         gpio_rdata;
    logic [1:0]                   gpio_rresp;
    logic                         gpio_rvalid;
    logic                         gpio_rready;

    // ========================================================
    // Internal AXI-Lite wires: Interconnect -> Timer
    // ========================================================

    logic [ADDR_WIDTH-1:0]         timer_awaddr;
    logic                         timer_awvalid;
    logic                         timer_awready;

    logic [DATA_WIDTH-1:0]         timer_wdata;
    logic [(DATA_WIDTH/8)-1:0]     timer_wstrb;
    logic                         timer_wvalid;
    logic                         timer_wready;

    logic [1:0]                   timer_bresp;
    logic                         timer_bvalid;
    logic                         timer_bready;

    logic [ADDR_WIDTH-1:0]         timer_araddr;
    logic                         timer_arvalid;
    logic                         timer_arready;

    logic [DATA_WIDTH-1:0]         timer_rdata;
    logic [1:0]                   timer_rresp;
    logic                         timer_rvalid;
    logic                         timer_rready;

    // ========================================================
    // AXI-Lite Interconnect
    // ========================================================

    axi_lite_interconnect #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_axi_lite_interconnect (
        .ACLK       (ACLK),
        .ARESETn    (ARESETn),

        // External slave-side AXI-Lite interface
        .S_AXI_AWADDR  (S_AXI_AWADDR),
        .S_AXI_AWVALID (S_AXI_AWVALID),
        .S_AXI_AWREADY (S_AXI_AWREADY),

        .S_AXI_WDATA   (S_AXI_WDATA),
        .S_AXI_WSTRB   (S_AXI_WSTRB),
        .S_AXI_WVALID  (S_AXI_WVALID),
        .S_AXI_WREADY  (S_AXI_WREADY),

        .S_AXI_BRESP   (S_AXI_BRESP),
        .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),

        .S_AXI_ARADDR  (S_AXI_ARADDR),
        .S_AXI_ARVALID (S_AXI_ARVALID),
        .S_AXI_ARREADY (S_AXI_ARREADY),

        .S_AXI_RDATA   (S_AXI_RDATA),
        .S_AXI_RRESP   (S_AXI_RRESP),
        .S_AXI_RVALID  (S_AXI_RVALID),
        .S_AXI_RREADY  (S_AXI_RREADY),

        // RAM master-side AXI-Lite interface
        .M_RAM_AWADDR  (ram_awaddr),
        .M_RAM_AWVALID (ram_awvalid),
        .M_RAM_AWREADY (ram_awready),

        .M_RAM_WDATA   (ram_wdata),
        .M_RAM_WSTRB   (ram_wstrb),
        .M_RAM_WVALID  (ram_wvalid),
        .M_RAM_WREADY  (ram_wready),

        .M_RAM_BRESP   (ram_bresp),
        .M_RAM_BVALID  (ram_bvalid),
        .M_RAM_BREADY  (ram_bready),

        .M_RAM_ARADDR  (ram_araddr),
        .M_RAM_ARVALID (ram_arvalid),
        .M_RAM_ARREADY (ram_arready),

        .M_RAM_RDATA   (ram_rdata),
        .M_RAM_RRESP   (ram_rresp),
        .M_RAM_RVALID  (ram_rvalid),
        .M_RAM_RREADY  (ram_rready),

        // GPIO master-side AXI-Lite interface
        .M_GPIO_AWADDR  (gpio_awaddr),
        .M_GPIO_AWVALID (gpio_awvalid),
        .M_GPIO_AWREADY (gpio_awready),

        .M_GPIO_WDATA   (gpio_wdata),
        .M_GPIO_WSTRB   (gpio_wstrb),
        .M_GPIO_WVALID  (gpio_wvalid),
        .M_GPIO_WREADY  (gpio_wready),

        .M_GPIO_BRESP   (gpio_bresp),
        .M_GPIO_BVALID  (gpio_bvalid),
        .M_GPIO_BREADY  (gpio_bready),

        .M_GPIO_ARADDR  (gpio_araddr),
        .M_GPIO_ARVALID (gpio_arvalid),
        .M_GPIO_ARREADY (gpio_arready),

        .M_GPIO_RDATA   (gpio_rdata),
        .M_GPIO_RRESP   (gpio_rresp),
        .M_GPIO_RVALID  (gpio_rvalid),
        .M_GPIO_RREADY  (gpio_rready),

        // Timer master-side AXI-Lite interface
        .M_TIMER_AWADDR  (timer_awaddr),
        .M_TIMER_AWVALID (timer_awvalid),
        .M_TIMER_AWREADY (timer_awready),

        .M_TIMER_WDATA   (timer_wdata),
        .M_TIMER_WSTRB   (timer_wstrb),
        .M_TIMER_WVALID  (timer_wvalid),
        .M_TIMER_WREADY  (timer_wready),

        .M_TIMER_BRESP   (timer_bresp),
        .M_TIMER_BVALID  (timer_bvalid),
        .M_TIMER_BREADY  (timer_bready),

        .M_TIMER_ARADDR  (timer_araddr),
        .M_TIMER_ARVALID (timer_arvalid),
        .M_TIMER_ARREADY (timer_arready),

        .M_TIMER_RDATA   (timer_rdata),
        .M_TIMER_RRESP   (timer_rresp),
        .M_TIMER_RVALID  (timer_rvalid),
        .M_TIMER_RREADY  (timer_rready)
    );

    // ========================================================
    // AXI-Lite RAM
    // ========================================================

    axi_lite_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .RAM_BYTES (RAM_BYTES)
    ) u_axi_lite_ram (
        .ACLK       (ACLK),
        .ARESETn    (ARESETn),

        .S_AXI_AWADDR  (ram_awaddr),
        .S_AXI_AWVALID (ram_awvalid),
        .S_AXI_AWREADY (ram_awready),

        .S_AXI_WDATA   (ram_wdata),
        .S_AXI_WSTRB   (ram_wstrb),
        .S_AXI_WVALID  (ram_wvalid),
        .S_AXI_WREADY  (ram_wready),

        .S_AXI_BRESP   (ram_bresp),
        .S_AXI_BVALID  (ram_bvalid),
        .S_AXI_BREADY  (ram_bready),

        .S_AXI_ARADDR  (ram_araddr),
        .S_AXI_ARVALID (ram_arvalid),
        .S_AXI_ARREADY (ram_arready),

        .S_AXI_RDATA   (ram_rdata),
        .S_AXI_RRESP   (ram_rresp),
        .S_AXI_RVALID  (ram_rvalid),
        .S_AXI_RREADY  (ram_rready)
    );

    // ========================================================
    // GPIO Peripheral
    // ========================================================

    gpio #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_gpio (
        .ACLK       (ACLK),
        .ARESETn    (ARESETn),

        .S_AXI_AWADDR  (gpio_awaddr),
        .S_AXI_AWVALID (gpio_awvalid),
        .S_AXI_AWREADY (gpio_awready),

        .S_AXI_WDATA   (gpio_wdata),
        .S_AXI_WSTRB   (gpio_wstrb),
        .S_AXI_WVALID  (gpio_wvalid),
        .S_AXI_WREADY  (gpio_wready),

        .S_AXI_BRESP   (gpio_bresp),
        .S_AXI_BVALID  (gpio_bvalid),
        .S_AXI_BREADY  (gpio_bready),

        .S_AXI_ARADDR  (gpio_araddr),
        .S_AXI_ARVALID (gpio_arvalid),
        .S_AXI_ARREADY (gpio_arready),

        .S_AXI_RDATA   (gpio_rdata),
        .S_AXI_RRESP   (gpio_rresp),
        .S_AXI_RVALID  (gpio_rvalid),
        .S_AXI_RREADY  (gpio_rready),

        .gpio_i        (gpio_i),
        .gpio_o        (gpio_o),
        .gpio_oe       (gpio_oe)
    );

    // ========================================================
    // Timer Peripheral
    // ========================================================

    timer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_timer (
        .ACLK       (ACLK),
        .ARESETn    (ARESETn),

        .S_AXI_AWADDR  (timer_awaddr),
        .S_AXI_AWVALID (timer_awvalid),
        .S_AXI_AWREADY (timer_awready),

        .S_AXI_WDATA   (timer_wdata),
        .S_AXI_WSTRB   (timer_wstrb),
        .S_AXI_WVALID  (timer_wvalid),
        .S_AXI_WREADY  (timer_wready),

        .S_AXI_BRESP   (timer_bresp),
        .S_AXI_BVALID  (timer_bvalid),
        .S_AXI_BREADY  (timer_bready),

        .S_AXI_ARADDR  (timer_araddr),
        .S_AXI_ARVALID (timer_arvalid),
        .S_AXI_ARREADY (timer_arready),

        .S_AXI_RDATA   (timer_rdata),
        .S_AXI_RRESP   (timer_rresp),
        .S_AXI_RVALID  (timer_rvalid),
        .S_AXI_RREADY  (timer_rready),

        .timer_irq     (timer_irq)
    );

endmodule
