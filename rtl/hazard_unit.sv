`include "hazard_unit_if.vh"

module hazard_unit (
    hazard_unit_if.hu hdif
);

    import rv32i_pkg::*;

    logic load_use_hazard;

    always_comb begin
        load_use_hazard =
            hdif.MemtoReg &&
            (hdif.wsel_out != regbits_t'(5'd0)) &&
            (
                (hdif.wsel_out == hdif.rsel1) ||
                (hdif.wsel_out == hdif.rsel2)
            );

        hdif.DCD_freeze  = 1'b0;
        hdif.PC_IF_freeze = 1'b0;
        hdif.Bub_ins     = 1'b0;

        hdif.EX_flush    = 1'b0;
        hdif.DC_flush    = 1'b0;
        hdif.MEM_flush   = 1'b0;

        // A resolved branch or jump has priority over a load-use stall.
        if (hdif.redirect) begin
            hdif.EX_flush  = 1'b1;
            hdif.DC_flush  = 1'b1;
            hdif.MEM_flush = 1'b1;
        end
        else if (load_use_hazard) begin
            hdif.DCD_freeze   = 1'b1;
            hdif.PC_IF_freeze = 1'b1;
            hdif.Bub_ins      = 1'b1;
        end
    end

endmodule
