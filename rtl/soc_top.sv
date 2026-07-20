`include "rv32i_core_if.vh"
`include "rv32i_axi_lite_master_if.vh"

module soc_top #(
    parameter logic [31:0] PC_INIT = 32'h0000_0000,
    parameter int unsigned RAM_BYTES = 4096,
    parameter string RAM_INIT_FILE = ""
) (
    input logic CLK,
    input logic nRST,

    input  logic [31:0] gpio_i,
    output logic [31:0] gpio_o,
    output logic [31:0] gpio_oe,

    output logic timer_irq,
    output logic halt,
    output logic illegal,
    output logic bus_error,

    output logic [31:0] debug_pc,
    output logic [31:0] debug_instruction,
    output logic [6:0]  debug_opcode,
    output logic [2:0]  debug_funct3,
    output logic [6:0]  debug_funct7,
    output logic        debug_pipeline_enable,
    output logic        debug_redirect,
    output logic        debug_bubble,
    output logic        debug_wb_wen,
    output logic [4:0]  debug_wb_rd,
    output logic [31:0] debug_wb_data
);

    rv32i_core_if coreif();

    rv32i_axi_lite_master_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) axiif();

    // ========================================================
    // RV32I processor
    // ========================================================

    rv32i_core #(
        .PC_INIT(PC_INIT)
    ) u_core (
        .CLK   (CLK),
        .nRST  (nRST),
        .coreif(coreif)
    );

    // ========================================================
    // Processor memory handshakes to AXI-Lite
    // ========================================================

    rv32i_axi_lite_master u_axi_master (
        .CLK      (CLK),
        .nRST     (nRST),
        .coreif   (coreif),
        .axiif    (axiif),
        .bus_error(bus_error)
    );

    // ========================================================
    // Existing AXI-Lite RAM/GPIO/Timer subsystem
    // ========================================================

    axi_lite_subsystem #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .RAM_BYTES (RAM_BYTES),
        .RAM_INIT_FILE (RAM_INIT_FILE)
    ) u_subsystem (
        .ACLK   (CLK),
        .ARESETn(nRST),

        .S_AXI_AWADDR (axiif.AWADDR),
        .S_AXI_AWVALID(axiif.AWVALID),
        .S_AXI_AWREADY(axiif.AWREADY),

        .S_AXI_WDATA  (axiif.WDATA),
        .S_AXI_WSTRB  (axiif.WSTRB),
        .S_AXI_WVALID (axiif.WVALID),
        .S_AXI_WREADY (axiif.WREADY),

        .S_AXI_BRESP  (axiif.BRESP),
        .S_AXI_BVALID (axiif.BVALID),
        .S_AXI_BREADY (axiif.BREADY),

        .S_AXI_ARADDR (axiif.ARADDR),
        .S_AXI_ARVALID(axiif.ARVALID),
        .S_AXI_ARREADY(axiif.ARREADY),

        .S_AXI_RDATA  (axiif.RDATA),
        .S_AXI_RRESP  (axiif.RRESP),
        .S_AXI_RVALID (axiif.RVALID),
        .S_AXI_RREADY (axiif.RREADY),

        .gpio_i   (gpio_i),
        .gpio_o   (gpio_o),
        .gpio_oe  (gpio_oe),
        .timer_irq(timer_irq)
    );

    // ========================================================
    // Architectural and verification outputs
    // ========================================================

    assign halt                  = coreif.halt;
    assign illegal               = coreif.illegal;
    assign debug_pc              = coreif.debug_pc;
    assign debug_instruction     = coreif.debug_instruction;
    assign debug_opcode          = coreif.debug_opcode;
    assign debug_funct3          = coreif.debug_funct3;
    assign debug_funct7          = coreif.debug_funct7;
    assign debug_pipeline_enable = coreif.debug_pipeline_enable;
    assign debug_redirect        = coreif.debug_redirect;
    assign debug_bubble          = coreif.debug_bubble;
    assign debug_wb_wen          = coreif.debug_wb_wen;
    assign debug_wb_rd           = coreif.debug_wb_rd;
    assign debug_wb_data         = coreif.debug_wb_data;

endmodule
