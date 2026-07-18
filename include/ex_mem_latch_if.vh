`ifndef EX_MEM_LATCH_IF_VH
`define EX_MEM_LATCH_IF_VH

interface ex_mem_latch_if;
    import rv32i_pkg::*;

    // Control signals.
    logic dmemREN;
    logic dmemREN_out;

    logic dmemWEN;
    logic dmemWEN_out;

    logic halt;
    logic halt_out;

    logic MemtoReg;
    logic MemtoReg_out;

    logic PCtoReg;
    logic PCtoReg_out;

    logic PCsrc;
    logic PCsrc_out;

    logic WEN;
    logic WEN_out;

    logic Zero;
    logic Zero_out;

    logic CareIfNotZero;
    logic CareIfNotZero_out;

    logic CareIfZero;
    logic CareIfZero_out;

    logic PCj;
    logic PCj_out;

    logic sync;
    logic sync_out;

    // Data signals.
    word_t imemaddr;
    word_t imemaddr_out;

    word_t output_port;
    word_t output_port_out;

    word_t rdat2;
    word_t rdat2_out;

    word_t imgenload;
    word_t imgenload_out;

    regbits_t wsel;
    regbits_t wsel_out;

    logic [2:0] funct3;
    logic [2:0] funct3_out;

    // Pipeline control.
    logic MEM_flush;
    logic Bub_ins;
    logic Bub_ins_out;
    logic pipeline_enable;

    modport ex_mem (
        input halt,
        input Zero,
        input CareIfNotZero,
        input CareIfZero,
        input PCj,
        input MEM_flush,
        input dmemREN,
        input dmemWEN,
        input MemtoReg,
        input PCtoReg,
        input WEN,
        input output_port,
        input PCsrc,
        input rdat2,
        input imemaddr,
        input wsel,
        input imgenload,
        input funct3,
        input Bub_ins,
        input pipeline_enable,
        input sync,

        output halt_out,
        output Zero_out,
        output CareIfNotZero_out,
        output CareIfZero_out,
        output PCj_out,
        output dmemREN_out,
        output dmemWEN_out,
        output MemtoReg_out,
        output PCtoReg_out,
        output WEN_out,
        output output_port_out,
        output PCsrc_out,
        output rdat2_out,
        output imemaddr_out,
        output wsel_out,
        output imgenload_out,
        output funct3_out,
        output Bub_ins_out,
        output sync_out
    );

    modport core (
        output halt,
        output Zero,
        output CareIfNotZero,
        output CareIfZero,
        output PCj,
        output MEM_flush,
        output dmemREN,
        output dmemWEN,
        output MemtoReg,
        output PCtoReg,
        output WEN,
        output output_port,
        output PCsrc,
        output rdat2,
        output imemaddr,
        output wsel,
        output imgenload,
        output funct3,
        output Bub_ins,
        output pipeline_enable,
        output sync,

        input halt_out,
        input Zero_out,
        input CareIfNotZero_out,
        input CareIfZero_out,
        input PCj_out,
        input dmemREN_out,
        input dmemWEN_out,
        input MemtoReg_out,
        input PCtoReg_out,
        input WEN_out,
        input output_port_out,
        input PCsrc_out,
        input rdat2_out,
        input imemaddr_out,
        input wsel_out,
        input imgenload_out,
        input funct3_out,
        input Bub_ins_out,
        input sync_out
    );

endinterface

`endif // EX_MEM_LATCH_IF_VH

