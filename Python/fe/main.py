from typing import List
import os
import shutil
import argparse
import yaml
from log import Log
from prettytable import PrettyTable
from fe.accuracy import OriAcc, QuanAcc, HwAcc
from fe.preproc import PreProc
from fe.params import Params
from fe.validate import ValGraph
from fe.dataset import ImageNetVal

# Status of a quantization stage
STATUS_PENDING = 0
STATUS_EXECUTED = 1
STATUS_OUT_OF_DATE = 2

class Manager:
    """A tool manager that integrates tools together."""
    def __init__(
        self,
        ori_model_fp: str,  # file path of the original onnx model
        quant_model_fp: str,  # file path of the quantized model
        output_params_fp: str,
        output_ir_fp: str, 
        eval_dataset,  # evaluation dataset.
        tmp_dir_path: str,  # directory path of the workspace.
    ) -> None:
        self.ori_model_fp: str = ori_model_fp
        self.quant_model_fp: str = quant_model_fp
        self.output_params_fp: str = output_params_fp
        self.output_ir_fp: str = output_ir_fp
        self.tmp_dir_path: str = tmp_dir_path
        self.eval_dataset = eval_dataset

        if not os.path.exists(tmp_dir_path):
            os.makedirs(tmp_dir_path)

    def run(self) -> None:
        # preapration
        status_ori_acc, status_quant_acc, status_preproc, status_params, status_val_graph, status_hw_acc = self._prepare()
        self._print_exec_overview(status_ori_acc, status_quant_acc, status_preproc, status_params, status_val_graph, status_hw_acc)
        
        # Accuracy of the original model
        if status_ori_acc != STATUS_EXECUTED:  # this stage is invalid
            Log.i("Manager: Run `ori_acc`.")
            ori_acc = OriAcc(
                ori_model_fp=self.ori_model_fp,
                eval_dataset=self.eval_dataset,
                res_fp=self._ori_acc_file_path()
            )
            ori_acc.run()
        else:
            Log.i("Manager: The stage `ori_acc` has been executed, skip it.")
        
        # Accuracy of the quantized model
        if status_quant_acc != STATUS_EXECUTED:  # this stage is invalid
            Log.i("Manager: Run `quant_acc`.")
            quant_acc = QuanAcc(
                quant_model_fp=self.quant_model_fp,
                eval_dataset=self.eval_dataset,
                res_fp=self._quant_acc_file_path()
            )
            quant_acc.run()
        else:
            Log.i("Manager: The stage `quant_acc` has been executed, skip it.")

        # preprocessing
        if status_preproc != STATUS_EXECUTED:  # this stage is invalid
            Log.i("Manager: Run `preproc`.")
            preproc = PreProc(
                quant_model_fp=self.quant_model_fp,
                processed_model_fp=self._preproc_model_file_path()
            )
            preproc.run()
        else:
            Log.i("Manager: The stage `preproc` has been executed, skip it.")

        # parameters
        if status_params != STATUS_EXECUTED:  # this stage is invalid
            Log.i("Manager: Run `params`.")
            params = Params(
                quant_model_fp=self._preproc_model_file_path(),
                res_fp=self._params_file_path()
            )
            params.run()
        else:
            Log.i("Manager: The stage `params` has been executed, skip it.")

        # Validation Graph
        if status_val_graph != STATUS_EXECUTED:  # this stage is invalid
            Log.i("Manager: Run `val_graph`.")
            val_graph = ValGraph(
                quant_model_fp=self._preproc_model_file_path(),
                params_fp=self._params_file_path(),
                val_graph_fp=self._val_model_file_path()
            )
            val_graph.run()
        else:
            Log.i("Manager: The stage `val_graph` has been executed, skip it.")
        
        # Accuracy of the Validation Graph
        if status_hw_acc != STATUS_EXECUTED:  # this stage is invalid
            Log.i("Manager: Run `hw_acc`.")
            hw_acc = HwAcc(
                val_model_fp=self._val_model_file_path(),
                eval_dataset=self.eval_dataset,
                res_fp=self._hw_acc_file_path()
            )
            hw_acc.run()
        else:
            Log.i("Manager: The stage `hw_acc` has been executed, skip it.")

        # Report

        # Outputs
        shutil.copy(self._preproc_model_file_path(), self.output_ir_fp)
        shutil.copy(self._params_file_path(), self.output_params_fp)

    def _prepare(self) -> List[int]:
        """Prepare for the execution, determine which tools should be invoked."""
        # status_ori_acc
        if os.path.exists(self._ori_acc_file_path()):
            status_ori_acc = STATUS_EXECUTED
        else:
            status_ori_acc = STATUS_PENDING
        # status_quant_acc
        if os.path.exists(self._quant_acc_file_path()):
            status_quant_acc = STATUS_EXECUTED
        else:
            status_quant_acc = STATUS_PENDING
        # status_preproc
        if os.path.exists(self._preproc_model_file_path()):
            status_preproc = STATUS_EXECUTED
        else:
            status_preproc = STATUS_PENDING 
        # status_params
        if status_preproc != STATUS_EXECUTED:  # previous stage is invalid
            if os.path.exists(self._params_file_path()):  # result file exists
                status_params = STATUS_OUT_OF_DATE
            else:  # result file dose not exist
                status_params = STATUS_PENDING
        else:  # previous stage is valid
            if os.path.exists(self._params_file_path()):  # result file exists
                status_params = STATUS_EXECUTED
            else:  # result file dose not exist
                status_params = STATUS_PENDING
        # status_val_graph
        if status_params != STATUS_EXECUTED:  # previous stage is invalid
            if os.path.exists(self._val_model_file_path()):  # result file exists
                status_val_graph = STATUS_OUT_OF_DATE
            else:  # result file dose not exist
                status_val_graph = STATUS_PENDING
        else:
            if os.path.exists(self._val_model_file_path()):  # result file exists
                status_val_graph = STATUS_EXECUTED
            else:  # result file dose not exist
                status_val_graph = STATUS_PENDING
        # status_hw_acc
        if status_val_graph != STATUS_EXECUTED:  # previous stage is invalid
            if os.path.exists(self._hw_acc_file_path()):  # result file exists
                status_hw_acc = STATUS_OUT_OF_DATE
            else:  # result file dose not exist
                status_hw_acc = STATUS_PENDING
        else:
            if os.path.exists(self._hw_acc_file_path()):  # result file exists
                status_hw_acc = STATUS_EXECUTED
            else:  # result file dose not exist
                status_hw_acc = STATUS_PENDING
        return status_ori_acc, status_quant_acc, status_preproc, status_params, status_val_graph, status_hw_acc

    def _print_exec_overview(self, status_ori_acc, status_quant_acc, status_preproc, status_params, status_val_graph, status_hw_acc):
        """Print the execution overview."""
        def _get_status(_status):
            if _status == STATUS_PENDING:
                return "Pending"
            elif _status == STATUS_EXECUTED:
                return "Executed"
            else:
                return "Out of date"

        table = PrettyTable([
            "stage_name", "status", "desc"
        ])
        table.add_row(["`ori_acc`", _get_status(status_ori_acc), "Evaluate the float32 model."])
        table.add_row(["`quant_acc`", _get_status(status_quant_acc), "Evaluate the quantized model."])
        table.add_row(["`preproc`", _get_status(status_preproc), "Pre-process the quantized model"])
        table.add_row(["`params`", _get_status(status_params), "Calculate shape and quantization parameters."])
        table.add_row(["`val_graph`", _get_status(status_val_graph), "Build Validation Graph."])
        table.add_row(["`hw_acc`", _get_status(status_hw_acc), "Evaluate the Validation Graph."])
        print(table)
    
    def _ori_acc_file_path(self):
        return os.path.join(self.tmp_dir_path, "ori_acc.yaml")

    def _quant_acc_file_path(self):
        return os.path.join(self.tmp_dir_path, "quant_acc.yaml")

    def _preproc_model_file_path(self):
        return os.path.join(self.tmp_dir_path, "preproc.onnx")
    
    def _params_file_path(self):
        return os.path.join(self.tmp_dir_path, "params.yaml")
    
    def _val_model_file_path(self):
        return os.path.join(self.tmp_dir_path, "val_graph.onnx")
    
    def _hw_acc_file_path(self):
        return os.path.join(self.tmp_dir_path, "hw_acc.yaml")

if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cfg_fp")
    args = parser.parse_args()

    cfg_fp = str(args.cfg_fp)
    with open(cfg_fp, mode="r", encoding="utf8") as f:
        cfg_data = yaml.safe_load(f)
        ori_model_fp = cfg_data["ori_model_fp"]
        quant_model_fp = cfg_data["quant_model_fp"]
        eval_dataset = cfg_data["eval_dataset"]
        output_params_fp = cfg_data["output_params_fp"]
        output_ir_fp = cfg_data["output_ir_fp"]
        tmp_dir_path = cfg_data["tmp_dir_path"]

    if eval_dataset == "ImageNetVal":
        ds = ImageNetVal()
    else:
        raise ValueError(f"Unsupported eval_dataset {eval_dataset}.")
    
    mgr = Manager(
        ori_model_fp=ori_model_fp,
        quant_model_fp=quant_model_fp,
        eval_dataset=ds,
        output_params_fp=output_params_fp,
        output_ir_fp=output_ir_fp,
        tmp_dir_path=tmp_dir_path
    )

    mgr.run()
