# JSON-RPC Server (`src/rpc/server.sage`)

## Purpose

Implements a JSON-RPC 2.0 server over TCP that dispatches incoming requests to session manager methods. Supports single requests and batch arrays.

## API

### `handle_request(req, session_mgr, logger) -> dict`

Process a single JSON-RPC request and return a response dict.

| Param | Type | Description |
|-------|------|-------------|
| `req` | dict | Parsed JSON-RPC request with `method`, optional `params`, optional `id` |
| `session_mgr` | dict | Session manager from `create_session_manager` |
| `logger` | dict | Logger instance |

**Supported methods:**

| Method | Params | Result |
|--------|--------|--------|
| `"connect"` | `{"session": "..."}` | `"connected"` |
| `"disconnect"` | `{"session": "..."}` | `"disconnected"` |
| `"getState"` | none | `"connected"` |
| `"getSessions"` | none | sessions dict from `sm_get_sessions` |
| _any other_ | — | error `-32601` (Method not found) |

**Response format:**
```python
# Success:
{"jsonrpc": "2.0", "result": ..., "id": req_id}

# Error:
{"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": req_id}
```

### `handle_connection(conn, session_mgr, logger)`

Read, parse, and respond to an incoming TCP connection.

| Param | Type | Description |
|-------|------|-------------|
| `conn` | TCP connection | From `tcp.accept()` |
| `session_mgr` | dict | Session manager |
| `logger` | dict | Logger |

**Flow:**
1. Read up to 8192 bytes via `tcp.recvall()`
2. If empty/nil, return
3. Parse JSON via `json_parse()`
4. If the parsed value is not an Array, wrap it in a single-element array (batch support)
5. Call `handle_request()` for each request
6. If single request, return a single response; if batch, return an array of responses
7. Stringify the response and send via `tcp.sendall()`

### `start_server(port: Number, session_mgr, logger)`

Start the RPC server on the given port. Blocks forever.

| Param | Type | Description |
|-------|------|-------------|
| `port` | Number | TCP port to listen on |
| `session_mgr` | dict | Session manager |
| `logger` | dict | Logger |

**Flow:**
1. Log "Starting RPC server on port <port>"
2. `tcp.listen(port)` — raise if nil
3. Loop: `tcp.accept()` → `handle_connection()` → `tcp_close()`

## Internal Design

### Request Handling

`handle_request` uses SageLang's `match` statement for method dispatch. Parameters are extracted via `dict_has()` guard + direct index:

```python
let params = {}
if dict_has(req, "params"):
    params = req["params"]
```

The request `id` is optional per JSON-RPC 2.0; if absent, `req_id` is `nil` (omitted from error responses per spec, though currently included).

### Connection Handling

The connection handler distinguishes single requests from batches:

```python
if type(parsed) != "Array":
    parsed = [parsed]
```

Responses mirror the input structure: single request → single response dict, array request → array of response dicts.

### Server Loop

The server loop is a simple `while running` with no threading — each connection blocks until complete. This is sufficient for a debugging backend where request volume is low.

## Codegen Considerations

- Uses `tcp` native module (`listen`, `accept`, `recvall`, `sendall`, `close`) — these calls prevent compilation via C/LLVM backend (see deployment strategy)
- No third-party JSON library — uses local `lib/json.sage`
- `dict_has()` guard required because `dict.get()` is unavailable in SageLang v4.0.8

## Test Coverage

Three tests in `tests/run_all.sage`:

| Test | What It Checks |
|------|----------------|
| `test_rpc_request` | `getSessions` returns valid JSON-RPC 2.0 response |
| `test_rpc_connect` | `connect("arm")` returns `result: "connected"` with matching `id` |
| `test_rpc_unknown_method` | Unknown method returns error code `-32601` |

## Usage Example

```python
from lib.log import create_logger
from src.session.session import create_session_manager, sm_register
from src.rpc.server import start_server

let logger = create_logger("janusdbg", 1)
let sm = create_session_manager(logger)
sm_register(sm, "arm", "localhost:2331")
start_server(8179, sm, logger)  # blocks forever
```
