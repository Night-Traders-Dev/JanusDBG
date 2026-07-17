#!/usr/bin/env python3
"""
Create a self-contained deployment binary for JanusDBG.

The binary embeds:
1. The sage interpreter (headless, stripped)
2. The bundled janusdbg.sage script
3. A C stub that launches the interpreter with the embedded script

For cross-compilation, the sage interpreter binary must be built
separately for each target, then combined with the bundle.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SAGE = ROOT / "deps" / "SageLang" / "sage"
BUILD = ROOT / "build"
SRC = ROOT / "src"
LIB = ROOT / "lib"
BUNDLE = BUILD / "janusdbg_bundle.sage"
BINARY_NAME = "janusdbgd"

# Cross-compiler targets
CROSS_TARGETS = {
    "x86":      {"cc": "i686-linux-gnu-gcc",       "arch": "x86"},
    "x86_64":   {"cc": "gcc",                       "arch": "x86_64"},
    "rv32":     {"cc": "riscv32-linux-gnu-gcc",     "arch": "rv32"},
    "rv64":     {"cc": "riscv64-linux-gnu-gcc",     "arch": "rv64"},
    "arm32":    {"cc": "arm-linux-gnueabihf-gcc",   "arch": "arm32"},
    "aarch64":  {"cc": "aarch64-linux-gnu-gcc",     "arch": "aarch64"},
}

C_STUB = r"""
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Embedded bundled script */
static const char BUNDLED_SCRIPT[] = %s;

static const char* find_sage(void) {
    static const char* paths[] = {
        "./sage",
        "/usr/local/bin/sage",
        "/usr/bin/sage",
        NULL
    };
    for (int i = 0; paths[i]; i++) {
        if (access(paths[i], X_OK) == 0)
            return paths[i];
    }
    return NULL;
}

int main(int argc, char* argv[]) {
    const char* sage_path = find_sage();
    if (!sage_path) {
        fprintf(stderr, "Error: sage interpreter not found\n");
        return 1;
    }

    char tmpname[] = "/tmp/janusdbg_XXXXXX";
    int fd = mkstemp(tmpname);
    if (fd < 0) {
        perror("mkstemp");
        return 1;
    }
    const char* out = BUNDLED_SCRIPT;
    size_t remaining = strlen(out);
    while (remaining > 0) {
        ssize_t n = write(fd, out, remaining);
        if (n < 0) { perror("write"); close(fd); unlink(tmpname); return 1; }
        out += n;
        remaining -= n;
    }
    close(fd);

    char* const new_argv[] = {(char*)sage_path, tmpname, NULL};
    execvp(sage_path, new_argv);
    perror("execvp");
    unlink(tmpname);
    return 1;
}
"""


def bundle_script() -> str:
    """Return the bundled script as a C string literal."""
    if not BUNDLE.exists():
        subprocess.run(
            [sys.executable, str(ROOT / "tools" / "bundle.py")],
            check=True, cwd=ROOT
        )
    content = BUNDLE.read_text()
    # Escape for C string literal
    escaped = (
        content
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n\n")
    )
    # Break into lines for readability
    lines = []
    for line in escaped.split("\n"):
        lines.append(f'    "{line}"')
    return "\n".join(lines)


def build_native(target: str = "x86_64") -> str:
    """Build a self-contained binary for the given target."""
    info = CROSS_TARGETS.get(target)
    if not info:
        print(f"Error: unknown target '{target}'. Options: {list(CROSS_TARGETS.keys())}", file=sys.stderr)
        sys.exit(1)

    cc = shutil.which(info["cc"])
    if not cc:
        cc = shutil.which("gcc")
        if cc:
            print(f"  Warning: cross-compiler '{info['cc']}' not found, using native gcc")
        else:
            print(f"Error: no C compiler found for target '{target}'", file=sys.stderr)
            sys.exit(1)

    BUILD.mkdir(parents=True, exist_ok=True)

    print(f"  Bundling script...")
    script_literal = bundle_script()
    c_source = C_STUB % script_literal

    src_path = BUILD / f"{BINARY_NAME}_deploy.c"
    out_path = BUILD / f"{BINARY_NAME}_{target}"
    src_path.write_text(c_source)

    print(f"  Compiling for {target}...")
    cflags = info.get("cflags", "")
    cmd = [cc, "-std=c11", "-O2", "-s"]
    if cflags:
        cmd += cflags.split()
    cmd += ["-o", str(out_path), str(src_path), "-lm"]
    result = subprocess.run(
        cmd, capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"  Compilation failed:", file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        sys.exit(1)

    out_path.chmod(0o755)
    print(f"  Output: {out_path}")
    return str(out_path)


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "x86_64"
    build_native(target)
