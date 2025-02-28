# Add source files into current fileset
proc add_src {directory} {
    puts "Searching verilog files in ${directory}."
    foreach file [glob -nocomplain -types f "${directory}/*.v"] {
        add_files -fileset sources_1 $file
    }
    foreach file [glob -nocomplain -types f "${directory}/*.vh"] {
        add_files -fileset sources_1 $file
    }
    foreach dir [glob -nocomplain -types d "${directory}/*"] {
        if {$dir ne "." && $dir ne ".."} {
            add_src $dir
        }
    }
}

set proj_name "sim_remap"
set bd_name "verify_top"
set_param general.maxThreads 32

create_project $proj_name ./$proj_name -part xcvu9p-flga2104-2L-e -force 
set_property BOARD_PART xilinx.com:vcu118:part0:2.4 [current_project]
# Read source files
add_src "../src/"
add_files -fileset sim_1 "../tb/tb_remap.sv"
# Read block design and make wrapper
source "bd_verify_top.tcl"
# Make wrapper
make_wrapper -files [get_files ${proj_name}/${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd] -top
# Add the wrapper file into design source
add_files -fileset sources_1 "${proj_name}/${proj_name}.gen/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v"
# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
# Top module of this simulation fileset
set_property top tb_remap [get_fileset sim_1]
# Run simulation
generate_target Simulation [get_files ${proj_name}/${proj_name}.srcs/sources_1/bd/verify_top/verify_top.bd]
export_ip_user_files -of_objects [get_files ${proj_name}/${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd] -no_script -sync -force -quiet
export_simulation -simulator xsim -of_objects [get_files ${proj_name}/${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd] -directory ${proj_name}/${proj_name}.ip_user_files/sim_scripts -ip_user_files_dir ${proj_name}/${proj_name}.ip_user_files -ipstatic_source_dir ${proj_name}/${proj_name}.ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
launch_simulation -simset [get_filesets sim_1]
# Run all
run all
# Close
close_sim
close_project
