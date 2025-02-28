import argparse
import os
import shutil

class Runner:
    def __init__(
        self,
        M, P, Q, R, S,
        model_dir, res_fp,
        workdir, ori_src_dir, ori_tb_dir, ori_work_dir
    ) -> None:
        self.M = M
        self.P = P
        self.Q = Q
        self.R = R
        self.S = S
        self.model_dir = model_dir
        self.res_fp = res_fp
        self.workdir = workdir
        self.ori_src_dir = ori_src_dir
        self.ori_tb_dir = ori_tb_dir
        self.ori_work_dir = ori_work_dir

        # Copy src directory
        print("Copy the src directory.")
        self._copy_src_dir()
        # Copy tb directory
        print("Copy the tb directory.")
        self._copy_tb_dir()
        # Copy work directory
        print("Copy the work directory.")
        self._copy_work_dir()
        # Launch vivado
        print("Launch vivado and run the testcase")
        self._run_vivado()
        # Clean workdir
        print("Clean workspace.")
        shutil.rmtree(self.workdir, ignore_errors=True)

    def _get_acc_name(self):
        return f"M{self.M}P{self.P}Q{self.Q}R{self.R}S{self.S}"
    
    def _copy_src_dir(self):
        """Copy src to workdir."""
        curr_src_dir = os.path.join(self.workdir, "src")
        shutil.rmtree(curr_src_dir, ignore_errors=True)
        os.makedirs(curr_src_dir)
        # Copy
        os.system(f"cp -R {self.ori_src_dir}/* {curr_src_dir}")
        # Modify incl.vh
        acc_name = self._get_acc_name()
        shutil.copy(
            os.path.join(curr_src_dir, "conf", f"__{acc_name}_incl.vh"), 
            os.path.join(curr_src_dir, "incl.vh")
        )

    def _copy_tb_dir(self):
        """Copy tb to workdir."""
        curr_tb_dir = os.path.join(self.workdir, "tb")
        shutil.rmtree(curr_tb_dir, ignore_errors=True)
        os.makedirs(curr_tb_dir)
        # Copy tb_model.sv
        shutil.copy(
            os.path.join(self.ori_tb_dir, "tb_model.sv"), 
            os.path.join(curr_tb_dir, "tb_model.sv")
        )
        # Copy comm_func.sv
        shutil.copy(
            os.path.join(self.ori_tb_dir, "comm_func.sv"), 
            os.path.join(curr_tb_dir, "comm_func.sv")
        )

    def _copy_work_dir(self):
        """Copy work to workdir."""
        curr_work_dir = os.path.join(self.workdir, "work")
        shutil.rmtree(curr_work_dir, ignore_errors=True)
        os.makedirs(curr_work_dir)
        # Copy bd_verify_top.tcl
        shutil.copy(
            os.path.join(self.ori_work_dir, "bd_verify_top.tcl"), 
            os.path.join(curr_work_dir, "bd_verify_top.tcl")
        )
        # Copy sim_model.tcl
        shutil.copy(
            os.path.join(self.ori_work_dir, "sim_model.tcl"), 
            os.path.join(curr_work_dir, "sim_model.tcl")
        )
        # Add macros
        # MODEL_DIR is the directory path of model
        # RES_FP is the result file path of the testbench
        with open(os.path.join(curr_work_dir, "sim_model.tcl"), mode="r", encoding="utf8") as f:
            content = f.read()
        content = content.replace(
            "# Replace this line to add macors",
            f"set_property verilog_define [list MODEL_DIR=\"{self.model_dir}\" RES_FP=\"{self.res_fp}\"] [get_fileset sim_1]"
        )
        with open(os.path.join(curr_work_dir, "sim_model.tcl"), mode="w", encoding="utf8") as f:
            f.write(content)

    def _run_vivado(self):
        """Launch vivado and run the tcl file."""
        curr_work_dir = os.path.join(self.workdir, "work")
        tcl_file_path = os.path.join(curr_work_dir, "sim_model.tcl")
        cmd1 = f"cd {curr_work_dir}"
        cmd2 = f"vivado -mode batch -source {tcl_file_path}"
        cmd = f"{cmd1} && {cmd2}"
        os.system(cmd)

if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--M", default=0)
    parser.add_argument("--P", default=0)
    parser.add_argument("--Q", default=0)
    parser.add_argument("--R", default=0)
    parser.add_argument("--S", default=0)

    parser.add_argument("--model_dir", default="")
    parser.add_argument("--res_fp", default="")

    parser.add_argument("--workdir", default="")
    parser.add_argument("--ori_src_dir", default="")
    parser.add_argument("--ori_tb_dir", default="")
    parser.add_argument("--ori_work_dir", default="")
    args = parser.parse_args()

    # Hardware parameters
    M = int(args.M)
    P = int(args.P)
    Q = int(args.Q)
    R = int(args.R)
    S = int(args.S)
    # File and directory path
    model_dir = str(args.model_dir)
    res_fp = str(args.res_fp)
    workdir = str(args.workdir)
    ori_src_dir = str(args.ori_src_dir)
    ori_tb_dir = str(args.ori_tb_dir)
    ori_work_dir = str(args.ori_work_dir)

    runner = Runner(
        M, P, Q, R, S,
        model_dir, res_fp,
        workdir, ori_src_dir, ori_tb_dir, ori_work_dir
    )
