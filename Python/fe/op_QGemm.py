import onnxruntime as ort
import onnx
import numpy as np
from onnx import helper, TensorProto, GraphProto, NodeProto
from io import BytesIO
from typing import Tuple, List, Dict, Any
from fe import op_helper
import utils

def hw_impl(
    inputs: List[str],  # A, B, C
    outputs: List[str],  # Y
    name: str,  # node_name
    params: Dict[str, Any],  # prepared parameters
) -> Tuple[List[NodeProto], List[TensorProto]]:  # nodes, initializers
    nodes, tensors = [], []

    m1, n1 = params["m1"], params["n1"]
    az, bz, yz = params["az"], params["bz"], params["yz"]

    tensors.extend([
        helper.make_tensor(name=f"{name}/Constant_0", data_type=TensorProto.INT64, dims=[], vals=[az]),
        helper.make_tensor(name=f"{name}/Constant_1", data_type=TensorProto.INT64, dims=[], vals=[bz]),
        helper.make_tensor(name=f"{name}/Constant_2", data_type=TensorProto.INT64, dims=[], vals=[yz]),
        helper.make_tensor(name=f"{name}/Constant_3", data_type=TensorProto.INT64, dims=[], vals=[m1]),
        helper.make_tensor(name=f"{name}/Constant_4", data_type=TensorProto.INT64, dims=[], vals=[n1]),
        helper.make_tensor(name=f"{name}/Constant_5", data_type=TensorProto.INT64, dims=[], vals=[0]),
        helper.make_tensor(name=f"{name}/Constant_6", data_type=TensorProto.INT64, dims=[], vals=[255]),
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
        op_type="Cast",
        inputs=[f"{name}/Sub_0"],
        outputs=[f"{name}/Cast_2"],
        name=f"{name}/Cast_2",
        to=TensorProto.FLOAT
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/Sub_1"],
        outputs=[f"{name}/Cast_3"],
        name=f"{name}/Cast_3",
        to=TensorProto.FLOAT
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[inputs[2]],
        outputs=[f"{name}/Cast_4"],
        name=f"{name}/Cast_4",
        to=TensorProto.FLOAT
    ))

    nodes.append(helper.make_node(
        op_type="Gemm",
        inputs=[f"{name}/Cast_2", f"{name}/Cast_3", f"{name}/Cast_4"],
        outputs=[f"{name}/Gemm_0"],
        name=f"{name}/Gemm_0",
        alpha=1.0,
        beta=1.0,
        transA=0,
        transB=1
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/Gemm_0"],
        outputs=[f"{name}/Cast_5"],
        name=f"{name}/Cast_5",
        to=TensorProto.INT64
    ))

    nodes.append(helper.make_node(
        op_type="Mul",
        inputs=[f"{name}/Cast_5", f"{name}/Constant_3"],
        outputs=[f"{name}/Mul_0"],
        name=f"{name}/Mul_0",
    ))

    ns, ts = op_helper.make_hw_shift2(
        inputs=[f"{name}/Mul_0", f"{name}/Constant_4"],
        outputs=[f"{name}/hw_shift_0"],
        ZW=9,
        name=f"{name}/hw_shift_0"
    )
    nodes.extend(ns)
    tensors.extend(ts)

    nodes.append(helper.make_node(
        op_type="Add",
        inputs=[f"{name}/hw_shift_0", f"{name}/Constant_2"],
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
    A, a_scale, a_zero_point,
    B, b_scale, b_zero_point,
    C,
    y_scale, y_zero_point,
) -> GraphProto:
    node = helper.make_node(
        op_type="QGemm",
        inputs=["A", "a_scale", "a_zero_point", "B", "b_scale", "b_zero_point", "C", "y_scale", "y_zero_point"],
        outputs=["Y"],
        name="node_0",
        domain="com.microsoft",
        alpha=1.0,
        transA=0,
        transB=1
    )

    # shape of Y
    M, _ = A.shape
    N = B.shape[0]

    graph = helper.make_graph(
        nodes=[node],
        name="graph_0",
        inputs=[
            helper.make_tensor_value_info(name="A", elem_type=TensorProto.UINT8, shape=A.shape),
        ],
        outputs=[
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.UINT8, shape=(M, N)),
        ],
        initializer=[
            helper.make_tensor(name="a_scale", data_type=TensorProto.FLOAT, dims=[], vals=a_scale),
            helper.make_tensor(name="a_zero_point", data_type=TensorProto.UINT8, dims=[], vals=a_zero_point),
            helper.make_tensor(name="B", data_type=TensorProto.UINT8, dims=B.shape, vals=B.flatten()),
            helper.make_tensor(name="b_scale", data_type=TensorProto.FLOAT, dims=[], vals=b_scale),
            helper.make_tensor(name="b_zero_point", data_type=TensorProto.UINT8, dims=[], vals=b_zero_point),
            helper.make_tensor(name="C", data_type=TensorProto.INT32, dims=C.shape, vals=C.flatten()),
            helper.make_tensor(name="y_scale", data_type=TensorProto.FLOAT, dims=[], vals=y_scale),
            helper.make_tensor(name="y_zero_point", data_type=TensorProto.UINT8, dims=[], vals=y_zero_point),
        ]
    )

    return graph

