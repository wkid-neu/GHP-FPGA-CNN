# CYZ_paper

## 文件说明
1. `FPGA_linux`文件夹存放硬件设计代码（Verilog和SystemVerilog）和驱动代码（C/C++）。
   
2. `Python`文件夹存放编译器代码。

3. 所需的onnx模型在这里获得:

https://github.com/osmr/imgclsmob

## 如何复现结果

以最新版本`cnn_accel6`的`M64P64`为例，其他的版本和加速器方法相同。

1. 找到比特流文件并烧录到FPGA中。
比特流文件在`./FPGA_linux/cnn_accel6/bitstreams/M64P64Q16R16S8/`中。

2. 进入`./FPGA_linux/cnn_accel6/linux_driver/run/`文件夹下，运行这里面的脚本来采集数据。
   
`run_model_e2e_perf.sh`用于采集各模型的端到端延时。

`run_model_ins_perf.sh`用于采集各模型的各个指令的延时。

`run_model_build_db.sh`用于构建卷积数据库，它采集的是各个Conv指令在静态和动态下的延时。

`run_test_*`用于测试各个功能部件。

所有采集到的原始数据都保存在`./FPGA_linux/cnn_accel6/linux_driver/exp_res/`文件夹下。

3. 进入`./Python/cnn_accel6/ana/`，开始分析结果。
首先运行脚本`merge_files.py`，把原始实验结果都copy到本文件夹下。

然后运行脚本`run_ana.py`，开始分析每一个模型，结果保存在每个模型对应的加速器下的`res_*`文件中。

然后运行脚本`plot.py`，开始绘制每个模型的性能图和推理延时占比图。
