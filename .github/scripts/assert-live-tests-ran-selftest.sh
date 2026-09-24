#!/bin/sh
# Fixtures for assert-live-tests-ran.sh, with the expected answer worked out by hand.
#
# This script gates a merge, so it is not allowed to be believed on sight. Every fixture below is
# real `swift test` output from this package, captured on 2026-09-24 on macOS 15 / Swift 6.2,
# except the `nomatch` one, which reproduces the `--filter "Integration"` typo that shipped before
# PR #10.
#
# Usage: assert-live-tests-ran-selftest.sh
set -eu

here=$(dirname "$0")
guard="$here/assert-live-tests-ran.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0

# expect: 0 = the guard must accept, 1 = the guard must reject
check() {
    name="$1"
    expect="$2"
    file="$3"
    set +e
    out=$(sh "$guard" "$file" 2>&1)
    got=$?
    set -e
    if [ "$got" -eq "$expect" ]; then
        printf 'ok   %-28s exit %s\n' "$name" "$got"
    else
        printf 'FAIL %-28s expected exit %s, got %s\n' "$name" "$expect" "$got"
        printf '     %s\n' "$out"
        fail=1
    fi
}

# No key on this host, so all 8 Live* tests throw XCTSkip. This is what main has been doing.
cat > "$tmp/all-skipped.log" <<'LOG'
Test Case '-[AnthropicTests.LiveStreamingTests testStreamingTextDeltas]' skipped (0.000 seconds).
Test Suite 'LiveStreamingTests' passed at 2026-09-24 02:20:24.024.
	 Executed 2 tests, with 2 tests skipped and 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'anthropic-swiftPackageTests.xctest' passed at 2026-09-24 02:20:24.024.
	 Executed 8 tests, with 8 tests skipped and 0 failures (0 unexpected) in 0.007 (0.008) seconds
Test Suite 'Selected tests' passed at 2026-09-24 02:20:24.024.
	 Executed 8 tests, with 8 tests skipped and 0 failures (0 unexpected) in 0.007 (0.011) seconds
✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.
LOG
check all-skipped 1 "$tmp/all-skipped.log"

# The original bug: `--filter "Integration"` names a directory, so nothing is selected.
cat > "$tmp/nomatch.log" <<'LOG'
Building for debugging...
Build complete!
warning: No matching test cases were run
LOG
check no-matching-cases 1 "$tmp/nomatch.log"

# A real live run: 8 selected, none skipped. XCTest omits the skipped clause entirely.
cat > "$tmp/all-ran.log" <<'LOG'
Test Suite 'Selected tests' passed at 2026-09-24 02:19:58.670.
	 Executed 8 tests, with 0 failures (0 unexpected) in 4.185 (4.204) seconds
LOG
check all-ran 0 "$tmp/all-ran.log"

# Partly live: the Skills write round trip is gated behind a second variable and skips itself.
cat > "$tmp/partly-ran.log" <<'LOG'
Test Suite 'Selected tests' passed at 2026-09-24 02:19:58.670.
	 Executed 8 tests, with 3 tests skipped and 0 failures (0 unexpected) in 3.185 (3.204) seconds
LOG
check partly-ran 0 "$tmp/partly-ran.log"

# Exactly one live test is enough; the boundary the >= 1 rule turns on.
cat > "$tmp/one-ran.log" <<'LOG'
	 Executed 8 tests, with 7 tests skipped and 0 failures (0 unexpected) in 1.185 seconds
LOG
check one-ran 0 "$tmp/one-ran.log"

# swift test died before any suite started — a compile error, a missing toolchain.
cat > "$tmp/no-summary.log" <<'LOG'
Building for debugging...
error: emit-module command failed with exit code 1
LOG
check no-summary 1 "$tmp/no-summary.log"

: > "$tmp/empty.log"
check empty-log 1 "$tmp/empty.log"

check missing-log 1 "$tmp/does-not-exist.log"

if [ "$fail" -ne 0 ]; then
    echo "selftest FAILED"
    exit 1
fi
echo "selftest passed"
