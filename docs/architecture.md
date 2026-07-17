# JanusDBG Architecture

## Overview

JanusDBG is a lightweight, dual-target debugger backend that bridges JSON-RPC 2.0 requests to GDB/MI (ARM Cortex-A) and OpenOCD Tcl (RISC-V) debug sessions. It is written in SageLang and designed to be cross-compiled to bare-metal or embedded targets via the SageLang C/LLVM codegen backends.

## High-Level Design

```
┌──────────────┐   JSON-RPC 2.0     ┌──────────────────────────────┐
│  RPC Client  │ ──────────────────▶ │  JanusDBG Backend            │
│ (IDE/Plugin)  │ ◀────────────────── │  ┌────────────────────────┐ │
└──────────────┘    TCP :8179        │  │  main.sage (entry)     │ │
                                      │  │  - argparse            │ │
                                      │  │  - create logger       │ │
                                      │  │  - create session mgr  │ │
                                      │  │  - start RPC server    │ │
                                      │  └────────────────────────┘ │
                                      │                              │
                                      │  ┌────────────────────────┐ │
                                      │  │  rpc/server.sage       │ │
                                      │  │  - TCP JSON-RPC 2.0    │ │
                                      │  │  - method dispatch      │ │
                                      │  │  - batch support        │ │
                                      │  └────────────────────────┘ │
                                      │                              │
                                      │  ┌────────────────────────┐ │
                                      │  │  session/session.sage  │ │
                                      │  │  - session lifecycle    │ │
                                      │  │  - register/connect     │ │
                                      │  └────────────────────────┘ │
                                      │                              │
                                      │  ┌────────────────────────┐ │
                                      │  │  adapters/gdb_mi.sage  │ │
                                      │  │  - ARM GDB/MI protocol  │ │
                                      │  └────────────────────────┘ │
                                      │                              │
                                      │  ┌────────────────────────┐ │
                                      │  │  adapters/openocd.sage │ │
                                      │  │  - RISC-V OpenOCD Tcl   │ │
                                      │  └────────────────────────┘ │
                                      │                              │
                                      │  ┌────────────────────────┐ │
                                      │  │  lib/log.sage           │ │
                                      │  │  - level-based logger   │ │
                                      │  └────────────────────────┘ │
                                      │                              │
                                      │  ┌────────────────────────┐ │
                                      │  │  lib/json.sage          │ │
                                      │  │  - self-contained JSON  │ │
                                      │  └────────────────────────┘ │
                                      └──────────────────────────────┘
```

## Module Dependency Graph

```
  main.sage
   ├── std.argparse
   ├── sys
   ├── lib/log.sage
   ├── src/rpc/server.sage
   │    ├── tcp (native module)
   │    ├── lib/json.sage
   │    ├── lib/log.sage
   │    └── src/session/session.sage
   └── src/session/session.sage
        └── lib/log.sage
```

No circular dependencies. Each module imports only what it needs.

## Cross-Compilation Strategy

JanusDBG cannot use native module calls (`tcp`, `json`) when compiled via the C/LLVM backend because SageLang's codegen backends do not support `import` from external native objects. The solution is a **deploy wrapper** (`tools/deploy.py`):

1. Bundle all source modules into a single `__bundle__.sage` via `tools/bundle.py`
2. Generate a C stub that `exec()`s the bundled script via the system `sage` interpreter
3. Cross-compile the C stub for the target architecture
4. The resulting binary embeds the bundle and invokes the interpreter at runtime

This means JanusDBG compiled binaries are not standalone — they require the SageLang interpreter on the target system.

## Target Architectures

| Target | C Compiler | Status |
|--------|-----------|--------|
| x86 (32-bit) | `i686-linux-gnu-gcc` | Built |
| x86\_64 | `gcc` (native) | Built |
| ARM 32-bit | `arm-linux-gnueabihf-gcc` | Built |
| ARM 64-bit | `aarch64-linux-gnu-gcc` | Built |
| RISC-V 64-bit | `riscv64-linux-gnu-gcc` | Built |
| RISC-V 32-bit | (none available) | Falls back to native gcc |

## Build System

The project uses two layers of build orchestration:

- **`sagemake`** — a SageLang script that performs check, test, build, deploy, and install operations
- **`Makefile`** — a thin wrapper around `sagemake` for convenience (`make build`, `make test`, etc.)

## Repository Structure

```
JanusDBG/
├── Makefile             # Make wrapper
├── sagemake             # Build orchestrator (SageLang)
├── src/
│   ├── main.sage        # Entry point
│   ├── rpc/server.sage  # JSON-RPC server
│   ├── session/session.sage  # Session manager
│   └── adapters/
│       ├── gdb_mi.sage  # ARM GDB/MI adapter
│       └── openocd.sage # RISC-V OpenOCD adapter
├── lib/
│   ├── log.sage         # Logger
│   └── json.sage        # JSON parser/serializer
├── tools/
│   ├── bundle.py         # Module bundler
│   └── deploy.py         # Cross-deploy tool
├── tests/
│   └── run_all.sage     # Test suite (15 tests)
├── deps/
│   └── SageLang/        # SageLang v4.0.8 source
└── docs/                 # This documentation
```

## Design Constraints

1. **No `std.json`** — the JSON module is self-contained because `std.json` may not be available on all targets
2. **No `std.log`** — the logger is minimal and avoids indirect callbacks unsupported by backends
3. **No `dict.get()`** — SageLang v4.0.8 dicts lack `.get()`; use `dict_has()` + direct index
4. **`continue` is reserved** — renamed to `cont` in `gdb_mi.sage`
5. **`from ... import` only** — all imports use explicit `from <module> import <name>` form for backend compatibility
6. **No circular imports** — the dependency graph is strictly acyclic
