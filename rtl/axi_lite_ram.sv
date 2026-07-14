`timescale 1ns/1ps

module axi_lite_ram #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int RAM_BYTES  = 4096
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
    input  logic                         S_AXI_RREADY
);

    // ========================================================
    // Local Parameters
    // ========================================================

    localparam int BYTE_LANES      = DATA_WIDTH / 8;
    localparam int WORDS           = RAM_BYTES / BYTE_LANES;
    localparam int ADDR_LSB        = $clog2(BYTE_LANES);
    localparam int RAM_ADDR_BITS   = $clog2(WORDS);
    localparam int RAM_OFFSET_BITS = $clog2(RAM_BYTES);

    localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

    // ========================================================
    // RAM Storage
    // ========================================================

    logic [DATA_WIDTH-1:0] mem [0:WORDS-1];

    // ========================================================
    // AXI-Lite Handshake Helpers
    // ========================================================

    logic write_fire;

    assign S_AXI_AWREADY = !S_AXI_BVALID;
    assign S_AXI_WREADY  = !S_AXI_BVALID;

    assign write_fire = S_AXI_AWVALID && S_AXI_AWREADY &&
                        S_AXI_WVALID  && S_AXI_WREADY;

    assign S_AXI_ARREADY = !S_AXI_RVALID;

// ========================================================
// Address Decode Helpers
// ========================================================

    logic aw_addr_aligned;
    logic ar_addr_aligned;
    
    logic aw_addr_in_range;
    logic ar_addr_in_range;
    
    logic aw_addr_valid;
    logic ar_addr_valid;
    
    logic [RAM_ADDR_BITS-1:0] aw_word_index;
    logic [RAM_ADDR_BITS-1:0] ar_word_index;
    
    assign aw_addr_aligned = (S_AXI_AWADDR[ADDR_LSB-1:0] == '0);
    assign ar_addr_aligned = (S_AXI_ARADDR[ADDR_LSB-1:0] == '0);
    
    assign aw_addr_in_range = (S_AXI_AWADDR[ADDR_WIDTH-1:RAM_OFFSET_BITS] == '0);
    assign ar_addr_in_range = (S_AXI_ARADDR[ADDR_WIDTH-1:RAM_OFFSET_BITS] == '0);
    
    assign aw_addr_valid = aw_addr_aligned && aw_addr_in_range;
    assign ar_addr_valid = ar_addr_aligned && ar_addr_in_range;
    
    assign aw_word_index = S_AXI_AWADDR[RAM_OFFSET_BITS-1:ADDR_LSB];
    assign ar_word_index = S_AXI_ARADDR[RAM_OFFSET_BITS-1:ADDR_LSB];
    // ========================================================
    // AXI Write Strobe Helper
    // ========================================================

    function automatic logic [DATA_WIDTH-1:0] apply_wstrb;
        input logic [DATA_WIDTH-1:0]     old_value;
        input logic [DATA_WIDTH-1:0]     new_value;
        input logic [BYTE_LANES-1:0]     wstrb;

        logic [DATA_WIDTH-1:0] result;
        int i;

        begin
            result = old_value;

            for (i = 0; i < BYTE_LANES; i++) begin
                if (wstrb[i]) begin
                    result[i*8 +: 8] = new_value[i*8 +: 8];
                end
            end

            return result;
        end
    endfunction

    // ========================================================
    // AXI4-Lite Write Logic
    // ========================================================

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= AXI_RESP_OKAY;
        end else begin

            // Complete write response
            if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
                S_AXI_BRESP  <= AXI_RESP_OKAY;
            end

            // Accept write transaction
            if (write_fire && !S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b1;

                if (aw_addr_valid) begin
                    S_AXI_BRESP <= AXI_RESP_OKAY;

                    mem[aw_word_index] <= apply_wstrb(
                        mem[aw_word_index],
                        S_AXI_WDATA,
                        S_AXI_WSTRB
                    );
                end else begin
                    S_AXI_BRESP <= AXI_RESP_SLVERR;
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
            S_AXI_RRESP  <= AXI_RESP_OKAY;
        end else begin

            // Complete read response
            if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
                S_AXI_RRESP  <= AXI_RESP_OKAY;
            end

            // Accept read address
            else if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                S_AXI_RVALID <= 1'b1;

                if (ar_addr_valid) begin
                    S_AXI_RRESP <= AXI_RESP_OKAY;
                    S_AXI_RDATA <= mem[ar_word_index];
                end else begin
                    S_AXI_RRESP <= AXI_RESP_SLVERR;
                    S_AXI_RDATA <= '0;
                end
            end
        end
    end

endmodule
