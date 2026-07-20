`include "decoder_if.vh"

module rv32i_decoder (
    decoder_if.decoder decif
);

    import rv32i_pkg::*;

    // Immgen helper functions

function automatic word_t sign_extend_12 (
    input logic [11:0] imm12
);
    sign_extend_12 = {
        {20{imm12[11]}},
        imm12
    };
endfunction

function automatic word_t sign_extend_13 (
    input logic [12:0] imm13
);
    sign_extend_13 = {
        {19{imm13[12]}},
        imm13
    };
endfunction


function automatic word_t generate_u_immediate (
    input logic [19:0] imm20
);
    generate_u_immediate = {
        imm20,
        12'b0
    };
endfunction

function automatic word_t sign_extend_21 (
    input logic [20:0] imm21
);
    sign_extend_21 = {
        {11{imm21[20]}},
        imm21
    };
endfunction

    // instruction decoder

    always_comb begin
        // Common instruction-field extraction
        decif.opcode = decif.instruction[6:0];
        decif.wsel   = decif.instruction[11:7];
        decif.funct3 = decif.instruction[14:12];
        decif.rsel1  = decif.instruction[19:15];
        decif.rsel2  = decif.instruction[24:20];
        decif.funct7 = decif.instruction[31:25];

        decif.immediate = '0;
        decif.aluop     = ALU_ADD;

        decif.WEN = 1'b0;

        decif.AluSrcA = 1'b0;
        decif.AluSrcB = 1'b0;

        decif.MemtoReg = 1'b0;
        decif.PCtoReg  = 1'b0;

        decif.PCsrc = 1'b0;
        decif.PCj   = 1'b0;

        decif.dmemREN = 1'b0;
        decif.dmemWEN = 1'b0;

        decif.CareIfZero    = 1'b0;
        decif.CareIfNotZero = 1'b0;

        decif.fence  = 1'b0;
        decif.ecall  = 1'b0;
        decif.ebreak = 1'b0;
        decif.halt   = 1'b0;

        // RV32A is not currently implemented.
        decif.sync = 1'b0;

        decif.illegal = 1'b0;

        // Opcode decoding

        case (decif.opcode)
            RTYPE: begin
                decif.WEN = 1'b1;
                case (decif.funct3)
                    3'b000: begin
                        case (decif.funct7)
                            7'b0000000:
                                decif.aluop = ALU_ADD;

                            7'b0100000:
                                decif.aluop = ALU_SUB;

                            default:
                                decif.illegal = 1'b1;
                        endcase
                    end
                    3'b001: begin
                        if (decif.funct7 == 7'b0000000) begin
                            decif.aluop = ALU_SLL;
                        end
                        else begin
                            decif.illegal = 1'b1;
                        end
                    end
                    3'b010: begin
                        if (decif.funct7 == 7'b0000000) begin
                            decif.aluop = ALU_SLT;
                        end
                        else begin
                            decif.illegal = 1'b1;
                        end
                    end
                    3'b011: begin
                        if (decif.funct7 == 7'b0000000) begin
                            decif.aluop = ALU_SLTU;
                        end
                        else begin
                            decif.illegal = 1'b1;
                        end
                    end
                    3'b100: begin
                        if (decif.funct7 == 7'b0000000) begin
                            decif.aluop = ALU_XOR;
                        end
                        else begin
                            decif.illegal = 1'b1;
                        end
                    end
                    3'b101: begin
                        case (decif.funct7)
                            7'b0000000:
                                decif.aluop = ALU_SRL;

                            7'b0100000:
                                decif.aluop = ALU_SRA;

                            default:
                                decif.illegal = 1'b1;
                        endcase
                    end
                    3'b110: begin
                        if (decif.funct7 == 7'b0000000) begin
                            decif.aluop = ALU_OR;
                        end
                        else begin
                            decif.illegal = 1'b1;
                        end
                    end
                    3'b111: begin
                        if (decif.funct7 == 7'b0000000) begin
                            decif.aluop = ALU_AND;
                        end
                        else begin
                            decif.illegal = 1'b1;
                        end
                    end
                    default: begin
                        decif.illegal = 1'b1;
                    end
                endcase
            end
            // Reg-imm instructions
            ITYPE: begin
                decif.WEN       = 1'b1;
                decif.AluSrcB   = 1'b1;
                decif.rsel2     = '0;
                decif.immediate =
                            sign_extend_12(
                                decif.instruction[31:20]
                            );
                case (decif.funct3)
                    3'b000:
                        decif.aluop = ALU_ADD;  // ADDI
                    3'b010:
                        decif.aluop = ALU_SLT;  // SLTI
                    3'b011:
                        decif.aluop = ALU_SLTU; // SLTIU
                    3'b100:
                        decif.aluop = ALU_XOR;  // XORI
                    3'b110:
                        decif.aluop = ALU_OR;   // ORI
                    3'b111:
                        decif.aluop = ALU_AND;  // ANDI
                    3'b001: begin
                        // SLLI
                        if (decif.funct7 == 7'b0000000) begin
                            decif.aluop = ALU_SLL;
                        end
                        else begin
                            decif.illegal = 1'b1;
                        end
                    end
                    3'b101: begin
                        // SRLI or SRAI
                        case (decif.funct7)
                            7'b0000000:
                                decif.aluop = ALU_SRL;

                            7'b0100000:
                                decif.aluop = ALU_SRA;

                            default:
                                decif.illegal = 1'b1;
                        endcase
                    end

                    default: begin
                        decif.illegal = 1'b1;
                    end

                endcase
            end

            // Load instructions
            ITYPE_LW: begin
                decif.rsel2     = '0;
                decif.WEN       = 1'b1;
                decif.AluSrcB   = 1'b1;
                decif.MemtoReg  = 1'b1;
                decif.dmemREN   = 1'b1;
                decif.aluop     = ALU_ADD;
                decif.immediate = sign_extend_12(decif.instruction[31:20]);
                case (decif.funct3)
                    3'b000, // LB
                    3'b001, // LH
                    3'b010, // LW
                    3'b100, // LBU
                    3'b101: // LHU
                        decif.illegal = 1'b0;
                    default:
                        decif.illegal = 1'b1;
                endcase
            end
            // Store instructions
            STYPE: begin
                decif.wsel      = '0;
                decif.AluSrcB   = 1'b1;
                decif.dmemWEN   = 1'b1;
                decif.aluop     = ALU_ADD;
                decif.immediate = sign_extend_12({
                    decif.instruction[31:25],
                    decif.instruction[11:7]
                });
                case (decif.funct3)
                    3'b000, // SB
                    3'b001, // SH
                    3'b010: // SW
                        decif.illegal = 1'b0;
                    default:
                        decif.illegal = 1'b1;
                endcase
            end
            // Conditional branches
            BTYPE: begin
                decif.wsel      = '0;
                decif.immediate = sign_extend_13({
                    decif.instruction[31],
                    decif.instruction[7],
                    decif.instruction[30:25],
                    decif.instruction[11:8],
                    1'b0
                });
                case (decif.funct3)
                    3'b000: begin // BEQ
                        decif.aluop      = ALU_SUB;
                        decif.CareIfZero = 1'b1;
                    end
                    3'b001: begin // BNE
                        decif.aluop         = ALU_SUB;
                        decif.CareIfNotZero = 1'b1;
                    end
                    3'b100: begin // BLT
                        decif.aluop         = ALU_SLT;
                        decif.CareIfNotZero = 1'b1;
                    end
                    3'b101: begin // BGE
                        decif.aluop      = ALU_SLT;
                        decif.CareIfZero = 1'b1;
                    end
                    3'b110: begin // BLTU
                        decif.aluop         = ALU_SLTU;
                        decif.CareIfNotZero = 1'b1;
                    end
                    3'b111: begin // BGEU
                        decif.aluop      = ALU_SLTU;
                        decif.CareIfZero = 1'b1;
                    end
                    default: begin
                        decif.illegal = 1'b1;
                    end
                endcase
            end
            // JAL
            JAL: begin
                decif.rsel1     = '0;
                decif.rsel2     = '0;
                decif.WEN       = 1'b1;
                decif.PCtoReg   = 1'b1;
                decif.PCsrc     = 1'b1;
                decif.immediate = sign_extend_21({
                    decif.instruction[31],
                    decif.instruction[19:12],
                    decif.instruction[20],
                    decif.instruction[30:21],
                    1'b0
                });
            end
            // JALR
            JALR: begin
                decif.rsel2     = '0;
                decif.WEN       = 1'b1;
                decif.AluSrcB   = 1'b1;
                decif.PCtoReg   = 1'b1;
                decif.PCj       = 1'b1;
                decif.aluop     = ALU_ADD;
                decif.immediate = sign_extend_12(
                    decif.instruction[31:20]
                );
                if (decif.funct3 != 3'b000) begin
                    decif.illegal = 1'b1;
                end
            end
            // LUI
            LUI: begin
                decif.rsel1     = '0;
                decif.rsel2     = '0;
                decif.WEN       = 1'b1;
                decif.AluSrcB   = 1'b1;
                decif.aluop     = ALU_ADD;
                decif.immediate = generate_u_immediate(
                    decif.instruction[31:12]
                );
            end
            // AUIPC
            AUIPC: begin
                decif.rsel1     = '0;
                decif.rsel2     = '0;
                decif.WEN       = 1'b1;
                decif.AluSrcA   = 1'b1;
                decif.AluSrcB   = 1'b1;
                decif.aluop     = ALU_ADD;
                decif.immediate = generate_u_immediate(
                    decif.instruction[31:12]
                );
            end
            // FENCE
            OPCODE_MISC_MEM: begin
                decif.rsel1 = '0;
                decif.rsel2 = '0;
                decif.wsel  = '0;

                if (decif.funct3 == 3'b000) begin
                    decif.fence = 1'b1;
                end
                else begin
                    decif.illegal = 1'b1;
                end
            end
            // ECALL / EBREAK
            OPCODE_SYSTEM: begin
                decif.rsel1 = '0;
                decif.rsel2 = '0;
                decif.wsel  = '0;
                case (decif.instruction)
                    32'h0000_0073: begin
                        decif.ecall = 1'b1;
                    end
                    32'h0010_0073: begin
                        decif.ebreak = 1'b1;
                        decif.halt   = 1'b1;
                    end
                    default: begin
                        // CSR instructions are not implemented yet.
                        decif.illegal = 1'b1;
                    end
                endcase
            end
            // Unknown opcode
            default: begin
                decif.illegal = 1'b1;
            end
        endcase
        // Illegal instructions must never cause side effects.
        if (decif.illegal) begin
            decif.WEN = 1'b0;

            decif.dmemREN = 1'b0;
            decif.dmemWEN = 1'b0;

            decif.PCsrc = 1'b0;
            decif.PCj   = 1'b0;

            decif.CareIfZero    = 1'b0;
            decif.CareIfNotZero = 1'b0;

            decif.fence  = 1'b0;
            decif.ecall  = 1'b0;
            decif.ebreak = 1'b0;
            decif.halt   = 1'b0;
        end

    end

endmodule
