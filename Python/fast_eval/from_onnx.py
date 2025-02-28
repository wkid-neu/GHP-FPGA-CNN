import onnx

def extract(model_path: str, res_file_path: str):
    """Extract supported layers from the given onnx model and wirte them into the csv file."""
    onnx_graph = onnx.load(model_path).graph
    for node in onnx_graph.node:
        print(node)
