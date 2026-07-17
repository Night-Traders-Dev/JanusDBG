## JSON-RPC 2.0 server over TCP.
import tcp
import json
from lib.log import info, warn, error

## Handle a single JSON-RPC request and return a response.
proc handle_request(req: Dict, session_mgr, logger):
    let method = req["method"]
    let params = req.get("params", {})
    let req_id = req.get("id", nil)

    match method:
        case "connect":
            session_mgr.connect(params["session"])
            return {"jsonrpc": "2.0", "result": "connected", "id": req_id}
        case "disconnect":
            session_mgr.disconnect(params["session"])
            return {"jsonrpc": "2.0", "result": "disconnected", "id": req_id}
        case "getState":
            return {"jsonrpc": "2.0", "result": session_mgr.get_state(), "id": req_id}
        case "getSessions":
            return {"jsonrpc": "2.0", "result": session_mgr.get_sessions(), "id": req_id}
        default:
            return {"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": req_id}

## Read, parse, and respond to an incoming TCP connection.
proc handle_connection(conn, session_mgr, logger):
    let data = tcp.recvall(conn, 8192)
    if data == "" or data == nil:
        return

    let parsed = json.parse(data)
    if type(parsed) != "Array":
        parsed = [parsed]

    let responses = []
    for req in parsed:
        let resp = handle_request(req, session_mgr, logger)
        push(responses, resp)

    let output = responses[0]
    if len(responses) > 1:
        output = responses
    let response_str = json.stringify(output)
    tcp.sendall(conn, response_str)

## Start the RPC server on the given port. Blocks forever.
proc start_server(port: Number, session_mgr, logger):
    info(logger, "Starting RPC server on port " + str(port))

    let server = tcp.listen(port)
    if server == nil:
        raise "Failed to start RPC server on port " + str(port)

    info(logger, "RPC server listening")

    let running = true
    while running:
        let conn = tcp.accept(server)
        if conn != nil:
            handle_connection(conn, session_mgr, logger)
            tcp.close(conn)
