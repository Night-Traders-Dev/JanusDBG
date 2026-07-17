# Build System (`sagemake` + `Makefile`)

## Purpose

Two-layer build orchestration for JanusDBG. `sagemake` is the primary build orchestrator written in SageLang; `Makefile` is a convenience wrapper.

## `sagemake` Targets

| Target | Description |
|--------|-------------|
| `check` | Run test suite, verify source syntax |
| `test` | Run test suite |
| `build` | Run tests, then build native binary |
| `build-all` | Run tests, then cross-compile for all 6 targets |
| `deploy` | Run tests, bundle, and create deployable C stubs |
| `install` | Copy binary to `PREFIX` (default `/usr/local/bin`) |
| `run` | Run the built binary with optional `ARGS` |
| `clean` | Remove build artifacts |
| `all` | Default: check → build-all |

### Check

```bash
./sagemake check
```

Verifies:
- All `.sage` source files compile without errors
- All 21 tests pass

### Build

```bash
./sagemake build            # Build for host architecture
./sagemake build-all        # Cross-compile for all targets
```

Build generates:
- `build/janusdbgd` — native binary
- `build/janusdbgd-x86`, `janusdbgd-x86_64`, `janusdbgd-arm`, `janusdbgd-arm64`, `janusdbgd-rv64`, `janusdbgd-rv32` — cross-compiled binaries

### Deploy

```bash
./sagemake deploy TARGET=arm
```

Steps:
1. Run tests
2. Bundle sources with `tools/bundle.py`
3. Generate C launcher stub with `tools/deploy.py`
4. Cross-compile for the specified target

## `Makefile` Targets

| Target | Delegates to |
|--------|-------------|
| `make all` | `./sagemake all` |
| `make check` | `./sagemake check` |
| `make test` | `./sagemake test` |
| `make build` | `./sagemake build` |
| `make run ARGS="..."` | `./sagemake run $(ARGS)` |
| `make install` | `./sagemake install` |
| `make clean` | `./sagemake clean` |

## Bundle Tool (`tools/bundle.py`)

### Purpose

Inlines all local module dependencies into a single `.sage` file for deployment.

### Operation

1. Recursively resolves `from ... import` statements
2. Inlines local module source (replacing import lines with the module body)
3. Deduplicates stdlib imports (only the import line is kept, not the stdlib source)
4. Writes a single `__bundle__.sage` file

### Example

Before bundling:
```python
# src/main.sage
from lib.log import create_logger, info
from std.argparse import create

proc main():
    let logger = create_logger("test", 1)
    info(logger, "hello")
```

After bundling:
```python
## --- BEGIN lib/log.sage ---
proc create_logger(name, level=1):
    return {"name": name, "level": level}
proc info(logger, msg):
    ... (inlined body)
## --- END lib/log.sage ---

from std.argparse import create

proc main():
    let logger = create_logger("test", 1)
    info(logger, "hello")
```

## Deploy Tool (`tools/deploy.py`)

### Purpose

Creates a self-contained C launcher stub that embeds the bundled script and invokes the SageLang interpreter at runtime.

### Operation

1. Read the bundle (`__bundle__.sage`)
2. Generate a C source file (`janusdbgd_launcher.c`):
   - Embeds the bundle as a string constant
   - Writes it to a temp file at runtime
   - Calls `exec()` on the SageLang interpreter with the temp file
3. Cross-compile the C stub for the specified target
4. Output: `build/janusdbgd-<target>` (an ELF binary)

### Launcher C Stub Structure

```c
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

static const char BUNDLE[] =
    "## --- BEGIN lib/log.sage\n"
    ...
    "## --- END src/main.sage\n";

int main() {
    char tmp[] = "/tmp/janusdbg_bundle_XXXXXX";
    int fd = mkstemp(tmp);
    write(fd, BUNDLE, strlen(BUNDLE));
    close(fd);

    pid_t pid = fork();
    if (pid == 0) {
        execlp("sage", "sage", tmp, NULL);
        exit(1);
    }
    int status;
    waitpid(pid, &status, 0);
    unlink(tmp);
    return WEXITSTATUS(status);
}
```

### Limitations

- The binary is not standalone — it requires `sage` (the SageLang interpreter) on `$PATH` at runtime
- This is because native module calls (`tcp`) cannot be compiled to C/LLVM by the SageLang backend

## Cross-Compilation

Cross-compilers used:

| Target | C Compiler | Source |
|--------|-----------|--------|
| x86 (32-bit) | `i686-linux-gnu-gcc` | system package |
| x86\_64 | `gcc` | native |
| ARM 32-bit | `arm-linux-gnueabi-gcc` | system package |
| ARM 64-bit | `aarch64-linux-gnu-gcc` | system package |
| RISC-V 64-bit | `riscv64-linux-gnu-gcc` | system package |
| RISC-V 32-bit | (falls back to native gcc) | not available |

## Output Structure

```
build/
├── __bundle__.sage          # Bundled source
├── janusdbgd                # Native binary
├── janusdbgd-x86            # 32-bit x86
├── janusdbgd-x86_64         # x86_64
├── janusdbgd-arm            # ARM 32-bit (hard-float)
├── janusdbgd-arm64          # AArch64
├── janusdbgd-rv64           # RISC-V 64-bit
├── janusdbgd-rv32           # RISC-V 32-bit (native fallback)
└── janusdbgd_launcher.c     # Generated C stub
```

## Codegen Considerations

- `sagemake` runs `check` (tests + lint) before every build — prevents codegen from running on broken source
- Bundle tool handles recursive imports and deduplication correctly for the backend to see a flat module namespace
- Deploy tool generates C code — must be valid C89/C99 for cross-compiler compatibility
- Adapter imports (`src.adapters.gdb_mi`, `src.adapters.openocd`) are included via the bundle's transitive dependency through `src/session/session.sage`
