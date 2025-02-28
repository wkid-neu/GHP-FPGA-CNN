import numpy as np
import onnx
import onnxruntime as ort
from io import BytesIO
from op_helper import (
    make_hw_shift, make_hw_round, make_hw_shift2
)
from onnx import helper, TensorProto

def hw_shift():
    shape = (5, 5)
    direction = "RIGHT"
    
    X = np.random.randint(-256, 255, shape).astype(np.int64)
    Y = np.array(2).astype(np.int64)

    graph = helper.make_graph(
        nodes=[],
        name="test_hw_shift2",
        inputs=[
            helper.make_tensor_value_info(name="X", elem_type=TensorProto.INT64, shape=shape),  # X
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.INT64, shape=[]),  # Y
        ],
        outputs=[
            helper.make_tensor_value_info(name="Z", elem_type=TensorProto.INT64, shape=shape),  # Z
        ],
        initializer=[]
    )

    nodes, tensors = make_hw_shift(
        inputs=["X", "Y"],
        outputs=["Z"],
        name="test_hw_shift2_node",
        direction=direction
    )
    graph.node.extend(nodes)
    graph.initializer.extend(tensors)

    # run inference
    model = helper.make_model(graph=graph)
    buf = BytesIO()
    onnx.save(model, buf)
    # onnx.save(model, "test.onnx")
    sess = ort.InferenceSession(buf.getvalue())
    res = sess.run(
        output_names=["Z"], 
        input_feed={
            "X": X,
            "Y": Y
        }
    )

    print(X)
    print(res[0])

def hw_round():
    XW, XFW = 10, 1
    XIW = XW-XFW

    shape = (5, 5)
    X = np.random.randint(-(2**(XW-1)), 2**(XW-1)-1, shape).astype(np.int64)
    # shape = (1,)
    # X = np.array([-35]).astype(np.int64)

    graph = helper.make_graph(
        nodes=[],
        name="test_hw_round",
        inputs=[
            helper.make_tensor_value_info(name="X", elem_type=TensorProto.INT64, shape=shape),  # X
        ],
        outputs=[
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.INT64, shape=shape),  # Y
        ],
        initializer=[]
    )

    nodes, tensors = make_hw_round(
        inputs=["X"],
        outputs=["Y"],
        XFW=XFW,
        YW=XIW,
        name="test_hw_round_node",
    )
    graph.node.extend(nodes)
    graph.initializer.extend(tensors)

    # run inference
    model = helper.make_model(graph=graph)
    buf = BytesIO()
    onnx.save(model, buf)
    # onnx.save(model, "test.onnx")
    sess = ort.InferenceSession(buf.getvalue())
    res = sess.run(
        output_names=["Y"], 
        input_feed={
            "X": X
        }
    )

    print(X/(2**XFW))
    print(res[0])

def hw_shift2():
    XW, ZW = 9, 8
    right_shift_bits = 1

    shape = (5, 5)
    X = np.random.randint(-(2**(XW-1)), 2**(XW-1)-1, shape).astype(np.int64)
    Y = np.array(right_shift_bits).astype(np.int64)

    graph = helper.make_graph(
        nodes=[],
        name="test_hw_shift2",
        inputs=[
            helper.make_tensor_value_info(name="X", elem_type=TensorProto.INT64, shape=shape),  # X
            helper.make_tensor_value_info(name="Y", elem_type=TensorProto.INT64, shape=[]),  # Y
        ],
        outputs=[
            helper.make_tensor_value_info(name="Z", elem_type=TensorProto.INT64, shape=shape),  # Z
        ],
        initializer=[]
    )

    nodes, tensors = make_hw_shift2(
        inputs=["X", "Y"],
        outputs=["Z"],
        ZW=ZW,
        name="test_hw_shift2_node"
    )
    graph.node.extend(nodes)
    graph.initializer.extend(tensors)

    # run inference
    model = helper.make_model(graph=graph)
    buf = BytesIO()
    onnx.save(model, buf)
    onnx.save(model, "test.onnx")
    sess = ort.InferenceSession(buf.getvalue())
    res = sess.run(
        output_names=["Z"], 
        input_feed={
            "X": X,
            "Y": Y
        }
    )

    print(X)
    print(res[0])

if __name__=="__main__":
    hw_shift2()
