`include "decoder_if.vh"

module rv32i_decoder_wrapper (
    input  logic [31:0] instruction,

    output logic [4:0]  rsel1,
    output logic [4:0]  rsel2,
    output logic [4:0]  wsel,

    output logic [31:0] immediate,
    output logic [3:0]  aluop,

    output logic [6:0]  opcode,
    output logic [2:0]  funct3,
    output logic [6:0]  funct7,

    output logic        WEN,

    output logic        AluSrcA,
    output logic        AluSrcB,

    output logic        MemtoReg,
    output logic        PCtoReg,

    output logic        PCsrc,
    output logic        PCj,

    output logic        dmemREN,
    output logic        dmemWEN,

    output logic        CareIfZero,
    output logic        CareIfNotZero,

    output logic        fence,
    output logic        ecall,
    output logic        ebreak,
    output logic        halt,
    output logic        sync,

    output logic        illegal
);

    import rv32i_pkg::*;

    decoder_if decif();

    // Drive the decoder interface from the wrapper input.
    always_comb begin
        decif.instruction = word_t'(instruction);
    end

    // Expose decoder-interface outputs as normal top-level ports.
    always_comb begin
        rsel1 = decif.rsel1;
        rsel2 = decif.rsel2;
        wsel  = decif.wsel;

        immediate = decif.immediate;
        aluop     = decif.aluop;

        opcode = decif.opcode;
        funct3 = decif.funct3;
        funct7 = decif.funct7;

        WEN = decif.WEN;

        AluSrcA = decif.AluSrcA;
        AluSrcB = decif.AluSrcB;

        MemtoReg = decif.MemtoReg;
        PCtoReg  = decif.PCtoReg;

        PCsrc = decif.PCsrc;
        PCj   = decif.PCj;

        dmemREN = decif.dmemREN;
        dmemWEN = decif.dmemWEN;

        CareIfZero    = decif.CareIfZero;
        CareIfNotZero = decif.CareIfNotZero;

        fence  = decif.fence;
        ecall  = decif.ecall;
        ebreak = decif.ebreak;
        halt   = decif.halt;
        sync   = decif.sync;

        illegal = decif.illegal;
    end

    rv32i_decoder dut (
        .decif(decif)
    );

endmodule
