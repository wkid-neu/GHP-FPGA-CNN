import onnxruntime as ort
import onnx
import numpy as np
from onnx import helper, TensorProto, GraphProto, NodeProto
from io import BytesIO
from typing import Tuple, List, Dict, Any
from fe import op_helper
import utils

def hw_impl(
    inputs: List[str],  # X1, X2, ...
    outputs: List[str],  # Y
    name: str,  # node_name
    params: Dict[str, Any],  # prepared parameters
) -> Tuple[List[NodeProto], List[TensorProto]]:  # nodes, initializers
    nodes, tensors = [], []

    yz = params["yz"]
    m_dict, n_dict, xz_dict = {}, {}, {}
    for i in range(len(inputs)):
        tensor_name = params[f"name{i}"]
        m_dict[tensor_name] = params[f"m{i}"]
        n_dict[tensor_name] = params[f"n{i}"]
        xz_dict[tensor_name] = params[f"xz{i}"]

    tensors.extend([
        helper.make_tensor(name=f"{name}/Constant_0", data_type=TensorProto.INT64, dims=[], vals=[yz]),
        helper.make_tensor(name=f"{name}/Constant_1", data_type=TensorProto.INT64, dims=[], vals=[0]),
        helper.make_tensor(name=f"{name}/Constant_2", data_type=TensorProto.INT64, dims=[], vals=[255]),
    ])

    for i in range(len(inputs)):
        tensors.extend([
            helper.make_tensor(name=f"{name}/{i}/Constant_0", data_type=TensorProto.INT64, dims=[], vals=[xz_dict[inputs[i]]]),
            helper.make_tensor(name=f"{name}/{i}/Constant_1", data_type=TensorProto.INT64, dims=[], vals=[m_dict[inputs[i]]]),
            helper.make_tensor(name=f"{name}/{i}/Constant_2", data_type=TensorProto.INT64, dims=[], vals=[n_dict[inputs[i]]]),
        ])

        nodes.append(helper.make_node(
            op_type="Cast",
            inputs=[inputs[i]],
            outputs=[f"{name}/{i}/Cast_0"],
            name=f"{name}/{i}/Cast_0",
            to=TensorProto.INT64
        ))

        nodes.append(helper.make_node(
            op_type="Sub",
            inputs=[f"{name}/{i}/Cast_0", f"{name}/{i}/Constant_0"],
            outputs=[f"{name}/{i}/Sub_0"],
            name=f"{name}/{i}/Sub_0",
        ))

        nodes.append(helper.make_node(
            op_type="Mul",
            inputs=[f"{name}/{i}/Sub_0", f"{name}/{i}/Constant_1"],
            outputs=[f"{name}/{i}/Mul_0"],
            name=f"{name}/{i}/Mul_0",
        ))

        ns, ts = op_helper.make_hw_shift2(
            inputs=[f"{name}/{i}/Mul_0", f"{name}/{i}/Constant_2"],
            outputs=[f"{name}/{i}/hw_shift_0"],
            ZW=9,
            name=f"{name}/{i}/hw_shift_0"
        )
        nodes.extend(ns)
        tensors.extend(ts)

        nodes.append(helper.make_node(
            op_type="Add",
            inputs=[f"{name}/{i}/hw_shift_0", f"{name}/Constant_0"],
            outputs=[f"{name}/{i}/Add_0"],
            name=f"{name}/{i}/Add_0",
        ))

    nodes.append(helper.make_node(
        op_type="Concat",
        inputs=[f"{name}/{i}/Add_0" for i in range(len(inputs))],
        outputs=[f"{name}/Concat_0"],
        name=f"{name}/Concat_0",
        axis=1
    ))

    nodes.append(helper.make_node(
        op_type="Clip",
        inputs=[f"{name}/Concat_0", f"{name}/Constant_1", f"{name}/Constant_2"],
        outputs=[f"{name}/Clip_0"],
        name=f"{name}/Clip_0"
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/Clip_0"],
        outputs=[outputs[0]],
        name=f"{name}/Cast_0",
        to=TensorProto.UINT8
    ))

    return nodes, tensors

def make_sw_graph(
    Y_scale, Y_zero_point,
    inputs  # ((input1, input1_scale, input1_zero_point), (input2, input2_scale, input2_zero_point), ...)
) -> GraphProto:
    input_names = ["Y_scale", "Y_zero_point"]
    for i in range(len(inputs)):
        input_names.extend([f"input{i}", f"input{i}_scale", f"input{i}_zero_point"])

    node = helper.make_node(
        op_type="QLinearConcat",
        inputs=input_names,
        outputs=["Y"],
        name="node_0",
        domain="com.microsoft",
        axis=1
    )

    input_value_infos = []
    for i in range(len(inputs)):
        input_value_infos.append(
            helper.make_tensor_value_info(name=f"input{i}", elem_type=TensorProto.UINT8, shape=inputs[i][0].shape),
        )
    
    init_tensors = [
        helper.make_tensor(name="Y_scale", data_type=TensorProto.FLOAT, dims=[], vals=Y_scale),
        helper.make_tensor(name="Y_zero_point", data_type=TensorProto.UINT8, dims=[], vals=Y_zero_point),
    ]
    for i in range(len(inputs)):
        init_tensors.extend([
            helper.make_tensor(name=f"input{i}_scale", data_type=TensorProto.FLOAT, dims=[], vals=inputs[i][1]),
            helper.make_tensor(name=f"input{i}_zero_point", data_type=TensorProto.UINT8, dims=[], vals=inputs[i][2]),
        ])

    input0 = inputs[0][0]
    y_shape = list(input0.shape)
    for i in range(1, len(inputs)):
        y_shape[1] += inputs[i][0].shape[1]
    
    graph = helper.make_graph(
        nodes=[node],
        name="graph_0",
        inputs=input_value_infos,
        outputs=[
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.UINT8, shape=y_shape),
        ],
        initializer=init_tensors
    )

    return graph

