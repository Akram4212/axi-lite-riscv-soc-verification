`include "decoder_if.vh"

module rv32i_decoder_wrapper (
    input  logic [2:0]  imm_type,
    input  logic [31:0] instruction,

    output logic [31:0] immediate
);

    import rv32i_pkg::*;

    decoder_if decif();

    always_comb begin
        decif.imm_type    = imm_type_t'(imm_type);
        decif.instruction = word_t'(instruction);

        immediate = decif.immediate;
    end

    rv32i_decoder dut (
        .decif (decif)
    );

endmodule
