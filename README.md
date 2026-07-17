# JanusDBG

**Unified debugging backend for heterogeneous ARM Cortex-A + RISC-V SoCs.**

JanusDBG is a lightweight backend daemon that bridges JSON-RPC 2.0 requests to GDB/MI (ARM) and OpenOCD Tcl (RISC-V) debug sessions. Written in SageLang and cross-compilable to embedded targets.

---

## Architecture

```
┌──────────────┐   JSON-RPC 2.0     ┌────────────────────────────────────┐
│  RPC Client  │ ──────────────────▶ │  JanusDBG Backend                  │
│ (IDE/Plugin)  │ ◀────────────────── │  ┌──────────────────────────────┐ │
└──────────────┘    TCP :8179        │  │  main.sage (entry)           │ │
                                      │  │  - argparse                  │ │
                                      │  │  - create logger             │ │
                                      │  │  - create session mgr        │ │
                                      │  │  - register sessions         │ │
                                      │  │  - start RPC server          │ │
                                      │  └──────────────────────────────┘ │
                                      │                                    │
                                      │  ┌──────────────────────────────┐ │
                                       │  │  rpc/server.sage             │ │
                                       │  │  - JSON-RPC 2.0 dispatcher   │ │
                                       │  │  - session & debug methods   │ │
                                       │  │  - batch request support     │ │
                                       │  │  - sync method routing       │ │
                                       │  └──────────────────────────────┘ │
                                       │                                    │
                                       │  ┌──────────────────────────────┐ │
                                       │  │  sync/engine.sage            │ │
                                       │  │  - cross-session coordination│ │
                                       │  │  - sequential multi-session  │ │
                                       │  │  - breakpoint tracking       │ │
                                       │  │  - merged state collection   │ │
                                       │  └──────────────────────────────┘ │
                                       │                                    │
                                       │  ┌──────────────────────────────┐ │
                                       │  │  session/session.sage        │ │
                                      │  │  - session lifecycle         │ │
                                      │  │  - adapter creation & mgmt   │ │
                                      │  │  - register/connect/disconnect│ │
                                      │  └──────────────────────────────┘ │
                                      │                                    │
                                      │  ┌──────────────────────────────┐ │
                                      │  │  adapters/gdb_mi.sage        │ │
                                      │  │  - ARM GDB/MI via TCP        │ │
                                      │  │  - (gdb) prompt detection    │ │
                                      │  └──────────────────────────────┘ │
                                      │                                    │
                                      │  ┌──────────────────────────────┐ │
                                      │  │  adapters/openocd.sage       │ │
                                      │  │  - RISC-V OpenOCD via TCP    │ │
                                      │  │  - raw Tcl command protocol  │ │
                                      │  └──────────────────────────────┘ │
                                      │                                    │
                                      │  ┌──────────────────────────────┐ │
                                      │  │  lib/log.sage                │ │
                                      │  │  lib/json.sage               │ │
                                      │  └──────────────────────────────┘ │
                                      └────────────────────────────────────┘
```

### Current Features (Implemented)

| Feature | Status | Description |
|---------|--------|-------------|
| **JSON-RPC 2.0 Server** | ✅ | TCP server on configurable port, single & batch requests |
| **Session Manager** | ✅ | Register ARM + RISC-V sessions, connect/disconnect lifecycle |
| **GDB/MI Adapter** | ✅ | TCP connection to GDB, send MI commands, (gdb) prompt parsing |
| **OpenOCD Adapter** | ✅ | TCP connection to OpenOCD Tcl server, send Tcl commands |
| **Error Handling** | ✅ | try/catch wraps all adapter ops, returns JSON-RPC error codes |
| **Sync Engine** | ✅ | Cross-session halt, resume, step, breakpoint, merged state |
| **Cross-Core Breakpoints** | ✅ | Set breakpoints on multiple sessions simultaneously |
| **Synchronized Step/Continue** | ✅ | Sequential multi-session step, halt, resume |
| **Cross-Compilation** | ✅ | Bundle + C launcher stub for 6 targets (x86, x86_64, arm32, aarch64, rv32, rv64) |
| **Test Suite** | ✅ | 33 tests covering all modules |

### Planned Features

