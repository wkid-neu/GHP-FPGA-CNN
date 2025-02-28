import onnx
from onnx import ModelProto, NodeProto
import utils
from typing import Dict, Any
import yaml
import math

def load_params_from_file(fp: str) -> Dict[str, Dict[str, Any]]:
    with open(fp, mode="r", encoding="utf8") as f:
        data = yaml.safe_load(f)
        return data

class Params:
    def __init__(
        self,
        quant_model_fp: str,  # file path of the quantized model
        res_fp: str,   # file path of results.
    ) -> None:
        self.quant_model: ModelProto = onnx.load_model(quant_model_fp)
        self.res_fp: str = res_fp

    def run(self) -> None:
        params = {}
        # Shape
        shape_params = ShapeInfer(self.quant_model).infer()
        params.update(shape_params)
        # Quantization Parameters
        quan_params = QuanParmas(self.quant_model, shape_params).run()
        for node_name, node_dict in params.items():
            node_dict.update(quan_params[node_name])
        # save
        self._save_params(params)

    def _save_params(self, params):
        with open(self.res_fp, mode="w", encoding="utf8") as f:
            yaml.safe_dump(params, f, sort_keys=False)

class ShapeInfer:
    def __init__(self, model: ModelProto) -> None:
        self.model = model
        self.params: Dict[str, Dict[str, Any]] = {}

    def infer(self) -> Dict[str, Dict[str, Any]]:
        for node in self.model.graph.node:
            self.params[node.name] = {}

        # The first pass, static dimensions
        self._update_static_dims()
        
        # The second pass,
        self._update_dynamic_dims()

        return self.params

    def _update_static_dims(self) -> None:
        for node in self.model.graph.node:
            if node.op_type == "QLinearConv":
                group = utils.onnx_find_attr_by_name(node, "group").i
                kernel_shape = utils.onnx_find_attr_by_name(node, "kernel_shape").ints
                strides = utils.onnx_find_attr_by_name(node, "strides").ints
                pads = utils.onnx_find_attr_by_name(node, "pads").ints
                W = utils.onnx_find_tensor_by_name(self.model.graph, node.input[3])
                self.params[node.name].update({
                    "group": group, "KH": kernel_shape[0], "KW": kernel_shape[1],
                    "strideH": strides[0], "strideW": strides[1],
                    "padL": pads[1], "padR": pads[3], "padU": pads[0], "padD": pads[2],
                    "OC": W.shape[0], "INC": W.shape[1]*group
                })
            elif node.op_type == "QGemm":
                alpha = utils.onnx_find_attr_by_name(node, "alpha").f
                transB = utils.onnx_find_attr_by_name(node, "transB").i
                B = utils.onnx_find_tensor_by_name(self.model.graph, node.input[3])
                if transB:
                    K, N = B.shape[1], B.shape[0]
                else:
                    K, N = B.shape[0], B.shape[1]
                self.params[node.name].update({
                    "alpha": alpha, "transB": transB,
                    "N": N, "K": K
                })
            elif node.op_type == "QLinearAdd":
                pass
            elif node.op_type == "QLinearAveragePool":
                kernel_shape = utils.onnx_find_attr_by_name(node, "kernel_shape").ints
                strides = utils.onnx_find_attr_by_name(node, "strides").ints
                pads = utils.onnx_find_attr_by_name(node, "pads").ints
                self.params[node.name].update({
                    "KH": kernel_shape[0], "KW": kernel_shape[1],
                    "strideH": strides[0], "strideW": strides[1],
                    "padL": pads[1], "padR": pads[3], "padU": pads[0], "padD": pads[2]
                })
            elif node.op_type == "QLinearConcat":
                pass
            elif node.op_type == "QLinearGlobalAveragePool":
                self.params[node.name].update({
                    "strideH": 1, "strideW": 1,
                    "padL": 0, "padR": 0, "padU": 0, "padD": 0,
                    "OH": 1, "OW": 1
                })
            elif node.op_type == "MaxPool":
                kernel_shape = utils.onnx_find_attr_by_name(node, "kernel_shape").ints
                strides = utils.onnx_find_attr_by_name(node, "strides").ints
                pads = utils.onnx_find_attr_by_name(node, "pads").ints
                self.params[node.name].update({
                    "KH": kernel_shape[0], "KW": kernel_shape[1],
                    "strideH": strides[0], "strideW": strides[1],
                    "padL": pads[1], "padR": pads[3], "padU": pads[0], "padD": pads[2]
                })
            elif node.op_type == "Flatten":
                pass
            elif node.op_type == "QuantizeLinear":
                pass
            elif node.op_type == "DequantizeLinear":
                pass
            else:
                raise ValueError(f"Unsupported node {node.name} with type {node.op_type}.")
    
    def _update_dynamic_dims(self) -> None:
        done_flags = {}
        for node in self.model.graph.node:
            done_flags[node.name] = False

        # The input node
        first_node = []
        for node in self.model.graph.node:
            if node.input[0] == self.model.graph.input[0].name:
                first_node.append(node)
        assert len(first_node) == 1, f"Unsupported quant_model which has input {len(first_node)} node(s), node(s): {first_node}."
        first_node = first_node[0]
        input_tensor_shape = utils.onnx_get_tensor_shape_by_value_info(self.model.graph.input[0]) 
        assert first_node.op_type == "QuantizeLinear", f"Unsupported quant_model whose first node is {first_node.name}."
        self.params[first_node.name].update({
            "x_shape": input_tensor_shape[1:],
            "y_shape": input_tensor_shape[1:]
        })
        done_flags[first_node.name] = True

        for node in self.model.graph.node:
            if not done_flags[node.name]:
                self._dyn_handle_node(node, done_flags)

    def _dyn_handle_node(self, node: NodeProto, done_flags: Dict[str, bool]) -> None:
        if node.op_type in ("QLinearConv", "QLinearAveragePool", "QLinearGlobalAveragePool", "MaxPool"):
            parents = utils.onnx_find_parents(node, self.model.graph)
            assert len(parents) == 1, f"Unresolved {node.op_type} node {node.name} with {len(parents)} parents."
            parent = parents[0]
            # Handle parent
            if not done_flags[parent.name]:
                self._dyn_handle_node(parent, done_flags)
            # Handle current node
            if parent.op_type == "QuantizeLinear":
                INC, INH_, INW_ = self.params[parent.name]["y_shape"]
            elif parent.op_type in ("QLinearConv", "QLinearAveragePool", "QLinearGlobalAveragePool", "MaxPool"):
                INC, INH_, INW_ = self.params[parent.name]["OC"], self.params[parent.name]["OH"], self.params[parent.name]["OW"]
            elif parent.op_type == "QLinearAdd":
                INC, INH_, INW_ = self.params[parent.name]["C_shape"]
            elif parent.op_type == "QLinearConcat":
                INC, INH_, INW_ = self.params[parent.name]["Y_shape"]
            else:
                raise ValueError(f"Unsupported sub-graph {parent.name} -> {node.name}.")
            self.params[node.name]["INC"], self.params[node.name]["INH_"], self.params[node.name]["INW_"] = INC, INH_, INW_
            # OH, OW
            if node.op_type == "QLinearConv":
                OH, OW = utils.conv_get_ofm_shape(
                    INH_, INW_, self.params[node.name]["KH"], self.params[node.name]["KW"],
                    self.params[node.name]["strideH"], self.params[node.name]["strideW"],
                    self.params[node.name]["padL"], self.params[node.name]["padR"], self.params[node.name]["padU"], self.params[node.name]["padD"],
                    ceil_mode=False
                )
            elif node.op_type in ("QLinearAveragePool", "MaxPool"):
                ceil_mode = utils.onnx_find_attr_by_name(node, "ceil_mode").i
                OH, OW = utils.conv_get_ofm_shape(
                    INH_, INW_, self.params[node.name]["KH"], self.params[node.name]["KW"],
                    self.params[node.name]["strideH"], self.params[node.name]["strideW"],
                    self.params[node.name]["padL"], self.params[node.name]["padR"], self.params[node.name]["padU"], self.params[node.name]["padD"],
                    ceil_mode=ceil_mode
                )
            else:
                OH, OW = 1, 1
            self.params[node.name]["OH"], self.params[node.name]["OW"] = OH, OW
            # OC
            if node.op_type in ("QLinearAveragePool", "QLinearGlobalAveragePool", "MaxPool"):
                self.params[node.name]["OC"] = INC
            # KH, KW update
            if node.op_type == "QLinearGlobalAveragePool":
                self.params[node.name]["KH"], self.params[node.name]["KW"] = INH_, INW_
            elif node.op_type in ("QLinearAveragePool", "MaxPool"):  # ceil_mode should be handled as paddings
                ceil_mode = utils.onnx_find_attr_by_name(node, "ceil_mode").i
                if ceil_mode:
                    new_padL, new_padR, new_padU, new_padD = utils.pool_ceil_mode_to_pads(
                        INH_, INW_,
                        self.params[node.name]["KH"], self.params[node.name]["KW"],
                        self.params[node.name]["strideH"], self.params[node.name]["strideW"],
                        self.params[node.name]["padL"], self.params[node.name]["padR"], self.params[node.name]["padU"], self.params[node.name]["padD"]
                    )
                    self.params[node.name]["padL"], self.params[node.name]["padR"], self.params[node.name]["padU"], self.params[node.name]["padD"] = new_padL, new_padR, new_padU, new_padD
        elif node.op_type == "QGemm":
            parents = utils.onnx_find_parents(node, self.model.graph)
            assert len(parents) == 1, f"Unresolved {node.op_type} node {node.name} with {len(parents)} parents."
            parent = parents[0]
            # Handle parent
            if not done_flags[parent.name]:
                self._dyn_handle_node(parent, done_flags)
            # Handle current node
            if parent.op_type == "QuantizeLinear":
                M = self.params[parent.name]["y_shape"][0]
            elif parent.op_type == "QLinearAdd":
                M = self.params[parent.name]["C_shape"][0]
            elif parent.op_type == "QLinearConcat":
                M = self.params[parent.name]["Y_shape"][0]
            elif parent.op_type == "QGemm":
                M = self.params[parent.name]["M"]
            elif parent.op_type == "Flatten":
                M = self.params[parent.name]["output_shape"][0]
            else:
                raise ValueError(f"Unsupported sub-graph {parent.name} -> {node.name}.")
            self.params[node.name]["M"] = M
        elif node.op_type == "QLinearAdd":
            parents = utils.onnx_find_parents(node, self.model.graph)
            assert len(parents) == 2, f"Unresolved {node.op_type} node {node.name} with {len(parents)} parents."
            # Handle parent
            for parent in parents:
                if not done_flags[parent.name]:
                    self._dyn_handle_node(parent, done_flags)
            # Handle current node
            for parent in parents:
                if parent.op_type == "QuantizeLinear":
                    self.params[node.name]["A_shape"] = self.params[parent.name]["y_shape"]
                elif parent.op_type in ("QLinearConv", "QLinearAveragePool", "QLinearGlobalAveragePool", "MaxPool"):
                    self.params[node.name]["A_shape"] = self.params[parent.name]["OC"], self.params[parent.name]["OH"], self.params[parent.name]["OW"]
                elif parent.op_type == "QGemm":
                    self.params[node.name]["A_shape"] = self.params[parent.name]["M"], self.params[parent.name]["N"]
                elif parent.op_type == "QLinearAdd":
                    self.params[node.name]["A_shape"] = self.params[parent.name]["C_shape"]
                elif parent.op_type == "QLinearConcat":
                    self.params[node.name]["A_shape"] = self.params[parent.name]["Y_shape"]
                elif parent.op_type == "Flatten":
                    self.params[node.name]["A_shape"] = self.params[parent.name]["output_shape"]
                else:
                    raise ValueError(f"Unsupported sub-graph {parent.name} -> {node.name}.")
                self.params[node.name]["B_shape"] = self.params[node.name]["A_shape"]
                self.params[node.name]["C_shape"] = self.params[node.name]["A_shape"]
        elif node.op_type == "QLinearConcat":
            parents = utils.onnx_find_parents(node, self.model.graph)
            # Handle parent
            for parent in parents:
                if not done_flags[parent.name]:
                    self._dyn_handle_node(parent, done_flags)
            # Handle current node
            shape_list = []
            for parent in parents:
                if parent.op_type == "QuantizeLinear":
                    shape_list.append(self.params[parent.name]["y_shape"])
                elif parent.op_type in ("QLinearConv", "QLinearAveragePool", "QLinearGlobalAveragePool", "MaxPool"):
                    shape_list.append((self.params[parent.name]["OC"], self.params[parent.name]["OH"], self.params[parent.name]["OW"]))
                elif parent.op_type == "QGemm":
                    shape_list.append((self.params[parent.name]["M"], self.params[parent.name]["N"]))
                elif parent.op_type == "QLinearAdd":
                    shape_list.append(self.params[parent.name]["C_shape"])
                elif parent.op_type == "QLinearConcat":
                    shape_list.append(self.params[parent.name]["Y_shape"])
                elif parent.op_type == "Flatten":
                    shape_list.append(self.params[parent.name]["output_shape"])
                else:
                    raise ValueError(f"Unsupported sub-graph {parent.name} -> {node.name}.")
            axis = utils.onnx_find_attr_by_name(node, "axis").i - 1
            Y_shape = list(shape_list[0])
            for i in range(1, len(shape_list)):
                shape = shape_list[i]
                Y_shape[axis] += shape[axis]
            self.params[node.name]["Y_shape"] = Y_shape 
        elif node.op_type == "Flatten":
            parents = utils.onnx_find_parents(node, self.model.graph)
            assert len(parents) == 1, f"Unresolved {node.op_type} node {node.name} with {len(parents)} parents."
            parent = parents[0]
            # Handle parent
            if not done_flags[parent.name]:
                self._dyn_handle_node(parent, done_flags)
            # Handle current node
            if parent.op_type == "QuantizeLinear":
                self.params[node.name]["input_shape"] = self.params[parent.name]["y_shape"]
            elif parent.op_type in ("QLinearConv", "QLinearAveragePool", "QLinearGlobalAveragePool", "MaxPool"):
                self.params[node.name]["input_shape"] = self.params[parent.name]["OC"], self.params[parent.name]["OH"], self.params[parent.name]["OW"]
            elif parent.op_type == "QGemm":
                self.params[node.name]["input_shape"] = self.params[parent.name]["M"], self.params[parent.name]["N"]
            elif parent.op_type == "QLinearAdd":
                self.params[node.name]["input_shape"] = self.params[parent.name]["C_shape"]
            elif parent.op_type == "QLinearConcat":
                self.params[node.name]["input_shape"] = self.params[parent.name]["Y_shape"]
            elif parent.op_type == "Flatten":
                self.params[node.name]["input_shape"] = self.params[parent.name]["output_shape"]
            elif parent.op_type == "DequantizeLinear":
                self.params[node.name]["input_shape"] = self.params[parent.name]["y_shape"]
            else:
                raise ValueError(f"Unsupported sub-graph {parent.name} -> {node.name}.")
            axis = utils.onnx_find_attr_by_name(node, "axis").i - 1
            input_shape = self.params[node.name]["input_shape"]
            if axis == 0:
                keep = (1,)
            else:
                keep = input_shape[0:axis]
            flatten = 1
            for it in input_shape[axis:]:
                flatten *= it
            output_shape = keep+(flatten,)
            self.params[node.name]["output_shape"] = output_shape
        elif node.op_type == "DequantizeLinear":
            parents = utils.onnx_find_parents(node, self.model.graph)
            assert len(parents) == 1, f"Unresolved {node.op_type} node {node.name} with {len(parents)} parents."
            parent = parents[0]
            # Handle parent
            if not done_flags[parent.name]:
                self._dyn_handle_node(parent, done_flags)
            # Handle current node
            if parent.op_type == "QuantizeLinear":
                self.params[node.name]["x_shape"] = self.params[parent.name]["y_shape"]
            elif parent.op_type in ("QLinearConv", "QLinearAveragePool", "QLinearGlobalAveragePool", "MaxPool"):
                self.params[node.name]["x_shape"] = self.params[parent.name]["OC"], self.params[parent.name]["OH"], self.params[parent.name]["OW"]
            elif parent.op_type == "QGemm":
                self.params[node.name]["x_shape"] = self.params[parent.name]["M"], self.params[parent.name]["N"]
            elif parent.op_type == "QLinearAdd":
                self.params[node.name]["x_shape"] = self.params[parent.name]["C_shape"]
            elif parent.op_type == "QLinearConcat":
                self.params[node.name]["x_shape"] = self.params[parent.name]["Y_shape"]
            elif parent.op_type == "Flatten":
                self.params[node.name]["x_shape"] = self.params[parent.name]["output_shape"]
            else:
                raise ValueError(f"Unsupported sub-graph {parent.name} -> {node.name}.")
            self.params[node.name]["y_shape"] = self.params[node.name]["x_shape"]
        else:
            raise ValueError(f"Unsupported node {node.name} with type {node.op_type}.")
    
        done_flags[node.name] = True      

