`timescale 1ns/1ps

module axi_lite_assertions #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input logic                         ACLK,
    input logic                         ARESETn,

    // AXI-Lite Write Address Channel
    input logic [ADDR_WIDTH-1:0]         AWADDR,
    input logic                         AWVALID,
    input logic                         AWREADY,

    // AXI-Lite Write Data Channel
    input logic [DATA_WIDTH-1:0]         WDATA,
    input logic [(DATA_WIDTH/8)-1:0]     WSTRB,
    input logic                         WVALID,
    input logic                         WREADY,

    // AXI-Lite Write Response Channel
    input logic [1:0]                   BRESP,
    input logic                         BVALID,
    input logic                         BREADY,

    // AXI-Lite Read Address Channel
    input logic [ADDR_WIDTH-1:0]         ARADDR,
    input logic                         ARVALID,
    input logic                         ARREADY,

    // AXI-Lite Read Data Channel
    input logic [DATA_WIDTH-1:0]         RDATA,
    input logic [1:0]                   RRESP,
    input logic                         RVALID,
    input logic                         RREADY
);

    // ========================================================
    // Previous-cycle tracking
    // ========================================================

    logic past_valid;

    logic [ADDR_WIDTH-1:0] awaddr_prev;
    logic                  awvalid_prev;
    logic                  awready_prev;

    logic [DATA_WIDTH-1:0] wdata_prev;
    logic [(DATA_WIDTH/8)-1:0] wstrb_prev;
    logic                  wvalid_prev;
    logic                  wready_prev;

    logic [1:0]            bresp_prev;
    logic                  bvalid_prev;
    logic                  bready_prev;

    logic [ADDR_WIDTH-1:0] araddr_prev;
    logic                  arvalid_prev;
    logic                  arready_prev;

    logic [DATA_WIDTH-1:0] rdata_prev;
    logic [1:0]            rresp_prev;
    logic                  rvalid_prev;
    logic                  rready_prev;

    // ========================================================
    // AXI-Lite Protocol Assertions
    // ========================================================

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            past_valid <= 1'b0;

            awaddr_prev  <= '0;
            awvalid_prev <= 1'b0;
            awready_prev <= 1'b0;

            wdata_prev   <= '0;
            wstrb_prev   <= '0;
            wvalid_prev  <= 1'b0;
            wready_prev  <= 1'b0;

            bresp_prev   <= '0;
            bvalid_prev  <= 1'b0;
            bready_prev  <= 1'b0;

            araddr_prev  <= '0;
            arvalid_prev <= 1'b0;
            arready_prev <= 1'b0;

            rdata_prev   <= '0;
            rresp_prev   <= '0;
            rvalid_prev  <= 1'b0;
            rready_prev  <= 1'b0;
        end else begin
            past_valid <= 1'b1;

            if (past_valid) begin

                // ====================================================
                // Write Address Channel Assertions
                // ====================================================
                //
                // If AWVALID was high and AWREADY was low last cycle,
                // then AWVALID must remain high and AWADDR must remain stable.
                //

                if (awvalid_prev && !awready_prev) begin
                    assert (AWVALID)
                        else $error("AXI assertion failed: AWVALID dropped before AWREADY");

                    assert (AWADDR == awaddr_prev)
                        else $error("AXI assertion failed: AWADDR changed while AWVALID && !AWREADY");
                end

                // ====================================================
                // Write Data Channel Assertions
                // ====================================================
                //
                // If WVALID was high and WREADY was low last cycle,
                // then WVALID must remain high and WDATA/WSTRB must remain stable.
                //

                if (wvalid_prev && !wready_prev) begin
                    assert (WVALID)
                        else $error("AXI assertion failed: WVALID dropped before WREADY");

                    assert (WDATA == wdata_prev)
                        else $error("AXI assertion failed: WDATA changed while WVALID && !WREADY");

                    assert (WSTRB == wstrb_prev)
                        else $error("AXI assertion failed: WSTRB changed while WVALID && !WREADY");
                end

                // ====================================================
                // Write Response Channel Assertions
                // ====================================================
                //
                // If BVALID was high and BREADY was low last cycle,
                // then BVALID must remain high and BRESP must remain stable.
                //

                if (bvalid_prev && !bready_prev) begin
                    assert (BVALID)
                        else $error("AXI assertion failed: BVALID dropped before BREADY");

                    assert (BRESP == bresp_prev)
                        else $error("AXI assertion failed: BRESP changed while BVALID && !BREADY");
                end

                // ====================================================
                // Read Address Channel Assertions
                // ====================================================
                //
                // If ARVALID was high and ARREADY was low last cycle,
                // then ARVALID must remain high and ARADDR must remain stable.
                //

                if (arvalid_prev && !arready_prev) begin
                    assert (ARVALID)
                        else $error("AXI assertion failed: ARVALID dropped before ARREADY");

                    assert (ARADDR == araddr_prev)
                        else $error("AXI assertion failed: ARADDR changed while ARVALID && !ARREADY");
                end

                // ====================================================
                // Read Data Channel Assertions
                // ====================================================
                //
                // If RVALID was high and RREADY was low last cycle,
                // then RVALID must remain high and RDATA/RRESP must remain stable.
                //

                if (rvalid_prev && !rready_prev) begin
                    assert (RVALID)
                        else $error("AXI assertion failed: RVALID dropped before RREADY");

                    assert (RDATA == rdata_prev)
                        else $error("AXI assertion failed: RDATA changed while RVALID && !RREADY");

                    assert (RRESP == rresp_prev)
                        else $error("AXI assertion failed: RRESP changed while RVALID && !RREADY");
                end
            end

            // ========================================================
            // Sample current-cycle values for next-cycle checks
            // ========================================================

            awaddr_prev  <= AWADDR;
            awvalid_prev <= AWVALID;
            awready_prev <= AWREADY;

            wdata_prev   <= WDATA;
            wstrb_prev   <= WSTRB;
            wvalid_prev  <= WVALID;
            wready_prev  <= WREADY;

            bresp_prev   <= BRESP;
            bvalid_prev  <= BVALID;
            bready_prev  <= BREADY;

            araddr_prev  <= ARADDR;
            arvalid_prev <= ARVALID;
            arready_prev <= ARREADY;

            rdata_prev   <= RDATA;
            rresp_prev   <= RRESP;
            rvalid_prev  <= RVALID;
            rready_prev  <= RREADY;
        end
    end

endmodule
