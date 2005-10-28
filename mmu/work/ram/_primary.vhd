library verilog;
use verilog.vl_types.all;
entity ram is
    generic(
        addr_size       : integer := 32;
        word_size       : integer := 32;
        mem_size        : integer := 65536;
        delay           : integer := 10
    );
    port(
        mfc             : out    vl_logic;
        strb            : in     vl_logic;
        rw              : in     vl_logic;
        addr            : in     vl_logic_vector;
        data            : inout  vl_logic_vector
    );
end ram;
