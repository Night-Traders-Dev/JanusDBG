# JanusDBG

**Unified debugging and profiling for heterogeneous ARM Cortex-A + RISC-V SoCs.**

JanusDBG connects simultaneously to GDB/MI (ARM) and OpenOCD/JTAG (RISC-V), providing cross-core breakpoints, synchronized execution control, and merged performance timelines — all from a VS Code extension.

---

## Features

- **Dual-Core Debugging** — Simultaneous ARM (GDB/MI) and RISC-V (OpenOCD) sessions with a unified interface
- **Cross-Core Breakpoints** — Set a breakpoint on one core; pause, inspect, and continue both
- **Synchronized Step/Continue** — Instruction-level coordinated stepping across heterogenous cores
- **Merged Performance Timeline** — Collect execution events from both cores into a single Gantt-style timeline
- **Register & Memory Views** — Unified state inspection with ARM/RISC-V prefix namespacing
- **Profiling Aggregator** — Flame graphs and performance metrics via hardware counters and software instrumentation
- **Scriptable** — Embedded SageLang REPL for custom debug and trace analysis scripts
- **VS Code Extension** — Rich UI with timeline, register views, and debug controls

---

## Architecture

```
┌─────────────────────┐          ┌──────────────────────────────────────┐
│   VS Code           │  JSON    │  JanusDBG Backend (SageLang)        │
│   Extension         │ ◄──────► │  ┌────────────────────────────────┐  │
│   (TypeScript)      │   RPC    │  │  Protocol Multiplexer          │  │
└─────────────────────┘          │  ├────────────────────────────────┤  │
                                 │  │  ARM Debug Session (GDB/MI)   │  │
                                 │  │  RISC-V Debug Session (OCD)   │  │
                                 │  ├────────────────────────────────┤  │
                                 │  │  Synchronization Engine       │  │
                                 │  │  Timeline Collector           │  │
                                 │  │  Profiling Aggregator         │  │
                                 │  │  JSON-RPC Server              │  │
                                 │  └────────────────────────────────┘  │
                                 └──────────────────────────────────────┘
```

### Backend Components

| Component | Description |
|-----------|-------------|
| **Protocol Adapters** | FFI bindings to GDB/MI and OpenOCD Tcl interfaces |
| **Session Manager** | Manages two independent debug sessions, state, breakpoints |
| **Synchronization Engine** | Cross-core step, continue, and breakpoint coordination |
| **Timeline Collector** | Merges execution events from both cores with sync markers |
| **Profiling Aggregator** | Hardware counter + software instrumentation → flame graphs |
| **RPC Server** | JSON-RPC 2.0 over WebSocket/stdio for VS Code communication |

---

## Quick Start

### Prerequisites

- **SageLang** v4.0.7+ (included at `deps/SageLang/`)
- GDB (for ARM debugging) — `gdb-multiarch` recommended
- OpenOCD (for RISC-V JTAG) — built with RISC-V support
- VS Code + Node.js (for the extension)
- A target SoC with ARM Cortex-A + RISC-V coprocessor (e.g., Allwinner D1, SigmaStar SSD202D)

### Build the Backend

```bash
# From the project root
make backend
```

This compiles the SageLang backend into a standalone binary using `sage --compile`.

### Run

```bash
# Start the backend server
./janusdbgd --arm-host localhost:2331 --rv-host localhost:3333

# In another terminal, launch VS Code and use the JanusDBG extension
```

### VS Code Extension

```bash
cd vscode-extension
npm install
npm run compile
code .
# Press F5 to launch an Extension Development Host
```

---

## Project Structure

```
janusdbg/
├── src/                  # SageLang backend source
│   ├── adapters/         # GDB/MI and OpenOCD protocol adapters
│   ├── session/          # Session manager & state
│   ├── sync/             # Cross-core synchronization engine
│   ├── timeline/         # Timeline collection & merging
│   ├── profiler/         # Profiling aggregation
│   ├── rpc/              # JSON-RPC server
│   └── main.sage         # Entry point
├── lib/                  # Pure-Sage helper libraries
├── tests/                # Test suites (std.testing)
├── vscode-extension/     # VS Code extension (TypeScript)
├── deps/SageLang/        # SageLang interpreter dependency
├── Makefile              # Build pipeline
└── plan.md               # Development plan (20 weeks)
```

---

## Development Phases

| Phase | Description | Duration |
|-------|-------------|----------|
| **0** | Environment & Foundation | Week 1–2 |
| **1** | Protocol Abstraction (GDB/MI + OpenOCD) | Week 3–5 |
| **2** | Synchronization & Cross-Core Control | Week 6–8 |
| **3** | Performance Profiling & Timeline | Week 9–12 |
| **4** | VS Code Extension Integration | Week 13–15 |
| **5** | Advanced Features & Polish | Week 16–18 |
| **6** | Testing, Packaging & Docs | Week 19–20 |

See [plan.md](plan.md) for the detailed plan.

---

## License

MIT
