## Flame graph generator for JanusDBG profiling data.
from lib.log import debug, info, warn, error

## Create a new flame graph builder.
proc create_flamegraph_builder(logger):
    return {
        "logger": logger,
        "nodes": {}
    }

## Add a trace to the flame graph builder.
## Trace is a list of function names (call stack), and count is the number of samples.
proc add_trace(builder, trace: Array, count: Number):
    let current_level = builder["nodes"]
    for func_name in trace:
        if not dict_has(current_level, func_name):
            current_level[func_name] = {
                "count": 0,
                "children": {}
            }
        current_level[func_name]["count"] = current_level[func_name]["count"] + count
        current_level = current_level[func_name]["children"]

## Generate a JSON representation of the flame graph for the frontend.
proc generate_json(builder):
    return {
        "name": "root",
        "value": 0,
        "children": _build_json_nodes(builder["nodes"])
    }

proc _build_json_nodes(nodes):
    let result = []
    let ks = dict_keys(nodes)
    for k in ks:
        let node = nodes[k]
        let item = {
            "name": k,
            "value": node["count"],
            "children": _build_json_nodes(node["children"])
        }
        push(result, item)
    return result
