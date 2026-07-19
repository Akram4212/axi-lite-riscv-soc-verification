`ifndef RV32I_AXI_LITE_MASTER_IF_VH
`define RV32I_AXI_LITE_MASTER_IF_VH

// ============================================================
// RV32I AXI-Lite Master Interface
//
// Connects the RV32I memory adapter to the existing AXI-Lite
// interconnect/subsystem.
//
// The processor-side instruction and data handshakes remain in
// rv32i_core_if. This interface contains only AXI-Lite signals.
// ============================================================

interface rv32i_axi_lite_master_if #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned STRB_WIDTH = DATA_WIDTH / 8
);

    // ========================================================
    // Write Address Channel
    // ========================================================

    logic [ADDR_WIDTH-1:0] AWADDR;
    logic                  AWVALID;
    logic                  AWREADY;

    // ========================================================
    // Write Data Channel
    // ========================================================

    logic [DATA_WIDTH-1:0] WDATA;
    logic [STRB_WIDTH-1:0] WSTRB;
    logic                  WVALID;
    logic                  WREADY;

    // ========================================================
    // Write Response Channel
    // ========================================================

    logic [1:0] BRESP;
    logic       BVALID;
    logic       BREADY;

    // ========================================================
    // Read Address Channel
    // ========================================================

    logic [ADDR_WIDTH-1:0] ARADDR;
    logic                  ARVALID;
    logic                  ARREADY;

    // ========================================================
    // Read Data Channel
    // ========================================================

    logic [DATA_WIDTH-1:0] RDATA;
    logic [1:0]            RRESP;
    logic                  RVALID;
    logic                  RREADY;

    // ========================================================
    // AXI-Lite Master Perspective
    //
    // Used by rv32i_axi_lite_master.sv.
    // ========================================================

    modport master (
        output AWADDR,
        output AWVALID,
        input  AWREADY,

        output WDATA,
        output WSTRB,
        output WVALID,
        input  WREADY,

        input  BRESP,
        input  BVALID,
        output BREADY,

        output ARADDR,
        output ARVALID,
        input  ARREADY,

        input  RDATA,
        input  RRESP,
        input  RVALID,
        output RREADY
    );

    // ========================================================
    // AXI-Lite Slave Perspective
    //
    // Used by an AXI-Lite interconnect, subsystem, or memory.
    // ========================================================

    modport slave (
        input  AWADDR,
        input  AWVALID,
        output AWREADY,

        input  WDATA,
        input  WSTRB,
        input  WVALID,
        output WREADY,

        output BRESP,
        output BVALID,
        input  BREADY,

        input  ARADDR,
        input  ARVALID,
        output ARREADY,

        output RDATA,
        output RRESP,
        output RVALID,
        input  RREADY
    );

    // ========================================================
    // Testbench Perspective
    //
    // The standalone adapter testbench emulates an AXI-Lite
    // slave and applies independent channel backpressure.
    // ========================================================

    modport tb (
        input  AWADDR,
        input  AWVALID,
        output AWREADY,

        input  WDATA,
        input  WSTRB,
        input  WVALID,
        output WREADY,

        output BRESP,
        output BVALID,
        input  BREADY,

        input  ARADDR,
        input  ARVALID,
        output ARREADY,

        output RDATA,
        output RRESP,
        output RVALID,
        input  RREADY
    );

    // ========================================================
    // Passive Monitor Perspective
    //
    // Used by protocol assertions, scoreboards, and coverage.
    // ========================================================

    modport monitor (
        input AWADDR,
        input AWVALID,
        input AWREADY,

        input WDATA,
        input WSTRB,
        input WVALID,
        input WREADY,

        input BRESP,
        input BVALID,
        input BREADY,

        input ARADDR,
        input ARVALID,
        input ARREADY,

        input RDATA,
        input RRESP,
        input RVALID,
        input RREADY
    );

endinterface

`endif // RV32I_AXI_LITE_MASTER_IF_VH
