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

21 tests total, covering 5 modules:

### lib.log (3 tests)

| Test | What It Checks |
|------|----------------|
| `test_log_create` | Logger creation, name/level fields, non-nil |
| `test_log_levels` | Correct level values (0–4) |
| `test_log_no_crash` | All five level functions execute, debug suppressed at INFO |

### session (7 tests)

| Test | What It Checks |
|------|----------------|
| `test_session_create` | Non-nil manager, initial state `"disconnected"` |
| `test_session_register` | Session exists, target/adapter_type match, connected is false |
| `test_session_multiple` | Multiple sessions registered, count=2 |
| `test_session_connect_attempt` | Connect without TCP target raises (try/catch) |
| `test_session_disconnect_cleanup` | Disconnect on unconnected session is safe (no crash) |
| `test_session_get_adapter_unknown` | `sm_get_adapter` raises for nonexistent session |
| `test_session_get_adapter_not_connected` | `sm_get_adapter` raises when session not connected |

### gdb_mi (2 tests)

| Test | What It Checks |
|------|----------------|
| `test_gdb_create` | Adapter creation, `fd` starts at -1 |
| `test_gdb_methods_raise_not_connected` | All 5 methods raise `"GDB not connected"` |

### openocd (2 tests)

| Test | What It Checks |
|------|----------------|
| `test_ocd_create` | Adapter creation, `fd` starts at -1 |
| `test_ocd_methods_raise_not_connected` | All 5 methods raise `"OpenOCD not connected"` |

### rpc (7 tests)

| Test | What It Checks |
|------|----------------|
| `test_rpc_request` | `getSessions` returns valid JSON-RPC 2.0 response |
| `test_rpc_unknown_method` | Unknown method returns error code `-32601` |
| `test_rpc_halt_not_connected` | `halt` without connect returns error `-32000` |
| `test_rpc_resume_not_connected` | `resume` without connect returns error |
| `test_rpc_step_not_connected` | `step` without connect returns error |
| `test_rpc_set_breakpoint_not_connected` | `setBreakpoint` without connect returns error |
| `test_rpc_read_registers_not_connected` | `readRegisters` without connect returns error |

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
- Adapter methods raise when not connected — tests use `try/catch` to verify error messages
- Session connect tests attempt real TCP connection on `localhost:1` (expected to fail) and catch the exception
- RPC error tests verify proper JSON-RPC error codes (`-32000` for application errors, `-32601` for unknown methods)
- All 21 tests pass (`./sagemake check` runs tests before and after every build)
