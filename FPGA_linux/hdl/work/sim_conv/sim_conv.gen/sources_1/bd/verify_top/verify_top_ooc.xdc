################################################################################

# This XDC is used only for OOC mode of synthesis, implementation
# This constraints file contains default clock frequencies to be used during
# out-of-context flows such as OOC Synthesis and Hierarchical Designs.
# This constraints file is not used in normal top-down synthesis (default flow
# of Vivado)
################################################################################
create_clock -name main_clk -period 4 [get_ports main_clk]
create_clock -name sa_clk -period 2.510 [get_ports sa_clk]

################################################################################