# Test Suite (`tests/run_all.sage`)

## Purpose

Comprehensive test suite covering all JanusDBG modules: logger, session manager, GDB/MI adapter, OpenOCD adapter, and RPC server.

## Running

```bash
./sagemake test
# or
make test
# or directly
sage tests/run_all.sage
```

Tests are run by the build system before and after every build operation.

## Test Summary

| # | Test Name | Module | What It Checks |
|---|-----------|--------|----------------|
| 1 | `log: create_logger` | lib.log | Logger creation, name/level fields, non-nil |
| 2 | `log: level constants` | lib.log | Correct level values (0–4) |
| 3 | `log: all functions no crash` | lib.log | All five level functions execute, debug suppressed |
| 4 | `session: create` | session | Non-nil manager, initial state `"disconnected"` |
| 5 | `session: register` | session | Session exists, target matches, connected is false |
| 6 | `session: register multiple` | session | Multiple sessions registered, count=2 |
| 7 | `session: connect` | session | Connect flips connected to true |
| 8 | `session: disconnect` | session | Connect/disconnect round-trip |
| 9 | `gdb_mi: create` | gdb_mi | Adapter creation, connected starts false |
| 10 | `gdb_mi: methods` | gdb_mi | All GDB methods execute without crash |
| 11 | `openocd: create` | openocd | Adapter creation, connected starts false |
| 12 | `openocd: methods` | openocd | All OpenOCD methods execute without crash |
| 13 | `rpc: basic request` | rpc | `getSessions` returns valid JSON-RPC 2.0 response |
| 14 | `rpc: connect` | rpc | `connect("arm")` returns `result: "connected"` |
| 15 | `rpc: unknown method` | rpc | Unknown method returns error `-32601` |

## Framework

Uses `std.testing` with the following API:

| Function | Purpose |
|----------|---------|
| `create_suite(name)` | Create a named test suite |
| `add_test(suite, name, proc)` | Register a test function |
| `run(suite)` | Execute all tests |
| `report(suite)` | Print results |
| `assert_equal(a, b, msg)` | Check equality |
| `assert_not_equal(a, b, msg)` | Check inequality |
| `assert_true(cond, msg)` | Check truthiness |

## Design Notes

- Each test is self-contained with its own logger and manager instances
- Tests import modules inline (inside the test procedure) to ensure fresh state
- Adapter tests manually set `connected = true` to test methods without requiring actual connections
- All 15 tests pass (`./sagemake check` runs tests before build)

## Usage Example

```python
from std.testing import create_suite, add_test, run, report, assert_equal

let suite = create_suite("My Tests")

proc test_foo():
    assert_equal(1, 1, "one should equal one")

add_test(suite, "test foo", test_foo)
run(suite)
report(suite)
```
