tcl_file_path="sim_rtm.tcl"

# launch vivado and run simulation.
echo "Launch Vivado and run simulation."
vivado -mode batch -source $tcl_file_path
rm vivado*
