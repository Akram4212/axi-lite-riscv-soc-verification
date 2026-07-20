`include "rv32i_core_if.vh"
`include "rv32i_axi_lite_master_if.vh"

module rv32i_axi_lite_master_wrapper (
    input logic CLK,
    input logic nRST,

    // ========================================================
    // Core-side request inputs
    // ========================================================

    input logic        imemREN,
    input logic [31:0] imemaddr,

    input logic        dmemREN,
    input logic        dmemWEN,
    input logic        datomic,
    input logic [31:0] dmemaddr,
    input logic [31:0] dmemstore,
    input logic [3:0]  dmem_wstrb,

    // ========================================================
    // Core-side completion outputs
    // ========================================================

    output logic        ihit,
    output logic [31:0] imemload,

    output logic        dhit,
    output logic [31:0] dmemload,

    output logic bus_error,

    // ========================================================
    // AXI-Lite master ports
    // ========================================================

    output logic [31:0] M_AXI_AWADDR,
    output logic        M_AXI_AWVALID,
    input  logic        M_AXI_AWREADY,

    output logic [31:0] M_AXI_WDATA,
    output logic [3:0]  M_AXI_WSTRB,
    output logic        M_AXI_WVALID,
    input  logic        M_AXI_WREADY,

    input  logic [1:0]  M_AXI_BRESP,
    input  logic        M_AXI_BVALID,
    output logic        M_AXI_BREADY,

    output logic [31:0] M_AXI_ARADDR,
    output logic        M_AXI_ARVALID,
    input  logic        M_AXI_ARREADY,

    input  logic [31:0] M_AXI_RDATA,
    input  logic [1:0]  M_AXI_RRESP,
    input  logic        M_AXI_RVALID,
    output logic        M_AXI_RREADY
);

    rv32i_core_if coreif();

    rv32i_axi_lite_master_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) axiif();

    // ========================================================
    // Flat core-side ports to interface
    // ========================================================

    assign coreif.imemREN    = imemREN;
    assign coreif.imemaddr   = imemaddr;

    assign coreif.dmemREN    = dmemREN;
    assign coreif.dmemWEN    = dmemWEN;
    assign coreif.datomic    = datomic;
    assign coreif.dmemaddr   = dmemaddr;
    assign coreif.dmemstore  = dmemstore;
    assign coreif.dmem_wstrb = dmem_wstrb;

    // The standalone adapter testbench does not model the
    // processor's architectural halt/illegal status.
    assign coreif.halt    = 1'b0;
    assign coreif.illegal = 1'b0;

    assign ihit     = coreif.ihit;
    assign imemload = coreif.imemload;
    assign dhit     = coreif.dhit;
    assign dmemload = coreif.dmemload;

    // ========================================================
    // AXI-Lite interface to flat wrapper ports
    // ========================================================

    assign M_AXI_AWADDR  = axiif.AWADDR;
    assign M_AXI_AWVALID = axiif.AWVALID;
    assign axiif.AWREADY = M_AXI_AWREADY;

    assign M_AXI_WDATA   = axiif.WDATA;
    assign M_AXI_WSTRB   = axiif.WSTRB;
    assign M_AXI_WVALID  = axiif.WVALID;
    assign axiif.WREADY  = M_AXI_WREADY;

    assign axiif.BRESP   = M_AXI_BRESP;
    assign axiif.BVALID  = M_AXI_BVALID;
    assign M_AXI_BREADY  = axiif.BREADY;

    assign M_AXI_ARADDR  = axiif.ARADDR;
    assign M_AXI_ARVALID = axiif.ARVALID;
    assign axiif.ARREADY = M_AXI_ARREADY;

    assign axiif.RDATA   = M_AXI_RDATA;
    assign axiif.RRESP   = M_AXI_RRESP;
    assign axiif.RVALID  = M_AXI_RVALID;
    assign M_AXI_RREADY  = axiif.RREADY;

    rv32i_axi_lite_master dut (
        .CLK      (CLK),
        .nRST     (nRST),
        .coreif   (coreif),
        .axiif    (axiif),
        .bus_error(bus_error)
    );

endmodule
