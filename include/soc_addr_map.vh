`ifndef SOC_ADDR_MAP_VH
`define SOC_ADDR_MAP_VH

// Peripheral base addresses
`define GPIO_BASE_ADDR   32'h1000_0000
`define TIMER_BASE_ADDR  32'h1000_1000

// 4 KB address regions
`define ADDR_MASK        32'hFFFF_F000

// AXI response codes
`define AXI_RESP_OKAY    2'b00
`define AXI_RESP_SLVERR  2'b10

`endif
