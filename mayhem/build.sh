#!/usr/bin/env bash
#
# mayhem/build.sh — build libforth's fuzz harness (instrumented) and the upstream
# test suite (normal flags). Runs inside the commit image as `mayhem` in /mayhem.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}"
: "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
export SANITIZER_FLAGS DEBUG_FLAGS CC LIB_FUZZING_ENGINE MAYHEM_JOBS

cd "$SRC"

# 1) Compile the project (libforth.c) instrumented so the FUZZED code carries
#    ASan/UBSan + DWARF<4 symbols AND SanitizerCoverage counters (fuzzer-no-link)
#    so libFuzzer sees edges in the library, not just the harness.
$CC $SANITIZER_FLAGS -fsanitize=fuzzer-no-link $DEBUG_FLAGS -std=c99 -I. \
	-c libforth.c -o /tmp/libforth.san.o

# 2) Build the fuzz harness twice: once with the libFuzzer engine, once with the
#    standalone run-once driver (a natural-crash reproducer).
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE -std=c99 -I. \
	mayhem/fuzz_forth.c /tmp/libforth.san.o -o /mayhem/fuzz_forth

$CC $SANITIZER_FLAGS $DEBUG_FLAGS -std=c99 -I. \
	"$STANDALONE_FUZZ_MAIN" mayhem/fuzz_forth.c /tmp/libforth.san.o \
	-o /mayhem/fuzz_forth-standalone

# 3) Build the upstream test suite with the project's NORMAL flags (clean,
#    uninstrumented) so mayhem/test.sh only RUNS it. `make forth` produces the
#    `./forth` binary whose `-u` flag runs the C-API unit tests, and which
#    evaluates forth.fth/unit.fth for the Forth-level functional tests.
make -j"$MAYHEM_JOBS" forth
