```markdown
# JanusDBG — Development Plan

## 1. Introduction

JanusDBG is a unified debugging and profiling tool for heterogeneous SoCs combining ARM Cortex‑A (Linux) and RISC‑V coprocessors (bare‑metal/RTOS). It connects to both GDB/MI and OpenOCD/JTAG simultaneously, providing cross‑core breakpoints, synchronized execution control, and merged performance timelines—all from a VS Code extension.

This plan outlines the development of the JanusDBG **backend** using **SageLang** (with a minimal C fallback for low‑level I/O), and the frontend as a standard VS Code extension. SageLang offers the right balance of performance, low‑level control, and high‑level scripting to build this tool quickly and reliably.

---

## 2. Why SageLang for JanusDBG?

| Requirement                  | How SageLang meets it                                                                                  |
|------------------------------|--------------------------------------------------------------------------------------------------------|
| **Performance**              | Compiles to native via C, LLVM, or JIT; sub‑millisecond GC pauses via concurrent tracing GC.           |
| **Low‑level I/O**            | FFI (`ffi_open`, `ffi_call`) to call C libraries (libgdb, libopenocd, serial, sockets).                |
| **Concurrency**              | Native threading, `async/await`, channels, thread pools for simultaneous debug sessions.               |
| **Scriptability**            | REPL, eval, dynamic code loading for custom debug scripts.                                             |
| **Networking**               | Built‑in TCP/HTTP/WebSocket modules; easy to implement a JSON‑RPC server for VS Code extension.        |
| **Metaprogramming**          | Generics, macros, compile‑time execution for protocol marshaling and code generation.                  |
| **Memory safety**            | GC and ARC modes; bounds checking; optional unsafe blocks for performance‑critical paths.              |
| **Cross‑platform**           | Compiles to Linux, macOS, Windows; supports ARM, x86, and RISC‑V hosts.                                 |
| **Extensibility**            | Module system and pure‑Sage libraries; allow user‑defined trace analysis scripts.                      |
| **Size and deployability**   | Compiles to a single binary (via `--compile`), no external VM required.                                |

---

## 3. System Architecture

```

+-------------------+          +-----------------------------+

|   VS Code         |  JSON   |  JanusDBG Backend (Sage)    |

|   Extension       | <─────> |  - Protocol Multiplexer     |

|   (TypeScript)    |  RPC    |  - ARM Debug Session (GDB)  |
+-------------------+         |  - RISC‑V Debug Session (OCD)|

