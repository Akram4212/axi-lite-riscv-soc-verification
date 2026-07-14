`ifndef SOC_ADDR_MAP_VH
`define SOC_ADDR_MAP_VH

// ============================================================
// AXI-Lite SoC Address Map
// ============================================================
//
// RAM   : 0x0000_0000 - 0x0000_0FFF
// GPIO  : 0x1000_0000 - 0x1000_0FFF
// Timer : 0x1000_1000 - 0x1000_1FFF
//
// Each peripheral currently occupies a 4 KB region.
// ============================================================

`define RAM_BASE_ADDR    32'h0000_0000
`define GPIO_BASE_ADDR   32'h1000_0000
`define TIMER_BASE_ADDR  32'h1000_1000

// 4 KB address region mask
`define ADDR_MASK        32'hFFFF_F000

// AXI-Lite response codes
`define AXI_RESP_OKAY    2'b00
`define AXI_RESP_SLVERR  2'b10

`endif
