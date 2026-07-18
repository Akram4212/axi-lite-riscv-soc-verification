`ifndef PC_IF_VH
`define PC_IF_VH

interface pc_if;
    import rv32i_pkg::*;

    logic  PC_Update;
    logic  PC_IF_freeze;
    word_t NextPCValue;
    word_t imemaddr;

    modport pc (
        input  PC_Update,
        input  PC_IF_freeze,
        input  NextPCValue,
        output imemaddr
    );

    modport core (
        output PC_Update,
        output PC_IF_freeze,
        output NextPCValue,
        input  imemaddr
    );

    modport tb (
        output PC_Update,
        output PC_IF_freeze,
        output NextPCValue,
        input  imemaddr
    );

endinterface

`endif // PC_IF_VH
