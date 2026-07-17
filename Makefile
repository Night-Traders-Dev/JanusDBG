# JanusDBG — Makefile (thin wrapper around ./sagemake)
#
# Usage:  make <target>    (same as ./sagemake <target>)
#         make run ARGS="--verbose"

.PHONY: all build build-all build-vscode install-vscode check test run install clean

all:
	./sagemake all

check:
	./sagemake check

build:
	./sagemake build

build-all:
	./sagemake build-all

build-vscode:
	./sagemake build-vscode

install-vscode:
	./sagemake install-vscode

test:
	./sagemake test

run:
	./sagemake run $(ARGS)

install:
	./sagemake install

clean:
	./sagemake clean
