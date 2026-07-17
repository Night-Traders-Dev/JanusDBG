# GDB/MI Adapter (`src/adapters/gdb_mi.sage`)

## Purpose

Adapter class for debugging ARM Cortex-A targets via GDB's Machine Interface (MI) protocol. Connects to a GDB process over TCP and sends MI commands.

## API

### `class GDBMIAdapter`

#### `proc init(self, host: String, port: Number, logger)`

Create a new GDB/MI adapter.

| Param | Type | Description |
|-------|------|-------------|
| `host` | String | GDB host (e.g. `"localhost"`) |
| `port` | Number | GDB MI port (e.g. `2331`) |
| `logger` | dict | Logger instance |

Sets `self.connected = false`.

#### `proc connect(self)`

Connect to the GDB MI target. Logs the connection attempt and sets `self.connected = true`.

#### `proc disconnect(self)`

Disconnect from the GDB MI target. Sets `self.connected = false`.

#### `proc send_command(self, cmd: String) -> String`

Send a raw MI command and return the response.

| Param | Type | Description |
|-------|------|-------------|
| `cmd` | String | MI command string (e.g. `"-target-select"`) |

Raises `"GDB not connected"` if `self.connected` is false. Currently returns `""` (stub).

#### `proc halt(self) -> String`

Send the MI halt command. Returns `self.send_command("-exec-interrupt")`.

#### `proc cont(self) -> String`

Resume execution. Returns `self.send_command("-exec-continue")`.

**Note:** Named `cont` rather than `continue` because `continue` is a reserved keyword in SageLang.

#### `proc step(self) -> String`

Single-step. Returns `self.send_command("-exec-step")`.

#### `proc set_breakpoint(self, location: String) -> String`

Set a breakpoint.

| Param | Type | Description |
|-------|------|-------------|
| `location` | String | Breakpoint location (e.g. `"*0x8000"`) |

Returns `self.send_command("-break-insert " + location)`.

#### `proc read_registers(self) -> String`

Read all registers. Returns `self.send_command("-target-reg-list")`.

## Internal Design

The adapter is a SageLang `class` with instance fields (`host`, `port`, `logger`, `connected`). All debug commands delegate to `send_command()`, which currently returns an empty string (TCP/MI protocol parsing is future work).

## Codegen Considerations

- Uses `class` keyword — supported by C/LLVM backends in SageLang v4.0.8
- `cont` instead of `continue` — the latter is a reserved keyword
- Method names follow SageLang convention (no `def`, uses `proc`)

## Test Coverage

Two tests in `tests/run_all.sage`:

| Test | What It Checks |
|------|----------------|
| `test_gdb_create` | Adapter creation, `connected` starts false |
| `test_gdb_methods` | All debug methods execute without error (sets `connected` manually) |

## Usage Example

```python
from lib.log import create_logger
from src.adapters.gdb_mi import GDBMIAdapter

let logger = create_logger("test", 1)
let gdb = GDBMIAdapter("localhost", 2331, logger)
gdb.connect()
gdb.set_breakpoint("*0x8000")
gdb.cont()
gdb.disconnect()
```
