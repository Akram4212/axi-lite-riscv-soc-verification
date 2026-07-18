`ifndef HAZARD_UNIT_IF_VH
`define HAZARD_UNIT_IF_VH

interface hazard_unit_if;
    import rv32i_pkg::*;

    regbits_t rsel1;
    regbits_t rsel2;
    regbits_t wsel_out;

    logic MemtoReg;
    logic redirect;

    logic Bub_ins;
    logic DCD_freeze;
    logic PC_IF_freeze;
    logic EX_flush;
    logic DC_flush;
    logic MEM_flush;

    modport hu (
        input rsel1,
        input rsel2,
        input wsel_out,
        input MemtoReg,
        input redirect,

        output Bub_ins,
        output DCD_freeze,
        output PC_IF_freeze,
        output EX_flush,
        output DC_flush,
        output MEM_flush
    );

    modport core (
        output rsel1,
        output rsel2,
        output wsel_out,
        output MemtoReg,
        output redirect,

        input Bub_ins,
        input DCD_freeze,
        input PC_IF_freeze,
        input EX_flush,
        input DC_flush,
        input MEM_flush
    );

endinterface

`endif // HAZARD_UNIT_IF_VH
