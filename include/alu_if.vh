`ifndef ALU_IF_VH
`define ALU_IF_VH

interface alu_if;

    import rv32i_pkg::*;

    logic negative;
    logic overflow;
    logic zero;

    aluop_t aluop;

    word_t portA;
    word_t portB;
    word_t output_port;

    modport alusource (
        input  portA,
        input  portB,
        input  aluop,

        output output_port,
        output negative,
        output overflow,
        output zero
    );

    modport tb (
        output portA,
        output portB,
        output aluop,

        input  output_port,
        input  negative,
        input  overflow,
        input  zero
    );

endinterface

`endif
