import onnxruntime as ort
import onnx
import numpy as np
from onnx import helper, TensorProto, GraphProto, NodeProto
from io import BytesIO
from typing import Tuple, List, Dict, Any
from fe import op_helper
import utils

def hw_impl(
    inputs: List[str],  # X
    outputs: List[str],  # Y
    name: str,  # node_name
    params: Dict[str, Any],  # prepared parameters
) -> Tuple[List[NodeProto], List[TensorProto]]:  # nodes, initializers
    nodes, tensors = [], []

    # quantization parameters
    m1, n1 = params["m1"], params["n1"]
    xz, yz = params["xz"], params["yz"]

    tensors.extend([
        helper.make_tensor(name=f"{name}/Constant_0", data_type=TensorProto.INT64, dims=[], vals=[xz]),
        helper.make_tensor(name=f"{name}/Constant_1", data_type=TensorProto.INT64, dims=[], vals=[m1]),
        helper.make_tensor(name=f"{name}/Constant_2", data_type=TensorProto.INT64, dims=[], vals=[n1]),
        helper.make_tensor(name=f"{name}/Constant_4", data_type=TensorProto.INT64, dims=[], vals=[yz]),
        helper.make_tensor(name=f"{name}/Constant_5", data_type=TensorProto.INT64, dims=[], vals=[0]),
        helper.make_tensor(name=f"{name}/Constant_6", data_type=TensorProto.INT64, dims=[], vals=[255]),
        helper.make_tensor(name=f"{name}/Constant_7", data_type=TensorProto.INT64, dims=[2,], vals=[-1,-2]),
    ])

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[inputs[0]],
        outputs=[f"{name}/Cast_0"],
        name=f"{name}/Cast_0",
        to=TensorProto.INT64
    ))

    nodes.append(helper.make_node(
        op_type="Sub",
        inputs=[f"{name}/Cast_0", f"{name}/Constant_0"],
        outputs=[f"{name}/Sub_0"],
        name=f"{name}/Sub_0"
    ))

    nodes.append(helper.make_node(
        op_type="ReduceSum",
        inputs=[f"{name}/Sub_0", f"{name}/Constant_7"],
        outputs=[f"{name}/ReduceSum_0"],
        name=f"{name}/ReduceSum_0",
        keepdims=1
    ))

    nodes.append(helper.make_node(
        op_type="Mul",
        inputs=[f"{name}/ReduceSum_0", f"{name}/Constant_1"],
        outputs=[f"{name}/Mul_0"],
        name=f"{name}/Mul_0"
    ))

    ns, ts = op_helper.make_hw_shift2(
        inputs=[f"{name}/Mul_0", f"{name}/Constant_2"],
        outputs=[f"{name}/hw_shift_0"],
        ZW=9,
        name=f"{name}/hw_shift_0"
    )
    nodes.extend(ns)
    tensors.extend(ts)

    nodes.append(helper.make_node(
        op_type="Add",
        inputs=[f"{name}/hw_shift_0", f"{name}/Constant_4"],
        outputs=[f"{name}/Add_0"],
        name=f"{name}/Add_0",
    ))

    nodes.append(helper.make_node(
        op_type="Clip",
        inputs=[f"{name}/Add_0", f"{name}/Constant_5", f"{name}/Constant_6"],
        outputs=[f"{name}/Clip_0"],
        name=f"{name}/Clip_0"
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/Clip_0"],
        outputs=[outputs[0]],
        name=f"{name}/Cast_6",
        to=TensorProto.UINT8
    ))

    return nodes, tensors

