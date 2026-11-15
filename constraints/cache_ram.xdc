# Apply at the leaf memory hierarchy: RAM_STYLE does not descend into nested
# modules. CIRCT extracts these arrays from InstCache and DataCache/BlockMem.
# Asynchronous tag memories deliberately retain their existing implementation.

set_property RAM_STYLE block [get_cells -hier -filter {NAME =~ */icache/lines_ext || NAME =~ */dcache/lines/mem_ext}]