```

**Backend Components:**

- **Protocol Adapters**: Use SageLang's FFI to interface with GDB/MI via `libgdb` or spawn `gdb` as a subprocess, and OpenOCD via its Tcl interface or socket.
- **Session Manager**: Manages two independent debug sessions, maintains state, handles breakpoints, watchpoints.
- **Synchronization Engine**: Implements cross‑core step, continue, and breakpoint coordination (e.g., stop both cores on any breakpoint hit).
- **Timeline Collector**: Collects execution events (PC, cycle counts, trace) from both cores and merges into a single timeline with synchronization markers.
- **Profiling Aggregator**: Uses SageLang's `std.profiler` and custom instrumentation to produce flame graphs and performance metrics.
- **RPC Server**: Exposes a JSON‑RPC or WebSocket interface to the VS Code extension.

---

## 4. Implementation Plan (Phases)

### Phase 0: Environment & Foundation (Week 1–2)

- **Set up SageLang** (v4.0.7+) from source, verify all backends.
- **Create project skeleton** (`janusdbg/` with `src/`, `lib/`, `tests/`).
- **Write build script** using SageLang's `std.build` (or a `Makefile`) to compile the backend with `sage --compile` for production.
- **Establish C fallback** for low‑level serial/JTAG communication if FFI proves insufficient (use `mem_alloc`/`mem_write` and inline assembly? Actually we'll use FFI to call system APIs directly).
- **Implement logging** using `std.log` with TRACE to FATAL levels.
- **Create VS Code extension skeleton** (TypeScript) with basic activation and connection to backend.

**Deliverables**: Working project skeleton, build pipeline, VS Code extension that can launch and communicate with the backend.

---

### Phase 1: Protocol Abstraction (Weeks 3–5)

- **GDB/MI Adapter**:
  - Use `ffi_open("libgdb")` or spawn `gdb` with `--interpreter=mi` and communicate via pipes.
  - Implement functions: `gdb_connect(host, port)`, `gdb_set_breakpoint`, `gdb_step`, `gdb_continue`, `gdb_read_registers`, `gdb_write_memory`.
  - Use `async proc` for non‑blocking I/O from GDB.
  - Parse MI output into Sage data structures (arrays/dicts).
- **OpenOCD Adapter**:
  - Connect to OpenOCD's Tcl server (port 6666) via TCP socket.
  - Send Tcl commands and parse responses.
  - Alternatively use `ffi_open("libopenocd")` if we build OpenOCD as a library (more complex).
  - Implement: `ocd_halt`, `ocd_resume`, `ocd_set_breakpoint`, `ocd_read_reg`, `ocd_step`.
- **Unified Debug Session**:
  - Abstract interface for ARM and RISC‑V with common methods (connect, disconnect, step, breakpoint, etc.).
  - Use generics or traits to define common behavior.

**Deliverables**: Two working adapters that can independently control each core; basic `connect` and `step` commands exposed via RPC.

---

### Phase 2: Synchronization & Cross‑Core Control (Weeks 6–8)

- **Event Loop**:
  - Use `thread.spawn` for each adapter's I/O polling.
  - Use `std.channel` for inter‑thread communication (commands and events).
- **Cross‑Core Breakpoints**:
  - When user sets a breakpoint on ARM, also set a corresponding breakpoint on RISC‑V (optional).
  - Implement "stop both" policy: if either core hits a breakpoint, both are halted.
  - Use `std.signal` or event bus to broadcast breakpoint hits.
- **Synchronized Step**:
  - Step ARM, then step RISC‑V, then merge state.
  - Handle instruction‑level synchronization with barriers (using `std.condvar`).
- **State Merging**:
  - Combine register dumps from both cores into a single view (dictionary with prefix `arm_` and `rv_`).
  - Provide API to retrieve merged state.

**Deliverables**: Full cross‑core breakpoint/step/continue functionality; ability to get merged register state.

---

### Phase 3: Performance Profiling & Timeline Merging (Weeks 9–12)

- **Profiling Data Collection**:
  - Use GDB's `trace` or `record` commands to collect instruction traces (ARM).
  - For RISC‑V, use OpenOCD's trace buffer or implement software instrumentation (inserting `ebreak`/counters).
  - Collect cycle counts via performance counters if available (use `perf_event_open` FFI on ARM Linux).
- **Timeline Builder**:
  - Define a timeline event structure: `{core, timestamp, type, pc, data}`.
  - Use a global monotonic clock (from `clock()` or system time) to correlate events.
  - Merge two event streams into a sorted list.
- **VS Code Visualization**:
  - Expose timeline data via RPC as JSON arrays.
  - VS Code extension renders a Gantt‑style timeline with clickable events.
- **Profiling Aggregator**:
  - Use `std.profiler` to instrument the backend itself, but also aggregate target profiling data.
  - Generate flame graphs (using `ml.viz` or custom SVG output) sent to frontend.

**Deliverables**: Timeline view in VS Code showing execution flow of both cores; basic profiling (PC samples, function hot spots).

---

### Phase 4: VS Code Extension Integration & UX (Weeks 13–15)

- **RPC Protocol**:
  - Define JSON‑RPC 2.0 over WebSocket or stdio.
  - Use SageLang's `net.websocket` or `http` to serve.
  - Implement methods: `connect`, `disconnect`, `setBreakpoint`, `removeBreakpoint`, `step`, `continue`, `getState`, `getTimeline`, `startProfiling`, `stopProfiling`.
- **Frontend UI**:
  - Use VS Code's Debug Adapter Protocol (DAP) or custom views.
  - Register a custom debugger type (`janusdbg`) and implement a DebugAdapter in TypeScript that talks to the backend.
  - Display register views, memory views, timeline, profile charts.
- **Commands**:
  - "JanusDBG: Attach to ARM/RISC‑V"
  - "JanusDBG: Set Cross Breakpoint"
  - "JanusDBG: Record Timeline"

**Deliverables**: Full working VS Code extension with basic debugging and profiling UI.

---

### Phase 5: Advanced Features & Polish (Weeks 16–18)

- **Cross‑Trigger Logic**:
  - Allow user to define rules: e.g., "when ARM PC == 0x8000, halt RISC‑V".
  - Implement using a simple DSL evaluated in SageLang, or using `std.agent` for rule engine.
- **Trace Analysis**:
  - Provide trace filtering, search, and statistics.
  - Use SageLang's `std.regex` and `std.db` to store traces and query.
- **Scripting Interface**:
  - Expose a SageLang REPL embedded in the backend (via `sage --repl` style) to allow user‑written debug scripts.
  - Provide API hooks for custom breakpoint conditions.
- **Performance Optimizations**:
  - Use AOT compilation (`sage --aot`) for the backend to reduce startup time.
  - Enable `-O3` and profile‑guided optimization.
- **Error Handling & Robustness**:
  - Proper exception handling for communication failures.
  - Automatic reconnect.
  - Graceful shutdown.

**Deliverables**: All advanced features polished; stable, production‑ready backend.

---

### Phase 6: Testing, Packaging & Documentation (Weeks 19–20)

- **Unit Tests**:
  - Use `std.testing` to test protocol parsers, timeline merger, etc.
  - Mock GDB/OpenOCD responses for CI.
- **Integration Tests**:
  - Test on real hardware (e.g., Allwinner D1, SigmaStar SSD202D) with both cores.
- **Packaging**:
  - Build standalone binary for Linux (x86_64, aarch64) using `sage --compile`.
  - Package VS Code extension as `.vsix`.
- **Documentation**:
  - User guide (setup, commands, examples).
  - API documentation for custom scripts.
  - Video tutorials.
- **Monetization Setup**:
  - Implement license check / subscription validation (using `http` to contact licensing server).

**Deliverables**: Release candidate; internal testing; prepared for beta launch.

---

## 5. Deployment & Monetization

- **Distribution**: VS Code Marketplace (free tier), private marketplace for paid features.
- **Licensing**: Use SageLang's `crypto` module to generate and verify machine‑bound licenses.
- **Subscription**: Integrate with Stripe or Paddle via HTTP API; backend checks subscription status at startup.
- **Enterprise**: Provide custom builds for OEMs with branding and extended support.

---

## 6. Risks & Mitigations

| Risk                                     | Mitigation                                                                 |
|------------------------------------------|----------------------------------------------------------------------------|
| GDB/MI protocol changes or instability   | Use stable MI commands; wrap with robust parsing; fallback to `libgdb`.    |
| OpenOCD Tcl interface latency            | Use non‑blocking I/O and buffering; optimize command batching.             |
| Timeline synchronization accuracy        | Use hardware timers (ARM PMU, RISC‑V mcycle) if available; else software correlation via periodic snapshots. |
| SageLang GC pauses affecting real‑time   | Use ARC mode (`--gc:arc`) for deterministic performance; minimize allocations in hot loops. |
| VS Code extension performance            | Offload heavy processing to backend; use WebWorker for UI rendering.       |
| Lack of community support for SageLang   | Write clear documentation; rely on C fallback for critical low‑level code; keep SageLang usage to high‑level orchestration. |

---

## 7. Timeline Summary

| Phase | Duration | Cumulative |
|-------|----------|------------|
| 0: Foundation | 2 weeks | 2 weeks |
| 1: Protocol Abstraction | 3 weeks | 5 weeks |
| 2: Cross‑Core Control | 3 weeks | 8 weeks |
| 3: Profiling & Timeline | 4 weeks | 12 weeks |
| 4: VS Code Integration | 3 weeks | 15 weeks |
| 5: Advanced Features | 3 weeks | 18 weeks |
| 6: Testing & Packaging | 2 weeks | 20 weeks |

Total: **20 weeks** (5 months) for a polished beta.

---

## 8. Next Steps

1. **Set up SageLang development environment** and run through its examples to build confidence.
2. **Prototype GDB/MI communication** using `ffi` and pipes to validate performance.
3. **Design the RPC interface** with clear data models for VS Code.
4. **Start implementing the VS Code extension** UI mockups and basic skeleton.

---

This plan leverages SageLang's strengths to build a feature‑rich, high‑performance debugger with a fraction of the effort of a C++ implementation. The language's built‑in modules for networking, concurrency, and profiling drastically shorten development time, while its compilation backends ensure the final product is fast and deployable.
```
