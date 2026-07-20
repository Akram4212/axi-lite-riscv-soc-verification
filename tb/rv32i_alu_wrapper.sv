`include "alu_if.vh"

module rv32i_alu_wrapper (
    input  logic [31:0] portA,
    input  logic [31:0] portB,
    input  logic [3:0]  aluop,

    output logic [31:0] output_port,
    output logic        zero,
    output logic        negative,
    output logic        overflow
);

    import rv32i_pkg::*;

    // Internal SystemVerilog interface instance
    alu_if aluif();

    // Connect ordinary wrapper inputs to the interface.
    always_comb begin
        aluif.portA = portA;
        aluif.portB = portB;
        aluif.aluop = aluop_t'(aluop);
    end

    // Connect interface outputs to ordinary wrapper outputs.
    always_comb begin
        output_port = aluif.output_port;
        zero        = aluif.zero;
        negative    = aluif.negative;
        overflow    = aluif.overflow;
    end

    // Actual design under test
    rv32i_alu dut (
        .aluif(aluif)
    );

endmodule