def make_hw_graph(
    A, a_scale, a_zero_point,
    B, b_scale, b_zero_point,
    C,
    y_scale, y_zero_point
) -> GraphProto:
    # prepare parameters
    M1 = float(a_scale)*float(b_scale)/float(y_scale)
    n1, m1 = utils.quantize_M(M1, 26)
    params = {
        "m1": m1, "n1": n1,
        "az": int(a_zero_point), "bz": int(b_zero_point), "yz": int(y_zero_point)
    }

    nodes, tensors = hw_impl(
        inputs=["A", "B", "C"],
        outputs=["Y"],
        name="hw_0",
        params=params
    )

    # shape of Y
    M, _ = A.shape
    N = B.shape[0]

    tensors.extend([
        helper.make_tensor(name="B", data_type=TensorProto.UINT8, dims=B.shape, vals=B.flatten()),
        helper.make_tensor(name="C", data_type=TensorProto.INT32, dims=C.shape, vals=C.flatten()),
    ])

    graph = helper.make_graph(
        nodes=nodes,
        name="graph_0",
        inputs=[
            helper.make_tensor_value_info(name="A", elem_type=TensorProto.UINT8, shape=A.shape),
        ],
        outputs=[
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.UINT8, shape=(M, N)),
        ],
        initializer=tensors
    )

    return graph

def exec_graph(
    graph: GraphProto,  # hw_graph or sw_graph
    A
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
            "A": A, 
        }
    )
    return res[0]

def test(
    A_shape=(2,3),
    B_shape=(4,3),
    rand_state: int = 1
):
    # real world example
    np.random.seed(rand_state)
    ori_A = np.random.randn(*A_shape)
    ori_B = np.random.randn(*B_shape)
    ori_C = np.random.randn(*(B_shape[0],))
    ori_Y = np.matmul(ori_A, ori_B.T)+ori_C

    # prepare inputs
    A, a_scale, a_zero_point = utils.quant_auto(ori_A, n_bits=8, signed=False)
    B, b_scale, b_zero_point = utils.quant_auto(ori_B, n_bits=8, signed=False)
    C = utils.quant(
        ori_C, a_scale*b_scale, 0,
        n_bits=32, signed=True
    )
    _, y_scale, y_zero_point = utils.quant_auto(ori_Y, n_bits=8, signed=False)

    # cast
    A, a_scale, a_zero_point = A.astype(np.uint8), np.array([a_scale]), np.array([a_zero_point])
    B, b_scale, b_zero_point = B.astype(np.uint8), np.array([b_scale]), np.array([b_zero_point])
    y_scale, y_zero_point = np.array([y_scale]), np.array([y_zero_point])
    C = C.astype(np.int32)

    # sw_res
    sw_graph = make_sw_graph(
        A, a_scale, a_zero_point,
        B, b_scale, b_zero_point,
        C,
        y_scale, y_zero_point
    )
    sw_res = exec_graph(
        sw_graph,
        A
    ).astype(np.int64)
    # print(sw_res)

    # hw_res
    hw_graph = make_hw_graph(
        A, a_scale, a_zero_point,
        B, b_scale, b_zero_point,
        C,
        y_scale, y_zero_point
    )
    hw_res = exec_graph(
        hw_graph,
        A
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
        A_shape=(1024,2048),
        B_shape=(2048,2048),
        # A_shape=(2,3),
        # B_shape=(4,3),
        rand_state=10
    )