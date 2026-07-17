# Session Manager (`src/session/session.sage`)

## Purpose

Manages debug session lifecycle (create, register, connect, disconnect, list). Implemented as a dictionary-based factory rather than a class — necessary because some SageLang codegen backends don't support `class`. Creates the appropriate adapter (GDB/MI or OpenOCD) on connection.

## API

All public procedures are module-level functions that operate on a session manager dict.

### `create_session_manager(logger) -> dict`

Create a new session manager.

| Param | Type | Description |
|-------|------|-------------|
| `logger` | dict | Logger instance from `lib.log` |

Returns a dict:
```python
{
    "logger": logger,
    "sessions": {},      # name → session dict
    "state": "disconnected"
}
```

### `sm_register(sm, name: String, target: String, adapter_type: String)`

Register a new debug session.

| Param | Type | Description |
|-------|------|-------------|
| `sm` | dict | Session manager from `create_session_manager` |
| `name` | String | Session identifier (e.g. `"arm"`, `"rv"`) |
| `target` | String | Target address string (e.g. `"localhost:2331"`) |
| `adapter_type` | String | Adapter class — `"gdb_mi"` or `"openocd"` |

Creates a session entry:
```python
{
    "name": name,
    "target": target,
    "adapter_type": adapter_type,
    "connected": false,
    "state": nil,
    "adapter": nil    # set by sm_connect
}
```

Logs `"Registered session: <name> @ <target> (<adapter_type>)"`.

### `sm_connect(sm, name: String)`

Connect to a named session by creating the appropriate adapter and establishing a TCP connection.

| Param | Type | Description |
|-------|------|-------------|
| `sm` | dict | Session manager |
| `name` | String | Session name |

**Flow:**
1. Looks up the session by name
2. Parses `target` into host and port (splits on `:`)
3. Creates the adapter based on `adapter_type`:
   - `"gdb_mi"` → `GDBMIAdapter(host, port, logger)`
   - `"openocd"` → `OpenOCDAdapter(host, port, logger)`
4. Calls `adapter.connect()` (establishes TCP connection)
5. Stores the adapter in `sess["adapter"]`
6. Sets `sess["connected"] = true`

Raises on unknown session, unknown adapter type, or TCP connection failure.

### `sm_disconnect(sm, name: String)`

Disconnect from a named session.

| Param | Type | Description |
|-------|------|-------------|
| `sm` | dict | Session manager |
| `name` | String | Session name |

If the session has an adapter, calls `adapter.disconnect()` (closes TCP socket). Resets `adapter` to nil and `connected` to false.

No-op if session doesn't exist (checks for `nil`).

### `sm_get_adapter(sm, name: String) -> object`

Get the adapter instance for a named session.

| Param | Type | Description |
|-------|------|-------------|
| `sm` | dict | Session manager |
| `name` | String | Session name |

Returns the adapter object (GDBMIAdapter or OpenOCDAdapter instance).

Raises `"Unknown session: <name>"` if the session doesn't exist.
Raises `"Session not connected: <name>"` if the adapter is nil (not yet connected).

### `sm_get_sessions(sm) -> dict`

Get all registered sessions and their status.

| Param | Type | Description |
|-------|------|-------------|
| `sm` | dict | Session manager |

Returns the `sessions` dict (name → session dict).

## Internal Design

The session manager is a plain SageLang dict with no methods or metatables:

- `sm["sessions"]` holds all registered sessions keyed by name
- `sm["state"]` is a top-level state string
- `sm["logger"]` is stored for logging within session operations

### Adapter Creation

When `sm_connect` is called, it imports the appropriate adapter class at runtime (inside a conditional) and instantiates it. The imports are within the function body rather than at module level, so the adapter classes are only needed when connecting to a session.

### State Management

The session dict acts as an aggregate root:
- `connected` — boolean reflecting adapter connection status
- `adapter` — the adapter instance (nil until connected)
- `adapter_type` — stored for adapter creation on connect
- `state` — reserved for future debug state tracking

## Codegen Considerations

- No `class` keyword — all operations are functions taking a dict as first argument
- Conditional imports for adapter classes — `from src.adapters.gdb_mi import GDBMIAdapter` is inside an `if/elif` block
- Uses `dict_has()` for nil checks (SageLang v4.0.8 lacks `.get()`)
- Logger parameter is explicit rather than through closures or global state

## Test Coverage

Seven tests in `tests/run_all.sage`:

| Test | What It Checks |
|------|----------------|
| `test_session_create` | Non-nil manager, initial state `"disconnected"` |
| `test_session_register` | Session exists after register, target matches, adapter_type matches, connected is false |
| `test_session_multiple` | Multiple sessions can be registered, len=2 |
| `test_session_connect_attempt` | Connect without GDB target raises (try/catch) |
| `test_session_disconnect_cleanup` | Disconnect on unconnected session is safe |
| `test_session_get_adapter_unknown` | `sm_get_adapter` raises for unknown session |
| `test_session_get_adapter_not_connected` | `sm_get_adapter` raises when not connected |

## Usage Example

```python
from lib.log import create_logger
from src.session.session import create_session_manager, sm_register, sm_connect, sm_get_adapter, sm_disconnect

let logger = create_logger("test", 1)
let sm = create_session_manager(logger)
sm_register(sm, "arm", "localhost:2331", "gdb_mi")
sm_connect(sm, "arm")
let adapter = sm_get_adapter(sm, "arm")
adapter.halt()
sm_disconnect(sm, "arm")
```
