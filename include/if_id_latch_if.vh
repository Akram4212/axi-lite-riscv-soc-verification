`ifndef IF_ID_LATCH_IF_VH
`define IF_ID_LATCH_IF_VH

interface if_id_latch_if;
    import rv32i_pkg::*;

    word_t imemload;
    word_t imemload_out;

    word_t imemaddr;
    word_t imemaddr_out;

    logic DC_flush;
    logic DCD_freeze;
    logic pipeline_enable;

    modport if_id (
        input  imemload,
        input  imemaddr,
        input  DC_flush,
        input  DCD_freeze,
        input  pipeline_enable,

        output imemload_out,
        output imemaddr_out
    );

    modport core (
        output imemload,
        output imemaddr,
        output DC_flush,
        output DCD_freeze,
        output pipeline_enable,

        input  imemload_out,
        input  imemaddr_out
    );

endinterface

`endif // IF_ID_LATCH_IF_VH
