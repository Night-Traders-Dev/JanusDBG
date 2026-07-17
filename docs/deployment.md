# Deployment (`tools/bundle.py` + `tools/deploy.py`)

## Purpose

JanusDBG uses native module calls (`tcp`, `sys`) that cannot be compiled via SageLang's C/LLVM codegen backends. Instead, `tools/deploy.py` generates a self-contained shell launcher that runs the bundled source under `sage --jit`, where all native module calls work correctly.

## Workflow

```
Source files (.sage)
        │
        ▼
tools/bundle.py  ───▶  build/janusdbg_bundle.sage  (single file, inlined deps)
        │
        ▼
tools/deploy.py  ───▶  build/janusdbgd_<target>  (executable shell launcher)
```

## Bundle Tool (`tools/bundle.py`)

### Purpose

Inlines all local module dependencies into a single `.sage` file for deployment.

### Algorithm

1. Recursively resolves `from ... import` statements from the entry point (`src/main.sage`)
2. Inlines local module source (replacing import lines with the module body)
3. Deduplicates stdlib imports (only the import line is kept, not the stdlib source)
4. Writes a single `build/janusdbg_bundle.sage` file

### Example output structure

```python
## -- stdlib imports --
from std.argparse import create, add_option, ...
from sys import args, exit as sys_exit

## --- src/session/session.sage ---
<inlined module body>

## --- lib/log.sage ---
<inlined module body>

## --- src/main.sage ---
<inlined module body>
```

## Deploy Tool (`tools/deploy.py`)

### Purpose

Generates a self-contained executable shell script that embeds the bundled source and launches it via `sage --jit`.

### Generated Launcher

```bash
#!/usr/bin/env bash
# JanusDBG — JIT-launched debugger backend
set -e
TMPFILE=$(mktemp /tmp/janusdbg_XXXXXX.sage)
trap "rm -f '$TMPFILE'" EXIT
cat > "$TMPFILE" << 'JANUSDBG_EOF'
## -- stdlib imports --
...
## --- src/main.sage ---
...
JANUSDBG_EOF
exec sage --jit "$TMPFILE" "$@"
```

The bundle content is embedded inline via a heredoc. At runtime:
1. A temp file is created with the bundled source
2. `sage --jit` is exec'd on the temp file with all CLI arguments passed through
3. On exit, the temp file is cleaned up by the `trap`

### Usage

```bash
python3 tools/deploy.py            # Build for "native"
python3 tools/deploy.py x86        # Build for x86 target
python3 tools/deploy.py aarch64    # Build for aarch64 target
# All produce identical launchers — the target name is only for the output filename
```

## Target Independence

Unlike the old C-stub approach, JIT launchers are **architecture-independent**. The same `janusdbgd` shell script works on x86_64, ARM, RISC-V, or any platform with `bash` and `sage` installed. The target name in the filename is purely for organizational convenience.

## Target Requirements

The target system must have:
- **bash** (or compatible POSIX shell)
- **SageLang interpreter** (`sage`) on `$PATH` — v4.0.8+

## Build Integration

```bash
./sagemake build          # Bundle + JIT launcher for native target
./sagemake build-all      # Bundle + JIT launchers for all 6 target names
./sagemake deploy         # Bundle + JIT launcher (same as build)
```

## Benefits over C-Stub Approach

| Aspect | Old (C stub) | New (JIT launcher) |
|--------|-------------|-------------------|
| Compilation required | C cross-compiler for each target | None |
| Target architecture | Must recompile per target | Single script works everywhere |
| Binary size | 30K+ per ELF | ~20K shell script |
| TCP networking | Buggy in compiled ELF | Works correctly under `--jit` |
| Build time | Seconds per target (compilation) | Instant (file generation only) |
| Cross-compilation | Complex, requires toolchains | Trivial (same file for all) |
