# Entry Point (`src/main.sage`)

## Purpose

`src/main.sage` is the entry point for the JanusDBG backend daemon. It parses command-line arguments, initializes the logger and session manager, registers default ARM and RISC-V sessions, and starts the JSON-RPC server.

## API

### `main()`

The main entry procedure. Called at module level inside a `try`/`catch` block.

**Flow:**
1. Create an argparse parser named `"janusdbgd"` with description `"Unified ARM+RISC-V debugger backend"`
2. Register options and flags
3. Parse args from `sys.args()`
4. Create a logger at `LOG_INFO` level (or `LOG_DEBUG` if `--verbose`)
5. Log "JanusDBG starting"
6. Create a session manager
7. Register an ARM session at the GDB host:port (default `localhost:2331`)
8. Register a RISC-V session at the OpenOCD host:port (default `localhost:3333`)
9. Start the RPC server on the configured port (default `8179`)
10. On return, log "JanusDBG shutting down"

## Command-Line Arguments

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--arm-host` | `-a` | ARM GDB host:port | `localhost:2331` |
| `--rv-host` | `-r` | RISC-V OpenOCD host:port | `localhost:3333` |
| `--rpc-port` | `-p` | RPC server port | `8179` |
| `--verbose` | `-v` | Enable debug-level logging | off |
| `config` | (positional) | Config file path (optional) | none |

## Top-Level Error Handling

```python
try:
    main()
catch e:
    print "FATAL: " + e
    sys_exit(1)
```

Any unhandled exception from `main()` is caught, printed with a `FATAL:` prefix, and the process exits with code 1.

## Internal Design

The module is intentionally thin — it wires together components with no business logic of its own. Constants `LOG_DEBUG` (0) and `LOG_INFO` (1) are defined at module level.

## Codegen Considerations

- All imports use `from ... import` form (backends reject `import foo` without explicit names)
- `sys_exit` is an alias for `sys.exit` to avoid potential parser issues with dotted names in `except` context
- Uses `tonumber()` to convert the string option `rpc-port` to a number for the TCP server

## Test Coverage

No direct tests for `main()` — the module-level `main()` is an integration point exercised indirectly by building and deploying. Component-level tests cover all imported modules.
