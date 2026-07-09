`ifndef GPIO_IF_VH
`define GPIO_IF_VH

// ============================================================
// GPIO Register Map
// ============================================================
// Local AXI-Lite register offsets
`define GPIO_REG_DATA_OUT      6'h00
`define GPIO_REG_DATA_IN       6'h04
`define GPIO_REG_DATA_DIR      6'h08
`define GPIO_REG_DATA_OUT_SET  6'h0C
`define GPIO_REG_DATA_OUT_CLR  6'h10

// ============================================================
// AXI-Lite Response Codes
// ============================================================
`define GPIO_AXI_RESP_OKAY     2'b00
`define GPIO_AXI_RESP_EXOKAY   2'b01
`define GPIO_AXI_RESP_SLVERR   2'b10
`define GPIO_AXI_RESP_DECERR   2'b11

`endif // GPIO_IF_VH
