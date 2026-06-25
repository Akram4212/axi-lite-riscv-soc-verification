// ============================================================
// gpio_if.vh
// GPIO register map and AXI response constants
// ============================================================

`ifndef GPIO_IF_VH
`define GPIO_IF_VH

// ---------------- AXI4-Lite response codes ----------------
`define GPIO_AXI_RESP_OKAY    2'b00
`define GPIO_AXI_RESP_EXOKAY  2'b01
`define GPIO_AXI_RESP_SLVERR  2'b10
`define GPIO_AXI_RESP_DECERR  2'b11

// ---------------- GPIO register offsets ----------------
//
// Base address is handled by the AXI interconnect.
// Inside this GPIO peripheral, we only decode the offset.
//
// Register map:
//   0x00  DATA_OUT      RW
//   0x04  DATA_IN       RO
//   0x08  DATA_DIR      RW
//   0x0C  DATA_OUT_SET  WO
//   0x10  DATA_OUT_CLR  WO

`define GPIO_REG_DATA_OUT      6'h00
`define GPIO_REG_DATA_IN       6'h04
`define GPIO_REG_DATA_DIR      6'h08
`define GPIO_REG_DATA_OUT_SET  6'h0C
`define GPIO_REG_DATA_OUT_CLR  6'h10

`endif