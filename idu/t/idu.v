//: idu.v
//: Verilog implemetation of Instruction Decoding Unit (IDU)
//: Salent v0.13
//: Copyright (c) 2005 Agent Zhang
//: 2005-09-11 2005-10-22

module idu (strb, rw, addr, mfc, data,
            ins, mod, rm, scale, index_reg, base_reg,
            bits16, disp, disp_len, imm, imm_len, bits16,
            s, w, d, R,
            reg1, reg2, sreg2, sreg3, eee, tttn, ST_i,
            rdy, pc_out, pc_in, reset, run, clk,
            error);

    parameter ADDR_SIZE = 32;
    parameter DISP_LEN  = 4;
    parameter IMM_LEN   = 6;

    parameter SYNTAX_ERROR = 0;
    parameter END_ERROR    = 1;

    output strb;
    reg    strb;
    output rw;

    output [ADDR_SIZE-1:0] addr;
    reg    [ADDR_SIZE-1:0] addr;

    input mfc;

    inout[7:0] data;

    output [2:0] ins;
    reg    [2:0] ins;

    output [1:0] mod;
    reg    [1:0] mod;

    output [2:0] rm;
    reg    [2:0] rm;

    output [1:0] scale;
    reg    [1:0] scale;

    output [2:0] index_reg;
    reg    [2:0] index_reg;

    output [2:0] base_reg;
    reg    [2:0] base_reg;

    output bits16;
    reg    bits16;

    output [DISP_LEN*8-1:0] disp;
    reg    [DISP_LEN*8-1:0] disp;

    output [2:0] disp_len;
    reg    [2:0] disp_len;

    output [IMM_LEN*8-1:0] imm;
    reg    [IMM_LEN*8-1:0] imm;

    output [2:0] imm_len;
    reg    [2:0] imm_len;
    output s, w, d, R;
    reg    s, w, d, R;

    output [2:0] reg1, reg2, sreg3, eee, ST_i;
    reg    [2:0] reg1, reg2, sreg3, eee, ST_i;

    output [1:0] sreg2;
    reg    [1:0] sreg2;

    output [3:0] tttn;
    reg    [3:0] tttn;

    output rdy;
    reg    rdy;

    output [ADDR_SIZE-1:0] pc_out;
    reg    [ADDR_SIZE-1:0] pc_out;

    input [ADDR_SIZE-1:0] pc_in;
    input reset, run, clk;

    output error;
    reg    error;

    //////////////////////////////////////////////////////////////////////////

    parameter S_0   = 5'b00000;
    parameter S_1   = 5'b00001;
    parameter S_2   = 5'b00010;
    parameter S_3   = 5'b00011;
    parameter S_4   = 5'b00100;
    parameter S_5   = 5'b00101;
    parameter S_6   = 5'b00110;
    parameter S_7   = 5'b00111;
    parameter S_8   = 5'b01000;
    parameter S_9   = 5'b01001;
    parameter S_10  = 5'b01010;
    parameter S_11  = 5'b01011;
    parameter S_12  = 5'b01100;
    parameter S_13  = 5'b01101;
    parameter S_START         = 5'b01110;
    parameter S_PREFIX        = 5'b01111;
    parameter S_END_ERROR     = 5'b10000;
    parameter S_SYN_ERROR     = 5'b10001;

    //////////////////////////////////////////////////////////////////////////

    reg [5-1:0] state;
    reg [5-1:0] next_state;
    reg [7:0] byte;

    task read_byte;
      begin
        // read one byte:
        addr = pc_out;
        strb = 1'b1;
        @ (posedge mfc);
        byte = data;
        strb = 1'b0;
        pc_out = pc_out + 1;
      end
    endtask

    task read_disp1;
      begin

        // read one byte:
        read_byte;
        disp[7:0] = byte;
        disp_len = 1;
      end
    endtask

    task read_disp4;
      begin

        // read one byte:
        read_byte;
        disp[7:0] = byte;

        // read one byte:
        read_byte;
        disp[15:8] = byte;

        // read one byte:
        read_byte;
        disp[23:16] = byte;

        // read one byte:
        read_byte;
        disp[31:24] = byte;
        disp_len = 4;
      end
    endtask

    task read_imm_data1;
      begin

        // read one byte:
        read_byte;
        imm[7:0] = byte;
        imm_len = 1;
      end
    endtask

    task read_imm_data2;
      begin

        // read one byte:
        read_byte;
        imm[7:0] = byte;

        // read one byte:
        read_byte;
        imm[15:8] = byte;
        imm_len = 2;
      end
    endtask

    task read_imm_data3;
      begin

        // read one byte:
        read_byte;
        imm[7:0] = byte;

        // read one byte:
        read_byte;
        imm[15:8] = byte;

        // read one byte:
        read_byte;
        imm[23:16] = byte;
        imm_len = 3;
      end
    endtask

    task read_imm_data4;
      begin

        // read one byte:
        read_byte;
        imm[7:0] = byte;

        // read one byte:
        read_byte;
        imm[15:8] = byte;

        // read one byte:
        read_byte;
        imm[23:16] = byte;

        // read one byte:
        read_byte;
        imm[31:24] = byte;
        imm_len = 4;
      end
    endtask

    task read_imm_data6;
      begin

        // read one byte:
        read_byte;
        imm[7:0] = byte;

        // read one byte:
        read_byte;
        imm[15:8] = byte;

        // read one byte:
        read_byte;
        imm[23:16] = byte;

        // read one byte:
        read_byte;
        imm[31:24] = byte;

        // read one byte:
        read_byte;
        imm[39:32] = byte;

        // read one byte:
        read_byte;
        imm[47:40] = byte;
        imm_len = 6;
      end
    endtask

    task get_imm_len;
      begin
        if ((s != 'bz) && !(w != 'bz))
          begin
            if (s == 1'b1) // 8-bit imm size
                imm_len = 1;
            else // full size imm size
              begin
                if (bits16 == 1'b1)
                    imm_len = 2;
                else
                    imm_len = 4;
              end
          end
        else if ((w != 'bz) && !(s != 'bz))
          begin
            if (w == 0) // 8-bit imm size
                imm_len = 1;
            else // full size imm size
              begin
                if (bits16 == 1'b1)
                    imm_len = 2;
                else
                    imm_len = 4;
              end
          end
        else if ((w != 'bz) && (s != 'bz))
          begin
            if (s == 1) // 8-bit imm size
                imm_len = 1;
            else if (w == 0) // 8-bit imm size
                imm_len = 1;
          end
        else // both w and s fields are absent
          begin
            if (bits16 == 1'b1)
                imm_len = 2;
            else
                imm_len = 4;
          end
      end
    endtask

    // Process the ModR/M byte:
    task process_ModRM;
        reg [2:0] base;
      begin
        mod = byte[7:6];
        rm  = byte[2:0];
        if (mod == 2'b00)   // Direct: EA = Disp32
            read_disp4;
        else if (rm == 3'b100)  // Base with index (uses SIB byte)
          begin
            // Get SIB byte:
            read_byte;
            scale = byte[7:6];
            index_reg = byte[5:3];
            base = byte[2:0];
            if (base == 3'b101)   // Base == EBP: EA = [Index] x Scale + Disp32
                read_disp4;     // Get 32-bit displacement:
            else   // EA = [Base] + [Index] x Scale
                base_reg = base;
          end
        else if (mod == 2'b01)
            if (rm == 3'b100)  // EA = [Base] + [Index] x Scale + Disp8
              begin
                // Get SIB byte:
                read_byte;
                scale = byte[7:6];
                index_reg = byte[5:3];
                base_reg  = byte[2:0];
                // Get 8-bit displacement:
                read_disp1;
              end
            else  // EA = [Reg] + Disp8
                read_disp1;   // Get 8-bit displacement:
        else if (mod == 2'b10)
          begin
            if (rm == 3'b100)  // EA = [Base] + [Index] x Scale + Disp32
                // Get SIB byte:
                read_byte;
                scale = byte[7:6];
                index_reg = byte[5:3];
                base_reg  = byte[2:0];
                // Get 32-bit displacement:
                read_disp4;
              end
            else   // EA = [Reg] + Disp32
                read_disp4;   // Get 32-bit displacement:
      end
    endtask

    assign rw = 1'b1;  // always read from ram

    always @ (run or clk or reset) begin
        if (reset == 1'b1)
            state = S_START;
        else if (run == 1'b1)
            state = next_state;
        else
            state = state;
    end

    always @ (run or reset or state) begin
        case(state)
        S_START:
          begin
            read_byte;
          end
        S_PREFIX:
          begin
            // Process preffix byte (if any):
            case(byte)
              8'hf2:
                begin
                    read_byte;
                    next_state = S_PREFIX;
                end
              8'hf3:
                begin
                    read_byte;
                    next_state = S_PREFIX;
                end
              8'hf0:
                begin
                    read_byte;
                    next_state = S_PREFIX;
                end
              8'h67:
                begin
                    read_byte;
                    next_state = S_PREFIX;
                end
              8'h66:
                begin
                    bits16 = 1'b1;
                    read_byte;
                    next_state = S_PREFIX;
                end
              8'h2e:
                begin
                    read_byte;
                    next_state = S_PREFIX;
                end
              8'h36:
                begin
                    read_byte;
                    next_state = S_PREFIX;
                end
              8'h3e:
                begin
                    read_byte;
                    next_state = S_PREFIX;
                end
              8'h26:
                begin
                    read_byte;
                    next_state = S_PREFIX;
                end
              8'h64:
                begin
                    read_byte;
                    next_state = S_PREFIX;
                end
              8'h65:
                begin
                    read_byte;
                    next_state = S_PREFIX;
                end
            default:
                next_state = S_0;
            endcase
          end

        S_0:
          begin


            casex (byte)
              8'b100000xx:
                next_state = S_1;
              8'b0001001x:
                next_state = S_6;
              8'b0001010x:
                next_state = S_9;
              8'b0001000x:
                next_state = S_11;
              default:
                next_state = S_SYN_ERROR;
            endcase
          end
        S_1:
          begin


            // Get the s field from the current byte:
            s = byte[1:1];
            // Get the w field from the current byte:
            w = byte[0:0];

            read_byte;            casex (byte)
              8'b11010xxx:
                next_state = S_4;
              8'bxx010xxx:
                next_state = S_2;
              default:
                next_state = S_SYN_ERROR;
            endcase
          end
        S_2:
          begin

            // Process the current ModR/M byte:
            process_ModRM;


            next_state = S_3;
          end
        S_3:
          begin


            // Get immediate data:
            get_imm_len;
            case (imm_len)
              1:
                  read_imm_data1;
              2:
                  read_imm_data2;
              3:
                  read_imm_data3;
              4:
                  read_imm_data4;
              6:
                  read_imm_data6;
            endcase


            ins = 6;
            rdy = 1;
            @ (negedge run);
            next_state = S_START;
            rdy = 0;
          end
        S_4:
          begin


            // Get the reg field from the current byte:
            reg1 = byte[2:0];

            next_state = S_5;
          end
        S_5:
          begin


            // Get immediate data:
            get_imm_len;
            case (imm_len)
              1:
                  read_imm_data1;
              2:
                  read_imm_data2;
              3:
                  read_imm_data3;
              4:
                  read_imm_data4;
              6:
                  read_imm_data6;
            endcase


            ins = 4;
            rdy = 1;
            @ (negedge run);
            next_state = S_START;
            rdy = 0;
          end
        S_6:
          begin


            // Get the w field from the current byte:
            w = byte[0:0];

            read_byte;            casex (byte)
              8'b11xxxxxx:
                next_state = S_8;
              8'bxxxxxxxx:
                next_state = S_7;
              default:
                next_state = S_SYN_ERROR;
            endcase
          end
        S_7:
          begin

            // Process the current ModR/M byte:
            process_ModRM;

            // Get the reg field from the current byte:
            reg1 = byte[5:3];

            ins = 2;
            rdy = 1;
            @ (negedge run);
            next_state = S_START;
            rdy = 0;
          end
        S_8:
          begin


            // Get the reg1 field from the current byte:
            reg1 = byte[5:3];
            // Get the reg2 field from the current byte:
            reg2 = byte[2:0];

            ins = 1;
            rdy = 1;
            @ (negedge run);
            next_state = S_START;
            rdy = 0;
          end
        S_9:
          begin


            // Get the w field from the current byte:
            w = byte[0:0];

            next_state = S_10;
          end
        S_10:
          begin


            // Get immediate data:
            get_imm_len;
            case (imm_len)
              1:
                  read_imm_data1;
              2:
                  read_imm_data2;
              3:
                  read_imm_data3;
              4:
                  read_imm_data4;
              6:
                  read_imm_data6;
            endcase


            ins = 5;
            rdy = 1;
            @ (negedge run);
            next_state = S_START;
            rdy = 0;
          end
        S_11:
          begin


            // Get the w field from the current byte:
            w = byte[0:0];

            read_byte;            casex (byte)
              8'b11xxxxxx:
                next_state = S_13;
              8'bxxxxxxxx:
                next_state = S_12;
              default:
                next_state = S_SYN_ERROR;
            endcase
          end
        S_12:
          begin

            // Process the current ModR/M byte:
            process_ModRM;

            // Get the reg field from the current byte:
            reg1 = byte[5:3];

            ins = 3;
            rdy = 1;
            @ (negedge run);
            next_state = S_START;
            rdy = 0;
          end
        S_13:
          begin


            // Get the reg1 field from the current byte:
            reg1 = byte[5:3];
            // Get the reg2 field from the current byte:
            reg2 = byte[2:0];

            ins = 0;
            rdy = 1;
            @ (negedge run);
            next_state = S_START;
            rdy = 0;
          end
        endcase
   end

   initial begin
       rdy = 0;
   end
endmodule
