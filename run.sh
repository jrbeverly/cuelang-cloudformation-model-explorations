#!/usr/bin/env bash
# Validate inputs and emit accepted CloudFormation templates:
#   ./run.sh <input>  vet the input, then emit the lowered CloudFormation
#                     template as JSON on stdout. Emission only runs on
#                     input that passes validation.
#   ./run.sh          demonstrate accept/reject end to end: the valid
#                     example must be accepted and its emission must match
#                     the committed golden template
#                     (testdata/valid.template.json); both invalid examples
#                     must be rejected with a diagnostic.
# Requires the cue CLI on PATH; the CLI is not vendored in this repo.
set -u
cd "$(dirname "$0")"

if [ "$#" -gt 1 ]; then
	echo "usage: $0 [<input-package>]" >&2
	exit 2
fi

if ! command -v cue >/dev/null 2>&1; then
	echo "error: cue CLI not on PATH; install cue (https://github.com/cue-lang/cue/releases) and retry" >&2
	exit 1
fi

if [ "$#" -eq 1 ]; then
	# Validation gate: only input that passes vet is emitted.
	if ! cue vet -c "./$1"; then
		echo "error: validation failed; no template emitted" >&2
		exit 1
	fi

	cue export -e Template --out json "./$1"
	exit 0
fi

# Accept/reject demonstration over the examples. Each example is a
# single-file package: cue treats the file argument as its own package, so
# the invalid cases are never unified with the valid one.
failures=0
total=0

# The first line of a vet error can be disjunction noise; the specific
# rejection is the line naming the offending field and value.
specific() {
	echo "$1" | grep -E "invalid value|undefined field|non-concrete value|field not allowed|invalid operand" | head -n 1
}

# The valid example must be accepted...
out=$(cue vet -c ./examples/valid.cue 2>&1)
code=$?
total=$((total + 1))
if [ "$code" -eq 0 ]; then
	echo "PASS examples/valid.cue: vet accepted"
else
	failures=$((failures + 1))
	echo "FAIL examples/valid.cue: expected acceptance, vet rejected"
	echo "  $(specific "$out")"
fi

# ...and its emission must match the committed golden template.
emitted=$(cue export -e Template --out json ./examples/valid.cue 2>&1)
total=$((total + 1))
if diff -u testdata/valid.template.json <(printf '%s\n' "$emitted") >/dev/null 2>&1; then
	echo "PASS examples/valid.cue: emission matches testdata/valid.template.json"
else
	failures=$((failures + 1))
	echo "FAIL examples/valid.cue: emission differs from testdata/valid.template.json"
	diff -u testdata/valid.template.json <(printf '%s\n' "$emitted") | head -n 20
fi

# Both invalid examples must be rejected with a diagnostic.
reject_check() {
	local input=$1 out code
	out=$(cue vet -c "$input" 2>&1)
	code=$?
	total=$((total + 1))
	if [ "$code" -ne 0 ]; then
		echo "PASS $input: vet rejected"
		echo "  $(specific "$out")"
	else
		failures=$((failures + 1))
		echo "FAIL $input: expected rejection, vet accepted"
	fi
}

reject_check ./examples/invalid-name.cue
reject_check ./examples/invalid-ref.cue

echo
echo "$((total - failures))/$total cases behaved as expected"
[ "$failures" -eq 0 ]
