`include "if_id_latch_if.vh"

module if_id_latch (
    input logic CLK,
    input logic nRST,
    if_id_latch_if.if_id if_id_if
);

    import rv32i_pkg::*;

    localparam word_t RV32I_NOP = 32'h0000_0013;

    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            if_id_if.imemload_out <= RV32I_NOP;
            if_id_if.imemaddr_out <= '0;
        end
        else if (if_id_if.DC_flush) begin
            if_id_if.imemload_out <= RV32I_NOP;
            if_id_if.imemaddr_out <= '0;
        end
        else if (if_id_if.pipeline_enable && !if_id_if.DCD_freeze) begin
            if_id_if.imemload_out <= if_id_if.imemload;
            if_id_if.imemaddr_out <= if_id_if.imemaddr;
        end
    end

endmodule
