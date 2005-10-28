//: mmu_t.v
//: toplevel module for testing mmu and ram
//: Salent v0.13
//: Copyright (c) 2005 Agent Zhang
//: 2005-08-25 2005-08-31

module mmu_t (mfc, strb, rw, mar, byte);
    parameter ADDR_SIZE = 32,
              WORD_SIZE = 32;

    wire bus_mfc;
    wire bus_strb, bus_rw;
    wire [ADDR_SIZE-1:0] bus_addr;
    wire [WORD_SIZE-1:0] bus_data;

    output mfc;
    input  strb, rw;
    input  [ADDR_SIZE-1:0] mar;
    inout  [7:0] byte;

    ram Ram(bus_mfc, bus_strb, bus_rw, bus_addr, bus_data);
    mmu Mmu(bus_strb, bus_rw, bus_addr, bus_mfc, bus_data,
            mfc, strb, rw, mar, byte);
endmodule
