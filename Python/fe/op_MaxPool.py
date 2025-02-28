import onnxruntime as ort
import onnx
import numpy as np
from onnx import helper, TensorProto, GraphProto, NodeProto
from io import BytesIO
from typing import Tuple, List, Dict, Any
from fe import op_helper
import utils

#
# Note: ceil_mode is not supported, it should be processed by explicitly setting pads
#
def hw_impl(
    inputs: List[str],  # X
    outputs: List[str],  # Y
    name: str,  # node_name
    params: Dict[str, Any],  # prepared parameters
) -> Tuple[List[NodeProto], List[TensorProto]]:  # nodes, initializers
    nodes, tensors = [], []

    INC = params["INC"]
    KH, KW = params["KH"], params["KW"]
    padL, padR, padU, padD = params["padL"], params["padR"], params["padU"], params["padD"]
    strideH, strideW = params["strideH"], params["strideW"]
    m1, n1 = params["m1"], params["n1"]
    xz, nxz, yz = params["xz"], params["nxz"], params["yz"]

    pads = np.array([0, 0, padU, padL, 0, 0, padD, padR])
    tensors.extend([
        helper.make_tensor(name=f"{name}/Constant_0", data_type=TensorProto.INT64, dims=[], vals=[nxz]),
        helper.make_tensor(name=f"{name}/Constant_1", data_type=TensorProto.INT64, dims=[], vals=[m1]),
        helper.make_tensor(name=f"{name}/Constant_2", data_type=TensorProto.INT64, dims=[], vals=[n1]),
        helper.make_tensor(name=f"{name}/Constant_3", data_type=TensorProto.INT64, dims=[], vals=[yz]),
        helper.make_tensor(name=f"{name}/Constant_4", data_type=TensorProto.INT64, dims=[], vals=[0]),
        helper.make_tensor(name=f"{name}/Constant_5", data_type=TensorProto.INT64, dims=[], vals=[255]),
        helper.make_tensor(name=f"{name}/Constant_6", data_type=TensorProto.INT64, dims=[], vals=[xz]),
        helper.make_tensor(name=f"{name}/Constant_7", data_type=TensorProto.INT64, dims=pads.shape, vals=pads.flatten()),
    ])

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[inputs[0]],
        outputs=[f"{name}/Cast_0"],
        name=f"{name}/Cast_0",
        to=TensorProto.INT64
    ))

    nodes.append(helper.make_node(
        op_type="Pad",
        inputs=[f"{name}/Cast_0", f"{name}/Constant_7", f"{name}/Constant_6"],
        outputs=[f"{name}/Pad_0"],
        name=f"{name}/Pad_0",
        mode="constant"
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/Pad_0"],
        outputs=[f"{name}/Cast_1"],
        name=f"{name}/Cast_1",
        to=TensorProto.FLOAT
    ))

    nodes.append(helper.make_node(
        op_type="MaxPool",
        inputs=[f"{name}/Cast_1"],
        outputs=[f"{name}/MaxPool_0"],
        name=f"{name}/MaxPool_0",
        kernel_shape=(KH, KW),
        pads=(0, 0, 0, 0),
        strides=(strideH, strideW)
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/MaxPool_0"],
        outputs=[f"{name}/Cast_2"],
        name=f"{name}/Cast_2",
        to=TensorProto.INT64
    ))

    nodes.append(helper.make_node(
        op_type="Sub",
        inputs=[f"{name}/Cast_2", f"{name}/Constant_0"],
        outputs=[f"{name}/Sub_0"],
        name=f"{name}/Sub_0"
    ))

    nodes.append(helper.make_node(
        op_type="Mul",
        inputs=[f"{name}/Sub_0", f"{name}/Constant_1"],
        outputs=[f"{name}/Mul_0"],
        name=f"{name}/Mul_0",
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
        inputs=[f"{name}/hw_shift_0", f"{name}/Constant_3"],
        outputs=[f"{name}/Add_0"],
        name=f"{name}/Add_0",
    ))

    nodes.append(helper.make_node(
        op_type="Clip",
        inputs=[f"{name}/Add_0", f"{name}/Constant_4", f"{name}/Constant_5"],
        outputs=[f"{name}/Clip_0"],
        name=f"{name}/Clip_0"
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/Clip_0"],
        outputs=[outputs[0]],
        name=f"{name}/Cast_3",
        to=TensorProto.UINT8
    ))

    return nodes, tensors

