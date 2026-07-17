`ifndef REGFILE_IF_VH
`define REGFILE_IF_VH

interface regfile_if;

    import rv32i_pkg::*;

    logic     WEN;
    regbits_t wsel;
    regbits_t rsel1;
    regbits_t rsel2;

    word_t wdat;
    word_t rdat1;
    word_t rdat2;

    // Register-file RTL perspective
    modport rf (
        input  WEN,
        input  wsel,
        input  rsel1,
        input  rsel2,
        input  wdat,

        output rdat1,
        output rdat2
    );

    // Testbench / wrapper perspective
    modport tb (
        output WEN,
        output wsel,
        output rsel1,
        output rsel2,
        output wdat,

        input  rdat1,
        input  rdat2
    );

endinterface

`endif // REGFILE_IF_VH
