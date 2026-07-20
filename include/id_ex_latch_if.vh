`ifndef ID_EX_LATCH_IF_VH
`define ID_EX_LATCH_IF_VH

interface id_ex_latch_if;
    import rv32i_pkg::*;

    // Data entering and leaving the ID/EX stage.
    word_t imemaddr;
    word_t imemaddr_out;

    word_t imgenload;
    word_t imgenload_out;

    word_t rdat1;
    word_t rdat1_out;

    word_t rdat2;
    word_t rdat2_out;

    regbits_t rsel1;
    regbits_t rsel1_out;

    regbits_t rsel2;
    regbits_t rsel2_out;

    regbits_t wsel;
    regbits_t wsel_out;

    logic [2:0] funct3;
    logic [2:0] funct3_out;

    // Control entering and leaving the ID/EX stage.
    aluop_t AluCtrlOP;
    aluop_t AluCtrlOP_out;

    logic WEN;
    logic WEN_out;

    logic AluSrcA;
    logic AluSrcA_out;

    logic AluSrcB;
    logic AluSrcB_out;

    logic CareIfZero;
    logic CareIfZero_out;

    logic CareIfNotZero;
    logic CareIfNotZero_out;

    logic dmemREN;
    logic dmemREN_out;

    logic dmemWEN;
    logic dmemWEN_out;

    logic PCj;
    logic PCj_out;

    logic PCsrc;
    logic PCsrc_out;

    logic MemtoReg;
    logic MemtoReg_out;

    logic PCtoReg;
    logic PCtoReg_out;

    logic halt;
    logic halt_out;

    logic sync;
    logic sync_out;

    // Pipeline control.
    logic EX_flush;
    logic Bub_ins;
    logic Bub_ins_out;
    logic pipeline_enable;

    modport id_ex (
        input WEN,
        input wsel,
        input rdat1,
        input rdat2,
        input AluSrcA,
        input AluSrcB,
        input CareIfZero,
        input CareIfNotZero,
        input dmemREN,
        input dmemWEN,
        input PCj,
        input AluCtrlOP,
        input PCsrc,
        input MemtoReg,
        input PCtoReg,
        input imemaddr,
        input imgenload,
        input halt,
        input rsel1,
        input rsel2,
        input funct3,
        input EX_flush,
        input Bub_ins,
        input pipeline_enable,
        input sync,

        output WEN_out,
        output wsel_out,
        output rdat1_out,
        output rdat2_out,
        output AluSrcA_out,
        output AluSrcB_out,
        output CareIfZero_out,
        output CareIfNotZero_out,
        output dmemREN_out,
        output dmemWEN_out,
        output PCj_out,
        output PCsrc_out,
        output AluCtrlOP_out,
        output MemtoReg_out,
        output PCtoReg_out,
        output imemaddr_out,
        output imgenload_out,
        output halt_out,
        output rsel1_out,
        output rsel2_out,
        output funct3_out,
        output Bub_ins_out,
        output sync_out
    );

    modport core (
        output WEN,
        output wsel,
        output rdat1,
        output rdat2,
        output AluSrcA,
        output AluSrcB,
        output CareIfZero,
        output CareIfNotZero,
        output dmemREN,
        output dmemWEN,
        output PCj,
        output AluCtrlOP,
        output PCsrc,
        output MemtoReg,
        output PCtoReg,
        output imemaddr,
        output imgenload,
        output halt,
        output rsel1,
        output rsel2,
        output funct3,
        output EX_flush,
        output Bub_ins,
        output pipeline_enable,
        output sync,

        input WEN_out,
        input wsel_out,
        input rdat1_out,
        input rdat2_out,
        input AluSrcA_out,
        input AluSrcB_out,
        input CareIfZero_out,
        input CareIfNotZero_out,
        input dmemREN_out,
        input dmemWEN_out,
        input PCj_out,
        input PCsrc_out,
        input AluCtrlOP_out,
        input MemtoReg_out,
        input PCtoReg_out,
        input imemaddr_out,
        input imgenload_out,
        input halt_out,
        input rsel1_out,
        input rsel2_out,
        input funct3_out,
        input Bub_ins_out,
        input sync_out
    );

endinterface

`endif // ID_EX_LATCH_IF_VH
