`include "rv32i_core_if.vh"
`include "rv32i_axi_lite_master_if.vh"

module rv32i_axi_lite_master (
    input logic CLK,
    input logic nRST,

    rv32i_core_if.memory            coreif,
    rv32i_axi_lite_master_if.master axiif,

    // Sticky indication that an AXI-Lite transaction completed
    // with a non-OKAY response. Cleared only by reset.
    output logic bus_error
);

    localparam logic [1:0] AXI_RESP_OKAY = 2'b00;

    typedef enum logic [2:0] {
        STATE_IDLE,
        STATE_READ_ADDRESS,
        STATE_READ_RESPONSE,
        STATE_WRITE_ADDRESS_DATA,
        STATE_WRITE_RESPONSE,
        STATE_COMPLETE
    } state_t;

    typedef enum logic [1:0] {
        OWNER_NONE,
        OWNER_IMEM,
        OWNER_DMEM_READ,
        OWNER_DMEM_WRITE
    } owner_t;

    state_t state;
    owner_t owner;

    logic [31:0] request_addr;
    logic [31:0] request_wdata;
    logic [3:0]  request_wstrb;

    logic [31:0] instruction_addr;

    // A memory instruction in the current core requires both
    // ihit and dhit in the same cycle. The adapter therefore
    // completes the data transaction first, remembers it, and
    // then completes the instruction fetch before pulsing both.
    logic bundle_needs_instruction;
    logic data_complete;

    // AXI-Lite write-address and write-data channels handshake
    // independently.
    logic aw_complete;
    logic w_complete;

    logic aw_handshake;
    logic w_handshake;
    logic b_handshake;
    logic ar_handshake;
    logic r_handshake;

    assign aw_handshake =
        axiif.AWVALID && axiif.AWREADY;

    assign w_handshake =
        axiif.WVALID && axiif.WREADY;

    assign b_handshake =
        axiif.BVALID && axiif.BREADY;

    assign ar_handshake =
        axiif.ARVALID && axiif.ARREADY;

    assign r_handshake =
        axiif.RVALID && axiif.RREADY;

    // ========================================================
    // AXI-Lite output logic
    // ========================================================

    always_comb begin
        axiif.AWADDR  = request_addr;
        axiif.AWVALID = 1'b0;

        axiif.WDATA   = request_wdata;
        axiif.WSTRB   = request_wstrb;
        axiif.WVALID  = 1'b0;

        axiif.BREADY  = 1'b0;

        axiif.ARADDR  = request_addr;
        axiif.ARVALID = 1'b0;

        axiif.RREADY  = 1'b0;

        case (state)
            STATE_READ_ADDRESS: begin
                axiif.ARVALID = 1'b1;
            end

            STATE_READ_RESPONSE: begin
                axiif.RREADY = 1'b1;
            end

            STATE_WRITE_ADDRESS_DATA: begin
                axiif.AWVALID = !aw_complete;
                axiif.WVALID  = !w_complete;
            end

            STATE_WRITE_RESPONSE: begin
                axiif.BREADY = 1'b1;
            end

            default: begin
                // Outputs remain at their defaults.
            end
        endcase
    end

    // ========================================================
    // Request capture and transaction state machine
    // ========================================================

    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            state                    <= STATE_IDLE;
            owner                    <= OWNER_NONE;

            request_addr             <= 32'b0;
            request_wdata            <= 32'b0;
            request_wstrb            <= 4'b0;
            instruction_addr         <= 32'b0;

            bundle_needs_instruction <= 1'b0;
            data_complete            <= 1'b0;

            aw_complete              <= 1'b0;
            w_complete               <= 1'b0;

            coreif.ihit              <= 1'b0;
            coreif.imemload          <= 32'b0;
            coreif.dhit              <= 1'b0;
            coreif.dmemload          <= 32'b0;

            bus_error                <= 1'b0;
        end
        else begin
            // RV32A atomic memory transactions are not supported.
            assert (!coreif.datomic)
            else $error(
                "Atomic memory transaction requested, but RV32A is not supported"
            );

            // Completion indications are one-cycle pulses.
            coreif.ihit <= 1'b0;
            coreif.dhit <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    owner                    <= OWNER_NONE;
                    bundle_needs_instruction <= 1'b0;
                    data_complete            <= 1'b0;
                    aw_complete              <= 1'b0;
                    w_complete               <= 1'b0;

                    // Data traffic has priority over instruction
                    // traffic because the core cannot advance a
                    // memory instruction until dhit is asserted.
                    if (!coreif.halt && coreif.dmemWEN) begin
                        owner         <= OWNER_DMEM_WRITE;
                        request_addr  <= {
                            coreif.dmemaddr[31:2],
                            2'b00
                        };
                        request_wdata <= coreif.dmemstore;
                        request_wstrb <= coreif.dmem_wstrb;

                        instruction_addr <= {
                            coreif.imemaddr[31:2],
                            2'b00
                        };

                        bundle_needs_instruction <=
                            coreif.imemREN;

                        state <= STATE_WRITE_ADDRESS_DATA;
                    end
                    else if (!coreif.halt && coreif.dmemREN) begin
                        owner        <= OWNER_DMEM_READ;
                        request_addr <= {
                            coreif.dmemaddr[31:2],
                            2'b00
                        };

                        instruction_addr <= {
                            coreif.imemaddr[31:2],
                            2'b00
                        };

                        bundle_needs_instruction <=
                            coreif.imemREN;

                        state <= STATE_READ_ADDRESS;
                    end
                    else if (!coreif.halt && coreif.imemREN) begin
                        owner <= OWNER_IMEM;

                        request_addr <= {
                            coreif.imemaddr[31:2],
                            2'b00
                        };

                        instruction_addr <= {
                            coreif.imemaddr[31:2],
                            2'b00
                        };

                        state <= STATE_READ_ADDRESS;
                    end
                end

                STATE_READ_ADDRESS: begin
                    if (ar_handshake) begin
                        state <= STATE_READ_RESPONSE;
                    end
                end

                STATE_READ_RESPONSE: begin
                    if (r_handshake) begin
                        if (axiif.RRESP != AXI_RESP_OKAY) begin
                            bus_error <= 1'b1;
                        end

                        case (owner)
                            OWNER_DMEM_READ: begin
                                coreif.dmemload <= axiif.RDATA;

                                if (bundle_needs_instruction) begin
                                    data_complete <= 1'b1;
                                    owner         <= OWNER_IMEM;
                                    request_addr  <= instruction_addr;
                                    state         <= STATE_READ_ADDRESS;
                                end
                                else begin
                                    coreif.dhit <= 1'b1;
                                    state       <= STATE_COMPLETE;
                                end
                            end

                            OWNER_IMEM: begin
                                // A branch/jump may redirect the
                                // instruction address while an old
                                // AXI read is outstanding. Discard
                                // that stale response and fetch the
                                // current address instead.
                                if (
                                    !coreif.imemREN ||
                                    ({
                                        coreif.imemaddr[31:2],
                                        2'b00
                                    } != instruction_addr)
                                ) begin
                                    if (
                                        data_complete &&
                                        coreif.imemREN
                                    ) begin
                                        instruction_addr <= {
                                            coreif.imemaddr[31:2],
                                            2'b00
                                        };
                                        request_addr <= {
                                            coreif.imemaddr[31:2],
                                            2'b00
                                        };
                                        owner <= OWNER_IMEM;
                                        state <= STATE_READ_ADDRESS;
                                    end
                                    else if (data_complete) begin
                                        coreif.dhit <= 1'b1;
                                        state       <= STATE_COMPLETE;
                                    end
                                    else begin
                                        owner <= OWNER_NONE;
                                        state <= STATE_IDLE;
                                    end
                                end
                                else begin
                                    coreif.imemload <= axiif.RDATA;
                                    coreif.ihit     <= 1'b1;

                                    if (data_complete) begin
                                        coreif.dhit <= 1'b1;
                                    end

                                    state <= STATE_COMPLETE;
                                end
                            end

                            default: begin
                                state <= STATE_IDLE;
                            end
                        endcase
                    end
                end

                STATE_WRITE_ADDRESS_DATA: begin
                    if (aw_handshake) begin
                        aw_complete <= 1'b1;
                    end

                    if (w_handshake) begin
                        w_complete <= 1'b1;
                    end

                    if (
                        (aw_complete || aw_handshake) &&
                        (w_complete || w_handshake)
                    ) begin
                        state <= STATE_WRITE_RESPONSE;
                    end
                end

                STATE_WRITE_RESPONSE: begin
                    if (b_handshake) begin
                        if (axiif.BRESP != AXI_RESP_OKAY) begin
                            bus_error <= 1'b1;
                        end

                        if (bundle_needs_instruction) begin
                            data_complete <= 1'b1;
                            owner         <= OWNER_IMEM;
                            request_addr  <= instruction_addr;
                            state         <= STATE_READ_ADDRESS;
                        end
                        else begin
                            coreif.dhit <= 1'b1;
                            state       <= STATE_COMPLETE;
                        end
                    end
                end

                STATE_COMPLETE: begin
                    // The completion pulse was visible for the
                    // entire previous cycle. The core consumes it
                    // on this edge and updates its request signals.
                    owner                    <= OWNER_NONE;
                    bundle_needs_instruction <= 1'b0;
                    data_complete            <= 1'b0;
                    aw_complete              <= 1'b0;
                    w_complete               <= 1'b0;
                    state                    <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