def make_sw_graph(
    X,
    kernel_shape, pads, strides,
    ceil_mode: bool = False
) -> GraphProto:
    node = helper.make_node(
        op_type="MaxPool",
        inputs=["X"],
        outputs=["Y"],
        name="node_0",
        domain=None,
        ceil_mode=ceil_mode,
        kernel_shape=kernel_shape,
        pads=pads,
        strides=strides
    )

    # shape of ofm
    OH, OW = utils.conv_get_ofm_shape(
        X.shape[-2], X.shape[-1],
        kernel_shape[0], kernel_shape[1],
        strides[0], strides[1],
        pads[1], pads[3], pads[0], pads[2],
        ceil_mode=ceil_mode
    )
    y_shape = list(X.shape)
    y_shape[-1], y_shape[-2] = OW, OH

    graph = helper.make_graph(
        nodes=[node],
        name="graph_0",
        inputs=[
            helper.make_tensor_value_info(name="X", elem_type=TensorProto.UINT8, shape=X.shape),
        ],
        outputs=[
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.UINT8, shape=y_shape),
        ],
        initializer=[]
    )

    return graph

def make_hw_graph(
    X,
    kernel_shape, pads, strides
) -> GraphProto:
    # prepare parameters
    params = {
        "INC": X.shape[1],
        "KH": kernel_shape[0], "KW": kernel_shape[1], 
        "strideH": strides[0], "strideW": strides[1], 
        "padL": pads[1], "padR": pads[3], "padU": pads[0], "padD": pads[2], 
        "m1": 1024, "n1": 10,
        "xz": 0, "nxz": 0, "yz": 0
    }

    nodes, tensors = hw_impl(
        inputs=["X"],
        outputs=["Y"],
        name="hw_0",
        params=params
    )

    # shape of ofm
    OH, OW = utils.conv_get_ofm_shape(
        X.shape[-2], X.shape[-1],
        kernel_shape[0], kernel_shape[1],
        strides[0], strides[1],
        pads[1], pads[3], pads[0], pads[2],
        ceil_mode=False
    )
    y_shape = list(X.shape)
    y_shape[-1], y_shape[-2] = OW, OH

    graph = helper.make_graph(
        nodes=nodes,
        name="graph_0",
        inputs=[
            helper.make_tensor_value_info(name="X", elem_type=TensorProto.UINT8, shape=X.shape),
        ],
        outputs=[
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.UINT8, shape=y_shape),
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
    shape=(1,3,4,4),
    kernel_shape=(3,3),
    pads=(1,1,1,1),  # (padU, padL, padD, padR)
    strides=(1,1),
    ceil_mode=0,
    rand_state: int = 1
):
    import torch
    import torch.nn.functional as F

    # handle pads
    padU, padL, padD, padR = pads[0], pads[1], pads[2], pads[3] 
    if ceil_mode:
        padL, padR, padU, padD = utils.pool_ceil_mode_to_pads(
            shape[-2], shape[-1], kernel_shape[0], kernel_shape[1],
            strides[0], strides[1],
            padL, padR, padU, padD
        )

    # real world example
    np.random.seed(rand_state)
    ori_X = np.random.randn(*shape)
    ori_Y = F.pad(
        input=torch.tensor(ori_X),
        pad=(pads[1], pads[3], pads[0], pads[2]),
        mode="constant",
        value=0.0
    )
    ori_Y = F._max_pool2d(
        input=ori_Y,
        kernel_size=kernel_shape,
        stride=strides,
        padding=(0,0),
        dilation=(1,1),
        ceil_mode=False,
        return_indices=False
    ).numpy()

    # prepare inputs
    X, _, _ = utils.quant_auto(ori_X, n_bits=8, signed=False)

    # cast
    X = X.astype(np.uint8)

    # sw results
    sw_graph = make_sw_graph(
        X,
        kernel_shape=kernel_shape,
        pads=pads,  # original paddings
        strides=strides,
        ceil_mode=ceil_mode
    )
    sw_res = exec_graph(
        sw_graph,
        X
    ).astype(np.int64)
    # print(sw_res)

    # hw results
    hw_graph = make_hw_graph(
        X,
        kernel_shape=kernel_shape,
        pads=(padU, padL, padD, padR),  # new paddings
        strides=strides
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
    # test(
    #     shape=(1,3,4,4),
    #     kernel_shape=(3,3),
    #     pads=(1,1,1,1),
    #     strides=(2,2),
    #     rand_state=1023
    # )

    # test(
    #     shape=(16,64,224,224),
    #     kernel_shape=(3,3),
    #     pads=(1,1,1,1),
    #     strides=(1,1),
    #     ceil_mode=True,
    #     rand_state=1023
    # )

    test(
        shape=(1,64,224,224),
        kernel_shape=(7,7),
        pads=(1,2,1,2),
        strides=(2,2),
        ceil_mode=True,
        rand_state=1023
    )

