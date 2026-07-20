`include "pc_if.vh"

module rv32i_pc #(
    parameter logic [31:0] PC_INIT = 32'h0000_0000
) (
    input  logic CLK,
    input  logic nRST,
    pc_if.pc pcif
);

    import rv32i_pkg::*;

    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            pcif.imemaddr <= word_t'(PC_INIT);
        end
        else if (pcif.PC_Update && !pcif.PC_IF_freeze) begin
            pcif.imemaddr <= pcif.NextPCValue;
        end
    end

endmodule
