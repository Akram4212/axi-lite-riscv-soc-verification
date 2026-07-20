`ifndef MEM_WB_LATCH_IF_VH
`define MEM_WB_LATCH_IF_VH

interface mem_wb_latch_if;
    import rv32i_pkg::*;

    logic MemtoReg;
    logic MemtoReg_out;

    logic PCtoReg;
    logic PCtoReg_out;

    logic WEN;
    logic WEN_out;

    logic halt;
    logic halt_out;

    word_t imemaddr;
    word_t imemaddr_out;

    word_t output_port;
    word_t output_port_out;

    word_t dmemload;
    word_t dmemload_out;

    regbits_t wsel;
    regbits_t wsel_out;

    logic pipeline_enable;

    modport mem_wb (
        input MemtoReg,
        input PCtoReg,
        input WEN,
        input halt,
        input imemaddr,
        input dmemload,
        input output_port,
        input wsel,
        input pipeline_enable,

        output MemtoReg_out,
        output PCtoReg_out,
        output WEN_out,
        output halt_out,
        output imemaddr_out,
        output dmemload_out,
        output output_port_out,
        output wsel_out
    );

    modport core (
        output MemtoReg,
        output PCtoReg,
        output WEN,
        output halt,
        output imemaddr,
        output dmemload,
        output output_port,
        output wsel,
        output pipeline_enable,

        input MemtoReg_out,
        input PCtoReg_out,
        input WEN_out,
        input halt_out,
        input imemaddr_out,
        input dmemload_out,
        input output_port_out,
        input wsel_out
    );

endinterface

`endif // MEM_WB_LATCH_IF_VH
