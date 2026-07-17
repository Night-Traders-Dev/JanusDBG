# Deployment (`tools/bundle.py` + `tools/deploy.py`)

## Purpose

JanusDBG cannot be compiled to native code via SageLang's C/LLVM backends because it uses native modules (`tcp`, `sys`) that the backends don't support. The deployment workflow creates a C launcher stub that embeds the bundled source and invokes the SageLang interpreter at runtime.

## Workflow

```
Source files (.sage)
        │
        ▼
tools/bundle.py  ───▶  __bundle__.sage  (single file, inlined deps)
        │
        ▼
tools/deploy.py  ───▶  janusdbgd_launcher.c  (C stub with embedded bundle)
        │
        ▼
Cross-compiler  ───▶  janusdbgd-<target>  (ELF binary)
```

## Bundle Tool (`tools/bundle.py`)

### Algorithm

1. Parse entry point (`src/main.sage`) for `from <pattern> import` lines
2. For each `from <local_path> import`:
   - Read the referenced `.sage` file
   - Recursively resolve its own imports
   - Replace the import line with the full module body (delimited by header/footer comments)
   - Track imported modules to avoid duplicate inlining
3. For `from <stdlib> import`:
   - Keep the import line as-is (stdlib modules are available at runtime)
   - Add to a deduplicated set
4. Write the combined output to `__bundle__.sage`

### Input/Output

```bash
python3 tools/bundle.py src/main.sage build/__bundle__.sage
```

Output structure:
```python
## --- BEGIN lib/log.sage ---
<inlined module body>
## --- END lib/log.sage ---

## --- BEGIN src/rpc/server.sage ---
<inlined module body>
## --- END src/rpc/server.sage ---

from std.argparse import create, ...
from sys import args, exit as sys_exit
from tcp import ...

## --- BEGIN src/main.sage ---
<inlined entry point>
## --- END src/main.sage ---
```

## Deploy Tool (`tools/deploy.py`)

### Algorithm

1. Read `__bundle__.sage`
2. Generate `janusdbgd_launcher.c`:
   - Embed bundle as a C string constant (with proper escaping)
   - `main()` writes the bundle to a temp file
   - `fork()`/`exec()` the SageLang interpreter with that file
   - Wait for child process and propagate exit code
3. Compile the C stub: `<target>-gcc -o janusdbgd-<target> janusdbgd_launcher.c`

### C Stub Structure

```c
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

static const char BUNDLE[] =
    "## --- BEGIN lib/log.sage ---\n"
    "proc create_logger(name, level=1)...\n"
    ...
    "## --- END src/main.sage ---\n";

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

## Target Requirements

The target system must have:
- SageLang interpreter (`sage`) on `$PATH`
- Dynamic linker and C runtime library appropriate to the architecture

## Limitations

- **Not standalone** — the compiled binary is a launcher, not a true native binary
- **Interpreter required** — `sage` must be installed on the target
- **Temp file** — the bundle is written to `/tmp` at each launch (minor I/O overhead)
- **No module caching** — each launch parses the bundle from scratch

## Build Integration

From `sagemake`:

```bash
./sagemake build       # Bundle + native compile
./sagemake build-all   # Bundle + cross-compile for all 6 targets
./sagemake deploy      # Bundle + C stub + compile for a specific target
```

## Testing Deployed Binaries

```bash
# Run a cross-compiled binary (requires qemu-user or target hardware)
qemu-arm build/janusdbgd-arm --help

# Run native binary
./build/janusdbgd --verbose
```
