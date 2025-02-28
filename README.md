# Towards High-Performance Flexible FPGA-Based Accelerators for CNN Inference: General Hardware Architecture and End-to-End Deploying Toolflow 

## README
1. The `FPGA_linux` folder stores hardware design code (Verilog and SystemVerilog) and driver code (C/C++).
   
2. The `Python`  folder stores compiler code.

3. The required onnx model can be obtained here:

https://github.com/osmr/imgclsmob

## How to reproduce the results.

Taking the latest version  as an example.

1. Generate bitstream files and burn them into FPGA.

For example, placing a bitstream file in `/ FPGA_inux/bitstreams/M64P64Q16R16S8/` folder.

2. Enter `./FPGA_inux/linux-d river/run/` folder,run the script in the to collect data.
   
`run_model_e2e_perf.sh` : End to end delay for collecting various models.

`run_model_ins_perf.sh`: Used to collect the delay of each instruction for each model.

`run_model_build_db.sh`: Used to build convolutional databases, it collects the latency of each Conv instruction in both static and dynamic states.

`run_test_*`: Used for testing various functional components.

All collected raw data is saved in `./FPGA_inux/linux-d river/extvres/`.


3. Enter `./Python/ana/`，analyzing results.

Firstly, run the script `merge files. py` and copy all the original experimental results to this folder.

Secondly, run the script `run_ana. py`to start analyzing each model, and save the results in the `res_ *` file under the accelerator corresponding to each model.

Then, run the script `plot. py` to start plotting the performance and inference delay ratio of each model.
