# JanusDBG — Makefile (thin wrapper around ./sagemake)
#
# Usage:  make <target>    (same as ./sagemake <target>)
#         make run ARGS="--verbose"

.PHONY: all build check test run install clean

all:
	./sagemake all

check:
	./sagemake check

build:
	./sagemake build

test:
	./sagemake test

run:
	./sagemake run $(ARGS)

install:
	./sagemake install

clean:
	./sagemake clean
