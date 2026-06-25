// ============================================================
// gpio.sv
// AXI4-Lite GPIO Peripheral
//
// Uses gpio_if.vh for register map and AXI response codes.
//
// Register Map:
//   0x00  DATA_OUT      RW   GPIO output value
//   0x04  DATA_IN       RO   GPIO input value
//   0x08  DATA_DIR      RW   GPIO direction, 1 = output, 0 = input
//   0x0C  DATA_OUT_SET  WO   Write 1s to set output bits
//   0x10  DATA_OUT_CLR  WO   Write 1s to clear output bits
//
// Main idea:
//   AWADDR chooses which register receives WDATA.
//   ARADDR chooses which register drives RDATA.
// ============================================================

`timescale 1ns/1ps

`include "gpio_if.vh"

module gpio #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)(
    input  logic                         ACLK,
    input  logic                         ARESETn,

    // ========================================================
    // AXI4-Lite Write Address Channel
    // ========================================================
    input  logic [ADDR_WIDTH-1:0]         S_AXI_AWADDR,
    input  logic                         S_AXI_AWVALID,
    output logic                         S_AXI_AWREADY,

    // ========================================================
    // AXI4-Lite Write Data Channel
    // ========================================================
    input  logic [DATA_WIDTH-1:0]         S_AXI_WDATA,
    input  logic [(DATA_WIDTH/8)-1:0]     S_AXI_WSTRB,
    input  logic                         S_AXI_WVALID,
    output logic                         S_AXI_WREADY,

    // ========================================================
    // AXI4-Lite Write Response Channel
    // ========================================================
    output logic [1:0]                   S_AXI_BRESP,
    output logic                         S_AXI_BVALID,
    input  logic                         S_AXI_BREADY,

    // ========================================================
    // AXI4-Lite Read Address Channel
    // ========================================================
    input  logic [ADDR_WIDTH-1:0]         S_AXI_ARADDR,
    input  logic                         S_AXI_ARVALID,
    output logic                         S_AXI_ARREADY,

    // ========================================================
    // AXI4-Lite Read Data Channel
    // ========================================================
    output logic [DATA_WIDTH-1:0]         S_AXI_RDATA,
    output logic [1:0]                   S_AXI_RRESP,
    output logic                         S_AXI_RVALID,
    input  logic                         S_AXI_RREADY,

    // ========================================================
    // GPIO Side
    // ========================================================
    input  logic [DATA_WIDTH-1:0]         gpio_i,
    output logic [DATA_WIDTH-1:0]         gpio_o,
    output logic [DATA_WIDTH-1:0]         gpio_oe
);

    // ========================================================
    // Internal GPIO registers
    // ========================================================
    logic [DATA_WIDTH-1:0] data_out_reg;
    logic [DATA_WIDTH-1:0] data_dir_reg;

    assign gpio_o  = data_out_reg;
    assign gpio_oe = data_dir_reg;

    // ========================================================
    // Write buffering
    //
    // AXI-Lite write address and write data can arrive in
    // different cycles, so we store them until both are valid.
    // ========================================================
    logic [ADDR_WIDTH-1:0]     awaddr_buf;
    logic [DATA_WIDTH-1:0]     wdata_buf;
    logic [(DATA_WIDTH/8)-1:0] wstrb_buf;

    logic awaddr_valid;
    logic wdata_valid;

    // Ready when this slave is not already holding that part
    // of the write transaction and not waiting for B response.
    assign S_AXI_AWREADY = (!awaddr_valid) && (!S_AXI_BVALID);
    assign S_AXI_WREADY  = (!wdata_valid)  && (!S_AXI_BVALID);

    // Read address ready when not already holding valid read data.
    assign S_AXI_ARREADY = !S_AXI_RVALID;

    // ========================================================
    // Byte-strobe helper
    //
    // WSTRB controls which bytes of WDATA are written.
    //
    // For 32-bit data:
    //   WSTRB[0] -> bits [7:0]
    //   WSTRB[1] -> bits [15:8]
    //   WSTRB[2] -> bits [23:16]
    //   WSTRB[3] -> bits [31:24]
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
    // Strobe-mask helper
    //
    // Used for DATA_OUT_SET and DATA_OUT_CLR so that WSTRB
    // still works correctly.
    // ========================================================
    function automatic logic [DATA_WIDTH-1:0] strobe_mask_data;
        input logic [DATA_WIDTH-1:0]     value;
        input logic [(DATA_WIDTH/8)-1:0] wstrb;

        logic [DATA_WIDTH-1:0] result;
        int i;

        begin
            result = '0;

            for (i = 0; i < DATA_WIDTH/8; i++) begin
                if (wstrb[i]) begin
                    result[i*8 +: 8] = value[i*8 +: 8];
                end
            end

            return result;
        end
    endfunction

    // ========================================================
    // AXI4-Lite Write Logic
    // ========================================================
      always_ff @(posedge ACLK, negedge ARESETn) begin
        if (!ARESETn) begin
            awaddr_buf   <= '0;
            wdata_buf    <= '0;
            wstrb_buf    <= '0;

            awaddr_valid <= 1'b0;
            wdata_valid  <= 1'b0;

            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= `GPIO_AXI_RESP_OKAY;

            data_out_reg <= '0;
            data_dir_reg <= '0;
        end else begin

            // ------------------------------------------------
            // Capture write address
            // ------------------------------------------------
            if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                awaddr_buf   <= S_AXI_AWADDR;
                awaddr_valid <= 1'b1;
            end

            // ------------------------------------------------
            // Capture write data
            // ------------------------------------------------
            if (S_AXI_WVALID && S_AXI_WREADY) begin
                wdata_buf   <= S_AXI_WDATA;
                wstrb_buf   <= S_AXI_WSTRB;
                wdata_valid <= 1'b1;
            end

            // ------------------------------------------------
            // Perform write once both AWADDR and WDATA arrived
            // ------------------------------------------------
            if (awaddr_valid && wdata_valid && !S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= `GPIO_AXI_RESP_OKAY;

                // Word alignment check
                if (awaddr_buf[1:0] != 2'b00) begin
                    S_AXI_BRESP <= `GPIO_AXI_RESP_SLVERR;
                end else begin
                    case (awaddr_buf[5:0])

                        // ------------------------------------
                        // DATA_OUT register
                        // Address offset 0x00
                        // ------------------------------------
                        `GPIO_REG_DATA_OUT: begin
                            data_out_reg <= apply_wstrb(
                                data_out_reg,
                                wdata_buf,
                                wstrb_buf
                            );
                        end

                        // ------------------------------------
                        // DATA_DIR register
                        // Address offset 0x08
                        //
                        // 1 = output
                        // 0 = input
                        // ------------------------------------
                        `GPIO_REG_DATA_DIR: begin
                            data_dir_reg <= apply_wstrb(
                                data_dir_reg,
                                wdata_buf,
                                wstrb_buf
                            );
                        end

                        // ------------------------------------
                        // DATA_OUT_SET register
                        // Address offset 0x0C
                        //
                        // Writing 1 sets the corresponding bit.
                        // Writing 0 leaves the bit unchanged.
                        // ------------------------------------
                        `GPIO_REG_DATA_OUT_SET: begin
                            data_out_reg <= data_out_reg |
                                            strobe_mask_data(wdata_buf, wstrb_buf);
                        end

                        // ------------------------------------
                        // DATA_OUT_CLR register
                        // Address offset 0x10
                        //
                        // Writing 1 clears the corresponding bit.
                        // Writing 0 leaves the bit unchanged.
                        // ------------------------------------
                        `GPIO_REG_DATA_OUT_CLR: begin
                            data_out_reg <= data_out_reg &
                                            ~strobe_mask_data(wdata_buf, wstrb_buf);
                        end

                        // ------------------------------------
                        // DATA_IN is read-only
                        // ------------------------------------
                        `GPIO_REG_DATA_IN: begin
                            S_AXI_BRESP <= `GPIO_AXI_RESP_SLVERR;
                        end

                        // ------------------------------------
                        // Invalid register offset
                        // ------------------------------------
                        default: begin
                            S_AXI_BRESP <= `GPIO_AXI_RESP_SLVERR;
                        end

                    endcase
                end

                awaddr_valid <= 1'b0;
                wdata_valid  <= 1'b0;
            end

            // ------------------------------------------------
            // Complete write response
            // ------------------------------------------------
            if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
                S_AXI_BRESP  <= `GPIO_AXI_RESP_OKAY;
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
            S_AXI_RRESP  <= `GPIO_AXI_RESP_OKAY;
        end else begin

            // ------------------------------------------------
            // Accept read address
            // ------------------------------------------------
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RDATA  <= '0;
                S_AXI_RRESP  <= `GPIO_AXI_RESP_OKAY;

                // Word alignment check
                if (S_AXI_ARADDR[1:0] != 2'b00) begin
                    S_AXI_RDATA <= '0;
                    S_AXI_RRESP <= `GPIO_AXI_RESP_SLVERR;
                end else begin
                    case (S_AXI_ARADDR[5:0])

                        // ------------------------------------
                        // Read DATA_OUT
                        // ------------------------------------
                        `GPIO_REG_DATA_OUT: begin
                            S_AXI_RDATA <= data_out_reg;
                        end

                        // ------------------------------------
                        // Read DATA_IN
                        // Comes directly from external pins
                        // ------------------------------------
                        `GPIO_REG_DATA_IN: begin
                            S_AXI_RDATA <= gpio_i;
                        end

                        // ------------------------------------
                        // Read DATA_DIR
                        // ------------------------------------
                        `GPIO_REG_DATA_DIR: begin
                            S_AXI_RDATA <= data_dir_reg;
                        end

                        // ------------------------------------
                        // SET and CLR are write-only helper regs.
                        // Reading them returns 0.
                        // ------------------------------------
                        `GPIO_REG_DATA_OUT_SET: begin
                            S_AXI_RDATA <= '0;
                        end

                        `GPIO_REG_DATA_OUT_CLR: begin
                            S_AXI_RDATA <= '0;
                        end

                        // ------------------------------------
                        // Invalid register offset
                        // ------------------------------------
                        default: begin
                            S_AXI_RDATA <= '0;
                            S_AXI_RRESP <= `GPIO_AXI_RESP_SLVERR;
                        end

                    endcase
                end
            end

            // ------------------------------------------------
            // Complete read transaction
            // ------------------------------------------------
            if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
                S_AXI_RRESP  <= `GPIO_AXI_RESP_OKAY;
            end
        end
    end

endmodule