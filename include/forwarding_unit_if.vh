`ifndef FORWARDING_UNIT_IF_VH
`define FORWARDING_UNIT_IF_VH

interface forwarding_unit_if;
    import rv32i_pkg::*;

    regbits_t EX_rsel1;
    regbits_t EX_rsel2;
    regbits_t MEM_wsel;
    regbits_t WB_wsel;

    logic MEM_WEN;
    logic WB_WEN;
    logic MEM_MemtoReg;

    logic MEM_ForwardA;
    logic MEM_ForwardB;
    logic WB_ForwardA;
    logic WB_ForwardB;

    modport fu (
        input EX_rsel1,
        input EX_rsel2,
        input MEM_WEN,
        input MEM_wsel,
        input WB_WEN,
        input WB_wsel,
        input MEM_MemtoReg,

        output MEM_ForwardA,
        output MEM_ForwardB,
        output WB_ForwardA,
        output WB_ForwardB
    );

    modport core (
        output EX_rsel1,
        output EX_rsel2,
        output MEM_WEN,
        output MEM_wsel,
        output WB_WEN,
        output WB_wsel,
        output MEM_MemtoReg,

        input MEM_ForwardA,
        input MEM_ForwardB,
        input WB_ForwardA,
        input WB_ForwardB
    );

endinterface

`endif // FORWARDING_UNIT_IF_VH
