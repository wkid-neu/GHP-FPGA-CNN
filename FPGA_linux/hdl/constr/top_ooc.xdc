# Using this command to prevent the PE in the Fc engine from being synthesized into 2 DSPs
set_property BLOCK_SYNTH.KEEP_EQUIVALENT_REGISTER 0 [get_cells -hierarchical *Fc_pe_inst]
