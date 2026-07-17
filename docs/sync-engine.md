# Synchronization Engine (`src/sync/engine.sage`)

## Purpose

Coordinates debug operations across multiple sessions (ARM + RISC-V). Provides synchronized halt, resume, step, breakpoint, and state-merging operations that iterate over a list of session names and execute the corresponding adapter method on each.

## API

### `create_sync_engine(session_mgr, logger) -> dict`

Create a new synchronization engine.

| Param | Type | Description |
|-------|------|-------------|
| `session_mgr` | dict | Session manager from `create_session_manager` |
| `logger` | dict | Logger instance from `lib.log` |

Returns a dict:
```python
{
    "session_mgr": session_mgr,
    "logger": logger,
    "breakpoints": {}    # addr → [session_names]
}
```

### `sync_halt(engine, session_names: Array)`

Halt multiple sessions sequentially.

| Param | Type | Description |
|-------|------|-------------|
| `engine` | dict | Sync engine from `create_sync_engine` |
| `session_names` | Array | List of session names (e.g. `["arm", "rv"]`) |

Iterates over `session_names`, calls `sm_get_adapter()` then `adapter.halt()` for each.

### `sync_resume(engine, session_names: Array)`

Resume multiple sessions sequentially.

Same pattern as `sync_halt` — calls `adapter.resume()` for each named session.

### `sync_step(engine, session_names: Array)`

Single-step multiple sessions sequentially.

Calls `adapter.step()` for each named session. Sessions are stepped one at a time (no parallelism).

### `sync_set_breakpoint(engine, session_names: Array, addr: String)`

Set a hardware breakpoint at the same address on multiple sessions.

| Param | Type | Description |
|-------|------|-------------|
| `engine` | dict | Sync engine |
| `session_names` | Array | List of session names |
| `addr` | String | Breakpoint address (format depends on adapter: `"*0x8000"` for GDB/MI, `"0x80000000"` for OpenOCD) |

Tracks the breakpoint in `engine["breakpoints"][addr]` for future management. Calls `adapter.set_breakpoint(addr)` for each session.

### `sync_get_merged_state(engine, session_names: Array) -> dict`

Get merged register state from multiple sessions.

| Param | Type | Description |
|-------|------|-------------|
| `engine` | dict | Sync engine |
| `session_names` | Array | List of session names |

Returns a dict keyed by session name:
```python
{
    "arm": "<raw GDB/MI register output>",
    "rv": "<raw OpenOCD register output>"
}
```

The returned values are raw adapter response strings (MI output for GDB, Tcl response for OpenOCD). Structured parsing is a future enhancement.

## Internal Design

The sync engine is a plain SageLang dict with no methods or metatables:

- `engine["session_mgr"]` — reference to the session manager for adapter lookup
- `engine["breakpoints"]` — breakpoint registry for tracking cross-session breakpoints
- All sync operations are sequential (no threading)

### Iteration Pattern

All sync operations follow the same pattern:
```python
for name in session_names:
    let adapter = sm_get_adapter(sm, name)
    adapter.<method>()
```

Errors propagate via `sm_get_adapter` (raises if session doesn't exist or isn't connected) or adapter methods (raise if TCP fails). Callers (typically the RPC server's try/catch) handle these as JSON-RPC error responses.

### Breakpoint Tracking

When `sync_set_breakpoint` is called, the breakpoint address is stored in `engine["breakpoints"]`:
```python
engine["breakpoints"][addr] = session_names
```

This enables future operations like `sync_remove_breakpoint`, `sync_list_breakpoints`, or cross-trigger behavior when a breakpoint fires.

## Design Decisions

- **Sequential, not parallel** — Operations run one session at a time. This avoids threading complexity and is sufficient since the dominant latency is the target communication, not the iteration overhead.
- **Raw state, not parsed** — `sync_get_merged_state` returns raw adapter strings rather than parsed register dicts. Parsing MI/Tcl output is protocol-specific and left for a future phase.
- **Error propagation** — The engine does not catch errors. If any session fails (not connected, TCP error), the exception propagates to the caller. This gives the RPC layer control over error responses.

## Codegen Considerations

- No `class` keyword — all operations are functions taking a dict as first argument
- Uses `sm_get_adapter` from `src.session.session` — no circular dependencies
- Array iteration uses `for name in session_names` — standard SageLang pattern
- No native module calls — the engine is pure SageLang, compatible with all backends

## Test Coverage

Seven tests in `tests/run_all.sage`:

| Test | What It Checks |
|------|----------------|
| `test_sync_engine_create` | Engine creation, breakpoints start empty |
| `test_sync_halt_raises_not_connected` | `sync_halt` raises when session not connected |
| `test_sync_resume_raises_not_connected` | `sync_resume` raises when session not connected |
| `test_sync_step_raises_not_connected` | `sync_step` raises when session not connected |
| `test_sync_set_breakpoint_raises_not_connected` | `sync_set_breakpoint` raises when session not connected |
| `test_sync_get_merged_state_raises_not_connected` | `sync_get_merged_state` raises when session not connected |
| `test_sync_multi_session_fails` | Multi-session halt raises when sessions not connected |

Plus 5 RPC-level tests verifying the sync methods return JSON-RPC errors when sessions are not connected.

## Usage Example

```python
from lib.log import create_logger
from src.session.session import create_session_manager, sm_register
from src.sync.engine import create_sync_engine, sync_halt, sync_get_merged_state

let logger = create_logger("test", 1)
let sm = create_session_manager(logger)
sm_register(sm, "arm", "localhost:2331", "gdb_mi")
sm_register(sm, "rv", "localhost:3333", "openocd")

let engine = create_sync_engine(sm, logger)

# After connecting both sessions via RPC "connect" commands:
sync_halt(engine, ["arm", "rv"])
let state = sync_get_merged_state(engine, ["arm", "rv"])
```
