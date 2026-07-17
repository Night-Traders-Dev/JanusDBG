## JSON-RPC 2.0 server over TCP.
from tcp import recvline, sendall, listen, accept, close as tcp_close
from lib.json import json_parse, json_stringify
from lib.log import info, warn, error
from src.session.session import sm_connect, sm_disconnect, sm_get_sessions, sm_get_adapter
from src.sync.engine import sync_halt, sync_resume, sync_step, sync_set_breakpoint, sync_get_merged_state

## Handle a single JSON-RPC request and return a response.
proc handle_request(req, session_mgr, sync_engine, logger):
    let method = req["method"]
    let params = {}
    if dict_has(req, "params"):
        params = req["params"]
    let req_id = nil
    if dict_has(req, "id"):
        req_id = req["id"]

    try:
        match method:
            case "connect":
                sm_connect(session_mgr, params["session"])
                return {"jsonrpc": "2.0", "result": "connected", "id": req_id}
            case "disconnect":
                sm_disconnect(session_mgr, params["session"])
                return {"jsonrpc": "2.0", "result": "disconnected", "id": req_id}
            case "getState":
                return {"jsonrpc": "2.0", "result": "connected", "id": req_id}
            case "getSessions":
                return {"jsonrpc": "2.0", "result": sm_get_sessions(session_mgr), "id": req_id}
            case "halt":
                let adapter = sm_get_adapter(session_mgr, params["session"])
                return {"jsonrpc": "2.0", "result": adapter.halt(), "id": req_id}
            case "resume":
                let adapter = sm_get_adapter(session_mgr, params["session"])
                return {"jsonrpc": "2.0", "result": adapter.resume(), "id": req_id}
            case "step":
                let adapter = sm_get_adapter(session_mgr, params["session"])
                return {"jsonrpc": "2.0", "result": adapter.step(), "id": req_id}
            case "setBreakpoint":
                let adapter = sm_get_adapter(session_mgr, params["session"])
                return {"jsonrpc": "2.0", "result": adapter.set_breakpoint(params["addr"]), "id": req_id}
            case "readRegisters":
                let adapter = sm_get_adapter(session_mgr, params["session"])
                return {"jsonrpc": "2.0", "result": adapter.read_registers(), "id": req_id}
            case "readReg":
                let adapter = sm_get_adapter(session_mgr, params["session"])
                return {"jsonrpc": "2.0", "result": adapter.read_reg(params["reg"]), "id": req_id}
            case "syncHalt":
                sync_halt(sync_engine, params["sessions"])
                return {"jsonrpc": "2.0", "result": "halted", "id": req_id}
            case "syncResume":
                sync_resume(sync_engine, params["sessions"])
                return {"jsonrpc": "2.0", "result": "resumed", "id": req_id}
            case "syncStep":
                sync_step(sync_engine, params["sessions"])
                return {"jsonrpc": "2.0", "result": "stepped", "id": req_id}
            case "syncSetBreakpoint":
                sync_set_breakpoint(sync_engine, params["sessions"], params["addr"])
                return {"jsonrpc": "2.0", "result": "set", "id": req_id}
            case "getMergedState":
                let state = sync_get_merged_state(sync_engine, params["sessions"])
                return {"jsonrpc": "2.0", "result": state, "id": req_id}
            default:
                return {"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": req_id}
    catch e:
        return {"jsonrpc": "2.0", "error": {"code": -32000, "message": e}, "id": req_id}

## Read, parse, and respond to an incoming TCP connection.
proc handle_connection(conn, session_mgr, sync_engine, logger):
    let data = recvline(conn, 65536)
    if data == nil or data == "":
        return

    let parsed = json_parse(data)
    if type(parsed) != "Array":
        parsed = [parsed]

    let responses = []
    for req in parsed:
        let resp = handle_request(req, session_mgr, sync_engine, logger)
        push(responses, resp)

    let output = responses[0]
    if len(responses) > 1:
        output = responses
    let response_str = json_stringify(output)
    sendall(conn, response_str)

## Start the RPC server on the given port. Blocks forever.
proc start_server(port: Number, session_mgr, sync_engine, logger):
    info(logger, "Starting RPC server on port " + str(port))

    let server = listen("0.0.0.0", port)
    if server < 0:
        raise "Failed to start RPC server on port " + str(port)

    info(logger, "RPC server listening")

    let running = true
    while running:
        let conn = accept(server)
        if conn >= 0:
            handle_connection(conn, session_mgr, sync_engine, logger)
            tcp_close(conn)
