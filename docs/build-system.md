# Build System (`sagemake` + `Makefile`)

## Purpose

Two-layer build orchestration for JanusDBG. `sagemake` is the primary build orchestrator written in Python; `Makefile` is a convenience wrapper.

## `sagemake` Targets

| Target | Description |
|--------|-------------|
| `check` | Lint all `.sage` source files |
| `test` | Run the 33-test suite |
| `build` | Run tests, bundle, generate JIT launcher for native target |
| `build-all` | Run tests, bundle, generate JIT launchers for all 6 target names |
| `deploy` | Bundle source + generate JIT launcher (no tests) |
| `build-vscode` | Compile VS Code extension (`npm install` + `tsc`) |
| `install-vscode` | Build and install VS Code extension via `code --install-extension` |
| `install` | Copy JIT launcher to `PREFIX` (default `/usr/local/bin`) |
| `run` | Run the backend in interpreter mode with optional `ARGS` |
| `clean` | Remove build artifacts |
| `all` | Default: check → test → build-all |

### Check

```bash
./sagemake check
```

Lints all Sage source files using `sage lint`.

### Build

```bash
./sagemake build            # Bundle + JIT launcher for native arch
./sagemake build-all        # Bundle + JIT launchers for 6 target names
./sagemake deploy           # Bundle + JIT launcher (no tests)
```

Build generates:
- `build/janusdbg_bundle.sage` — the bundled single-file source
- `build/janusdbgd_<target>` — executable shell launcher for each target

### Deploy

```bash
./sagemake deploy
```

Steps:
1. Bundle sources with `tools/bundle.py`
2. Generate JIT shell launcher with `tools/deploy.py`

### VS Code Extension

```bash
./sagemake build-vscode       # npm install + tsc
./sagemake install-vscode     # build-vscode + vsce package + code --install-extension
```

The VS Code extension is at `vscode-extension/`. It registers debug adapter commands and a JanusDBG debugger type.

## `Makefile` Targets

| Target | Delegates to |
|--------|-------------|
| `make all` | `./sagemake all` |
| `make check` | `./sagemake check` |
| `make test` | `./sagemake test` |
| `make build` | `./sagemake build` |
| `make build-vscode` | `./sagemake build-vscode` |
| `make install-vscode` | `./sagemake install-vscode` |
| `make run ARGS="..."` | `./sagemake run $(ARGS)` |
| `make install` | `./sagemake install` |
| `make clean` | `./sagemake clean` |

## Bundle Tool (`tools/bundle.py`)

Inlines all local module dependencies into a single `.sage` file. See [deployment](deployment.md) for details.

## Deploy Tool (`tools/deploy.py`)

Generates a self-contained executable shell script that embeds the bundled source and launches via `sage --jit`. See [deployment](deployment.md) for details.

## JIT-Based Deployment

JanusDBG uses `sage --jit` instead of C/LLVM compilation because:
- Native module calls (`tcp`, `sys`) work correctly under `--jit`
- The C/LLVM backends cannot resolve native module imports at compile time
- No cross-compilation is needed — the same shell launcher works on any architecture
- Build time drops from seconds (C compilation) to near-instant (file generation)

## Output Structure

```
build/
├── janusdbg_bundle.sage          # Bundled source (shared by all targets)
├── janusdbgd_x86                 # JIT launcher for x86
├── janusdbgd_x86_64              # JIT launcher for x86_64
├── janusdbgd_rv32                # JIT launcher for RISC-V 32-bit
├── janusdbgd_rv64                # JIT launcher for RISC-V 64-bit
├── janusdbgd_arm32               # JIT launcher for ARM 32-bit
└── janusdbgd_aarch64             # JIT launcher for ARM 64-bit
```

All launchers are identical shell scripts — the target name is only for the output filename. Each is ~20K and contains the entire application embedded inline.

## Target Independence

Since the launcher is a shell script that invokes `sage --jit`, it is architecture-independent. The same `janusdbgd` script runs on any platform with `bash` and `sage` installed:

```bash
# All of these use the same launcher content:
./build/janusdbgd_x86_64              # Native x86_64
./build/janusdbgd_aarch64             # ARM 64-bit (with qemu-aarch64 + sage)
./build/janusdbgd_rv64                # RISC-V 64-bit (with qemu-riscv64 + sage)
```

## Prerequisites

- **SageLang interpreter** — `deps/SageLang/sage` (v4.0.8+)
- **bash** — for running the JIT launcher
- **gcc** — only needed if building the SageLang interpreter from source
- **Node.js + npm** — only needed for VS Code extension targets
