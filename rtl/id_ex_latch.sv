`include "id_ex_latch_if.vh"

module id_ex_latch (
    input logic CLK,
    input logic nRST,
    id_ex_latch_if.id_ex id_ex_if
);

    import rv32i_pkg::*;

    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST || id_ex_if.EX_flush) begin
            id_ex_if.WEN_out           <= 1'b0;
            id_ex_if.dmemREN_out       <= 1'b0;
            id_ex_if.dmemWEN_out       <= 1'b0;
            id_ex_if.halt_out          <= 1'b0;
            id_ex_if.MemtoReg_out      <= 1'b0;
            id_ex_if.PCtoReg_out       <= 1'b0;

            id_ex_if.AluSrcA_out       <= 1'b0;
            id_ex_if.AluSrcB_out       <= 1'b0;
            id_ex_if.AluCtrlOP_out     <= ALU_ADD;
            id_ex_if.CareIfZero_out    <= 1'b0;
            id_ex_if.CareIfNotZero_out <= 1'b0;
            id_ex_if.PCj_out           <= 1'b0;
            id_ex_if.PCsrc_out         <= 1'b0;

            id_ex_if.rdat1_out         <= '0;
            id_ex_if.rdat2_out         <= '0;
            id_ex_if.wsel_out          <= '0;
            id_ex_if.imemaddr_out      <= '0;
            id_ex_if.imgenload_out     <= '0;
            id_ex_if.rsel1_out         <= '0;
            id_ex_if.rsel2_out         <= '0;
            id_ex_if.funct3_out        <= '0;
            id_ex_if.Bub_ins_out       <= 1'b0;
            id_ex_if.sync_out          <= 1'b0;
        end
        else if (id_ex_if.pipeline_enable && id_ex_if.Bub_ins) begin
            // Insert a side-effect-free bubble into EX.
            id_ex_if.WEN_out           <= 1'b0;
            id_ex_if.dmemREN_out       <= 1'b0;
            id_ex_if.dmemWEN_out       <= 1'b0;
            id_ex_if.halt_out          <= 1'b0;
            id_ex_if.MemtoReg_out      <= 1'b0;
            id_ex_if.PCtoReg_out       <= 1'b0;

            id_ex_if.AluSrcA_out       <= 1'b0;
            id_ex_if.AluSrcB_out       <= 1'b0;
            id_ex_if.AluCtrlOP_out     <= ALU_ADD;
            id_ex_if.CareIfZero_out    <= 1'b0;
            id_ex_if.CareIfNotZero_out <= 1'b0;
            id_ex_if.PCj_out           <= 1'b0;
            id_ex_if.PCsrc_out         <= 1'b0;

            id_ex_if.rdat1_out         <= '0;
            id_ex_if.rdat2_out         <= '0;
            id_ex_if.wsel_out          <= '0;
            id_ex_if.imemaddr_out      <= '0;
            id_ex_if.imgenload_out     <= '0;
            id_ex_if.rsel1_out         <= '0;
            id_ex_if.rsel2_out         <= '0;
            id_ex_if.funct3_out        <= '0;
            id_ex_if.Bub_ins_out       <= 1'b1;
            id_ex_if.sync_out          <= 1'b0;
        end
        else if (id_ex_if.pipeline_enable) begin
            id_ex_if.WEN_out           <= id_ex_if.WEN;
            id_ex_if.dmemREN_out       <= id_ex_if.dmemREN;
            id_ex_if.dmemWEN_out       <= id_ex_if.dmemWEN;
            id_ex_if.halt_out          <= id_ex_if.halt;
            id_ex_if.MemtoReg_out      <= id_ex_if.MemtoReg;
            id_ex_if.PCtoReg_out       <= id_ex_if.PCtoReg;

            id_ex_if.AluSrcA_out       <= id_ex_if.AluSrcA;
            id_ex_if.AluSrcB_out       <= id_ex_if.AluSrcB;
            id_ex_if.AluCtrlOP_out     <= id_ex_if.AluCtrlOP;
            id_ex_if.CareIfZero_out    <= id_ex_if.CareIfZero;
            id_ex_if.CareIfNotZero_out <= id_ex_if.CareIfNotZero;
            id_ex_if.PCj_out           <= id_ex_if.PCj;
            id_ex_if.PCsrc_out         <= id_ex_if.PCsrc;

            id_ex_if.rdat1_out         <= id_ex_if.rdat1;
            id_ex_if.rdat2_out         <= id_ex_if.rdat2;
            id_ex_if.wsel_out          <= id_ex_if.wsel;
            id_ex_if.imemaddr_out      <= id_ex_if.imemaddr;
            id_ex_if.imgenload_out     <= id_ex_if.imgenload;
            id_ex_if.rsel1_out         <= id_ex_if.rsel1;
            id_ex_if.rsel2_out         <= id_ex_if.rsel2;
            id_ex_if.funct3_out        <= id_ex_if.funct3;
            id_ex_if.Bub_ins_out       <= 1'b0;
            id_ex_if.sync_out          <= id_ex_if.sync;
        end
    end

endmodule
