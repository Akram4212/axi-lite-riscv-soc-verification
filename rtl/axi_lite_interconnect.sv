`timescale 1ns/1ps

`include "soc_addr_map.vh"

module axi_lite_interconnect #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input  logic                         ACLK,
    input  logic                         ARESETn,

    // ========================================================
    // AXI-Lite Slave Interface
    // From external master / cocotb / future CPU
    // ========================================================

    // Write address channel
    input  logic [ADDR_WIDTH-1:0]         S_AXI_AWADDR,
    input  logic                         S_AXI_AWVALID,
    output logic                         S_AXI_AWREADY,

    // Write data channel
    input  logic [DATA_WIDTH-1:0]         S_AXI_WDATA,
    input  logic [(DATA_WIDTH/8)-1:0]     S_AXI_WSTRB,
    input  logic                         S_AXI_WVALID,
    output logic                         S_AXI_WREADY,

    // Write response channel
    output logic [1:0]                   S_AXI_BRESP,
    output logic                         S_AXI_BVALID,
    input  logic                         S_AXI_BREADY,

    // Read address channel
    input  logic [ADDR_WIDTH-1:0]         S_AXI_ARADDR,
    input  logic                         S_AXI_ARVALID,
    output logic                         S_AXI_ARREADY,

    // Read data channel
    output logic [DATA_WIDTH-1:0]         S_AXI_RDATA,
    output logic [1:0]                   S_AXI_RRESP,
    output logic                         S_AXI_RVALID,
    input  logic                         S_AXI_RREADY,

    // ========================================================
    // AXI-Lite Master Interface to RAM
    // Connect these to axi_lite_ram.sv S_AXI_* ports
    // ========================================================

    output logic [ADDR_WIDTH-1:0]         M_RAM_AWADDR,
    output logic                         M_RAM_AWVALID,
    input  logic                         M_RAM_AWREADY,

    output logic [DATA_WIDTH-1:0]         M_RAM_WDATA,
    output logic [(DATA_WIDTH/8)-1:0]     M_RAM_WSTRB,
    output logic                         M_RAM_WVALID,
    input  logic                         M_RAM_WREADY,

    input  logic [1:0]                   M_RAM_BRESP,
    input  logic                         M_RAM_BVALID,
    output logic                         M_RAM_BREADY,

    output logic [ADDR_WIDTH-1:0]         M_RAM_ARADDR,
    output logic                         M_RAM_ARVALID,
    input  logic                         M_RAM_ARREADY,

    input  logic [DATA_WIDTH-1:0]         M_RAM_RDATA,
    input  logic [1:0]                   M_RAM_RRESP,
    input  logic                         M_RAM_RVALID,
    output logic                         M_RAM_RREADY,

    // ========================================================
    // AXI-Lite Master Interface to GPIO
    // Connect these to gpio.sv S_AXI_* ports
    // ========================================================

    output logic [ADDR_WIDTH-1:0]         M_GPIO_AWADDR,
    output logic                         M_GPIO_AWVALID,
    input  logic                         M_GPIO_AWREADY,

    output logic [DATA_WIDTH-1:0]         M_GPIO_WDATA,
    output logic [(DATA_WIDTH/8)-1:0]     M_GPIO_WSTRB,
    output logic                         M_GPIO_WVALID,
    input  logic                         M_GPIO_WREADY,

    input  logic [1:0]                   M_GPIO_BRESP,
    input  logic                         M_GPIO_BVALID,
    output logic                         M_GPIO_BREADY,

    output logic [ADDR_WIDTH-1:0]         M_GPIO_ARADDR,
    output logic                         M_GPIO_ARVALID,
    input  logic                         M_GPIO_ARREADY,

    input  logic [DATA_WIDTH-1:0]         M_GPIO_RDATA,
    input  logic [1:0]                   M_GPIO_RRESP,
    input  logic                         M_GPIO_RVALID,
    output logic                         M_GPIO_RREADY,

    // ========================================================
    // AXI-Lite Master Interface to Timer
    // Connect these to timer.sv S_AXI_* ports
    // ========================================================

    output logic [ADDR_WIDTH-1:0]         M_TIMER_AWADDR,
    output logic                         M_TIMER_AWVALID,
    input  logic                         M_TIMER_AWREADY,

    output logic [DATA_WIDTH-1:0]         M_TIMER_WDATA,
    output logic [(DATA_WIDTH/8)-1:0]     M_TIMER_WSTRB,
    output logic                         M_TIMER_WVALID,
    input  logic                         M_TIMER_WREADY,

    input  logic [1:0]                   M_TIMER_BRESP,
    input  logic                         M_TIMER_BVALID,
    output logic                         M_TIMER_BREADY,

    output logic [ADDR_WIDTH-1:0]         M_TIMER_ARADDR,
    output logic                         M_TIMER_ARVALID,
    input  logic                         M_TIMER_ARREADY,

    input  logic [DATA_WIDTH-1:0]         M_TIMER_RDATA,
    input  logic [1:0]                   M_TIMER_RRESP,
    input  logic                         M_TIMER_RVALID,
    output logic                         M_TIMER_RREADY
);

    // ========================================================
    // Slave Select Encoding
    // ========================================================

    typedef enum logic [2:0] {
        SEL_NONE  = 3'b000,
        SEL_RAM   = 3'b001,
        SEL_GPIO  = 3'b010,
        SEL_TIMER = 3'b011,
        SEL_ERROR = 3'b100
    } slave_sel_t;

    slave_sel_t write_sel;
    slave_sel_t read_sel;

    slave_sel_t aw_decode;
    slave_sel_t ar_decode;

    logic write_idle;
    logic read_idle;

    logic invalid_write_resp_valid;
    logic invalid_read_resp_valid;

    // ========================================================
    // Address Decode
    // ========================================================

    function automatic slave_sel_t decode_addr;
        input logic [ADDR_WIDTH-1:0] addr;

        begin
            if ((addr & `ADDR_MASK) == `RAM_BASE_ADDR) begin
                decode_addr = SEL_RAM;
            end else if ((addr & `ADDR_MASK) == `GPIO_BASE_ADDR) begin
                decode_addr = SEL_GPIO;
            end else if ((addr & `ADDR_MASK) == `TIMER_BASE_ADDR) begin
                decode_addr = SEL_TIMER;
            end else begin
                decode_addr = SEL_ERROR;
            end
        end
    endfunction

    function automatic logic [ADDR_WIDTH-1:0] local_addr;
        input logic [ADDR_WIDTH-1:0] addr;
        input slave_sel_t            sel;

        begin
            case (sel)
                SEL_RAM: begin
                    local_addr = addr - `RAM_BASE_ADDR;
                end

                SEL_GPIO: begin
                    local_addr = addr - `GPIO_BASE_ADDR;
                end

                SEL_TIMER: begin
                    local_addr = addr - `TIMER_BASE_ADDR;
                end

                default: begin
                    local_addr = addr;
                end
            endcase
        end
    endfunction

    assign aw_decode = decode_addr(S_AXI_AWADDR);
    assign ar_decode = decode_addr(S_AXI_ARADDR);

    assign write_idle = (write_sel == SEL_NONE) && !invalid_write_resp_valid;
    assign read_idle  = (read_sel  == SEL_NONE) && !invalid_read_resp_valid;

    // ========================================================
    // Combinational AXI Routing
    // ========================================================

    always_comb begin
        // ----------------------------------------------------
        // Default master-side responses
        // ----------------------------------------------------
        S_AXI_AWREADY = 1'b0;
        S_AXI_WREADY  = 1'b0;

        S_AXI_BVALID  = 1'b0;
        S_AXI_BRESP   = `AXI_RESP_OKAY;

        S_AXI_ARREADY = 1'b0;

        S_AXI_RVALID  = 1'b0;
        S_AXI_RDATA   = '0;
        S_AXI_RRESP   = `AXI_RESP_OKAY;

        // ----------------------------------------------------
        // Default RAM outputs
        // ----------------------------------------------------
        M_RAM_AWADDR  = local_addr(S_AXI_AWADDR, SEL_RAM);
        M_RAM_AWVALID = 1'b0;

        M_RAM_WDATA   = S_AXI_WDATA;
        M_RAM_WSTRB   = S_AXI_WSTRB;
        M_RAM_WVALID  = 1'b0;

        M_RAM_BREADY  = 1'b0;

        M_RAM_ARADDR  = local_addr(S_AXI_ARADDR, SEL_RAM);
        M_RAM_ARVALID = 1'b0;

        M_RAM_RREADY  = 1'b0;

        // ----------------------------------------------------
        // Default GPIO outputs
        // ----------------------------------------------------
        M_GPIO_AWADDR  = local_addr(S_AXI_AWADDR, SEL_GPIO);
        M_GPIO_AWVALID = 1'b0;

        M_GPIO_WDATA   = S_AXI_WDATA;
        M_GPIO_WSTRB   = S_AXI_WSTRB;
        M_GPIO_WVALID  = 1'b0;

        M_GPIO_BREADY  = 1'b0;

        M_GPIO_ARADDR  = local_addr(S_AXI_ARADDR, SEL_GPIO);
        M_GPIO_ARVALID = 1'b0;

        M_GPIO_RREADY  = 1'b0;

        // ----------------------------------------------------
        // Default Timer outputs
        // ----------------------------------------------------
        M_TIMER_AWADDR  = local_addr(S_AXI_AWADDR, SEL_TIMER);
        M_TIMER_AWVALID = 1'b0;

        M_TIMER_WDATA   = S_AXI_WDATA;
        M_TIMER_WSTRB   = S_AXI_WSTRB;
        M_TIMER_WVALID  = 1'b0;

        M_TIMER_BREADY  = 1'b0;

        M_TIMER_ARADDR  = local_addr(S_AXI_ARADDR, SEL_TIMER);
        M_TIMER_ARVALID = 1'b0;

        M_TIMER_RREADY  = 1'b0;

        // ====================================================
        // Write Address/Data Routing
        //
        // Simplified AXI-Lite behavior:
        // This interconnect accepts AW and W together.
        // ====================================================

        if (write_idle && S_AXI_AWVALID && S_AXI_WVALID) begin
            case (aw_decode)

                SEL_RAM: begin
                    S_AXI_AWREADY = M_RAM_AWREADY;
                    S_AXI_WREADY  = M_RAM_WREADY;

                    M_RAM_AWVALID = S_AXI_AWVALID;
                    M_RAM_WVALID  = S_AXI_WVALID;
                end

                SEL_GPIO: begin
                    S_AXI_AWREADY = M_GPIO_AWREADY;
                    S_AXI_WREADY  = M_GPIO_WREADY;

                    M_GPIO_AWVALID = S_AXI_AWVALID;
                    M_GPIO_WVALID  = S_AXI_WVALID;
                end

                SEL_TIMER: begin
                    S_AXI_AWREADY = M_TIMER_AWREADY;
                    S_AXI_WREADY  = M_TIMER_WREADY;

                    M_TIMER_AWVALID = S_AXI_AWVALID;
                    M_TIMER_WVALID  = S_AXI_WVALID;
                end

                default: begin
                    // Invalid address: accept transaction and generate SLVERR.
                    S_AXI_AWREADY = 1'b1;
                    S_AXI_WREADY  = 1'b1;
                end

            endcase
        end

        // ====================================================
        // Write Response Routing
        // ====================================================

        if (invalid_write_resp_valid) begin
            S_AXI_BVALID = 1'b1;
            S_AXI_BRESP  = `AXI_RESP_SLVERR;
        end else begin
            case (write_sel)

                SEL_RAM: begin
                    S_AXI_BVALID = M_RAM_BVALID;
                    S_AXI_BRESP  = M_RAM_BRESP;
                    M_RAM_BREADY = S_AXI_BREADY;
                end

                SEL_GPIO: begin
                    S_AXI_BVALID  = M_GPIO_BVALID;
                    S_AXI_BRESP   = M_GPIO_BRESP;
                    M_GPIO_BREADY = S_AXI_BREADY;
                end

                SEL_TIMER: begin
                    S_AXI_BVALID   = M_TIMER_BVALID;
                    S_AXI_BRESP    = M_TIMER_BRESP;
                    M_TIMER_BREADY = S_AXI_BREADY;
                end

                default: begin
                    S_AXI_BVALID = 1'b0;
                    S_AXI_BRESP  = `AXI_RESP_OKAY;
                end

            endcase
        end

        // ====================================================
        // Read Address Routing
        // ====================================================

        if (read_idle && S_AXI_ARVALID) begin
            case (ar_decode)

                SEL_RAM: begin
                    S_AXI_ARREADY = M_RAM_ARREADY;
                    M_RAM_ARVALID = S_AXI_ARVALID;
                end

                SEL_GPIO: begin
                    S_AXI_ARREADY  = M_GPIO_ARREADY;
                    M_GPIO_ARVALID = S_AXI_ARVALID;
                end

                SEL_TIMER: begin
                    S_AXI_ARREADY   = M_TIMER_ARREADY;
                    M_TIMER_ARVALID = S_AXI_ARVALID;
                end

                default: begin
                    // Invalid address: accept transaction and generate SLVERR.
                    S_AXI_ARREADY = 1'b1;
                end

            endcase
        end

        // ====================================================
        // Read Data Routing
        // ====================================================

        if (invalid_read_resp_valid) begin
            S_AXI_RVALID = 1'b1;
            S_AXI_RDATA  = '0;
            S_AXI_RRESP  = `AXI_RESP_SLVERR;
        end else begin
            case (read_sel)

                SEL_RAM: begin
                    S_AXI_RVALID = M_RAM_RVALID;
                    S_AXI_RDATA  = M_RAM_RDATA;
                    S_AXI_RRESP  = M_RAM_RRESP;
                    M_RAM_RREADY = S_AXI_RREADY;
                end

                SEL_GPIO: begin
                    S_AXI_RVALID  = M_GPIO_RVALID;
                    S_AXI_RDATA   = M_GPIO_RDATA;
                    S_AXI_RRESP   = M_GPIO_RRESP;
                    M_GPIO_RREADY = S_AXI_RREADY;
                end

                SEL_TIMER: begin
                    S_AXI_RVALID   = M_TIMER_RVALID;
                    S_AXI_RDATA    = M_TIMER_RDATA;
                    S_AXI_RRESP    = M_TIMER_RRESP;
                    M_TIMER_RREADY = S_AXI_RREADY;
                end

                default: begin
                    S_AXI_RVALID = 1'b0;
                    S_AXI_RDATA  = '0;
                    S_AXI_RRESP  = `AXI_RESP_OKAY;
                end

            endcase
        end
    end

    // ========================================================
    // Sequential Transaction Tracking
    // ========================================================

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            write_sel                <= SEL_NONE;
            read_sel                 <= SEL_NONE;
            invalid_write_resp_valid <= 1'b0;
            invalid_read_resp_valid  <= 1'b0;
        end else begin

            // ------------------------------------------------
            // Write transaction accepted
            // ------------------------------------------------
            if (write_idle &&
                S_AXI_AWVALID && S_AXI_AWREADY &&
                S_AXI_WVALID  && S_AXI_WREADY) begin

                case (aw_decode)

                    SEL_RAM: begin
                        write_sel <= SEL_RAM;
                    end

                    SEL_GPIO: begin
                        write_sel <= SEL_GPIO;
                    end

                    SEL_TIMER: begin
                        write_sel <= SEL_TIMER;
                    end

                    default: begin
                        invalid_write_resp_valid <= 1'b1;
                    end

                endcase
            end

            // ------------------------------------------------
            // Write response completed
            // ------------------------------------------------
            if (invalid_write_resp_valid && S_AXI_BREADY) begin
                invalid_write_resp_valid <= 1'b0;
            end

            if ((write_sel == SEL_RAM) &&
                M_RAM_BVALID && S_AXI_BREADY) begin
                write_sel <= SEL_NONE;
            end

            if ((write_sel == SEL_GPIO) &&
                M_GPIO_BVALID && S_AXI_BREADY) begin
                write_sel <= SEL_NONE;
            end

            if ((write_sel == SEL_TIMER) &&
                M_TIMER_BVALID && S_AXI_BREADY) begin
                write_sel <= SEL_NONE;
            end

            // ------------------------------------------------
            // Read transaction accepted
            // ------------------------------------------------
            if (read_idle &&
                S_AXI_ARVALID && S_AXI_ARREADY) begin

                case (ar_decode)

                    SEL_RAM: begin
                        read_sel <= SEL_RAM;
                    end

                    SEL_GPIO: begin
                        read_sel <= SEL_GPIO;
                    end

                    SEL_TIMER: begin
                        read_sel <= SEL_TIMER;
                    end

                    default: begin
                        invalid_read_resp_valid <= 1'b1;
                    end

                endcase
            end

            // ------------------------------------------------
            // Read response completed
            // ------------------------------------------------
            if (invalid_read_resp_valid && S_AXI_RREADY) begin
                invalid_read_resp_valid <= 1'b0;
            end

            if ((read_sel == SEL_RAM) &&
                M_RAM_RVALID && S_AXI_RREADY) begin
                read_sel <= SEL_NONE;
            end

            if ((read_sel == SEL_GPIO) &&
                M_GPIO_RVALID && S_AXI_RREADY) begin
                read_sel <= SEL_NONE;
            end

            if ((read_sel == SEL_TIMER) &&
                M_TIMER_RVALID && S_AXI_RREADY) begin
                read_sel <= SEL_NONE;
            end
        end
    end

endmodule
