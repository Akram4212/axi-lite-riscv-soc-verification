`include "decoder_if.vh"

module rv32i_decoder (
    decoder_if.decoder decif
);

    import rv32i_pkg::*;

    always_comb begin : IMMEDIATE_GENERATION
        decif.immediate = '0;
        unique case (decif.imm_type)
            // I-type:ADDI, loads, JALR, and immediate ALU instructions
            IMM_I: begin
                decif.immediate = {
                    {20{decif.instruction[31]}},
                    decif.instruction[31:20]
                };
            end
            // S-type:SB, SH, SW
            IMM_S: begin
                decif.immediate = {
                    {20{decif.instruction[31]}},
                    decif.instruction[31:25],
                    decif.instruction[11:7]
                };
            end
            // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
            IMM_B: begin
                decif.immediate = {
                    {19{decif.instruction[31]}},
                    decif.instruction[31],
                    decif.instruction[7],
                    decif.instruction[30:25],
                    decif.instruction[11:8],
                    1'b0
                };
            end
            // U-type:LUI, AUIPC
            IMM_U: begin
                decif.immediate = {
                    decif.instruction[31:12],
                    12'b0
                };
            end
            // J-type: JAL
            IMM_J: begin
                decif.immediate = {
                    {11{decif.instruction[31]}},
                    decif.instruction[31],
                    decif.instruction[19:12],
                    decif.instruction[20],
                    decif.instruction[30:21],
                    1'b0
                };
            end
            default: begin
                decif.immediate = '0;
            end
        endcase
    end
endmodule
