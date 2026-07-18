`include "rv32i_core_if.vh"

`include "pc_if.vh"
`include "decoder_if.vh"
`include "regfile_if.vh"
`include "alu_if.vh"

`include "if_id_latch_if.vh"
`include "id_ex_latch_if.vh"
`include "ex_mem_latch_if.vh"
`include "mem_wb_latch_if.vh"

`include "forwarding_unit_if.vh"
`include "hazard_unit_if.vh"


module rv32i_core #(
    parameter logic [31:0] PC_INIT = 32'h0000_0000
) (
    input logic CLK,
    input logic nRST,

    rv32i_core_if.core coreif
);

    import rv32i_pkg::*;

    // Internal interfaces
    pc_if              pcif();
    decoder_if         decif();
    regfile_if         regif();
    alu_if             aluif();

    if_id_latch_if     idif();
    id_ex_latch_if     exif();
    ex_mem_latch_if    memif();
    mem_wb_latch_if    wbif();

    forwarding_unit_if fwif();
    hazard_unit_if     huif();

    // Internal datapath/control signals
    logic memory_operation;
    logic normal_pipeline_advance;
    logic pipeline_enable;

    logic branch_taken_mem;
    logic redirect_mem;

    word_t branch_target_mem;

    word_t forwarded_rs1;
    word_t forwarded_rs2;

    word_t decode_rdat1;
    word_t decode_rdat2;

    word_t alu_operand_a;
    word_t alu_operand_b;

    word_t load_data_mem;
    word_t writeback_data;

    logic illegal_seen;
    // Submodule instances
    rv32i_pc #(
        .PC_INIT(PC_INIT)
    ) pc_inst (
        .CLK  (CLK),
        .nRST (nRST),
        .pcif (pcif)
    );

    if_id_latch if_id_inst (
        .CLK      (CLK),
        .nRST     (nRST),
        .if_id_if (idif)
    );

    rv32i_decoder decoder_inst (
        .decif(decif)
    );


    rv32i_regfile regfile_inst (
        .CLK  (CLK),
        .nRST (nRST),
        .rfi  (regif)
    );


    id_ex_latch id_ex_inst (
        .CLK      (CLK),
        .nRST     (nRST),
        .id_ex_if (exif)
    );

    forwarding_unit forwarding_inst (
        .fuif(fwif)
    );

    rv32i_alu alu_inst (
        .aluif(aluif)
    );

    ex_mem_latch ex_mem_inst (
        .CLK       (CLK),
        .nRST      (nRST),
        .ex_mem_if (memif)
    );

    hazard_unit hazard_inst (
        .hdif(huif)
    );

    mem_wb_latch mem_wb_inst (
        .CLK       (CLK),
        .nRST      (nRST),
        .mem_wb_if (wbif)
    );

    // Global pipeline control

    assign memory_operation =
        memif.dmemREN_out ||
        memif.dmemWEN_out;

    // The core assumes independent instruction and data response channels, as in separate I-cache and D-cache interfaces.
    // A memory instruction advances only when both the current instruction fetch and data access have completed.
    assign normal_pipeline_advance =
        !coreif.halt &&
        coreif.ihit &&
        (!memory_operation || coreif.dhit);

    // A branch or jump resolved in MEM must be allowed to update the PC and move the redirecting instruction into WB even when the
    // currently requested sequential instruction has not hit.
    assign pipeline_enable =
        normal_pipeline_advance ||
        (redirect_mem && !coreif.halt);

    // IF stage: PC and instruction request
    assign coreif.imemREN  = !coreif.halt;
    assign coreif.imemaddr = pcif.imemaddr;

    assign pcif.PC_Update =
        pipeline_enable;

    assign pcif.PC_IF_freeze =
        huif.PC_IF_freeze;

    assign branch_target_mem =
        memif.imemaddr_out +
        memif.imgenload_out;

    always_comb begin
        pcif.NextPCValue =
            pcif.imemaddr +
            word_t'(32'd4);

        // JALR target: (rs1 + immediate) with bit zero cleared.
        if (memif.PCj_out) begin
            pcif.NextPCValue = {
                memif.output_port_out[31:1],
                1'b0
            };
        end
        // Conditional branch or JAL target: instruction PC + immediate.
        else if (branch_taken_mem || memif.PCsrc_out) begin
            pcif.NextPCValue =
                branch_target_mem;
        end
    end

    // IF/ID latch inputs.
    assign idif.imemload =
        coreif.imemload;

    assign idif.imemaddr =
        pcif.imemaddr;

    assign idif.DCD_freeze =
        huif.DCD_freeze;

    assign idif.DC_flush =
        huif.DC_flush;

    assign idif.pipeline_enable =
        pipeline_enable;

    // ID stage: integrated decoder and register reads

    assign decif.instruction =
        idif.imemload_out;

    assign regif.rsel1 =
        decif.rsel1;

    assign regif.rsel2 =
        decif.rsel2;
        
    always_comb begin
    decode_rdat1 = regif.rdat1;
    decode_rdat2 = regif.rdat2;

    // Same-cycle WB-to-ID bypass.
    //
    // The register file and ID/EX latch both use the rising edge.
    // Therefore, an instruction in ID may otherwise capture the
    // old value of a register being written in WB on that edge.
    if (
        wbif.WEN_out &&
        (wbif.wsel_out != regbits_t'(5'd0))
    ) begin

        if (wbif.wsel_out == decif.rsel1) begin
            decode_rdat1 = writeback_data;
        end

        if (wbif.wsel_out == decif.rsel2) begin
            decode_rdat2 = writeback_data;
        end

    end
end

    // Hazard detection compares the instruction in ID against a load
    // currently in EX.
    assign huif.rsel1 =
        decif.rsel1;

    assign huif.rsel2 =
        decif.rsel2;

    assign huif.wsel_out =
        exif.wsel_out;

    assign huif.MemtoReg =
        exif.MemtoReg_out;

    assign huif.redirect =
        redirect_mem;

    // ID/EX latch inputs.
    assign exif.imemaddr =
        idif.imemaddr_out;

    assign exif.imgenload =
        decif.immediate;

    assign exif.rdat1 =
    decode_rdat1;

    assign exif.rdat2 =
    decode_rdat2;

    assign exif.rsel1 =
        decif.rsel1;

    assign exif.rsel2 =
        decif.rsel2;

    assign exif.wsel =
        decif.wsel;

    assign exif.funct3 =
        decif.funct3;

    assign exif.AluCtrlOP =
        decif.aluop;

    assign exif.WEN =
        decif.WEN;

    assign exif.AluSrcA =
        decif.AluSrcA;

    assign exif.AluSrcB =
        decif.AluSrcB;

    assign exif.CareIfZero =
        decif.CareIfZero;

    assign exif.CareIfNotZero =
        decif.CareIfNotZero;

    assign exif.dmemREN =
        decif.dmemREN;

    assign exif.dmemWEN =
        decif.dmemWEN;

    assign exif.PCj =
        decif.PCj;

    assign exif.PCsrc =
        decif.PCsrc;

    assign exif.MemtoReg =
        decif.MemtoReg;

    assign exif.PCtoReg =
        decif.PCtoReg;

    // Illegal instructions are already side-effect free in the decoder. Propagate them as a halt so older instructions can
    // retire before the pipeline stops.
    assign exif.halt =
        decif.halt ||
        decif.illegal;

    assign exif.sync =
        decif.sync;

    assign exif.EX_flush =
        huif.EX_flush;

    assign exif.Bub_ins =
        huif.Bub_ins;

    assign exif.pipeline_enable =
        pipeline_enable;

    // Keep an architectural indication that an illegal instruction was observed, even after it leaves the decode stage.
    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            illegal_seen <= 1'b0;
        end
        else if (pipeline_enable && decif.illegal) begin
            illegal_seen <= 1'b1;
        end
    end
    // Forwarding control
    assign fwif.EX_rsel1 =
        exif.rsel1_out;

    assign fwif.EX_rsel2 =
        exif.rsel2_out;

    assign fwif.MEM_WEN =
        memif.WEN_out;

    assign fwif.MEM_wsel =
        memif.wsel_out;

    assign fwif.MEM_MemtoReg =
        memif.MemtoReg_out;

    assign fwif.WB_WEN =
        wbif.WEN_out;

    assign fwif.WB_wsel =
        wbif.wsel_out;
    // EX stage: forwarding muxes and ALU
    always_comb begin
        forwarded_rs1 =
            exif.rdat1_out;

        if (fwif.WB_ForwardA) begin
            forwarded_rs1 =
                writeback_data;
        end

        if (fwif.MEM_ForwardA) begin
            forwarded_rs1 =
                memif.output_port_out;
        end

        forwarded_rs2 =
            exif.rdat2_out;

        if (fwif.WB_ForwardB) begin
            forwarded_rs2 =
                writeback_data;
        end

        if (fwif.MEM_ForwardB) begin
            forwarded_rs2 =
                memif.output_port_out;
        end
    end


    always_comb begin
        if (exif.AluSrcA_out) begin
            alu_operand_a =
                exif.imemaddr_out;
        end
        else begin
            alu_operand_a =
                forwarded_rs1;
        end

        if (exif.AluSrcB_out) begin
            alu_operand_b =
                exif.imgenload_out;
        end
        else if (exif.sync_out) begin
            alu_operand_b =
                '0;
        end
        else begin
            alu_operand_b =
                forwarded_rs2;
        end
    end


    assign aluif.portA =
        alu_operand_a;

    assign aluif.portB =
        alu_operand_b;

    assign aluif.aluop =
        exif.AluCtrlOP_out;

    // EX/MEM latch inputs.
    assign memif.halt =
        exif.halt_out;

    assign memif.Zero =
        aluif.zero;

    assign memif.output_port =
        aluif.output_port;

    assign memif.rdat2 =
        forwarded_rs2;

    assign memif.CareIfNotZero =
        exif.CareIfNotZero_out;

    assign memif.CareIfZero =
        exif.CareIfZero_out;

    assign memif.dmemREN =
        exif.dmemREN_out;

    assign memif.dmemWEN =
        exif.dmemWEN_out;

    assign memif.PCj =
        exif.PCj_out;

    assign memif.PCsrc =
        exif.PCsrc_out;

    assign memif.MemtoReg =
        exif.MemtoReg_out;

    assign memif.PCtoReg =
        exif.PCtoReg_out;

    assign memif.WEN =
        exif.WEN_out;

    assign memif.imemaddr =
        exif.imemaddr_out;

    assign memif.wsel =
        exif.wsel_out;

    assign memif.imgenload =
        exif.imgenload_out;

    assign memif.funct3 =
        exif.funct3_out;

    assign memif.MEM_flush =
        huif.MEM_flush;

    assign memif.Bub_ins =
        exif.Bub_ins_out;

    assign memif.pipeline_enable =
        pipeline_enable;

    assign memif.sync =
        exif.sync_out;
    // MEM stage: redirect decision and data-memory formatting
    assign branch_taken_mem =
        (
            memif.CareIfZero_out &&
            memif.Zero_out
        ) ||
        (
            memif.CareIfNotZero_out &&
            !memif.Zero_out
        );

    assign redirect_mem =
        branch_taken_mem ||
        memif.PCsrc_out ||
        memif.PCj_out;

    assign coreif.dmemREN =
        memif.dmemREN_out &&
        !coreif.halt;

    assign coreif.dmemWEN =
        memif.dmemWEN_out &&
        !coreif.halt;

    assign coreif.datomic =
        memif.sync_out;

    assign coreif.dmemaddr =
        memif.output_port_out;


    always_comb begin
        coreif.dmemstore =
            memif.rdat2_out;

        coreif.dmem_wstrb =
            4'b0000;

        if (coreif.dmemWEN) begin
            case (memif.funct3_out)

                3'b000: begin
                    // SB
                    coreif.dmem_wstrb =
                        4'b0001 <<
                        memif.output_port_out[1:0];

                    coreif.dmemstore =
                        memif.rdat2_out <<
                        {
                            memif.output_port_out[1:0],
                            3'b000
                        };
                end

                3'b001: begin
                    // SH
                    coreif.dmem_wstrb =
                        memif.output_port_out[1]
                        ? 4'b1100
                        : 4'b0011;

                    coreif.dmemstore =
                        memif.rdat2_out <<
                        {
                            memif.output_port_out[1],
                            4'b0000
                        };
                end

                3'b010: begin
                    // SW
                    coreif.dmem_wstrb =
                        4'b1111;

                    coreif.dmemstore =
                        memif.rdat2_out;
                end

                default: begin
                    coreif.dmem_wstrb =
                        4'b0000;

                    coreif.dmemstore =
                        memif.rdat2_out;
                end

            endcase
        end
    end


    always_comb begin
        load_data_mem =
            coreif.dmemload;

        case (memif.funct3_out)

            3'b000: begin
                // LB
                case (memif.output_port_out[1:0])
                    2'b00:
                        load_data_mem = {
                            {24{coreif.dmemload[7]}},
                            coreif.dmemload[7:0]
                        };

                    2'b01:
                        load_data_mem = {
                            {24{coreif.dmemload[15]}},
                            coreif.dmemload[15:8]
                        };

                    2'b10:
                        load_data_mem = {
                            {24{coreif.dmemload[23]}},
                            coreif.dmemload[23:16]
                        };

                    2'b11:
                        load_data_mem = {
                            {24{coreif.dmemload[31]}},
                            coreif.dmemload[31:24]
                        };
                endcase
            end

            3'b001: begin
                // LH
                if (memif.output_port_out[1]) begin
                    load_data_mem = {
                        {16{coreif.dmemload[31]}},
                        coreif.dmemload[31:16]
                    };
                end
                else begin
                    load_data_mem = {
                        {16{coreif.dmemload[15]}},
                        coreif.dmemload[15:0]
                    };
                end
            end

            3'b010: begin
                // LW
                load_data_mem =
                    coreif.dmemload;
            end

            3'b100: begin
                // LBU
                case (memif.output_port_out[1:0])
                    2'b00:
                        load_data_mem = {
                            24'b0,
                            coreif.dmemload[7:0]
                        };

                    2'b01:
                        load_data_mem = {
                            24'b0,
                            coreif.dmemload[15:8]
                        };

                    2'b10:
                        load_data_mem = {
                            24'b0,
                            coreif.dmemload[23:16]
                        };

                    2'b11:
                        load_data_mem = {
                            24'b0,
                            coreif.dmemload[31:24]
                        };
                endcase
            end

            3'b101: begin
                // LHU
                if (memif.output_port_out[1]) begin
                    load_data_mem = {
                        16'b0,
                        coreif.dmemload[31:16]
                    };
                end
                else begin
                    load_data_mem = {
                        16'b0,
                        coreif.dmemload[15:0]
                    };
                end
            end

            default: begin
                load_data_mem =
                    coreif.dmemload;
            end

        endcase
    end

    // MEM/WB latch inputs.
    assign wbif.imemaddr =
        memif.imemaddr_out;

    assign wbif.dmemload =
        load_data_mem;

    assign wbif.output_port =
        memif.output_port_out;

    assign wbif.wsel =
        memif.wsel_out;

    assign wbif.MemtoReg =
        memif.MemtoReg_out;

    assign wbif.PCtoReg =
        memif.PCtoReg_out;

    assign wbif.WEN =
        memif.WEN_out;

    assign wbif.halt =
        memif.halt_out;

    assign wbif.pipeline_enable =
        pipeline_enable;

    // WB stage: final writeback selection

    always_comb begin
        writeback_data =
            wbif.output_port_out;

        if (wbif.MemtoReg_out) begin
            writeback_data =
                wbif.dmemload_out;
        end

        if (wbif.PCtoReg_out) begin
            writeback_data =
                wbif.imemaddr_out +
                word_t'(32'd4);
        end
    end

    assign regif.wdat =
        writeback_data;

    assign regif.wsel =
        wbif.wsel_out;

    // Gate the synchronous write during a full pipeline stall so a held WB instruction is not reported as repeatedly committing.
    assign regif.WEN =
        wbif.WEN_out &&
        pipeline_enable;

    // Status and verification outputs

    assign coreif.halt = wbif.halt_out;

    assign coreif.illegal =
        illegal_seen;

    assign coreif.debug_pc =
        pcif.imemaddr;

    assign coreif.debug_instruction =
        idif.imemload_out;

    assign coreif.debug_opcode =
        decif.opcode;

    assign coreif.debug_funct3 =
        decif.funct3;

    assign coreif.debug_funct7 =
        decif.funct7;

    assign coreif.debug_fence =
        decif.fence;

    assign coreif.debug_ecall =
        decif.ecall;

    assign coreif.debug_ebreak =
        decif.ebreak;

    assign coreif.debug_pipeline_enable =
        pipeline_enable;

    assign coreif.debug_redirect =
        redirect_mem;

    assign coreif.debug_bubble =
        memif.Bub_ins_out;

    assign coreif.debug_alu_negative =
    aluif.negative;

    assign coreif.debug_alu_overflow =
    aluif.overflow;

    assign coreif.debug_wb_wen =
        regif.WEN;

    assign coreif.debug_wb_rd =
        wbif.wsel_out;

    assign coreif.debug_wb_data =
        writeback_data;

endmodule
