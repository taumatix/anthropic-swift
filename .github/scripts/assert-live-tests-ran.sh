#!/bin/sh
# Fail unless at least one test in a `swift test` log actually executed rather than skipping.
#
# The job this guards is named "Integration Tests" and its whole value is that it touched the real
# API. It has twice reported success having touched nothing: once because `--filter "Integration"`
# matched no test case (swift test filters on TestCase/testMethod, and `Integration` is only a
# directory), and once because every Live* test throws XCTSkip when ANTHROPIC_API_KEY is absent.
# Both exit 0.
#
# The previous guard tested `[ -z "$ANTHROPIC_API_KEY" ]`, which is a proxy: it catches the missing
# key and misses the filter typo, and it turns main permanently red in a repo that has no such
# secret. This reads what the run reported instead.
#
# Usage: assert-live-tests-ran.sh <swift-test-output-log>
set -eu

log="${1:?usage: assert-live-tests-ran.sh <swift-test-output-log>}"

if [ ! -s "$log" ]; then
    echo "assert-live-tests-ran: '$log' is missing or empty; the test step produced no output." >&2
    exit 1
fi

if grep -q 'No matching test cases were run' "$log"; then
    echo "assert-live-tests-ran: swift test reported 'No matching test cases were run'." >&2
    echo "  The --filter argument matches no test case. It filters on TestCase/testMethod names," >&2
    echo "  not on directories." >&2
    exit 1
fi

# XCTest prints one roll-up per suite and the widest one last, in either of two shapes:
#     Executed 8 tests, with 8 tests skipped and 0 failures (0 unexpected) in 0.007 seconds
#     Executed 144 tests, with 0 failures (0 unexpected) in 0.185 seconds
# The second omits the skipped clause entirely when nothing skipped.
summary=$(grep 'Executed [0-9][0-9]* test' "$log" | tail -n 1 || true)

if [ -z "$summary" ]; then
    echo "assert-live-tests-ran: no 'Executed N tests' line in '$log'." >&2
    echo "  swift test did not get as far as running a test suite." >&2
    exit 1
fi

executed=$(printf '%s\n' "$summary" | sed -n 's/.*Executed \([0-9][0-9]*\) test.*/\1/p')
skipped=$(printf '%s\n' "$summary" | sed -n 's/.*with \([0-9][0-9]*\) tests* skipped.*/\1/p')
[ -n "$skipped" ] || skipped=0

ran=$((executed - skipped))

if [ "$ran" -lt 1 ]; then
    echo "assert-live-tests-ran: $executed test(s) selected, $skipped skipped, $ran actually ran." >&2
    echo "  This job proved nothing. If the skips say ANTHROPIC_API_KEY is unset, the secret is" >&2
    echo "  missing from the environment that reached swift test." >&2
    exit 1
fi

echo "assert-live-tests-ran: $ran live test(s) executed ($executed selected, $skipped skipped)."
