`ifndef RV32I_CORE_IF_VH
`define RV32I_CORE_IF_VH

interface rv32i_core_if;

    import rv32i_pkg::*;

    // Instruction-memory interface

    logic  imemREN;
    word_t imemaddr;

    logic  ihit;
    word_t imemload;


    // Data-memory interface

    logic  dmemREN;
    logic  dmemWEN;
    logic  datomic;
    word_t dmemaddr;
    word_t dmemstore;
    logic [3:0] dmem_wstrb;
    logic  dhit;
    word_t dmemload;
    // Architectural status
    logic halt;
    logic illegal;
    // Verification/debug outputs
    word_t debug_pc;
    word_t debug_instruction;

    logic [6:0] debug_opcode;
    logic [2:0] debug_funct3;
    logic [6:0] debug_funct7;

    logic debug_fence;
    logic debug_ecall;
    logic debug_ebreak;

    logic debug_pipeline_enable;
    logic debug_redirect;
    logic debug_bubble;
    logic debug_alu_negative;
logic debug_alu_overflow;
    logic     debug_wb_wen;
    regbits_t debug_wb_rd;
    word_t    debug_wb_data;

    // Processor-core perspective.
    modport core (
        input  ihit,
        input  imemload,
        input  dhit,
        input  dmemload,

        output imemREN,
        output imemaddr,

        output dmemREN,
        output dmemWEN,
        output datomic,
        output dmemaddr,
        output dmemstore,
        output dmem_wstrb,

        output halt,
        output illegal,

        output debug_alu_negative,
        output debug_alu_overflow,
        output debug_pc,
        output debug_instruction,
        output debug_opcode,
        output debug_funct3,
        output debug_funct7,
        output debug_fence,
        output debug_ecall,
        output debug_ebreak,
        output debug_pipeline_enable,
        output debug_redirect,
        output debug_bubble,
        output debug_wb_wen,
        output debug_wb_rd,
        output debug_wb_data
    );

    // Memory-system perspective.
    modport memory (
        input  imemREN,
        input  imemaddr,

        input  dmemREN,
        input  dmemWEN,
        input  datomic,
        input  dmemaddr,
        input  dmemstore,
        input  dmem_wstrb,

        output ihit,
        output imemload,
        output dhit,
        output dmemload,

        input  halt,
        input  illegal
    );

    // Testbench perspective.
    modport tb (
        output ihit,
        output imemload,
        output dhit,
        output dmemload,

        input imemREN,
        input imemaddr,

        input dmemREN,
        input dmemWEN,
        input datomic,
        input dmemaddr,
        input dmemstore,
        input dmem_wstrb,

        input halt,
        input illegal,

        input debug_alu_negative,
        input debug_alu_overflow,
        input debug_pc,
        input debug_instruction,
        input debug_opcode,
        input debug_funct3,
        input debug_funct7,
        input debug_fence,
        input debug_ecall,
        input debug_ebreak,
        input debug_pipeline_enable,
        input debug_redirect,
        input debug_bubble,
        input debug_wb_wen,
        input debug_wb_rd,
        input debug_wb_data
    );

endinterface

`endif // RV32I_CORE_IF_VH
