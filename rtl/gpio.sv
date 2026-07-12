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
   /* logic [ADDR_WIDTH-1:0]     awaddr_buf;
    // Upper address bits are intentionally unused inside this local GPIO slave.
    // The SoC-level AXI-Lite interconnect will handle full address decoding.*/
    logic unused_addr_bits;

    assign unused_addr_bits = &{
        1'b0,
        S_AXI_AWADDR[ADDR_WIDTH-1:6],
        S_AXI_ARADDR[ADDR_WIDTH-1:6]
    };
    /*logic [DATA_WIDTH-1:0]     wdata_buf;
    logic [(DATA_WIDTH/8)-1:0] wstrb_buf;

    logic awaddr_valid;
    logic wdata_valid;*/

    // Ready when this slave is not already holding that part
    // of the write transaction and not waiting for B response.
    assign S_AXI_AWREADY = !S_AXI_BVALID;
    assign S_AXI_WREADY  = !S_AXI_BVALID;

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

    logic write_fire;

    assign write_fire = S_AXI_AWVALID && S_AXI_AWREADY &&
                        S_AXI_WVALID  && S_AXI_WREADY;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= `GPIO_AXI_RESP_OKAY;

            data_out_reg <= '0;
            data_dir_reg <= '0;
        end else begin

            // ------------------------------------------------
            // Perform write when AW and W handshake together
            // ------------------------------------------------
            if (write_fire && !S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= `GPIO_AXI_RESP_OKAY;

                if (S_AXI_AWADDR[1:0] != 2'b00) begin
                    S_AXI_BRESP <= `GPIO_AXI_RESP_SLVERR;
                end else begin

                    case (S_AXI_AWADDR[5:0])

                        `GPIO_REG_DATA_OUT: begin
                            data_out_reg <= apply_wstrb(
                                data_out_reg,
                                S_AXI_WDATA,
                                S_AXI_WSTRB
                            );
                        end

                        `GPIO_REG_DATA_DIR: begin
                            data_dir_reg <= apply_wstrb(
                                data_dir_reg,
                                S_AXI_WDATA,
                                S_AXI_WSTRB
                            );
                        end

                        `GPIO_REG_DATA_OUT_SET: begin
                            data_out_reg <= data_out_reg |
                                            strobe_mask_data(S_AXI_WDATA, S_AXI_WSTRB);
                        end

                        `GPIO_REG_DATA_OUT_CLR: begin
                            data_out_reg <= data_out_reg &
                                            ~strobe_mask_data(S_AXI_WDATA, S_AXI_WSTRB);
                        end

                        `GPIO_REG_DATA_IN: begin
                            S_AXI_BRESP <= `GPIO_AXI_RESP_SLVERR;
                        end

                        default: begin
                            S_AXI_BRESP <= `GPIO_AXI_RESP_SLVERR;
                        end

                    endcase
                end
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

    assign S_AXI_ARREADY = !S_AXI_RVALID;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RDATA  <= '0;
            S_AXI_RRESP  <= `GPIO_AXI_RESP_OKAY;
        end else begin

            // Complete read response first
            if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
                S_AXI_RRESP  <= `GPIO_AXI_RESP_OKAY;
            end

            // Accept new read address only when no response is pending
            else if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP  <= `GPIO_AXI_RESP_OKAY;
                S_AXI_RDATA  <= '0;

                if (S_AXI_ARADDR[1:0] != 2'b00) begin
                    S_AXI_RRESP <= `GPIO_AXI_RESP_SLVERR;
                    S_AXI_RDATA <= '0;
                end else begin
                    case (S_AXI_ARADDR[5:0])

                        `GPIO_REG_DATA_OUT: begin
                            S_AXI_RDATA <= data_out_reg;
                        end

                        `GPIO_REG_DATA_IN: begin
                            S_AXI_RDATA <= gpio_i;
                        end

                        `GPIO_REG_DATA_DIR: begin
                            S_AXI_RDATA <= data_dir_reg;
                        end

                        `GPIO_REG_DATA_OUT_SET: begin
                            S_AXI_RDATA <= '0;
                        end

                        `GPIO_REG_DATA_OUT_CLR: begin
                            S_AXI_RDATA <= '0;
                        end

                        default: begin
                            S_AXI_RDATA <= '0;
                            S_AXI_RRESP <= `GPIO_AXI_RESP_SLVERR;
                        end

                    endcase
                end
            end
        end
    end
endmodule
