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
        .PC_INIT  (32'h0000_0000),
        .RAM_BYTES(4096)
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

    // ========================================================
    // Test-only firmware preload
    //
    // Program:
    //   GPIO direction[3:0] = output
    //   GPIO output[3:0]    = 0x5
    //   Timer compare       = 10
    //   Timer enable/IRQ    = enabled
    //   Poll timer MATCH
    //   EBREAK
    //
    // The existing AXI-Lite RAM array is:
    //   dut.u_subsystem.u_axi_lite_ram.mem
    // ========================================================

    integer word_index;

    initial begin
        for (word_index = 0; word_index < 1024;
             word_index = word_index + 1) begin
            dut.u_subsystem.u_axi_lite_ram.mem[word_index] =
                32'h0000_0013; // NOP
        end

        dut.u_subsystem.u_axi_lite_ram.mem[0]  =
            32'h1000_02B7; // lui   t0, 0x10000
        dut.u_subsystem.u_axi_lite_ram.mem[1]  =
            32'h00F0_0313; // addi  t1, zero, 15
        dut.u_subsystem.u_axi_lite_ram.mem[2]  =
            32'h0062_A423; // sw    t1, 8(t0)
        dut.u_subsystem.u_axi_lite_ram.mem[3]  =
            32'h0050_0393; // addi  t2, zero, 5
        dut.u_subsystem.u_axi_lite_ram.mem[4]  =
            32'h0072_A023; // sw    t2, 0(t0)

        dut.u_subsystem.u_axi_lite_ram.mem[5]  =
            32'h1000_1E37; // lui   t3, 0x10001
        dut.u_subsystem.u_axi_lite_ram.mem[6]  =
            32'h00A0_0E93; // addi  t4, zero, 10
        dut.u_subsystem.u_axi_lite_ram.mem[7]  =
            32'h01DE_2423; // sw    t4, 8(t3)
        dut.u_subsystem.u_axi_lite_ram.mem[8]  =
            32'h0050_0F13; // addi  t5, zero, 5
        dut.u_subsystem.u_axi_lite_ram.mem[9]  =
            32'h01EE_2023; // sw    t5, 0(t3)

        dut.u_subsystem.u_axi_lite_ram.mem[10] =
            32'h00CE_2F83; // lw    t6, 12(t3)
        dut.u_subsystem.u_axi_lite_ram.mem[11] =
            32'h001F_FF93; // andi  t6, t6, 1
        dut.u_subsystem.u_axi_lite_ram.mem[12] =
            32'hFE0F_8CE3; // beq   t6, zero, -8
        dut.u_subsystem.u_axi_lite_ram.mem[13] =
            32'h0010_0073; // ebreak
    end

endmodule
