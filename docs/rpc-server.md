# JSON-RPC Server (`src/rpc/server.sage`)

## Purpose

Implements a JSON-RPC 2.0 server over TCP that dispatches incoming requests to session manager methods and adapter commands. Supports single requests and batch arrays. Error handling wraps all operations with try/catch returning structured error responses.

## API

### `handle_request(req, session_mgr, logger) -> dict`

Process a single JSON-RPC request and return a response dict. All adapter operations are wrapped in try/catch — exceptions return `{"code": -32000, "message": <error string>}`.

| Param | Type | Description |
|-------|------|-------------|
| `req` | dict | Parsed JSON-RPC request with `method`, optional `params`, optional `id` |
| `session_mgr` | dict | Session manager from `create_session_manager` |
| `logger` | dict | Logger instance |

**Supported methods:**

#### Session Management

| Method | Params | Result | Description |
|--------|--------|--------|-------------|
| `"connect"` | `{"session": "..."}` | `"connected"` | Create adapter and connect via TCP |
| `"disconnect"` | `{"session": "..."}` | `"disconnected"` | Disconnect and clean up adapter |
| `"getState"` | none | `"connected"` | Return current connection state |
| `"getSessions"` | none | sessions dict | List all registered sessions |

#### Debug Commands

| Method | Params | Adapter Call | Description |
|--------|--------|-------------|-------------|
| `"halt"` | `{"session": "..."}` | `adapter.halt()` | Halt target |
| `"resume"` | `{"session": "..."}` | `adapter.resume()` | Resume target |
| `"step"` | `{"session": "..."}` | `adapter.step()` | Single-step |
| `"setBreakpoint"` | `{"session": "...", "addr": "..."}` | `adapter.set_breakpoint(addr)` | Set breakpoint |
| `"readRegisters"` | `{"session": "..."}` | `adapter.read_registers()` | Read all registers |
| `"readReg"` | `{"session": "...", "reg": "..."}` | `adapter.read_reg(reg)` | Read one register |

**Response format:**
```python
# Success:
{"jsonrpc": "2.0", "result": ..., "id": req_id}

# Error (application):
{"jsonrpc": "2.0", "error": {"code": -32000, "message": "..."}, "id": req_id}

# Error (method not found):
{"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": req_id}
```

### `handle_connection(conn, session_mgr, logger)`

Read, parse, and respond to an incoming TCP connection.

| Param | Type | Description |
|-------|------|-------------|
| `conn` | Number | TCP socket fd from `tcp.accept()` |
| `session_mgr` | dict | Session manager |
| `logger` | dict | Logger |

**Flow:**
1. Read one line via `tcp.recvline()` (up to 65536 bytes)
2. If nil or empty, return (client disconnected or no data)
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
2. `tcp.listen("0.0.0.0", port)` — bind to all interfaces (returns fd or -1)
3. Raise if `server < 0` (listen failed)
4. Loop: `tcp.accept(server)` → `handle_connection()` → `tcp_close(conn)`

## Internal Design

### Error Handling

All adapter operations in `handle_request` are wrapped in a single `try/catch` block. Any exception from `sm_get_adapter`, `sm_connect`, or adapter methods is caught and returned as a JSON-RPC error response with code `-32000`.

This ensures every request receives a valid JSON-RPC response, even when the session is not connected or the target is unreachable.

### Request Handling

`handle_request` uses SageLang's `match` statement for method dispatch. Parameters are extracted via `dict_has()` guard + direct index:

```python
let params = {}
if dict_has(req, "params"):
    params = req["params"]
```

The request `id` is optional per JSON-RPC 2.0; if absent, `req_id` is `nil`.

### Connection Handling

The server uses line-based protocol (`tcp.recvline`) instead of exact-length reads (`tcp.recvall`) — each JSON-RPC message must be a single line (minified JSON). This avoids the problem of `recvall` blocking when the exact message size is unknown.

Batch requests are detected by checking `type(parsed) != "Array"`.

### Server Loop

The server loop is a simple `while running` with no threading — each connection blocks until complete. This is sufficient for a debugging backend where request volume is low.

## Codegen Considerations

- Uses `tcp` native module (`listen`, `accept`, `recvline`, `sendall`, `close`) — prevents direct C/LLVM compilation
- No third-party JSON library — uses local `lib/json.sage`
- `dict_has()` guard required because `dict.get()` is unavailable in SageLang v4.0.8
- `listen("0.0.0.0", port)` — takes `(host, port)` not just `(port)` as in earlier versions

## Test Coverage

Six tests in `tests/run_all.sage`:

| Test | What It Checks |
|------|----------------|
| `test_rpc_request` | `getSessions` returns valid JSON-RPC 2.0 response |
| `test_rpc_unknown_method` | Unknown method returns error code `-32601` |
| `test_rpc_halt_not_connected` | `halt` without connect returns error `-32000` |
| `test_rpc_resume_not_connected` | `resume` without connect returns error |
| `test_rpc_step_not_connected` | `step` without connect returns error |
| `test_rpc_set_breakpoint_not_connected` | `setBreakpoint` without connect returns error |
| `test_rpc_read_registers_not_connected` | `readRegisters` without connect returns error |

## Usage Example

```python
from lib.log import create_logger
from src.session.session import create_session_manager, sm_register
from src.rpc.server import start_server

let logger = create_logger("janusdbg", 1)
let sm = create_session_manager(logger)
sm_register(sm, "arm", "localhost:2331", "gdb_mi")
sm_register(sm, "rv", "localhost:3333", "openocd")
start_server(8179, sm, logger)  # blocks forever
```
