set_param general.maxThreads 32
set_part xcvu9p-flga2104-2L-e

proc read_src {directory} {
    puts "Searching verilog files in ${directory}."
    foreach file [glob -nocomplain -types f "${directory}/*.v"] {
        read_verilog $file
    }
    foreach dir [glob -nocomplain -types d "${directory}/*"] {
        if {$dir ne "." && $dir ne ".."} {
            read_src $dir
        }
    }
}

read_src "../src/"
read_xdc "test.xdc"

synth_design -top Fc -keep_equivalent_registers

report_utilization -file utilization.txt
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 1000 -input_pins -routable_nets -file timing.txt
