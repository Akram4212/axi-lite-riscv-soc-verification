module memory_control (
    input logic CLK,
    input logic nRST,

    // Core-side instruction request.
    input  logic        imemREN,
    input  logic [31:0] imemaddr,
    output logic        ihit,
    output logic [31:0] imemload,

    // Core-side data request.
    input  logic        dmemREN,
    input  logic        dmemWEN,
    input  logic [31:0] dmemaddr,
    input  logic [31:0] dmemstore,
    input  logic [3:0]  dmem_wstrb,
    output logic        dhit,
    output logic [31:0] dmemload,

    // Single-port RAM request.
    output logic        ramREN,
    output logic        ramWEN,
    output logic [31:0] ramaddr,
    output logic [31:0] ramstore,
    output logic [3:0]  ram_wstrb,
    input  logic [31:0] ramload,
    input  logic        ram_ready
);

    typedef enum logic [1:0] {
        IDLE,
        IMEM_ACCESS,
        DMEM_READ,
        DMEM_WRITE
    } state_t;

    state_t state;
    state_t next_state;

    logic [31:0] request_addr;
    logic [31:0] next_request_addr;

    logic [31:0] request_store;
    logic [31:0] next_request_store;

    logic [3:0] request_wstrb;
    logic [3:0] next_request_wstrb;

    always_comb begin
        next_state         = state;
        next_request_addr  = request_addr;
        next_request_store = request_store;
        next_request_wstrb = request_wstrb;

        case (state)
            IDLE: begin
                // Preserve the original controller's data-over-instruction
                // arbitration priority.
                if (dmemWEN) begin
                    next_request_addr  = dmemaddr;
                    next_request_store = dmemstore;
                    next_request_wstrb = dmem_wstrb;
                    next_state         = DMEM_WRITE;
                end
                else if (dmemREN) begin
                    next_request_addr  = dmemaddr;
                    next_request_store = '0;
                    next_request_wstrb = '0;
                    next_state         = DMEM_READ;
                end
                else if (imemREN) begin
                    next_request_addr  = imemaddr;
                    next_request_store = '0;
                    next_request_wstrb = '0;
                    next_state         = IMEM_ACCESS;
                end
            end

            IMEM_ACCESS,
            DMEM_READ,
            DMEM_WRITE: begin
                if (ram_ready) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_comb begin
        ramREN    = 1'b0;
        ramWEN    = 1'b0;
        ramaddr   = request_addr;
        ramstore  = request_store;
        ram_wstrb = request_wstrb;

        ihit     = 1'b0;
        imemload = ramload;

        dhit     = 1'b0;
        dmemload = ramload;

        case (state)
            IMEM_ACCESS: begin
                ramREN = 1'b1;

                if (ram_ready) begin
                    ihit     = 1'b1;
                    imemload = ramload;
                end
            end

            DMEM_READ: begin
                ramREN = 1'b1;

                if (ram_ready) begin
                    dhit     = 1'b1;
                    dmemload = ramload;
                end
            end

            DMEM_WRITE: begin
                ramWEN = 1'b1;

                if (ram_ready) begin
                    dhit = 1'b1;
                end
            end

            default: begin
                // Defaults are safe and side-effect free.
            end
        endcase
    end

    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            state         <= IDLE;
            request_addr  <= '0;
            request_store <= '0;
            request_wstrb <= '0;
        end
        else begin
            state         <= next_state;
            request_addr  <= next_request_addr;
            request_store <= next_request_store;
            request_wstrb <= next_request_wstrb;
        end
    end

endmodule
