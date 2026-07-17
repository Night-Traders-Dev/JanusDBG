# OpenOCD Adapter (`src/adapters/openocd.sage`)

## Purpose

Adapter class for debugging RISC-V targets via OpenOCD's Tcl server (port 6666 by default). Communicates by sending raw Tcl commands over telnet.

## API

### `class OpenOCDAdapter`

#### `proc init(self, host: String, port: Number, logger)`

Create a new OpenOCD adapter.

| Param | Type | Description |
|-------|------|-------------|
| `host` | String | OpenOCD Tcl server host (e.g. `"localhost"`) |
| `port` | Number | Tcl server port (e.g. `6666`) |
| `logger` | dict | Logger instance |

Sets `self.connected = false`.

#### `proc connect(self)`

Connect to the OpenOCD Tcl server. Logs the connection attempt and sets `self.connected = true`.

#### `proc disconnect(self)`

Disconnect from the OpenOCD Tcl server. Sets `self.connected = false`.

#### `proc send_tcl(self, cmd: String) -> String`

Send a raw Tcl command and return the response.

| Param | Type | Description |
|-------|------|-------------|
| `cmd` | String | Raw Tcl command (e.g. `"halt"`) |

Raises `"OpenOCD not connected"` if `self.connected` is false. Currently returns `""` (stub).

#### `proc halt(self) -> String`

Halt the target core. Returns `self.send_tcl("halt")`.

#### `proc resume(self) -> String`

Resume the target core. Returns `self.send_tcl("resume")`.

#### `proc step(self) -> String`

Single-step the target core. Returns `self.send_tcl("step")`.

#### `proc set_breakpoint(self, addr: String) -> String`

Set a hardware breakpoint at the given address.

| Param | Type | Description |
|-------|------|-------------|
| `addr` | String | Address string (e.g. `"0x80000000"`) |

Returns `self.send_tcl("bp " + addr + " 2 hw")`.

**Note:** The `"2 hw"` suffix specifies a hardware breakpoint of length 2 (Word), standard for RISC-V.

#### `proc read_reg(self, reg: String) -> String`

Read a register value by name.

| Param | Type | Description |
|-------|------|-------------|
| `reg` | String | Register name (e.g. `"pc"`) |

Returns `self.send_tcl("reg " + reg)`.

## Internal Design

Follows the same class-based pattern as `GDBMIAdapter`. All commands delegate to `send_tcl()`, currently a stub returning `""`. The OpenOCD Tcl server typically runs on port 6666 and accepts raw commands terminated by newline.

## Codegen Considerations

- Uses `class` keyword (supported by backends)
- No syntax conflicts with SageLang reserved words
- String concatenation for command construction (backends handle this reliably)

## Test Coverage

Two tests in `tests/run_all.sage`:

| Test | What It Checks |
|------|----------------|
| `test_ocd_create` | Adapter creation, `connected` starts false |
| `test_ocd_methods` | All debug methods execute without error (sets `connected` manually) |

## Usage Example

```python
from lib.log import create_logger
from src.adapters.openocd import OpenOCDAdapter

let logger = create_logger("test", 1)
let ocd = OpenOCDAdapter("localhost", 6666, logger)
ocd.connect()
ocd.set_breakpoint("0x80000000")
ocd.read_reg("pc")
ocd.disconnect()
```
