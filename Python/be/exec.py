from typing import List
from log import Log
import networkx as nx

def make_exec_seq(graph: nx.DiGraph) -> List[str]:
    """Generate the execution sequence for the graph."""
    Log.i(f"Exec_seq: Start running.")
    ret = list(nx.topological_sort(graph))
    Log.i(f"Exec_seq: Done.")
    return ret
