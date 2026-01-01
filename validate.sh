#!/usr/bin/env bash
# Expected pass/fail matrix for the model constraints.
# Requires the cue CLI on PATH; the CLI is not vendored in this repo.
set -u
cd "$(dirname "$0")"

if ! command -v cue >/dev/null 2>&1; then
	echo "error: cue CLI not on PATH; install cue (https://github.com/cue-lang/cue/releases) and retry" >&2
	exit 1
fi

failures=0
total=0

# The first line of a vet error can be disjunction noise; the specific
# rejection is the line naming the offending field and value.
specific() {
	echo "$1" | grep -E "invalid value|undefined field|non-concrete value|field not allowed" | head -n 1
}

expect_pass() {
	local out code
	out=$(cue vet -c "./$1" 2>&1)
	code=$?
	total=$((total + 1))
	if [ "$code" -eq 0 ]; then
		echo "PASS $1: vet accepted"
	else
		failures=$((failures + 1))
		echo "FAIL $1: expected acceptance, vet rejected"
		echo "  $(specific "$out")"
	fi
}

expect_reject() {
	local out code
	out=$(cue vet -c "./$1" 2>&1)
	code=$?
	total=$((total + 1))
	if [ "$code" -ne 0 ]; then
		echo "PASS $1: vet rejected"
		echo "  $(specific "$out")"
	else
		failures=$((failures + 1))
		echo "FAIL $1: expected rejection, vet accepted"
	fi
}

# Instances the constraints must reject.
expect_reject testdata/invalid/name-over-limit
expect_reject testdata/invalid/name-unbounded
expect_reject testdata/invalid/name-unsafe-charset
expect_reject testdata/invalid/dangling-ref
expect_reject testdata/invalid/unknown-getatt

# Instances that must still pass.
expect_pass testdata/valid/minimal
expect_pass testdata/valid/references
expect_pass testdata/valid/composed-name

echo
echo "$((total - failures))/$total cases behaved as expected"
[ "$failures" -eq 0 ]
