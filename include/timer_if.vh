`ifndef TIMER_IF_VH
`define TIMER_IF_VH

// Timer register offsets
`define TIMER_REG_CTRL      6'h00
`define TIMER_REG_COUNT     6'h04
`define TIMER_REG_COMPARE   6'h08
`define TIMER_REG_STATUS    6'h0C

// AXI-Lite response codes
`define TIMER_AXI_RESP_OKAY    2'b00
`define TIMER_AXI_RESP_SLVERR  2'b10

`endif
