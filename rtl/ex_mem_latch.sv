`include "ex_mem_latch_if.vh"

module ex_mem_latch (
    input logic CLK,
    input logic nRST,
    ex_mem_latch_if.ex_mem ex_mem_if
);

    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST || ex_mem_if.MEM_flush) begin
            ex_mem_if.halt_out          <= 1'b0;
            ex_mem_if.Zero_out          <= 1'b0;
            ex_mem_if.CareIfNotZero_out <= 1'b0;
            ex_mem_if.CareIfZero_out    <= 1'b0;
            ex_mem_if.dmemREN_out       <= 1'b0;
            ex_mem_if.dmemWEN_out       <= 1'b0;
            ex_mem_if.PCj_out           <= 1'b0;
            ex_mem_if.PCsrc_out         <= 1'b0;
            ex_mem_if.MemtoReg_out      <= 1'b0;
            ex_mem_if.PCtoReg_out       <= 1'b0;
            ex_mem_if.WEN_out           <= 1'b0;

            ex_mem_if.output_port_out   <= '0;
            ex_mem_if.rdat2_out         <= '0;
            ex_mem_if.imemaddr_out      <= '0;
            ex_mem_if.wsel_out          <= '0;
            ex_mem_if.imgenload_out     <= '0;
            ex_mem_if.funct3_out        <= '0;
            ex_mem_if.Bub_ins_out       <= 1'b0;
            ex_mem_if.sync_out          <= 1'b0;
        end
        else if (ex_mem_if.pipeline_enable) begin
            ex_mem_if.halt_out          <= ex_mem_if.halt;
            ex_mem_if.Zero_out          <= ex_mem_if.Zero;
            ex_mem_if.CareIfNotZero_out <= ex_mem_if.CareIfNotZero;
            ex_mem_if.CareIfZero_out    <= ex_mem_if.CareIfZero;
            ex_mem_if.dmemREN_out       <= ex_mem_if.dmemREN;
            ex_mem_if.dmemWEN_out       <= ex_mem_if.dmemWEN;
            ex_mem_if.PCj_out           <= ex_mem_if.PCj;
            ex_mem_if.PCsrc_out         <= ex_mem_if.PCsrc;
            ex_mem_if.MemtoReg_out      <= ex_mem_if.MemtoReg;
            ex_mem_if.PCtoReg_out       <= ex_mem_if.PCtoReg;
            ex_mem_if.WEN_out           <= ex_mem_if.WEN;

            ex_mem_if.output_port_out   <= ex_mem_if.output_port;
            ex_mem_if.rdat2_out         <= ex_mem_if.rdat2;
            ex_mem_if.imemaddr_out      <= ex_mem_if.imemaddr;
            ex_mem_if.wsel_out          <= ex_mem_if.wsel;
            ex_mem_if.imgenload_out     <= ex_mem_if.imgenload;
            ex_mem_if.funct3_out        <= ex_mem_if.funct3;
            ex_mem_if.Bub_ins_out       <= ex_mem_if.Bub_ins;
            ex_mem_if.sync_out          <= ex_mem_if.sync;
        end
    end

endmodule
