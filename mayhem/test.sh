#!/usr/bin/env bash
#
# mayhem/test.sh — RUN libforth's own upstream test suite (built by mayhem/build.sh).
# Mirrors `make test` (= unit.test + forth.test in the makefile):
#   1. `./forth -u`  — the C-API unit tests in unit.c; prints "passed  P/T".
#   2. `./forth -s <core> forth.fth unit.fth` — the Forth-level unit tests in
#      unit.fth (T{ ... -> ... }T known-answer tests); a failing test invalidates
#      the core so the save (and the run) fails. Each passing test prints "ok".
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

if [ ! -x ./forth ]; then
  echo "FATAL: ./forth test binary missing — mayhem/build.sh should have built it" >&2
  emit_ctrf "libforth-make-test" 0 1
  exit 1
fi

# 1) C-API unit tests (`make unit.test` == ./forth -u). Output: "passed  P/T".
unit_out="$(./forth -u 2>&1)"
unit_rc=$?
unit_line="$(printf '%s\n' "$unit_out" | grep -Eo 'passed[[:space:]]+[0-9]+/[0-9]+' | head -1)"
unit_passed="$(printf '%s' "$unit_line" | grep -Eo '[0-9]+' | sed -n 1p)"
unit_total="$(printf '%s' "$unit_line" | grep -Eo '[0-9]+' | sed -n 2p)"
unit_passed="${unit_passed:-0}"
unit_total="${unit_total:-0}"
unit_failed=$(( unit_total - unit_passed ))
# A run that emitted no parsable "passed P/T" line is a failure (e.g. neutered binary).
if [ "$unit_total" -eq 0 ] || [ "$unit_rc" -ne 0 ]; then
  unit_failed=$(( unit_failed > 0 ? unit_failed : 1 ))
fi

# 2) Forth-level unit tests (`make forth.test`): evaluate forth.fth + unit.fth and
#    save the core — any failing T{ test invalidates the core and fails the save.
#    Count each passing test's "ok" line; assert the run terminated with the
#    "END OF UNIT TESTS" marker AND actually produced a core file.
fth_core=/tmp/forth_test.core
rm -f "$fth_core"
fth_out="$(./forth -s "$fth_core" forth.fth unit.fth 2>&1)"
fth_rc=$?
fth_ok="$(printf '%s\n' "$fth_out" | grep -c ' ok')"
fth_failed=0
if [ "$fth_rc" -ne 0 ] || [ ! -s "$fth_core" ] || [ "$fth_ok" -eq 0 ] \
   || ! printf '%s\n' "$fth_out" | grep -q 'END OF UNIT TESTS'; then
  fth_failed=1
fi
rm -f "$fth_core"

passed=$(( unit_passed + fth_ok ))
failed=$(( unit_failed + fth_failed ))
echo "libforth: C-API unit tests passed ${unit_passed}/${unit_total} (rc=${unit_rc}); Forth-level tests ok=${fth_ok} rc=${fth_rc}"
emit_ctrf "libforth-make-test" "$passed" "$failed"
