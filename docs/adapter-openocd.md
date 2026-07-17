# OpenOCD Adapter (`src/adapters/openocd.sage`)

## Purpose

Adapter class for debugging RISC-V targets via OpenOCD's Tcl server (port 6666 by default). Connects via TCP and sends raw Tcl commands.

## API

### `class OpenOCDAdapter`

#### `proc init(self, host: String, port: Number, logger)`

Create a new OpenOCD adapter.

| Param | Type | Description |
|-------|------|-------------|
| `host` | String | OpenOCD Tcl server host (e.g. `"localhost"`) |
| `port` | Number | Tcl server port (e.g. `6666`) |
| `logger` | dict | Logger instance |

Sets `self.fd = -1`.

#### `proc connect(self)`

Connect to the OpenOCD Tcl server via TCP. Raises on failure.

- Calls `tcp.connect(host, port)` from SageLang's native `tcp` module
- Returns `-1` on DNS failure, connection refused, etc.

#### `proc disconnect(self)`

Disconnect from the OpenOCD Tcl server. Closes the TCP socket if `self.fd >= 0`.

#### `proc send_tcl(self, cmd: String) -> String`

Send a raw Tcl command and return the response.

| Param | Type | Description |
|-------|------|-------------|
| `cmd` | String | Raw Tcl command (e.g. `"halt"`) |

**Protocol:**
1. Appends `"\n"` to command and sends via `tcp.sendall()`
2. Reads one line via `tcp.recvline()` as the response
3. Returns the response string (empty string if nil)

Raises `"OpenOCD not connected"` if `self.fd < 0`.

#### Debug methods

Each method delegates to `send_tcl` with the appropriate command:

| Method | Tcl Command | Description |
|--------|------------|-------------|
| `halt()` | `halt` | Halt the target core |
| `resume()` | `resume` | Resume the target core |
| `step()` | `step` | Single-step the target |
| `set_breakpoint(addr)` | `bp <addr> 2 hw` | Set hardware breakpoint |
| `read_reg(reg)` | `reg <reg>` | Read register by name |
| `start_trace()` | `trace start` | Start trace collection |
| `stop_trace()` | `trace stop` | Stop trace collection |
| `poll_trace()` | `trace status` | Poll trace data |

The `"2 hw"` suffix in `set_breakpoint` specifies a hardware breakpoint of length 2 (Word), standard for RISC-V.

## Internal Design

Uses SageLang's native `tcp` module for all I/O:
- `tcp.connect(host, port) -> Number` — returns fd or -1
- `tcp.sendall(fd, data) -> Bool` — loops until all data sent
- `tcp.recvline(fd, maxlen) -> String | Nil` — reads until `\n` or maxlen
- `tcp.close(fd) -> Nil` — closes socket

OpenOCD's Tcl server does not use a prompt marker like GDB/MI. Responses are typically shorter and simpler — the server returns the result of evaluating the Tcl command.

### Response Reading

Unlike GDB's multi-line MI responses, OpenOCD's Tcl server returns a single line per command (in most cases). The adapter reads one line via `tcp.recvline()`.

### Error Handling

- Connection failure raises with the target host:port
- Commands on unconnected adapter raise `"OpenOCD not connected"`
- `tcp.sendall()` failure returns false
- `tcp.recvline()` returns nil on EOF — adapter returns empty string

## Codegen Considerations

- Uses `class` keyword (supported by backends)
- No syntax conflicts with SageLang reserved words
- Uses `tcp` native module — prevents direct C/LLVM compilation (handled by deploy launcher strategy)
- All I/O operations are synchronous

## Test Coverage

Two tests in `tests/run_all.sage`:

| Test | What It Checks |
|------|----------------|
| `test_ocd_create` | Adapter creation, `fd` starts at -1 |
| `test_ocd_methods_raise_not_connected` | All five methods raise `"OpenOCD not connected"` when `fd < 0` |

## Usage Example

```python
from lib.log import create_logger
from src.adapters.openocd import OpenOCDAdapter

let logger = create_logger("test", 1)
let ocd = OpenOCDAdapter("localhost", 6666, logger)
ocd.connect()
ocd.set_breakpoint("0x80000000")
let pc = ocd.read_reg("pc")
ocd.disconnect()
```
