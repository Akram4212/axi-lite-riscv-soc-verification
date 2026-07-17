`include "regfile_if.vh"

module rv32i_regfile_wrapper (
    input  logic        CLK,
    input  logic        nRST,

    input  logic        WEN,
    input  logic [4:0]  wsel,
    input  logic [4:0]  rsel1,
    input  logic [4:0]  rsel2,
    input  logic [31:0] wdat,

    output logic [31:0] rdat1,
    output logic [31:0] rdat2
);

    import rv32i_pkg::*;

    regfile_if rfi();
    always_comb begin
        rfi.WEN   = WEN;
        rfi.wsel  = regbits_t'(wsel);
        rfi.rsel1 = regbits_t'(rsel1);
        rfi.rsel2 = regbits_t'(rsel2);
        rfi.wdat  = word_t'(wdat);
    end

    always_comb begin
        rdat1 = rfi.rdat1;
        rdat2 = rfi.rdat2;
    end

    rv32i_regfile dut (
        .CLK  (CLK),
        .nRST (nRST),
        .rfi  (rfi)
    );

endmodule
