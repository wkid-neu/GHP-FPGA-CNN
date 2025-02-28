import onnxruntime as ort
import onnx
import numpy as np
from onnx import helper, TensorProto, GraphProto, NodeProto
from io import BytesIO
from typing import Tuple, List, Dict, Any
from fe import op_helper
import utils

def hw_impl(
    inputs: List[str],  # X, W, B
    outputs: List[str],  # Y
    name: str,  # node_name
    params: Dict[str, Any],  # prepared parameters
) -> Tuple[List[NodeProto], List[TensorProto]]:  # nodes, initializers
    nodes, tensors = [], []

    KH, KW = params["KH"], params["KW"]
    padL, padR, padU, padD = params["padL"], params["padR"], params["padU"], params["padD"]
    strideH, strideW = params["strideH"], params["strideW"]
    group = params["group"]
    m1, n1 = params["m1"], params["n1"]
    xz, wz, yz = params["xz"], params["wz"], params["yz"]

    tensors.extend([
        helper.make_tensor(name=f"{name}/Constant_0", data_type=TensorProto.INT64, dims=[], vals=[xz]),
        helper.make_tensor(name=f"{name}/Constant_1", data_type=TensorProto.INT64, dims=[], vals=[wz]),
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
        op_type="Conv",
        inputs=[f"{name}/Cast_2", f"{name}/Cast_3", f"{name}/Cast_4"],
        outputs=[f"{name}/Conv_0"],
        name=f"{name}/Conv_0",
        group=group,
        kernel_shape=(KH, KW),
        pads=(padU, padL, padD, padR),
        strides=(strideH, strideW)
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/Conv_0"],
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
    x, x_scale, x_zero_point,
    w, w_scale, w_zero_point,
    y_scale, y_zero_point,
    B,
    kernel_shape, pads, strides, group
) -> GraphProto:
    node = helper.make_node(
        op_type="QLinearConv",
        inputs=["x", "x_scale", "x_zero_point", "w", "w_scale", "w_zero_point", "y_scale", "y_zero_point", "B"],
        outputs=["y"],
        name="node_0",
        domain="com.microsoft",
        group=group,
        kernel_shape=kernel_shape,
        pads=pads,
        strides=strides
    )

    # shape of ofm
    OH, OW = utils.conv_get_ofm_shape(
        x.shape[-2], x.shape[-1],
        kernel_shape[0], kernel_shape[1],
        strides[0], strides[1],
        pads[1], pads[3], pads[0], pads[2]
    )
    y_shape = (x.shape[0], w.shape[0], OH, OW)

    graph = helper.make_graph(
        nodes=[node],
        name="graph_0",
        inputs=[
            helper.make_tensor_value_info(name="x", elem_type=TensorProto.UINT8, shape=x.shape),
        ],
        outputs=[
            helper.make_tensor_value_info(name="y", elem_type=TensorProto.UINT8, shape=y_shape),
        ],
        initializer=[
            helper.make_tensor(name="x_scale", data_type=TensorProto.FLOAT, dims=[], vals=x_scale),
            helper.make_tensor(name="x_zero_point", data_type=TensorProto.UINT8, dims=[], vals=x_zero_point),
            helper.make_tensor(name="w", data_type=TensorProto.UINT8, dims=w.shape, vals=w.flatten()),
            helper.make_tensor(name="w_scale", data_type=TensorProto.FLOAT, dims=[], vals=w_scale),
            helper.make_tensor(name="w_zero_point", data_type=TensorProto.UINT8, dims=[], vals=w_zero_point),
            helper.make_tensor(name="y_scale", data_type=TensorProto.FLOAT, dims=[], vals=y_scale),
            helper.make_tensor(name="y_zero_point", data_type=TensorProto.UINT8, dims=[], vals=y_zero_point),
            helper.make_tensor(name="B", data_type=TensorProto.INT32, dims=B.shape, vals=B.flatten()),
        ]
    )

    return graph

def make_hw_graph(
    x, x_scale, x_zero_point,
    w, w_scale, w_zero_point,
    y_scale, y_zero_point,
    B,
    kernel_shape, pads, strides, group
) -> GraphProto:
    # prepare parameters
    M1 = float(x_scale)*float(w_scale)/float(y_scale)
    n1, m1 = utils.quantize_M(M1, 26)
    params = {
        "KH": kernel_shape[0], "KW": kernel_shape[1], 
        "strideH": strides[0], "strideW": strides[1], 
        "padL": pads[1], "padR": pads[3], "padU": pads[0], "padD": pads[2], 
        "group": group,
        "m1": m1, "n1": n1,
        "xz": int(x_zero_point), "wz": int(w_zero_point), "yz": int(y_zero_point)
    }

    nodes, tensors = hw_impl(
        inputs=["x", "w", "B"],
        outputs=["y"],
        name="hw_0",
        params=params
    )

    # shape of ofm
    OH, OW = utils.conv_get_ofm_shape(
        x.shape[-2], x.shape[-1],
        kernel_shape[0], kernel_shape[1],
        strides[0], strides[1],
        pads[1], pads[3], pads[0], pads[2]
    )
    y_shape = (x.shape[0], w.shape[0], OH, OW)

    tensors.extend([
        helper.make_tensor(name="w", data_type=TensorProto.UINT8, dims=w.shape, vals=w.flatten()),
        helper.make_tensor(name="B", data_type=TensorProto.INT32, dims=B.shape, vals=B.flatten()),
    ])

    graph = helper.make_graph(
        nodes=nodes,
        name="graph_0",
        inputs=[
            helper.make_tensor_value_info(name="x", elem_type=TensorProto.UINT8, shape=x.shape),
        ],
        outputs=[
            helper.make_tensor_value_info(name="y", elem_type=TensorProto.UINT8, shape=y_shape),
        ],
        initializer=tensors
    )

    return graph

def exec_graph(
    graph: GraphProto,  # hw_graph or sw_graph
    x
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
        output_names=["y"], 
        input_feed={
            "x": x, 
        }
    )
    return res[0]

def test(
    x_shape=(1,4,4,4),
    OC=16,
    kernel_shape=(3,3),
    pads=(1,1,1,1),  # (padU, padL, padD, padR)
    strides=(1,1),
    group=2,
    rand_state: int = 1
):
    import torch
    import torch.nn.functional as F

    # real world example
    np.random.seed(rand_state)
    ori_x = np.random.randn(*x_shape)
    ori_w = np.random.randn(OC, x_shape[1]//group, kernel_shape[0], kernel_shape[1])
    ori_B = np.random.randn(OC,)
    ori_y = F.pad(
        input=torch.tensor(ori_x),
        pad=(pads[1], pads[3], pads[0], pads[2]),
        mode="constant",
        value=0.0
    )
    ori_y = F.conv2d(
        input=ori_y,
        weight=torch.tensor(ori_w),
        bias=torch.tensor(ori_B),
        stride=strides,
        padding=(0,0),
        groups=group
    ).numpy()

    # prepare inputs
    x, x_scale, x_zero_point = utils.quant_auto(ori_x, n_bits=8, signed=False)
    w, w_scale, w_zero_point = utils.quant_auto(ori_w, n_bits=8, signed=False)
    B = utils.quant(
        ori_B, x_scale*w_scale, 0,
        n_bits=32, signed=True
    )
    _, y_scale, y_zero_point = utils.quant_auto(ori_y, n_bits=8, signed=False)

    # cast
    x, x_scale, x_zero_point = x.astype(np.uint8), np.array([x_scale]), np.array([x_zero_point])
    w, w_scale, w_zero_point = w.astype(np.uint8), np.array([w_scale]), np.array([w_zero_point])
    y_scale, y_zero_point = np.array([y_scale]), np.array([y_zero_point])
    B = B.astype(np.int32)

    # sw_res
    sw_graph = make_sw_graph(
        x, x_scale, x_zero_point,
        w, w_scale, w_zero_point,
        y_scale, y_zero_point,
        B,
        kernel_shape=kernel_shape,
        pads=pads,
        strides=strides,
        group=group
    )
    sw_res = exec_graph(
        sw_graph,
        x
    ).astype(np.int64)
    # print(sw_res)

    # hw_res
    hw_graph = make_hw_graph(
        x, x_scale, x_zero_point,
        w, w_scale, w_zero_point,
        y_scale, y_zero_point,
        B,
        kernel_shape=kernel_shape,
        pads=pads,
        strides=strides,
        group=group
    )
    hw_res = exec_graph(
        hw_graph,
        x
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
        x_shape=(16,64,224,224),
        OC=128,
        kernel_shape=(11,11),
        pads=(1,1,1,1),
        strides=(4,4),
        group=1,
        rand_state=2048
    )
