`timescale 1ns/1ps

`include "timer_if.vh"

module timer #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)(
    input  logic                         ACLK,
    input  logic                         ARESETn,

    // AXI4-Lite Write Address Channel
    input  logic [ADDR_WIDTH-1:0]         S_AXI_AWADDR,
    input  logic                         S_AXI_AWVALID,
    output logic                         S_AXI_AWREADY,

    // AXI4-Lite Write Data Channel
    input  logic [DATA_WIDTH-1:0]         S_AXI_WDATA,
    input  logic [(DATA_WIDTH/8)-1:0]     S_AXI_WSTRB,
    input  logic                         S_AXI_WVALID,
    output logic                         S_AXI_WREADY,

    // AXI4-Lite Write Response Channel
    output logic [1:0]                   S_AXI_BRESP,
    output logic                         S_AXI_BVALID,
    input  logic                         S_AXI_BREADY,

    // AXI4-Lite Read Address Channel
    input  logic [ADDR_WIDTH-1:0]         S_AXI_ARADDR,
    input  logic                         S_AXI_ARVALID,
    output logic                         S_AXI_ARREADY,

    // AXI4-Lite Read Data Channel
    output logic [DATA_WIDTH-1:0]         S_AXI_RDATA,
    output logic [1:0]                   S_AXI_RRESP,
    output logic                         S_AXI_RVALID,
    input  logic                         S_AXI_RREADY,

    // Timer interrupt output
    output logic                         timer_irq
);

    // ========================================================
    // Timer Registers
    // ========================================================

    logic [31:0] ctrl_reg;
    logic [31:0] count_reg;
    logic [31:0] compare_reg;
    logic [31:0] status_reg;

    localparam int CTRL_ENABLE  = 0;
    localparam int CTRL_CLEAR   = 1;
    localparam int CTRL_IRQ_EN  = 2;

    localparam int STATUS_MATCH = 0;

    // ========================================================
    // AXI-Lite Write Strobe Helper
    // ========================================================

    function automatic logic [DATA_WIDTH-1:0] apply_wstrb;
        input logic [DATA_WIDTH-1:0]     old_value;
        input logic [DATA_WIDTH-1:0]     new_value;
        input logic [(DATA_WIDTH/8)-1:0] wstrb;

        logic [DATA_WIDTH-1:0] result;
        int i;

        begin
            result = old_value;

            for (i = 0; i < DATA_WIDTH/8; i++) begin
                if (wstrb[i]) begin
                    result[i*8 +: 8] = new_value[i*8 +: 8];
                end
            end

            return result;
        end
    endfunction

    // ========================================================
    // AXI-Lite Handshake Helpers
    // ========================================================

    logic write_fire;

    assign S_AXI_AWREADY = !S_AXI_BVALID;
    assign S_AXI_WREADY  = !S_AXI_BVALID;

    assign write_fire = S_AXI_AWVALID && S_AXI_AWREADY &&
                        S_AXI_WVALID  && S_AXI_WREADY;

    assign S_AXI_ARREADY = !S_AXI_RVALID;

    // Upper address bits are intentionally unused inside this local timer slave.
    // Full SoC address decoding will be handled by the AXI-Lite interconnect.
    logic unused_addr_bits;

    assign unused_addr_bits = &{
        1'b0,
        S_AXI_AWADDR[ADDR_WIDTH-1:6],
        S_AXI_ARADDR[ADDR_WIDTH-1:6]
    };

    // ========================================================
    // AXI4-Lite Write Logic + Timer Core Logic
    // ========================================================

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            ctrl_reg    <= '0;
            count_reg   <= '0;
            compare_reg <= '0;
            status_reg  <= '0;
            timer_irq   <= 1'b0;

            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= `TIMER_AXI_RESP_OKAY;
        end else begin

            // Default registered IRQ update.
            // IRQ becomes high when MATCH flag is set and IRQ_EN is enabled.
            timer_irq <= status_reg[STATUS_MATCH] && ctrl_reg[CTRL_IRQ_EN];

            // ------------------------------------------------
            // Complete AXI write response
            // ------------------------------------------------
            if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
                S_AXI_BRESP  <= `TIMER_AXI_RESP_OKAY;
            end

            // ------------------------------------------------
            // Timer behavior
            // ------------------------------------------------

            // CLEAR bit is self-clearing.
            // Software writes CTRL_CLEAR = 1 to reset count and clear match.
            if (ctrl_reg[CTRL_CLEAR]) begin
                count_reg              <= '0;
                status_reg[STATUS_MATCH] <= 1'b0;
                ctrl_reg[CTRL_CLEAR]   <= 1'b0;
            end

            // Count when enabled.
            else if (ctrl_reg[CTRL_ENABLE]) begin
                count_reg <= count_reg + 32'd1;

                if ((compare_reg != 32'd0) &&
                    ((count_reg + 32'd1) >= compare_reg)) begin
                    status_reg[STATUS_MATCH] <= 1'b1;
                end
            end

            // ------------------------------------------------
            // Accept AXI write transaction
            // ------------------------------------------------
            if (write_fire && !S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= `TIMER_AXI_RESP_OKAY;

                if (S_AXI_AWADDR[1:0] != 2'b00) begin
                    S_AXI_BRESP <= `TIMER_AXI_RESP_SLVERR;
                end else begin
                    case (S_AXI_AWADDR[5:0])

                        `TIMER_REG_CTRL: begin
                            ctrl_reg <= apply_wstrb(
                                ctrl_reg,
                                S_AXI_WDATA,
                                S_AXI_WSTRB
                            );
                        end

                        `TIMER_REG_COUNT: begin
                            count_reg <= apply_wstrb(
                                count_reg,
                                S_AXI_WDATA,
                                S_AXI_WSTRB
                            );
                        end

                        `TIMER_REG_COMPARE: begin
                            compare_reg <= apply_wstrb(
                                compare_reg,
                                S_AXI_WDATA,
                                S_AXI_WSTRB
                            );
                        end

                        `TIMER_REG_STATUS: begin
                            // Write-one-to-clear for MATCH flag.
                            // Since MATCH is bit 0, WSTRB[0] must be active.
                            if (S_AXI_WSTRB[0] && S_AXI_WDATA[STATUS_MATCH]) begin
                                status_reg[STATUS_MATCH] <= 1'b0;
                            end
                        end

                        default: begin
                            S_AXI_BRESP <= `TIMER_AXI_RESP_SLVERR;
                        end

                    endcase
                end
            end
        end
    end

    // ========================================================
    // AXI4-Lite Read Logic
    // ========================================================

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RDATA  <= '0;
            S_AXI_RRESP  <= `TIMER_AXI_RESP_OKAY;
        end else begin

            // Complete read response
            if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
                S_AXI_RRESP  <= `TIMER_AXI_RESP_OKAY;
            end

            // Accept new read address
            else if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RDATA  <= '0;
                S_AXI_RRESP  <= `TIMER_AXI_RESP_OKAY;

                if (S_AXI_ARADDR[1:0] != 2'b00) begin
                    S_AXI_RDATA <= '0;
                    S_AXI_RRESP <= `TIMER_AXI_RESP_SLVERR;
                end else begin
                    case (S_AXI_ARADDR[5:0])

                        `TIMER_REG_CTRL: begin
                            S_AXI_RDATA <= ctrl_reg;
                        end

                        `TIMER_REG_COUNT: begin
                            S_AXI_RDATA <= count_reg;
                        end

                        `TIMER_REG_COMPARE: begin
                            S_AXI_RDATA <= compare_reg;
                        end

                        `TIMER_REG_STATUS: begin
                            S_AXI_RDATA <= status_reg;
                        end

                        default: begin
                            S_AXI_RDATA <= '0;
                            S_AXI_RRESP <= `TIMER_AXI_RESP_SLVERR;
                        end

                    endcase
                end
            end
        end
    end

endmodule
