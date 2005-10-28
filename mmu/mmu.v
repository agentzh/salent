//: mmu.v
//: Memory Maneagement Units(MMU)
//: Salent v0.12
//: Copyright (c) 2005 Wan Xunxin. All rights reserved.
//: 2005-08-04 2005-08-31

module mmu (bus_strb, bus_rw, bus_addr, bus_mfc, bus_data,
            mfc, strb, rw, mar, byte);
    parameter ADDR_SIZE = 32,
              WORD_SIZE = 32;

    output bus_strb, bus_rw;
    output [ADDR_SIZE-1:0] bus_addr;
    input  bus_mfc;
    inout  [WORD_SIZE-1:0] bus_data;

    reg bus_strb,bus_rw;
    reg [ADDR_SIZE-1:0] bus_addr;

    output mfc;
    input  strb, rw;
    input  [ADDR_SIZE-1:0] mar;
    inout  [7:0] byte;

    reg  mfc;

    reg [WORD_SIZE-1:0] data, datar, dataw ;
    reg [7:0] bytedata;

    assign byte = bytedata;
    assign bus_data = dataw;
    assign address = mar[1:0];
    always begin: mmu
        reg first_time;
        mfc = 1'b0;
        bus_rw = 1'b0;
        dataw = 32'bz;
        datar = 32'bz;
        data  = 32'bz;
        bytedata = 8'bz;
        bus_addr = 32'bz;
        bus_strb = 1'b0;
        first_time = 1'b1;
        forever begin
            @ (posedge strb);  
            if (first_time == 1'b1 || bus_addr[ADDR_SIZE-1:2] != mar[ADDR_SIZE-1:2]) begin
                if (first_time == 1'b1) begin
                    first_time = 1'b0;
                end
                bus_addr = mar;
                bus_rw = 1'b1;
                bus_strb = 1'b1;
                @ (posedge bus_mfc);
                $display(bus_data);
                data = bus_data;
                $display(data);
                bus_strb = 1'b0;
                #5;
            end
            if (rw) begin
                datar = data;
                case (address)
                    2'b11: bytedata = datar[3*8+7 : 3*8];
                    2'b10: bytedata = datar[2*8+7 : 2*8];
                    2'b01: bytedata = datar[1*8+7 : 1*8];
                    2'b00: bytedata = datar[0*8+7 : 0*8];
                endcase
            end else begin
                dataw = data;
                bytedata = byte;
                case (address)
                    2'b11: dataw[3*8+7 : 3*8] = bytedata;
                    2'b10: dataw[2*8+7 : 2*8] = bytedata;
                    2'b01: dataw[1*8+7 : 1*8] = bytedata;
                    2'b00: dataw[0*8+7 : 0*8] = bytedata;
                endcase
                data = dataw;
                bus_addr = mar;
                bus_rw = 1'b0;
                bus_strb = 1'b1;
                @ (posedge bus_mfc);
                bus_strb = 1'b0;
            end
            #5;
            mfc = 1'b1;
            @ (negedge strb);
            mfc = 1'b0;
            dataw = 32'bz;
            bytedata = 8'bz;
        end
    end
endmodule
