vlog -nologo -quiet -incr -vlog95compat mmu.v
vsim -quiet work.mmu
add wave rw bus_rw strb bus_strb  mfc bus_mfc -hex addr bus_addr byte bus_data 
add list -nodelta -hex mfc byte
force strb 0
force rw 1'bz
force addr 'bz
force byte 'bz

# 
force rw 0 1
force addr 16#0 2
force data -cancel 15 16#FFFF 1
force strb 1 3
force strb 0 15
run 20
#