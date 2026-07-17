`ifndef DECODER_IF_VH
`define DECODER_IF_VH

interface decoder_if;

    import rv32i_pkg::*;

    imm_type_t imm_type;
    word_t     instruction;
    word_t     immediate;

    modport decoder (
        input  imm_type,
        input  instruction,
        output immediate
    );

    modport tb (
        output imm_type,
        output instruction,
        input  immediate
    );

endinterface

`endif // DECODER_IF_VH
