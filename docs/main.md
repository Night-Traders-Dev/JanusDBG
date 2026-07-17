# Logger (`lib/log.sage`)

## Purpose

A minimal, self-contained logger that avoids `std.log` (which uses indirect callbacks not supported by the C/LLVM codegen backends). Supports five log levels with output filtering.

## API

### Constants

`LOG_NAMES = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]`

### `create_logger(name: String, level=1) -> dict`

Create a logger instance.

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `String` | — | Logger name (displayed in output) |
| `level` | `Number` | `1` | Minimum log level (0=DEBUG..4=FATAL) |

Returns a dict: `{"name": name, "level": level}`

### Level Functions

Each function checks `logger["level"]` against the threshold before printing:

| Function | Threshold | Level Index | Prefix |
|----------|-----------|-------------|--------|
| `debug(logger, msg)` | `level <= 0` | 0 | `[DEBUG]` |
| `info(logger, msg)` | `level <= 1` | 1 | `[INFO]` |
| `warn(logger, msg)` | `level <= 2` | 2 | `[WARN]` |
| `error(logger, msg)` | `level <= 3` | 3 | `[ERROR]` |
| `fatal(logger, msg)` | `level <= 4` | 4 | `[FATAL]` |

### Output Format

```
[LEVEL] name: message
```

## Internal Design

The logger is a pure-function module with no global state:

- `log_print()` clamps the level index to `[0, 4]` before indexing `LOG_NAMES`
- Level functions short-circuit: if `logger["level"]` exceeds the threshold, the message is silently dropped
- Uses `print` (a built-in SageLang keyword) for output — no I/O library dependency

## Codegen Considerations

- No `std.log` import — avoids unsupported callback indirect calls
- `logger` is a plain dict, not a class instance — compatible with backends that don't support `class`
- No file I/O or complex formatting

## Test Coverage

Three tests in `tests/run_all.sage`:

| Test | What It Checks |
|------|----------------|
| `test_log_create` | Logger creation, name/level fields, non-nil |
| `test_log_levels` | Correct level values (0–4) |
| `test_log_no_crash` | All five level functions execute without error, debug suppressed at INFO level |

## Usage Example

```python
from lib.log import create_logger, info, debug

let logger = create_logger("mymodule", 1)  # INFO level
info(logger, "Starting up")                # prints: [INFO] mymodule: Starting up
debug(logger, "detail")                    # suppressed (level 1 > 0)
```