| Feature | Status | Description |
|---------|--------|-------------|
| **VS Code Extension** | 📋 | Rich UI with debug controls, register views, timeline |
| **Performance Timeline** | 📋 | Merged execution events from both cores |
| **Profiling Aggregator** | 📋 | Flame graphs from hardware counters |
| **Embedded REPL** | 📋 | SageLang REPL for custom trace scripts |

---

## Quick Start

### Prerequisites

- **SageLang** v4.0.8+ (included at `deps/SageLang/`)
- GDB (for ARM debugging) — `gdb-multiarch` recommended
- OpenOCD (for RISC-V JTAG) — built with RISC-V support

### Build

```bash
# Build native binary
make build

# Build for all 6 target architectures
make build-all
```

### Run

```bash
# Start the backend server (defaults: ARM@localhost:2331, RV@localhost:3333, RPC@:8179)
./build/janusdbgd

# With custom targets
./build/janusdbgd --arm-host 192.168.1.10:2331 --rv-host 192.168.1.11:3333 --verbose
```

### Test

```bash
make test
# or
./sagemake test
```

---

## RPC Protocol

Debug commands available over JSON-RPC 2.0:

```json
// Connect to a session
{"method": "connect", "params": {"session": "arm"}, "id": 1}
→ {"jsonrpc": "2.0", "result": "connected", "id": 1}

// Halt the target
{"method": "halt", "params": {"session": "arm"}, "id": 2}
→ {"jsonrpc": "2.0", "result": "*stopped,...", "id": 2}

// Set a breakpoint
{"method": "setBreakpoint", "params": {"session": "arm", "addr": "*0x8000"}, "id": 3}
→ {"jsonrpc": "2.0", "result": "^done,bkpt=...", "id": 3}
```

Full API reference: [RPC Server](docs/rpc-server.md)

---

## Project Structure

```
JanusDBG/
├── Makefile              # Build wrapper
├── sagemake              # Build orchestrator (SageLang)
├── src/
│   ├── main.sage         # Entry point
│   ├── rpc/server.sage   # JSON-RPC server (TCP)
│   ├── session/session.sage  # Session manager
│   ├── sync/engine.sage  # Synchronization engine
│   └── adapters/
│       ├── gdb_mi.sage   # GDB/MI adapter (TCP)
│       └── openocd.sage  # OpenOCD adapter (TCP)
├── lib/
│   ├── log.sage          # Level-based logger
│   └── json.sage         # Self-contained JSON parser/serializer
├── tools/
│   ├── bundle.py         # Module bundler
│   └── deploy.py         # Cross-deploy C launcher generator
├── tests/
│   └── run_all.sage      # 33 tests
├── build/                # Built binaries
├── deps/SageLang/        # SageLang v4.0.8 source
└── docs/                 # Component documentation (11 files)
```

---

## Cross-Compilation & Deployment

JanusDBG uses native `tcp` module calls that cannot be compiled via SageLang's C/LLVM backends. The deploy strategy creates a C launcher stub that embeds the bundled source and invokes the system `sage` interpreter at runtime.

See [Deployment](docs/deployment.md) and [Build System](docs/build-system.md) for details.

---

## Documentation

Component-level documentation is in `docs/`:

| Document | Contents |
|----------|----------|
| [Architecture](docs/architecture.md) | System design, module deps, cross-compilation strategy |
| [Entry Point](docs/main.md) | CLI args, main flow |
| [Logger](docs/lib-log.md) | Level-based logger API |
| [JSON Utilities](docs/lib-json.md) | Self-contained JSON parser/serializer |
| [Session Manager](docs/session-manager.md) | Session lifecycle, adapter creation |
| [RPC Server](docs/rpc-server.md) | JSON-RPC 2.0 dispatch, error handling, sync methods |
| [Sync Engine](docs/sync-engine.md) | Cross-session coordination, merged state |
| [GDB/MI Adapter](docs/adapter-gdb-mi.md) | ARM debug adapter, TCP protocol |
| [OpenOCD Adapter](docs/adapter-openocd.md) | RISC-V debug adapter, Tcl protocol |
| [Test Suite](docs/test-suite.md) | 21 test coverage map |
| [Build System](docs/build-system.md) | sagemake/Makefile targets, bundle/deploy |
| [Deployment](docs/deployment.md) | Cross-compile workflow, C launcher |

---

## License

MIT
