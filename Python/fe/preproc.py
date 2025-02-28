import onnx
import utils
from log import Log

class PreProc:
    def __init__(
        self,
        quant_model_fp: str,  # file path of the quantized onnx model
        processed_model_fp: str,  # file path of the processed onnx model
    ) -> None:
        self.quant_model_fp: str = quant_model_fp
        self.processed_model_fp: str = processed_model_fp
    
    def run(self) -> None:
        quant_model = onnx.load_model(self.quant_model_fp)
        self._proc1(quant_model)
        self._proc2(quant_model)
        # self._proc3(quant_model)
        onnx.save_model(quant_model, self.processed_model_fp)

    def _proc1(self, model) -> None:
        """DQ -> Flatten -> output   ==========>    Flatten -> DQ -> output."""
        def pattern_match(graph):
            ret = []
            for node in graph.node:
                # DQ
                if node.op_type == "DequantizeLinear":
                    children = utils.onnx_find_children(node, graph)
                    if len(children) > 0:
                        child = children[0]
                    else:
                        continue
                    # Flatten
                    if child.op_type == "Flatten":
                        # output
                        if child.output[0] == graph.output[0].name:
                            Log.i(f"`preproc`: {node.name} -> {child.name} -> output")
                            ret.append(node)
                        else:
                            continue
                    else:
                        continue
            return ret

        Log.i("`preproc`: process Pattern DQ -> Flatten -> output.")
        nodes = pattern_match(model.graph)
        # node is DQ, child is Flatten, 
        for node in nodes:
            child = utils.onnx_find_children(node, model.graph)[0]
            parent = utils.onnx_find_parents(node, model.graph)[0]
            child.input[0] = parent.output[0]
            node.input[0] = child.output[0]
            model.graph.output[0].name = node.output[0]

    def _proc2(self, model) -> None:
        """DQ -> Flatten -> Q   ==========>    Flatten. """
        def pattern_match(graph):
            ret = []
            for node in graph.node:
                if node.op_type == "Flatten":
                    parents = utils.onnx_find_parents(node, graph)
                    children = utils.onnx_find_children(node, graph)
                    parent = parents[0]
                    if len(children) > 0:
                        child = children[0]
                    else:
                        continue
                    if parent.op_type == "DequantizeLinear" and child.op_type == "QuantizeLinear":
                        Log.i(f"`preproc`: {parent.name} -> {node.name} -> {child.name}")
                        ret.append(node)
            return ret

        Log.i("`preproc`: process Pattern DQ -> Flatten -> Q.")
        nodes = pattern_match(model.graph)
        for node in nodes:
            parent = utils.onnx_find_parents(node, model.graph)[0]
            child = utils.onnx_find_children(node, model.graph)[0]
            # handle parent
            prev_nodes = utils.onnx_find_parents(parent, model.graph)
            if len(prev_nodes) == 1:
                prev_node = prev_nodes[0]
                node.input[0] = prev_node.output[0]
                node.output[0] = child.output[0]
            else:
                continue
            # handle child
            next_nodes = utils.onnx_find_children(child, model.graph)
            if len(next_nodes) == 1:
                next_node = next_nodes[0]
                next_node.input[0] = node.output[0]
            else:
                continue
            # remove unused nodes
            model.graph.node.remove(parent)
            model.graph.node.remove(child)
    
    def _proc3(self, model) -> None:
        """Remove useless quantization operations in Concat nodes."""
        def pattern_match(graph):
            ret = []
            for node in graph.node:
                if node.op_type == "QLinearConcat":
                    parents = utils.onnx_find_parents(node, graph)
                    ret.append((node, parents))
            return ret

        Log.i("`preproc`: Remove useless quantization operations in Concat nodes.")
        match_res = pattern_match(model.graph)
        for node, parents in match_res:
            Log.i(f"`preproc`: Handle Concat node {node.name}")
            target_scale, target_zero_point = utils.onnx_find_tensor_by_name(model.graph, node.input[0]), utils.onnx_find_tensor_by_name(model.graph, node.input[1])
            target_scale, target_zero_point = float(target_scale), int(target_zero_point)
            for parent in parents:
                if parent.op_type == "QLinearConv":
                    scale_tensor = utils.onnx_find_tensor_by_name(model.graph, parent.input[6], return_raw_obj=True)
                    zero_point_scale = utils.onnx_find_tensor_by_name(model.graph, parent.input[7], return_raw_obj=True)
                    scale_tensor.float_data[0] = target_scale
                    zero_point_scale.int32_data[0] = target_zero_point
