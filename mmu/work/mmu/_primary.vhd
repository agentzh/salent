library verilog;
use verilog.vl_types.all;
entity mmu is
    generic(
        addr_size       : integer := 32;
        word_size       : integer := 32
    );
    port(
        bus_strb        : out    vl_logic;
        bus_rw          : out    vl_logic;
        bus_addr        : out    vl_logic_vector;
        bus_mfc         : in     vl_logic;
        bus_data        : inout  vl_logic_vector;
        mfc             : out    vl_logic;
        strb            : in     vl_logic;
        rw              : in     vl_logic;
        mar             : in     vl_logic_vector;
        byte            : inout  vl_logic_vector(7 downto 0)
    );
end mmu;
