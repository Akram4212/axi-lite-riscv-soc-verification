`include "forwarding_unit_if.vh"

module forwarding_unit (
    forwarding_unit_if.fu fuif
);

    import rv32i_pkg::*;

    logic mem_match_a;
    logic mem_match_b;
    logic wb_match_a;
    logic wb_match_b;

    always_comb begin
        mem_match_a =
            (fuif.MEM_wsel != regbits_t'(5'd0)) &&
            (fuif.EX_rsel1 == fuif.MEM_wsel);

        mem_match_b =
            (fuif.MEM_wsel != regbits_t'(5'd0)) &&
            (fuif.EX_rsel2 == fuif.MEM_wsel);

        wb_match_a =
            (fuif.WB_wsel != regbits_t'(5'd0)) &&
            (fuif.EX_rsel1 == fuif.WB_wsel);

        wb_match_b =
            (fuif.WB_wsel != regbits_t'(5'd0)) &&
            (fuif.EX_rsel2 == fuif.WB_wsel);

        // A load result is not available early enough for MEM-to-EX
        // forwarding. The load-use hazard unit inserts the needed bubble.
        fuif.MEM_ForwardA =
            fuif.MEM_WEN &&
            !fuif.MEM_MemtoReg &&
            mem_match_a;

        fuif.MEM_ForwardB =
            fuif.MEM_WEN &&
            !fuif.MEM_MemtoReg &&
            mem_match_b;

        // Give MEM forwarding priority when both stages target the same
        // source register.
        fuif.WB_ForwardA =
            fuif.WB_WEN &&
            wb_match_a &&
            !fuif.MEM_ForwardA;

        fuif.WB_ForwardB =
            fuif.WB_WEN &&
            wb_match_b &&
            !fuif.MEM_ForwardB;
    end

endmodule
