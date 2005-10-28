library verilog;
use verilog.vl_types.all;
entity mmu_t is
    generic(
        addr_size       : integer := 32;
        word_size       : integer := 32
    );
    port(
        mfc             : out    vl_logic;
        strb            : in     vl_logic;
        rw              : in     vl_logic;
        mar             : in     vl_logic_vector;
        byte            : inout  vl_logic_vector(7 downto 0)
    );
end mmu_t;
