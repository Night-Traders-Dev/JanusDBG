# GDB/MI Adapter (`src/adapters/gdb_mi.sage`)

## Purpose

Adapter class for debugging ARM Cortex-A targets via GDB's Machine Interface (MI) protocol. Connects to a GDB process over TCP and sends MI commands. Reads responses line-by-line until the `(gdb)` prompt.

## API

### `class GDBMIAdapter`

#### `proc init(self, host: String, port: Number, logger)`

Create a new GDB/MI adapter.

| Param | Type | Description |
|-------|------|-------------|
| `host` | String | GDB host (e.g. `"localhost"`) |
| `port` | Number | GDB MI port (e.g. `2331`) |
| `logger` | dict | Logger instance |

Sets `self.fd = -1`.

#### `proc connect(self)`

Connect to the GDB MI target via TCP. Raises on failure.

- Calls `tcp.connect(host, port)` from SageLang's native `tcp` module
- Returns `-1` on DNS failure, connection refused, etc.
- Reads any greeting data from GDB (optional)

#### `proc disconnect(self)`

Disconnect from the GDB MI target. Closes the TCP socket if `self.fd >= 0`.

#### `proc send_command(self, cmd: String) -> String`

Send a raw MI command and return the accumulated response.

| Param | Type | Description |
|-------|------|-------------|
| `cmd` | String | MI command string (e.g. `"-target-select"`) |

**Protocol:**
1. Appends `"\n"` to command and sends via `tcp.sendall()`
2. Reads lines via `tcp.recvline()` until the `(gdb)` prompt or EOF
3. Returns the concatenated response (excluding the prompt)

Raises `"GDB not connected"` if `self.fd < 0`.

#### Debug methods

Each method delegates to `send_command` with the appropriate MI command:

| Method | MI Command | Description |
|--------|-----------|-------------|
| `halt()` | `-exec-interrupt` | Halt the target |
| `cont()` | `-exec-continue` | Resume execution |
| `step()` | `-exec-step` | Single-step |
| `set_breakpoint(location)` | `-break-insert <location>` | Set a breakpoint |
| `read_registers()` | `-target-reg-list` | Read all registers |

## Internal Design

Uses SageLang's native `tcp` module for all I/O. The `tcp` module provides:
- `tcp.connect(host, port) -> Number` — returns fd or -1
- `tcp.sendall(fd, data) -> Bool` — loops until all data sent
- `tcp.recvline(fd, maxlen) -> String | Nil` — reads until `\n` or maxlen
- `tcp.close(fd) -> Nil` — closes socket

### Response Reading

GDB/MI responses are structured as:
```
^done,<results>
~"text output"
(gdb)
```

The `(gdb)\n` prompt signals the end of a response. The adapter accumulates all lines until this prompt, then returns the result.

### Error Handling

- Connection failure raises with the target host:port
- Commands on unconnected adapter raise `"GDB not connected"`
- `tcp.sendall()` failure returns false (caught by calling code)
- `tcp.recvline()` returns nil on EOF/error (loop terminates)

## Codegen Considerations

- Uses `class` keyword (supported by C/LLVM backends in SageLang v4.0.8)
- `cont` instead of `continue` — `continue` is a reserved keyword
- Uses `tcp` native module — prevents direct C/LLVM compilation (handled by deploy launcher strategy)
- All I/O operations are synchronous (blocking)

## Test Coverage

Two tests in `tests/run_all.sage`:

| Test | What It Checks |
|------|----------------|
| `test_gdb_create` | Adapter creation, `fd` starts at -1 |
| `test_gdb_methods_raise_not_connected` | All five methods raise `"GDB not connected"` when `fd < 0` |

## Usage Example

```python
from lib.log import create_logger
from src.adapters.gdb_mi import GDBMIAdapter

let logger = create_logger("test", 1)
let gdb = GDBMIAdapter("localhost", 2331, logger)
gdb.connect()
let bp_result = gdb.set_breakpoint("*0x8000")
let cont_result = gdb.cont()
gdb.disconnect()
```
