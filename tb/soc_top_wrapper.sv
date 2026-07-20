module soc_top_wrapper (
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

    soc_top #(
        .PC_INIT      (32'h0000_0000),
        .RAM_BYTES    (4096),
        .RAM_INIT_FILE("firmware/selected.hex")
    ) dut (
        .CLK                  (CLK),
        .nRST                 (nRST),

        .gpio_i               (gpio_i),
        .gpio_o               (gpio_o),
        .gpio_oe              (gpio_oe),

        .timer_irq            (timer_irq),
        .halt                 (halt),
        .illegal              (illegal),
        .bus_error            (bus_error),

        .debug_pc             (debug_pc),
        .debug_instruction    (debug_instruction),
        .debug_opcode         (debug_opcode),
        .debug_funct3         (debug_funct3),
        .debug_funct7         (debug_funct7),
        .debug_pipeline_enable(debug_pipeline_enable),
        .debug_redirect       (debug_redirect),
        .debug_bubble         (debug_bubble),
        .debug_wb_wen         (debug_wb_wen),
        .debug_wb_rd          (debug_wb_rd),
        .debug_wb_data        (debug_wb_data)
    );

endmodule
