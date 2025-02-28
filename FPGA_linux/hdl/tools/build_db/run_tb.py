import argparse
import os
import shutil
import numpy as np

class Runner:
    def __init__(
        self,
        M, P, Q, R, S,
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, w_mode,
        workdir, db_fp, ori_src_dir, ori_tb_dir, ori_work_dir
    ) -> None:
        self.M = M
        self.P = P
        self.Q = Q
        self.R = R
        self.S = S
        self.OC = OC
        self.INC = INC
        self.INH_ = INH_
        self.INW_ = INW_
        self.KH = KH
        self.KW = KW
        self.strideH = strideH
        self.strideW = strideW
        self.padL = padL
        self.padR = padR
        self.padU = padU
        self.padD = padD
        self.w_mode = w_mode
        self.workdir = workdir
        self.db_fp = db_fp
        self.ori_src_dir = ori_src_dir
        self.ori_tb_dir = ori_tb_dir
        self.ori_work_dir = ori_work_dir

        # We should skip if the record is present.
        if self._is_present():
            print("Record is already present in the database, skip it")
            return

        # Copy src directory
        print("Copy the src directory.")
        self._copy_src_dir()
        # Copy tb directory
        print("Copy the tb directory.")
        self._copy_tb_dir()
        # Copy work directory
        print("Copy the work directory.")
        self._copy_work_dir()
        # Generate testcase
        print("Generate testcase")
        self._gen_testcase()
        # Launch vivado
        print("Launch vivado and run the testcase")
        self._run_vivado()
        # Calculate latency
        print("Calculate the latency.")
        latency = self._get_latency()
        # Update database
        print("Updata database.")
        self._update_db(latency)
        # Clean workdir
        print("Clean workspace.")
        shutil.rmtree(self.workdir, ignore_errors=True)

    def _get_acc_name(self):
        return f"M{self.M}P{self.P}Q{self.Q}R{self.R}S{self.S}"
    
    def _get_testcase_dir(self):
        return os.path.join(self.workdir, "tb", "sim_conv")
    
    def _get_res_file_path(self):
        return os.path.join(self.workdir, "tb", "res.txt")

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
        # Copy tb_conv.sv
        shutil.copy(
            os.path.join(self.ori_tb_dir, "tb_conv.sv"), 
            os.path.join(curr_tb_dir, "tb_conv.sv")
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
        # Copy sim_conv.tcl
        shutil.copy(
            os.path.join(self.ori_work_dir, "sim_conv.tcl"), 
            os.path.join(curr_work_dir, "sim_conv.tcl")
        )
        # Add macros
        # DIR_PATH is the directory path of testcase
        # RES_FP is the result file path of the testbench
        with open(os.path.join(curr_work_dir, "sim_conv.tcl"), mode="r", encoding="utf8") as f:
            content = f.read()
        content = content.replace(
            "# Replace this line to add macors",
            f"set_property verilog_define [list DIR_PATH=\"{self._get_testcase_dir()}\" RES_FP=\"{self._get_res_file_path()}\"] [get_fileset sim_1]"
        )
        with open(os.path.join(curr_work_dir, "sim_conv.tcl"), mode="w", encoding="utf8") as f:
            f.write(content)

    def _gen_testcase(self):
        """Generate testcase."""
        cmd1 = "export PYTHONPATH=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/"
        cmd2 = f"python3 /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case/conv.py --M {self.M} --P {self.P} --Q {self.Q} --R {self.R}  --S {self.S} --OC {self.OC} --INC {self.INC} --INH_ {self.INH_} --INW_ {self.INW_} --KH {self.KH} --KW {self.KW} --strideH {self.strideH} --strideW {self.strideW} --padL {self.padL} --padR {self.padR} --padU {self.padU} --padD {self.padD} --w_mode {self.w_mode} --output_dir_path {self._get_testcase_dir()}"
        cmd = f"{cmd1} && {cmd2}"
        os.system(cmd)

    def _run_vivado(self):
        """Launch vivado and run the tcl file."""
        curr_work_dir = os.path.join(self.workdir, "work")
        tcl_file_path = os.path.join(curr_work_dir, "sim_conv.tcl")
        cmd1 = f"cd {curr_work_dir}"
        cmd2 = f"vivado -mode batch -source {tcl_file_path}"
        cmd = f"{cmd1} && {cmd2}"
        os.system(cmd)

    def _get_latency(self):
        """Read the start and end time to calculate the latency."""
        with open(self._get_res_file_path(), mode="r", encoding="utf8") as f:
            times = []
            for line in f:
                line = line.strip()
                if line == "":
                    continue
                times.append(int(line))
            start, end = times[0], times[1]
        return end-start
    
    def _update_db(self, latency):
        """Update database."""
        prev_db = self._load_db()
        primary_keys = (
            int(self.M), int(self.P), int(self.Q), int(self.R), int(self.S),
            int(self.OC), int(self.INC), int(self.INH_), int(self.INW_), 
            int(self.KH), int(self.KW), int(self.strideH), int(self.strideW), 
            int(self.padL), int(self.padR), int(self.padU), int(self.padD), 
            str(self.w_mode)
        )
        prev_latency = prev_db.get(primary_keys, None)
        if prev_latency is not None:
            print(f"Updata record, prev: {prev_latency}, new: {latency}")
        else:
            print(f"Write record, latency: {latency}")
        prev_db.update({primary_keys: latency})
        # Write back to file
        with open(self.db_fp, mode="w", encoding="utf8") as f:
            f.write("M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, w_mode, latency\n")
            for k, v in prev_db.items():
                f.write(",".join([str(field) for field in k]))
                f.write(f",{v}\n")

    def _is_present(self):
        """Return True if current testcase is present in the database."""
        db = self._load_db()
        primary_keys = (
            int(self.M), int(self.P), int(self.Q), int(self.R), int(self.S),
            int(self.OC), int(self.INC), int(self.INH_), int(self.INW_), 
            int(self.KH), int(self.KW), int(self.strideH), int(self.strideW), 
            int(self.padL), int(self.padR), int(self.padU), int(self.padD), 
            str(self.w_mode)
        )
        return (primary_keys in db.keys())

    def _load_db(self):
        """Load database from file."""
        ret = {}
        if os.path.exists(self.db_fp):
            raw_data = np.loadtxt(self.db_fp, str, delimiter=",")
            for i in range(1, len(raw_data)):
                M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, w_mode, latency = raw_data[i]
                primary_keys = (
                    int(M), int(P), int(Q), int(R), int(S),
                    int(OC), int(INC), int(INH_), int(INW_), 
                    int(KH), int(KW), int(strideH), int(strideW), 
                    int(padL), int(padR), int(padU), int(padD), 
                    str(w_mode)
                )
                ret[primary_keys] = int(latency)
        return ret

if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--M", default=0)
    parser.add_argument("--P", default=0)
    parser.add_argument("--Q", default=0)
    parser.add_argument("--R", default=0)
    parser.add_argument("--S", default=0)

    parser.add_argument("--OC", default=0)
    parser.add_argument("--INC", default=0)
    parser.add_argument("--INH_", default=0)
    parser.add_argument("--INW_", default=0)
    parser.add_argument("--KH", default=0)
    parser.add_argument("--KW", default=0)
    parser.add_argument("--strideH", default=0)
    parser.add_argument("--strideW", default=0)
    parser.add_argument("--padL", default=0)
    parser.add_argument("--padR", default=0)
    parser.add_argument("--padU", default=0)
    parser.add_argument("--padD", default=0)
    parser.add_argument("--w_mode", default="sta")

    parser.add_argument("--workdir", default="")
    parser.add_argument("--db_fp", default="")
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
    # Test case configuration
    OC = int(args.OC)
    INC = int(args.INC)
    INH_ = int(args.INH_)
    INW_ = int(args.INW_)
    KH = int(args.KH)
    KW = int(args.KW)
    strideH = int(args.strideH)
    strideW = int(args.strideW)
    padL = int(args.padL)
    padR = int(args.padR)
    padU = int(args.padU)
    padD = int(args.padD)
    w_mode = str(args.w_mode)
    # File and directory path
    workdir = str(args.workdir)
    db_fp = str(args.db_fp)
    ori_src_dir = str(args.ori_src_dir)
    ori_tb_dir = str(args.ori_tb_dir)
    ori_work_dir = str(args.ori_work_dir)

    runner = Runner(
        M, P, Q, R, S,
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, w_mode,
        workdir, db_fp, ori_src_dir, ori_tb_dir, ori_work_dir
    )
