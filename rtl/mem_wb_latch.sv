`include "mem_wb_latch_if.vh"

module mem_wb_latch (
    input logic CLK,
    input logic nRST,
    mem_wb_latch_if.mem_wb mem_wb_if
);

    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            mem_wb_if.MemtoReg_out    <= 1'b0;
            mem_wb_if.PCtoReg_out     <= 1'b0;
            mem_wb_if.WEN_out         <= 1'b0;
            mem_wb_if.halt_out        <= 1'b0;

            mem_wb_if.imemaddr_out    <= '0;
            mem_wb_if.dmemload_out    <= '0;
            mem_wb_if.output_port_out <= '0;
            mem_wb_if.wsel_out        <= '0;
        end
        else if (mem_wb_if.pipeline_enable) begin
            mem_wb_if.MemtoReg_out    <= mem_wb_if.MemtoReg;
            mem_wb_if.PCtoReg_out     <= mem_wb_if.PCtoReg;
            mem_wb_if.WEN_out         <= mem_wb_if.WEN;
            mem_wb_if.halt_out        <= mem_wb_if.halt;

            mem_wb_if.imemaddr_out    <= mem_wb_if.imemaddr;
            mem_wb_if.dmemload_out    <= mem_wb_if.dmemload;
            mem_wb_if.output_port_out <= mem_wb_if.output_port;
            mem_wb_if.wsel_out        <= mem_wb_if.wsel;
        end
    end

endmodule
