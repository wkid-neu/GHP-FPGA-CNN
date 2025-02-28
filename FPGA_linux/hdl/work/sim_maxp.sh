acc_name=M64P64Q16R16S8
tcl_file_path="sim_maxp.tcl"
conf_file_path="../tb/cfg_maxp.yaml"
output_dir_path="../tb/sim_maxp"

# Convert Verilog header to yaml file
echo "Converting verilog header file to yaml format."
export PYTHONPATH=../tools/
python3 ../tools/vh2yaml.py --vh_fp ../src/conf/__${acc_name}_incl.vh --yaml_fp __params.yaml
# Generate testcases
echo "Start Generating testcases."
export PYTHONPATH=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/
python3 /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case/maxp.py --hw_params_fp __params.yaml --testcase_conf_fp $conf_file_path --output_dir_path $output_dir_path --rand_state 2023
# launch vivado and run simulation.
echo "Launch Vivado and run simulation."
rm vivado*
vivado -mode batch -source $tcl_file_path

# Clean the workspace
echo "Clean workspace."
rm __params.yaml