`include "regfile_if.vh"

module rv32i_regfile (
    input logic CLK,
    input logic nRST,

    regfile_if.rf rfi
);

    import rv32i_pkg::*;
    word_t registers [0:31];

    integer i;
    always_comb begin
        if (rfi.rsel1 == regbits_t'(5'd0)) begin
            rfi.rdat1 = '0;
        end
        else begin
            rfi.rdat1 = registers[rfi.rsel1];
        end

        if (rfi.rsel2 == regbits_t'(5'd0)) begin
            rfi.rdat2 = '0;
        end
        else begin
            rfi.rdat2 = registers[rfi.rsel2];
        end
    end

    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= '0;
            end
        end
        else begin
            registers[0] <= '0;

            if (rfi.WEN && (rfi.wsel != regbits_t'(5'd0))) begin
                registers[rfi.wsel] <= rfi.wdat;
            end
        end
    end

endmodule