def make_hw_graph(
    Y_scale, Y_zero_point,
    inputs,  # ((input1, input1_scale, input1_zero_point), (input2, input2_scale, input2_zero_point), ...)
) -> GraphProto:
    # prepare parameters
    params = {}
    for i in range(len(inputs)):
        M = float(inputs[i][1])/float(Y_scale)
        n, m = utils.quantize_M(M, 26)
        params.update({
            f"name{i}": f"input{i}", 
            f"m{i}": m, f"n{i}": n, f"xz{i}": int(inputs[i][2])
        })
    params["yz"] = int(Y_zero_point)

    nodes, tensors = hw_impl(
        inputs=[f"input{i}" for i in range(len(inputs))],
        outputs=["Y"],
        name="hw_0",
        params=params
    )

    input_value_infos = []
    for i in range(len(inputs)):
        input_value_infos.append(
            helper.make_tensor_value_info(name=f"input{i}", elem_type=TensorProto.UINT8, shape=inputs[i][0].shape),
        )

    input0 = inputs[0][0]
    y_shape = list(input0.shape)
    for i in range(1, len(inputs)):
        y_shape[1] += inputs[i][0].shape[1]

    graph = helper.make_graph(
        nodes=nodes,
        name="graph_0",
        inputs=input_value_infos,
        outputs=[
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.UINT8, shape=y_shape),
        ],
        initializer=tensors
    )

    return graph

def exec_graph(
    graph: GraphProto,  # hw_graph or sw_graph
    inputs  # (input1, input2, ...)
) -> np.ndarray:
    # build model
    model = helper.make_model(graph=graph)

    # save model into buffer
    buf = BytesIO()
    # onnx.save(model, "test.onnx")
    onnx.save(model, buf)

    input_feed = {}
    for i in range(len(inputs)):
        input_feed[f"input{i}"] = inputs[i]

    # run inference
    sess = ort.InferenceSession(buf.getvalue())
    res = sess.run(
        output_names=["Y"], 
        input_feed=input_feed
    )
    return res[0]

def test(
    input0_shape=(1,3,4,4),
    chan_list=(4,5,6),
    rand_state: int = 1
):
    # real world example
    np.random.seed(rand_state)
    ori_inputs = [np.random.randn(*input0_shape)]
    for i in range(len(chan_list)):
        input_shape = list(input0_shape)
        input_shape[1] = chan_list[i]
        ori_inputs.append(np.random.randn(*input_shape))

    # prepare inputs
    input_list, scale_list, zero_point_list = [], [], []
    for i in range(len(chan_list)+1):
        input, input_scale, input_zero_point = utils.quant_auto(ori_inputs[i], n_bits=8, signed=False)
        input_list.append(input)
        scale_list.append(input_scale)
        zero_point_list.append(input_zero_point)
    
    Y_scale, Y_zero_point = scale_list[0], zero_point_list[0]
    for i in range(1, len(chan_list)+1):
        if scale_list[i] > Y_scale:
            Y_scale, Y_zero_point = scale_list[i], zero_point_list[i]
    
    # cast
    input_list = [it.astype(np.uint8) for it in input_list]
    scale_list = [np.array([it]) for it in scale_list]
    zero_point_list = [np.array([it]) for it in zero_point_list]
    Y_scale, Y_zero_point = np.array([Y_scale]), np.array([Y_zero_point])
    
    inputs = []
    for i in range(len(chan_list)+1):
        inputs.append([input_list[i], scale_list[i], zero_point_list[i]])
    
    # sw_res
    sw_graph = make_sw_graph(
        Y_scale, Y_zero_point,
        inputs
    )
    sw_res = exec_graph(
        sw_graph,
        input_list
    ).astype(np.int64)
    # print("sw_res", sw_res)

    # hw_res
    hw_graph = make_hw_graph(
        Y_scale, Y_zero_point,
        inputs
    )
    hw_res = exec_graph(
        hw_graph,
        input_list
    ).astype(np.int64)
    # print("hw_res", hw_res)

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
        input0_shape=(1,3,512,512),
        chan_list=(4,5,6, 7, 8, 9, 10),
        rand_state=1024
    )
    # test(
    #     input0_shape=(1,1,1,4),
    #     chan_list=(1,),
    #     rand_state=1
    # )
