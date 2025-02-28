import onnx
from onnx import helper, ModelProto
from fe.params import load_params_from_file
from fe import op_QGemm
from fe import op_QLinearAdd
from fe import op_QLinearAveragePool
from fe import op_QLinearConcat
from fe import op_QLinearConv
from fe import op_QLinearGlobalAveragePool
from fe import op_MaxPool
from typing import Dict, Any
import utils
from log import Log

class ValGraph:
    def __init__(
        self,
        quant_model_fp: str,  # file path of the quantized model
        params_fp: str,  # file path of parameters
        val_graph_fp: str,  # file path of the validation graph
    ) -> None:
        self.quant_model: ModelProto = onnx.load_model(quant_model_fp)
        self.params: Dict[str, Dict[str, Any]] = load_params_from_file(params_fp)
        self.val_graph_fp: str = val_graph_fp

    def run(self) -> None:
        nodes, tensors = [], []
        for node in self.quant_model.graph.node:
            Log.i(f"`val_graph`: handle node {node.name} with type {node.op_type}.")
            if node.op_type == "QLinearConv":
                ns, ts = op_QLinearConv.hw_impl(
                    inputs=[node.input[0], node.input[3], node.input[8]],
                    outputs=[node.output[0]],
                    name=node.name,
                    params=self.params[node.name]
                )
                nodes.extend(ns)
                tensors.extend(ts)
            elif node.op_type == "QGemm":
                ns, ts = op_QGemm.hw_impl(
                    inputs=[node.input[0], node.input[3], node.input[6]],
                    outputs=[node.output[0]],
                    name=node.name,
                    params=self.params[node.name]
                )
                nodes.extend(ns)
                tensors.extend(ts)
            elif node.op_type == "QLinearAdd":
                ns, ts = op_QLinearAdd.hw_impl(
                    inputs=[node.input[0], node.input[3]],
                    outputs=[node.output[0]],
                    name=node.name,
                    params=self.params[node.name]
                )
                nodes.extend(ns)
                tensors.extend(ts)
            elif node.op_type == "QLinearAveragePool":
                # handle ceil_mode by updating pads of parameters
                ceil_mode = utils.onnx_find_attr_by_name(node, "ceil_mode").i
                if ceil_mode:
                    padL, padR, padU, padD = utils.pool_ceil_mode_to_pads(
                        self.params[node.name]["INH_"], self.params[node.name]["INW_"],
                        self.params[node.name]["KH"], self.params[node.name]["KW"],
                        self.params[node.name]["strideH"], self.params[node.name]["strideW"],
                        self.params[node.name]["padL"], self.params[node.name]["padR"], self.params[node.name]["padU"], self.params[node.name]["padD"]
                    )
                    self.params[node.name].update({
                        "padL": padL, "padR": padR, "padU": padU, "padD": padD
                    })
                ns, ts = op_QLinearAveragePool.hw_impl(
                    inputs=[node.input[0]],
                    outputs=[node.output[0]],
                    name=node.name,
                    params=self.params[node.name]
                )
                nodes.extend(ns)
                tensors.extend(ts)
            elif node.op_type == "QLinearConcat":
                n_parents = (len(node.input)-2)//3
                ns, ts = op_QLinearConcat.hw_impl(
                    inputs=[node.input[2+i*3] for i in range(n_parents)],
                    outputs=[node.output[0]],
                    name=node.name,
                    params=self.params[node.name]
                )
                nodes.extend(ns)
                tensors.extend(ts)
            elif node.op_type == "QLinearGlobalAveragePool":
                ns, ts = op_QLinearGlobalAveragePool.hw_impl(
                    inputs=[node.input[0]],
                    outputs=[node.output[0]],
                    name=node.name,
                    params=self.params[node.name]
                )
                nodes.extend(ns)
                tensors.extend(ts)
            elif node.op_type == "MaxPool":
                ns, ts = op_MaxPool.hw_impl(
                    inputs=[node.input[0]],
                    outputs=[node.output[0]],
                    name=node.name,
                    params=self.params[node.name]
                )
                nodes.extend(ns)
                tensors.extend(ts)
            else:
                nodes.append(node)
        # build model
        tensors.extend(self.quant_model.graph.initializer)
        infer_graph = helper.make_graph(
            nodes=nodes,
            name=self.quant_model.graph.name,
            inputs=self.quant_model.graph.input,
            outputs=self.quant_model.graph.output,
            initializer=tensors
        )
        infer_model = helper.make_model(infer_graph)
        # Save model
        onnx.save_model(infer_model, self.val_graph_fp)
