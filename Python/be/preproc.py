import onnx
import networkx as nx
import utils
from log import Log
import os

def proc(onnx_graph: onnx.GraphProto, output_dir_path: str) -> nx.DiGraph:
    """Convert onnx graph into DAG, and do some pre-processing."""
    Log.i(f"Preproc: Build DAG.")
    g = utils.onnx_to_dag(onnx_graph)
    _remove_flatten(g)
    _remove_quant(g)
    _remove_dequant(g)
    Log.i(f"Preproc: Check the graph.")
    assert nx.is_directed_acyclic_graph(g), f"Error, the graph is not a DAG after pre-processing."
    Log.i(f"Preproc: Save the graph into file.")
    utils.visualize_dag(g, os.path.join(output_dir_path, "DAG"))
    Log.i(f"Preproc: Done!")
    return g

def _remove_flatten(graph: nx.DiGraph) -> None:
    """Remove flatten vertices."""
    # Find nodes
    flatten_nodes, new_edges = [], []
    for node, attr in graph.nodes.items():
        onnx_node = attr["att_obj"]
        if onnx_node.op_type == "Flatten":
            flatten_nodes.append(node)
            # Previous nodes
            prevs = list(graph.predecessors(node))
            assert len(prevs) == 1, f"Unsupported Flatten node {node} which has {len(prevs)} predecessors."
            # Next nodes
            nexts = list(graph.successors(node))
            assert len(nexts) == 1, f"Unsupported Flatten node {node} which has {len(nexts)} successors."
            # Create a new edge
            new_edges.append((prevs[0], nexts[0]))
    # Remove nodes
    for node, edge in zip(flatten_nodes, new_edges):
        graph.remove_node(node)
        graph.add_edge(*edge)
        Log.i(f"Preproc: Remove {node} from DAG.")

def _remove_quant(graph: nx.DiGraph) -> None:
    """Remove the input QuantizeLinear vertex."""
    # Find the input node
    first_node = []
    for node, attr in graph.nodes.items():
        if graph.in_degree(node) == 0:
            first_node.append(node)
    assert len(first_node) == 1, f"Unsupported DAG with {len(first_node)} input node(s), node(s): {first_node}."
    first_node = first_node[0]
    # The first node must be QuantizeLinear
    onnx_node = graph.nodes[first_node]["att_obj"]
    assert onnx_node.op_type == "QuantizeLinear", f"The input node must be QuantizeLinear, current is {onnx_node.op_type}."
    # Remove the node
    Log.i(f"Preproc: Remove {first_node} from DAG.")
    graph.remove_node(first_node)

def _remove_dequant(graph: nx.DiGraph) -> None:
    """Remove the output DequantizeLinear vertex."""
    # Find the output node
    last_node = []
    for node, attr in graph.nodes.items():
        if graph.out_degree(node) == 0:
            last_node.append(node)
    assert len(last_node) == 1, f"Unsupported DAG with {len(last_node)} output node(s), node(s): {last_node}."
    last_node = last_node[0]
    # The last node must be DequantizeLinear
    onnx_node = graph.nodes[last_node]["att_obj"]
    assert onnx_node.op_type == "DequantizeLinear", f"The output node must be QuantizeLinear, current is {onnx_node.op_type}."
    # Remove the node
    Log.i(f"Preproc: Remove {last_node} from DAG.")
    graph.remove_node(last_node)
