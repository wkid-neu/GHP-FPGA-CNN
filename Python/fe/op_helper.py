from onnx import helper, NodeProto, TensorProto
from typing import List, Tuple, Any

def make_hw_shift(
    inputs: List[str],  # X, Y
    outputs: List[str],  # Z,
    ZW: int,  # width of Y
    name: str,  # node name
    **kwargs: Any,  # direction, "LEFT"/"RIGHT"
) -> Tuple[List[NodeProto], List[TensorProto]]:  # nodes, initializers
    """Shift operator that supports signed and unsigned input."""
    nodes, tensors = [], []

    tensors.extend([
        helper.make_tensor(name=f"{name}/Constant_0", data_type=TensorProto.INT64, dims=[], vals=[-(2**(ZW-1))]),
        helper.make_tensor(name=f"{name}/Constant_1", data_type=TensorProto.INT64, dims=[], vals=[(2**(ZW-1))-1]),
    ])

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[inputs[1]],
        outputs=[f"{name}/Cast_1"],
        name=f"{name}/Cast_1",
        to=TensorProto.UINT64
    ))

    nodes.append(helper.make_node(
        op_type="Sign",
        inputs=[inputs[0]],
        outputs=[f"{name}/Sign_0"],
        name=f"{name}/Sign_0"
    ))

    nodes.append(helper.make_node(
        op_type="Abs",
        inputs=[inputs[0]],
        outputs=[f"{name}/Abs_0"],
        name=f"{name}/Abs_0"
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/Abs_0"],
        outputs=[f"{name}/Cast_2"],
        name=f"{name}/Cast_2",
        to=TensorProto.UINT64
    ))

    nodes.append(helper.make_node(
        op_type="BitShift",
        inputs=[f"{name}/Cast_2", f"{name}/Cast_1"],
        outputs=[f"{name}/BitShift_0"],
        name=f"{name}/BitShift_0",
        direction=kwargs["direction"]
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/BitShift_0"],
        outputs=[f"{name}/Cast_3"],
        name=f"{name}/Cast_3",
        to=TensorProto.INT64
    ))

    nodes.append(helper.make_node(
        op_type="Mul",
        inputs=[f"{name}/Cast_3", f"{name}/Sign_0"],
        outputs=[f"{name}/Mul_0"],
        name=f"{name}/Mul_0"
    ))

    nodes.append(helper.make_node(
        op_type="Clip",
        inputs=[f"{name}/Mul_0", f"{name}/Constant_0", f"{name}/Constant_1"],
        outputs=[outputs[0]],
        name=f"{name}/Clip_0"
    ))

    return nodes, tensors

def make_hw_round(
    inputs: List[str],  # X
    outputs: List[str],  # Y
    XFW: int,  # width of fraction bits
    YW: int,  # width of Y
    name: str,  # node name
) -> Tuple[List[NodeProto], List[TensorProto]]:  # nodes, initializers
    """Round operator that supports fixed-point data."""
    nodes, tensors = [], []

    const_0_tensor = helper.make_tensor(
        name=f"{name}/Constant_0",
        data_type=TensorProto.DOUBLE,
        dims=[],
        vals=[2**XFW]
    )
    tensors.append(const_0_tensor)

    const_1_tensor = helper.make_tensor(
        name=f"{name}/Constant_1",
        data_type=TensorProto.INT64,
        dims=[],
        vals=[-(2**(YW-1))]
    )
    tensors.append(const_1_tensor)

    const_2_tensor = helper.make_tensor(
        name=f"{name}/Constant_2",
        data_type=TensorProto.INT64,
        dims=[],
        vals=[2**(YW-1)-1]
    )
    tensors.append(const_2_tensor)

    cast_0_node = helper.make_node(
        op_type="Cast",
        inputs=[
            inputs[0],  # input
        ],
        outputs=[
            f"{name}/Cast_0",  # output
        ],
        name=f"{name}/Cast_0",
        to=TensorProto.DOUBLE
    )
    nodes.append(cast_0_node)

    div_0_node = helper.make_node(
        op_type="Div",
        inputs=[
            f"{name}/Cast_0",  # A
            f"{name}/Constant_0",  # B
        ],
        outputs=[
            f"{name}/Div_0",  # output
        ],
        name=f"{name}/Div_0",
    )
    nodes.append(div_0_node)

    round_0_node = helper.make_node(
        op_type="Round",
        inputs=[
            f"{name}/Div_0",  # 
        ],
        outputs=[
            f"{name}/Round_0",  # Y
        ],
        name=f"{name}/Round_0",
    )
    nodes.append(round_0_node)

    cast_2_node = helper.make_node(
        op_type="Cast",
        inputs=[
            f"{name}/Round_0",  # input
        ],
        outputs=[
            f"{name}/Cast_2",  # output
        ],
        name=f"{name}/Cast_2",
        to=TensorProto.INT64
    )
    nodes.append(cast_2_node)

    clip_0_node = helper.make_node(
        op_type="Clip",
        inputs=[
            f"{name}/Cast_2",  # input
            f"{name}/Constant_1",  # min
            f"{name}/Constant_2",  # max
        ],
        outputs=[
            outputs[0],  # output
        ],
        name=f"{name}/Clip_0",
    )
    nodes.append(clip_0_node)

    return nodes, tensors

