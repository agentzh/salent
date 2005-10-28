vlog -nologo -quiet -incr -vlog95compat ram.v
vlog -nologo -quiet -incr -vlog95compat mmu.v
vlog -nologo -quiet -incr -vlog95compat mmu_t.v
vsim -quiet work.mmu_t
add wave -hex /Mmu/dataw /Mmu/datar /Mmu/data /Mmu/address rw strb mfc -hex mar byte /Mmu/bytedata bus_addr bus_data bus_strb   bus_mfc  bus_rw  /Ram/mem(0) /Ram/mem(1)
add list -nodelta -hex mfc byte

force strb 0
force rw 1'bz
force mar 'bz
force byte 'bz

# 
force rw 0 1
force mar 16#0 2
force byte -cancel 60 16#FF 1
force strb 1 3
force strb 0 60
run 70

# 
force rw 0 1
force mar 16#1 2
force byte -cancel 60 16#AB 1
force strb 1 3
force strb 0 60
run 70

# 
force rw 1 2
force mar 16#0 3
force strb 1 4
force strb 0 60
run 70

# 
force rw 1 2
force mar 16#1 1
force strb 1 3
force strb 0 55
run 70

write list -event mmu_t.lst
# quit
