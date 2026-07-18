module ram #(
    parameter int unsigned WORDS = 4096,
    parameter int unsigned LATENCY = 0,
    parameter string INIT_FILE = "",
    parameter int unsigned ADDR_W =
        (WORDS <= 1) ? 1 : $clog2(WORDS)
) (
    input logic CLK,
    input logic nRST,

    input  logic        ramREN,
    input  logic        ramWEN,
    input  logic [31:0] ramaddr,
    input  logic [31:0] ramstore,
    input  logic [3:0]  ram_wstrb,

    output logic [31:0] ramload,
    output logic        ram_ready,
    output logic        busy,

    input  logic [ADDR_W-1:0] dbg_addr,
    output logic [31:0]       dbg_data_out
);

    localparam int unsigned COUNT_W =
        (LATENCY <= 1) ? 1 : $clog2(LATENCY + 1);

    logic [31:0] mem [0:WORDS-1];

    logic [31:0] request_addr;
    logic [31:0] request_store;
    logic [3:0]  request_wstrb;
    logic        request_write;

    logic [COUNT_W-1:0] count;

    wire [ADDR_W-1:0] request_index =
        request_addr[ADDR_W+1:2];

    integer byte_index;

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    assign dbg_data_out = mem[dbg_addr];

    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST) begin
            request_addr  <= '0;
            request_store <= '0;
            request_wstrb <= '0;
            request_write <= 1'b0;
            count         <= '0;
            ramload       <= '0;
            ram_ready     <= 1'b0;
            busy          <= 1'b0;
        end
        else begin
            ram_ready <= 1'b0;

            if (!busy && (ramREN || ramWEN)) begin
                request_addr  <= ramaddr;
                request_store <= ramstore;
                request_wstrb <= ram_wstrb;
                request_write <= ramWEN;
                count         <= COUNT_W'(LATENCY);
                busy          <= 1'b1;
            end
            else if (busy) begin
                if (count == COUNT_W'(0)) begin
                    if (request_write) begin
                        for (byte_index = 0;
                             byte_index < 4;
                             byte_index = byte_index + 1) begin
                            if (request_wstrb[byte_index]) begin
                                mem[request_index][8*byte_index +: 8]
                                    <= request_store[
                                        8*byte_index +: 8
                                    ];
                            end
                        end
                    end
                    else begin
                        ramload <= mem[request_index];
                    end

                    ram_ready <= 1'b1;
                    busy      <= 1'b0;
                end
                else begin
                    count <= count - COUNT_W'(1);
                end
            end
        end
    end

endmodule
