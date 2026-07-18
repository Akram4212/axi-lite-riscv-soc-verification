`include "rv32i_core_if.vh"

module rv32i_core_wrapper #(
    parameter logic [31:0] PC_INIT = 32'h0000_0000
) (
    input  logic        CLK,
    input  logic        nRST,

    // Instruction-memory response
    input  logic        ihit,
    input  logic [31:0] imemload,

    // Data-memory response
    input  logic        dhit,
    input  logic [31:0] dmemload,

    // Instruction-memory request
    output logic        imemREN,
    output logic [31:0] imemaddr,

    // Data-memory request
    output logic        dmemREN,
    output logic        dmemWEN,
    output logic        datomic,
    output logic [31:0] dmemaddr,
    output logic [31:0] dmemstore,
    output logic [3:0]  dmem_wstrb,

    // Architectural status
    output logic        halt,
    output logic        illegal,

    // Debug outputs
    output logic [31:0] debug_pc,
    output logic [31:0] debug_instruction,
    output logic [6:0]  debug_opcode,
    output logic [2:0]  debug_funct3,
    output logic [6:0]  debug_funct7,

    output logic        debug_fence,
    output logic        debug_ecall,
    output logic        debug_ebreak,


    output logic        debug_pipeline_enable,
    output logic        debug_redirect,
    output logic        debug_bubble,

    output logic debug_alu_negative,
    output logic debug_alu_overflow,

    output logic        debug_wb_wen,
    output logic [4:0]  debug_wb_rd,
    output logic [31:0] debug_wb_data
);

    import rv32i_pkg::*;

    rv32i_core_if coreif();

    // Drive core inputs.
    always_comb begin
        coreif.ihit     = ihit;
        coreif.imemload = word_t'(imemload);

        coreif.dhit     = dhit;
        coreif.dmemload = word_t'(dmemload);
    end

    // Expose core outputs.
    always_comb begin
        imemREN  = coreif.imemREN;
        imemaddr = coreif.imemaddr;

        dmemREN    = coreif.dmemREN;
        dmemWEN    = coreif.dmemWEN;
        datomic    = coreif.datomic;
        dmemaddr   = coreif.dmemaddr;
        dmemstore  = coreif.dmemstore;
        dmem_wstrb = coreif.dmem_wstrb;

        halt    = coreif.halt;
        illegal = coreif.illegal;

        debug_pc              = coreif.debug_pc;
        debug_instruction     = coreif.debug_instruction;
        debug_opcode          = coreif.debug_opcode;
        debug_funct3          = coreif.debug_funct3;
        debug_funct7          = coreif.debug_funct7;
        debug_fence           = coreif.debug_fence;
        debug_ecall           = coreif.debug_ecall;
        debug_ebreak          = coreif.debug_ebreak;
        debug_pipeline_enable = coreif.debug_pipeline_enable;
        debug_alu_negative =
            coreif.debug_alu_negative;

        debug_alu_overflow =
            coreif.debug_alu_overflow;
        
        debug_redirect        = coreif.debug_redirect;
        debug_bubble          = coreif.debug_bubble;
        debug_wb_wen          = coreif.debug_wb_wen;
        debug_wb_rd           = coreif.debug_wb_rd;
        debug_wb_data         = coreif.debug_wb_data;
    end

    rv32i_core #(
        .PC_INIT(PC_INIT)
    ) dut (
        .CLK   (CLK),
        .nRST  (nRST),
        .coreif(coreif)
    );

endmodule
