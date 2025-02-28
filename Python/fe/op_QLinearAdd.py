import onnxruntime as ort
import onnx
import numpy as np
from onnx import helper, TensorProto, GraphProto, NodeProto
from io import BytesIO
from typing import Tuple, List, Dict, Any
from fe import op_helper
import utils

def hw_impl(
    inputs: List[str],  # A, B
    outputs: List[str],  # C
    name: str,  # node_name
    params: Dict[str, Any],  # prepared parameters
) -> Tuple[List[NodeProto], List[TensorProto]]:  # nodes, initializers
    nodes, tensors = [], []

    m1, m2, n = params["m1"], params["m2"], params["n"]
    az, bz, cz = params["az"], params["bz"], params["cz"]

    tensors.extend([
        helper.make_tensor(name=f"{name}/Constant_0", data_type=TensorProto.INT64, dims=[], vals=[az]),
        helper.make_tensor(name=f"{name}/Constant_1", data_type=TensorProto.INT64, dims=[], vals=[bz]),
        helper.make_tensor(name=f"{name}/Constant_2", data_type=TensorProto.INT64, dims=[], vals=[cz]),
        helper.make_tensor(name=f"{name}/Constant_3", data_type=TensorProto.INT64, dims=[], vals=[m1]),
        helper.make_tensor(name=f"{name}/Constant_4", data_type=TensorProto.INT64, dims=[], vals=[m2]),
        helper.make_tensor(name=f"{name}/Constant_5", data_type=TensorProto.INT64, dims=[], vals=[n]),
        helper.make_tensor(name=f"{name}/Constant_6", data_type=TensorProto.INT64, dims=[], vals=[0]),
        helper.make_tensor(name=f"{name}/Constant_7", data_type=TensorProto.INT64, dims=[], vals=[255]),
    ])

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[inputs[0]],
        outputs=[f"{name}/Cast_0"],
        name=f"{name}/Cast_0",
        to=TensorProto.INT64
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[inputs[1]],
        outputs=[f"{name}/Cast_1"],
        name=f"{name}/Cast_1",
        to=TensorProto.INT64
    ))

    nodes.append(helper.make_node(
        op_type="Sub",
        inputs=[f"{name}/Cast_0", f"{name}/Constant_0"],
        outputs=[f"{name}/Sub_0"],
        name=f"{name}/Sub_0"
    ))

    nodes.append(helper.make_node(
        op_type="Sub",
        inputs=[f"{name}/Cast_1", f"{name}/Constant_1"],
        outputs=[f"{name}/Sub_1"],
        name=f"{name}/Sub_1"
    ))

    nodes.append(helper.make_node(
        op_type="Mul",
        inputs=[f"{name}/Sub_0", f"{name}/Constant_3"],
        outputs=[f"{name}/Mul_0"],
        name=f"{name}/Mul_0"
    ))

    nodes.append(helper.make_node(
        op_type="Mul",
        inputs=[f"{name}/Sub_1", f"{name}/Constant_4"],
        outputs=[f"{name}/Mul_1"],
        name=f"{name}/Mul_1"
    ))

    nodes.append(helper.make_node(
        op_type="Add",
        inputs=[f"{name}/Mul_0", f"{name}/Mul_1"],
        outputs=[f"{name}/Add_0"],
        name=f"{name}/Add_0"
    ))

    ns, ts = op_helper.make_hw_shift2(
        inputs=[f"{name}/Add_0", f"{name}/Constant_5"],
        outputs=[f"{name}/hw_shift_0"],
        ZW=9,
        name=f"{name}/hw_shift_0"
    )
    nodes.extend(ns)
    tensors.extend(ts)

    nodes.append(helper.make_node(
        op_type="Add",
        inputs=[f"{name}/hw_shift_0", f"{name}/Constant_2"],
        outputs=[f"{name}/Add_1"],
        name=f"{name}/Add_1"
    ))

    nodes.append(helper.make_node(
        op_type="Clip",
        inputs=[f"{name}/Add_1", f"{name}/Constant_6", f"{name}/Constant_7"],
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
    A, A_scale, A_zero_point,
    B, B_scale, B_zero_point,
    C_scale, C_zero_point
) -> GraphProto:
    node = helper.make_node(
        op_type="QLinearAdd",
        inputs=["A", "A_scale", "A_zero_point", "B", "B_scale", "B_zero_point", "C_scale", "C_zero_point"],
        outputs=["C"],
        name="node_0",
        domain="com.microsoft"
    )

    graph = helper.make_graph(
        nodes=[node],
        name="graph_0",
        inputs=[
            helper.make_tensor_value_info(name="A", elem_type=TensorProto.UINT8, shape=A.shape),
            helper.make_tensor_value_info(name="B", elem_type=TensorProto.UINT8, shape=B.shape),
        ],
        outputs=[
            helper.make_tensor_value_info(name="C", elem_type=TensorProto.UINT8, shape=A.shape),
        ],
        initializer=[
            helper.make_tensor(name="A_scale", data_type=TensorProto.FLOAT, dims=[], vals=A_scale),
            helper.make_tensor(name="A_zero_point", data_type=TensorProto.UINT8, dims=[], vals=A_zero_point),
            helper.make_tensor(name="B_scale", data_type=TensorProto.FLOAT, dims=[], vals=B_scale),
            helper.make_tensor(name="B_zero_point", data_type=TensorProto.UINT8, dims=[], vals=B_zero_point),
            helper.make_tensor(name="C_scale", data_type=TensorProto.FLOAT, dims=[], vals=C_scale),
            helper.make_tensor(name="C_zero_point", data_type=TensorProto.UINT8, dims=[], vals=C_zero_point),
        ]
    )

    return graph

def make_hw_graph(
    A, A_scale, A_zero_point,
    B, B_scale, B_zero_point,
    C_scale, C_zero_point
) -> GraphProto:
    # prepare parameters
    M1, M2 = float(A_scale)/float(C_scale), float(B_scale)/float(C_scale)
    n, (m1, m2) = utils.quantize_M_list((M1, M2), 26)
    params = {
        "m1": m1, "m2": m2, "n": n,
        "az": int(A_zero_point), "bz": int(B_zero_point), "cz": int(C_zero_point)
    }

    nodes, tensors = hw_impl(
        inputs=["A", "B"],
        outputs=["C"],
        name="hw_0",
        params=params
    )

    graph = helper.make_graph(
        nodes=nodes,
        name="graph_0",
        inputs=[
            helper.make_tensor_value_info(name="A", elem_type=TensorProto.UINT8, shape=A.shape),
            helper.make_tensor_value_info(name="B", elem_type=TensorProto.UINT8, shape=B.shape),
        ],
        outputs=[
            helper.make_tensor_value_info(name="C", elem_type=TensorProto.UINT8, shape=A.shape),
        ],
        initializer=tensors
    )

    return graph

def exec_graph(
    graph: GraphProto,  # hw_graph or sw_graph
    A, B
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
        output_names=["C"], 
        input_feed={
            "A": A, 
            "B": B, 
        }
    )
    return res[0]

def test(
    shape=(1,3,4,4),
    rand_state: int = 1
):
    # real world example
    np.random.seed(rand_state)
    ori_A = np.random.randn(*shape)
    ori_B = np.random.randn(*shape)
    ori_C = ori_A+ori_B
    
    # prepare inputs
    np.random.seed(rand_state)
    A, A_scale, A_zero_point = utils.quant_auto(ori_A, n_bits=8, signed=False)
    B, B_scale, B_zero_point = utils.quant_auto(ori_B, n_bits=8, signed=False)
    _, C_scale, C_zero_point = utils.quant_auto(ori_C, n_bits=8, signed=False)

    # cast
    A, A_scale, A_zero_point = A.astype(np.uint8), np.array([A_scale]), np.array([A_zero_point])
    B, B_scale, B_zero_point = B.astype(np.uint8), np.array([B_scale]), np.array([B_zero_point])
    C_scale, C_zero_point = np.array([C_scale]), np.array([C_zero_point])

    # sw results
    sw_graph = make_sw_graph(
        A, A_scale, A_zero_point,
        B, B_scale, B_zero_point,
        C_scale, C_zero_point
    )
    sw_res = exec_graph(
        sw_graph,
        A, B
    ).astype(np.int64)
    # print(sw_res)

    # hw_res
    hw_graph = make_hw_graph(
        A, A_scale, A_zero_point,
        B, B_scale, B_zero_point,
        C_scale, C_zero_point,
    )
    hw_res = exec_graph(
        hw_graph,
        A, B
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
        shape=(2, 32, 224, 224),
        rand_state=1024
    )