class QuanParmas:
    def __init__(self, model: ModelProto, shape_params: Dict[str, Dict[str, Any]]) -> None:
        self.model: ModelProto = model
        self.shape_params: Dict[str, Dict[str, Any]] = shape_params
        self.params: Dict[str, Dict[str, Any]] = {}
    
    def run(self) -> Dict[str, Dict[str, Any]]:
        for node in self.model.graph.node:
            self.params[node.name] = {}
        for node in self.model.graph.node:
            if node.op_type == "QLinearConv":
                x_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[1])
                x_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[2])
                w_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[4])
                w_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[5])
                y_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[6])
                y_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[7])
                M1 = float(x_scale)*float(w_scale)/float(y_scale)
                n1, m1 = utils.quantize_M(M1, 26)
                self.params[node.name].update({
                    "m1": m1, "n1": n1,
                    "xz": int(x_zero_point), "wz": int(w_zero_point), "yz": int(y_zero_point)
                })
            elif node.op_type == "QGemm":
                a_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[1])
                a_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[2])
                b_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[4])
                b_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[5])
                y_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[7])
                y_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[8])
                M1 = float(a_scale)*float(b_scale)/float(y_scale)
                n1, m1 = utils.quantize_M(M1, 26)
                self.params[node.name].update({
                    "m1": m1, "n1": n1,
                    "az": int(a_zero_point), "bz": int(b_zero_point), "yz": int(y_zero_point)
                })
            elif node.op_type == "QLinearAdd":
                A_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[1])
                A_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[2])
                B_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[4])
                B_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[5])
                C_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[6])
                C_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[7])
                M1, M2 = float(A_scale)/float(C_scale), float(B_scale)/float(C_scale)
                n, (m1, m2) = utils.quantize_M_list((M1, M2), 26)
                self.params[node.name].update({
                    "m1": m1, "m2": m2, "n": n,
                    "az": int(A_zero_point), "bz": int(B_zero_point), "cz": int(C_zero_point)
                })
            elif node.op_type in ("QLinearAveragePool", "QLinearGlobalAveragePool"):
                N = self.shape_params[node.name]["KH"]*self.shape_params[node.name]["KW"]
                x_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[1])
                x_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[2])
                y_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[3])
                y_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[4])
                M1 = float(x_scale)/(float(y_scale)*N)
                n1, m1 = utils.quantize_M(M1, 26)
                self.params[node.name].update({
                    "m1": m1, "n1": n1,
                    "xz": int(x_zero_point), "nxz": N*int(x_zero_point), "yz": int(y_zero_point)
                })
            elif node.op_type == "QLinearConcat":
                Y_scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[0])
                Y_zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[1])
                n_parents = (len(node.input)-2)//3
                primary_tensor_name, curr_dist = "", math.inf
                for i in range(n_parents):
                    tensor_name = node.input[2+i*3]
                    scale = utils.onnx_find_tensor_by_name(self.model.graph, node.input[2+i*3+1])
                    zero_point = utils.onnx_find_tensor_by_name(self.model.graph, node.input[2+i*3+2])
                    # primary tensor
                    dist = abs(scale-Y_scale)
                    if dist < curr_dist:
                        primary_tensor_name = tensor_name
                        curr_dist = dist
                    # quantization parmeters
                    M = float(scale)/float(Y_scale)
                    n, m = utils.quantize_M(M, 26)
                    self.params[node.name].update({
                        f"name{i}": tensor_name,
                        f"m{i}": m, f"n{i}": n, f"xz{i}": int(zero_point)
                    })
                self.params[node.name].update({
                    "primary_tensor_name": primary_tensor_name,
                    "yz": int(Y_zero_point)
                })
            elif node.op_type == "MaxPool":
                self.params[node.name].update({
                    "m1": 1024, "n1": 10,
                    "xz": 0, "nxz": 0, "yz": 0
                })
            elif node.op_type == "Flatten":
                pass
            elif node.op_type == "QuantizeLinear":
                pass
            elif node.op_type == "DequantizeLinear":
                pass
            else:
                raise ValueError(f"Unsupported node {node.name} with type {node.op_type}.")
        return self.params

if __name__=="__main__":
    params = Params(
        "../ort_quant/squeezenet1_0-quan.onnx",
        # "../ort_quant/vovnet27s-quan.onnx",
        # "../ort_quant/resnet18-quan.onnx",
        "test.yaml"
    )
    params.run()
