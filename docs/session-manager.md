# Session Manager (`src/session/session.sage`)

## Purpose

Manages debug session lifecycle (create, register, connect, disconnect, list). Implemented as a dictionary-based factory rather than a class — necessary because some SageLang codegen backends don't support `class`.

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

### `sm_register(sm, name: String, target: String)`

Register a new debug session.

| Param | Type | Description |
|-------|------|-------------|
| `sm` | dict | Session manager from `create_session_manager` |
| `name` | String | Session identifier (e.g. `"arm"`, `"rv"`) |
| `target` | String | Target address string (e.g. `"localhost:2331"`) |

Creates a session entry:
```python
{
    "name": name,
    "target": target,
    "connected": false,
    "state": nil
}
```

Logs `"Registered session: <name> @ <target>"`.

### `sm_connect(sm, name: String)`

Connect to a named session.

| Param | Type | Description |
|-------|------|-------------|
| `sm` | dict | Session manager |
| `name` | String | Session name |

Raises `"Unknown session: " + name` if the session doesn't exist. Sets `connected = true` and logs the connection.

### `sm_disconnect(sm, name: String)`

Disconnect from a named session.

| Param | Type | Description |
|-------|------|-------------|
| `sm` | dict | Session manager |
| `name` | String | Session name |

No-op if session doesn't exist (checks for `nil`). Sets `connected = false` and logs disconnection.

### `sm_get_sessions(sm) -> dict`

Get all registered sessions and their status.

| Param | Type | Description |
|-------|------|-------------|
| `sm` | dict | Session manager |

Returns the `sessions` dict (name → session dict).

## Internal Design

The session manager is a plain SageLang dict with no methods or metatables:

- `sm["sessions"]` holds all registered sessions keyed by name
- `sm["state"]` is a top-level state string (currently always `"disconnected"`)
- `sm["logger"]` is stored for logging within session operations

Connection/disconnection currently only flips a boolean — real adapter I/O is a future extension.

## Codegen Considerations

- No `class` keyword — all operations are functions taking a dict as first argument
- Uses `dict_has()` for nil-check on `sessions[name]` — SageLang v4.0.8 doesn't have `.get()`
- No `self` parameter — `sm` is explicit as the first argument of each function
- Logger parameter is passed explicitly rather than through closures or global state

## Test Coverage

Five tests in `tests/run_all.sage`:

| Test | What It Checks |
|------|----------------|
| `test_session_create` | Non-nil manager, initial state `"disconnected"` |
| `test_session_register` | Session exists after register, target matches, connected is false |
| `test_session_multiple` | Multiple sessions can be registered, len=2 |
| `test_session_connect` | Connect flips `connected` to true |
| `test_session_disconnect` | Connect then disconnect returns `connected` to false |

## Usage Example

```python
from lib.log import create_logger
from src.session.session import create_session_manager, sm_register, sm_connect, sm_get_sessions

let logger = create_logger("test", 1)
let sm = create_session_manager(logger)
sm_register(sm, "arm", "localhost:2331")
sm_connect(sm, "arm")
let sessions = sm_get_sessions(sm)
```