def make_hw_shift2(
    inputs: List[str],  # X, Y
    outputs: List[str],  # Z,
    ZW: int,  # width of Z
    name: str,  # node name
) -> Tuple[List[NodeProto], List[TensorProto]]:  # nodes, initializers
    """Right-Shift operator that supports signed and unsigned input."""
    nodes, tensors = [], []

    tensors.extend([
        helper.make_tensor(name=f"{name}/Constant_0", data_type=TensorProto.INT64, dims=[], vals=[1]),
        helper.make_tensor(name=f"{name}/Constant_1", data_type=TensorProto.INT64, dims=[], vals=[2]),
        helper.make_tensor(name=f"{name}/Constant_2", data_type=TensorProto.INT64, dims=[], vals=[-(2**(ZW-1))]),
        helper.make_tensor(name=f"{name}/Constant_3", data_type=TensorProto.INT64, dims=[], vals=[(2**(ZW-1))-1]),
    ])

    nodes.append(helper.make_node(
        op_type="Sub",
        inputs=[inputs[1], f"{name}/Constant_0"],
        outputs=[f"{name}/Sub_0"],
        name=f"{name}/Sub_0"
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/Sub_0"],
        outputs=[f"{name}/Cast_0"],
        name=f"{name}/Cast_0",
        to=TensorProto.UINT64
    ))

    nodes.append(helper.make_node(
        op_type="Sign",
        inputs=[inputs[0]],
        outputs=[f"{name}/Sign_0"],
        name=f"{name}/Sign_0"
    ))

    nodes.append(helper.make_node(
        op_type="Abs",
        inputs=[inputs[0]],
        outputs=[f"{name}/Abs_0"],
        name=f"{name}/Abs_0"
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/Abs_0"],
        outputs=[f"{name}/Cast_1"],
        name=f"{name}/Cast_1",
        to=TensorProto.UINT64
    ))

    nodes.append(helper.make_node(
        op_type="BitShift",
        inputs=[f"{name}/Cast_1", f"{name}/Cast_0"],
        outputs=[f"{name}/BitShift_0"],
        name=f"{name}/BitShift_0",
        direction="RIGHT"
    ))

    nodes.append(helper.make_node(
        op_type="Cast",
        inputs=[f"{name}/BitShift_0"],
        outputs=[f"{name}/Cast_2"],
        name=f"{name}/Cast_2",
        to=TensorProto.INT64
    ))

    nodes.append(helper.make_node(
        op_type="Mod",
        inputs=[f"{name}/Cast_2", f"{name}/Constant_1"],
        outputs=[f"{name}/Mod_0"],
        name=f"{name}/Mod_0"
    ))

    nodes.append(helper.make_node(
        op_type="Add",
        inputs=[f"{name}/Cast_2", f"{name}/Mod_0"],
        outputs=[f"{name}/Add_0"],
        name=f"{name}/Add_0"
    ))

    nodes.append(helper.make_node(
        op_type="Div",
        inputs=[f"{name}/Add_0", f"{name}/Constant_1"],
        outputs=[f"{name}/Div_0"],
        name=f"{name}/Div_0"
    ))

    nodes.append(helper.make_node(
        op_type="Mul",
        inputs=[f"{name}/Div_0", f"{name}/Sign_0"],
        outputs=[f"{name}/Mul_0"],
        name=f"{name}/Mul_0"
    ))

    nodes.append(helper.make_node(
        op_type="Clip",
        inputs=[f"{name}/Mul_0", f"{name}/Constant_2", f"{name}/Constant_3"],
        outputs=[outputs[0]],
        name=f"{name}/Clip_0"
    ))

    return nodes, tensors
