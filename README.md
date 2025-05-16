# Towards High-Performance Flexible FPGA-Based Accelerators for CNN Inference: General Hardware Architecture and End-to-End Deploying Toolflow 

## License

This project is dual-licensed under the following terms:

### Open Source Use
- The source code is released under the **[GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE)**.  
  - Derivative works must comply with the AGPL's open source requirements, including making their source code publicly available under the same license.  
  - For details, see the full [AGPL-3.0 license text](LICENSE).

### Commercial Licensing
- **Commercial use** (including but not limited to SaaS offerings, proprietary integrations, or resale) requires a **paid commercial license**.  
- The commercial license grants rights to:  
  - Use the code in closed-source products.  
  - Modify the code without open-sourcing derivative works.  
  - Access priority technical support and updates.  
- To obtain a commercial license, contact us at [sales@yourcompany.com](mailto:sales@yourcompany.com).  

### Patent Notice
This code is protected by patents (e.g., Patent No. US1234567).  
- **Non-commercial use** is permitted under AGPL-3.0.  
- **Commercial use** requires explicit patent authorization.  

1. The `FPGA_linux` folder stores hardware design code (Verilog and SystemVerilog) and driver code (C/C++).
   
2. The `Python`  folder stores compiler code.

3. The required onnx model can be obtained here:

https://github.com/osmr/imgclsmob

## How to reproduce the results.

Taking the latest version  as an example.

1. Generate bitstream files and burn them into FPGA.

For example, placing a bitstream file in `./FPGA_inux/bitstreams/M64P64Q16R16S8/` folder.

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