def make_sw_graph(
    X, x_scale, x_zero_point,
    y_scale, y_zero_point
) -> GraphProto:
    node = helper.make_node(
        op_type="QLinearGlobalAveragePool",
        inputs=["X", "x_scale", "x_zero_point", "y_scale", "y_zero_point"],
        outputs=["Y"],
        name="node_0",
        domain="com.microsoft"
    )

    graph = helper.make_graph(
        nodes=[node],
        name="graph_0",
        inputs=[
            helper.make_tensor_value_info(name="X", elem_type=TensorProto.UINT8, shape=X.shape),
        ],
        outputs=[
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.UINT8, shape=X.shape[0: len(X.shape)-2]+(1,1)),
        ],
        initializer=[
            helper.make_tensor(name="x_scale", data_type=TensorProto.FLOAT, dims=[], vals=x_scale),
            helper.make_tensor(name="x_zero_point", data_type=TensorProto.UINT8, dims=[], vals=x_zero_point),
            helper.make_tensor(name="y_scale", data_type=TensorProto.FLOAT, dims=[], vals=y_scale),
            helper.make_tensor(name="y_zero_point", data_type=TensorProto.UINT8, dims=[], vals=y_zero_point),
        ]
    )

    return graph

def make_hw_graph(
    X, x_scale, x_zero_point,
    y_scale, y_zero_point
) -> GraphProto:
    # prepare parameters
    N = X.shape[-1]*X.shape[-2]
    M1 = float(x_scale)/(float(y_scale)*N)
    n1, m1 = utils.quantize_M(M1, 34)
    params = {
        "m1": m1, "n1": n1,
        "xz": int(x_zero_point), "yz": int(y_zero_point)
    }

    nodes, tensors = hw_impl(
        inputs=["X"],
        outputs=["Y"],
        name="hw_0",
        params=params
    )
    
    graph = helper.make_graph(
        nodes=nodes,
        name="graph_0",
        inputs=[
            helper.make_tensor_value_info(name="X", elem_type=TensorProto.UINT8, shape=X.shape),
        ],
        outputs=[
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.UINT8, shape=X.shape[0: len(X.shape)-2]+(1,1)),
        ],
        initializer=tensors
    )

    return graph

def exec_graph(
    graph: GraphProto,  # hw_graph or sw_graph
    X
) -> np.ndarray:
    # build model
    model = helper.make_model(graph=graph)

    # save model into buffer
    buf = BytesIO()
    # onnx.save(model, "test.onnx")
    onnx.save(model, buf)

    # run inference
    sess = ort.InferenceSession(buf.getvalue())
    res = sess.run(
        output_names=["Y"], 
        input_feed={
            "X": X, 
        }
    )
    return res[0]

def test(
    shape = (1,3,2,2),
    rand_state: int = 1
):
    import torch
    import torch.nn.functional as F

    # real world example
    np.random.seed(rand_state)
    ori_X = np.random.randn(*shape)
    ori_Y = F.avg_pool2d(
        input=torch.tensor(ori_X),
        kernel_size=(shape[-2], shape[-1]),
        stride=(1, 1),
        padding=(0,0),
        ceil_mode=False,
        count_include_pad=True
    ).numpy()
    
    # prepare inputs
    X, x_scale, x_zero_point = utils.quant_auto(ori_X, n_bits=8, signed=False)
    _, y_scale, y_zero_point = utils.quant_auto(ori_Y, n_bits=8, signed=False)

    # cast
    X, x_scale, x_zero_point = X.astype(np.uint8), np.array([x_scale]), np.array([x_zero_point])
    y_scale, y_zero_point = np.array([y_scale]), np.array([y_zero_point])

    # sw results
    sw_graph = make_sw_graph(
        X, x_scale, x_zero_point,
        y_scale, y_zero_point
    )
    sw_res = exec_graph(
        sw_graph,
        X
    ).astype(np.int64)
    # print(sw_res)

    # hw results
    hw_graph = make_hw_graph(
        X, x_scale, x_zero_point,
        y_scale, y_zero_point
    )
    hw_res = exec_graph(
        hw_graph,
        X
    ).astype(np.int64)
    # print(hw_res)

    allclose = np.allclose(hw_res, sw_res)
    if not allclose:
        dist = hw_res-sw_res
        max_dist, min_dist = np.max(dist), np.min(dist)
        print(f"dist [{min_dist}, {max_dist}]")
        n_nonzeros = np.count_nonzero(dist)
        print(f"Mismatch/Total: {n_nonzeros}/{dist.size}")
    else:
        print("All close.")

if __name__=="__main__":
    test(
        shape=(1024,1024,10,10),
        rand_state=100
    )