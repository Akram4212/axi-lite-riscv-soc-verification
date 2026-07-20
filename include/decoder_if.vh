`ifndef DECODER_IF_VH
`define DECODER_IF_VH

interface decoder_if;

    import rv32i_pkg::*;

    // Complete instruction received from instruction memory
    word_t instruction;

    // Extracted register selectors
    regbits_t rsel1;
    regbits_t rsel2;
    regbits_t wsel;

    // Generated immediate
    word_t immediate;

    // Final ALU operation
    aluop_t aluop;

    // Instruction fields useful to memory/control logic
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    // Register-file control
    logic WEN;

    // ALU operand selection
    // AluSrcA:
    //   0 = register rdat1
    //   1 = program counter
    //
    // AluSrcB:
    //   0 = register rdat2
    //   1 = immediate
    logic AluSrcA;
    logic AluSrcB;

    // Writeback selection
    logic MemtoReg;
    logic PCtoReg;

    // Program-counter control
    logic PCsrc;
    logic PCj;

    // Memory request controls
    logic dmemREN;
    logic dmemWEN;

    // Branch decision controls
    logic CareIfZero;
    logic CareIfNotZero;

    // System controls
    logic fence;
    logic ecall;
    logic ebreak;
    logic halt;

    // Reserved for future RV32A LR/SC support
    logic sync;

    // Invalid or unsupported instruction
    logic illegal;

    modport decoder (
        input  instruction,

        output rsel1,
        output rsel2,
        output wsel,
        output immediate,
        output aluop,
        output opcode,
        output funct3,
        output funct7,
        output WEN,
        output AluSrcA,
        output AluSrcB,
        output MemtoReg,
        output PCtoReg,
        output PCsrc,
        output PCj,
        output dmemREN,
        output dmemWEN,
        output CareIfZero,
        output CareIfNotZero,
        output fence,
        output ecall,
        output ebreak,
        output halt,
        output sync,
        output illegal
    );

    modport tb (
        output instruction,

        input rsel1,
        input rsel2,
        input wsel,
        input immediate,
        input aluop,
        input opcode,
        input funct3,
        input funct7,
        input WEN,
        input AluSrcA,
        input AluSrcB,
        input MemtoReg,
        input PCtoReg,
        input PCsrc,
        input PCj,
        input dmemREN,
        input dmemWEN,
        input CareIfZero,
        input CareIfNotZero,
        input fence,
        input ecall,
        input ebreak,
        input halt,
        input sync,
        input illegal
    );

endinterface

`endif // DECODER_IF_VH
