`include "alu_if.vh"

module rv32i_alu (
    alu_if.alusource aluif
);

    import rv32i_pkg::*;

    always_comb begin : OPCODE_ARITHMETIC

        aluif.output_port = '0;
        aluif.zero        = 1'b0;
        aluif.negative    = 1'b0;
        aluif.overflow    = 1'b0;

        case (aluif.aluop)

            ALU_ADD: begin
                aluif.output_port =
                    aluif.portA + aluif.portB;

                aluif.overflow =
                    (aluif.portA[31] == aluif.portB[31]) &&
                    (aluif.output_port[31] != aluif.portA[31]);
            end

            ALU_SUB: begin
                aluif.output_port =
                    aluif.portA - aluif.portB;

                aluif.overflow =
                    (aluif.portA[31] != aluif.portB[31]) &&
                    (aluif.output_port[31] != aluif.portA[31]);
            end

            ALU_SLL: begin
                aluif.output_port =
                    aluif.portA << aluif.portB[4:0];

                if (aluif.portB[4:0] != 5'd0) begin
                    aluif.overflow =
                        |(
                            aluif.portA >>
                            (
                                6'd32 -
                                {1'b0, aluif.portB[4:0]}
                            )
                        );
                end
            end

            ALU_SRL: begin
                aluif.output_port =
                    aluif.portA >> aluif.portB[4:0];
            end

            ALU_SRA: begin
                aluif.output_port =
                    $signed(aluif.portA) >>>
                    aluif.portB[4:0];
            end

            ALU_AND: begin
                aluif.output_port =
                    aluif.portA & aluif.portB;
            end

            ALU_OR: begin
                aluif.output_port =
                    aluif.portA | aluif.portB;
            end

            ALU_XOR: begin
                aluif.output_port =
                    aluif.portA ^ aluif.portB;
            end

            ALU_SLT: begin
                aluif.output_port = {
                    31'b0,
                    $signed(aluif.portA) <
                    $signed(aluif.portB)
                };
            end

            ALU_SLTU: begin
                aluif.output_port = {
                    31'b0,
                    aluif.portA < aluif.portB
                };
            end

            default: begin
                aluif.output_port = '0;
            end

        endcase

        aluif.zero =
            (aluif.output_port == '0);

        aluif.negative =
            aluif.output_port[31];

    end

endmodule
