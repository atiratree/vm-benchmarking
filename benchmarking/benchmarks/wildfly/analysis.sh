#!/bin/bash
# Wildlfy Summary at the end also includes building and setup of the tests
# We measure only the test cases without blacklisted tests

function log(){
	echo "$1" | tee "$VERBOSE_FILE" >> "$ANALYSIS"
}

function logDetailed(){
	echo "$1"  >> "$DETAILED_ANALYSIS"
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VERBOSE_FILE="${VERBOSE_FILE:-/dev/null}"
BLACLISTED_TESTS="$SCRIPTS_DIR/analysis-blacklisted-tests"

OUTPUT="$1"
ANALYSIS="$2"
DETAILED_ANALYSIS="$3"
SHOW_HEADER="$4"

if [ ! -f "$OUTPUT" ]; then
	echo "file for analysis must be specified" >&2
	exit 1
fi

if [ ! -f "$ANALYSIS" ]; then
	echo "file for analysis result must be specified" >&2
	exit 2
fi

if [ -n "$SHOW_HEADER" ]; then
    log "# all tests runtime (in seconds) without tests setup"
fi


FAILED=""
FAILED_PARSE=""

REGEX="Time elapsed: ([0-9.]+) sec"

TIME=0

while read -r line; do
	logDetailed  "$line"

    if [[ "$line" =~ "FAILURE" || "$line" =~ "ERROR" ]]; then
		FAILED="$line"
	fi

    if [[ "$line" =~ $REGEX ]]; then
        SEC="${BASH_REMATCH[1]}"
        TIME="`echo "$TIME + $SEC" | bc`"
    else
        FAILED_PARSE="$line"
    fi
done <<< "`grep -e 'Time elapsed:' "$OUTPUT" | grep -v -f "$BLACLISTED_TESTS" `"


if [ -n "$FAILED" ]; then
    log "FAIL: tests were not successful: $FAILED"
    exit 3
fi

if [ -n "$FAILED_PARSE" ]; then
    log "FAIL: could not parse result: $FAILED_PARSE"
    exit 4
fi

log "$TIME"
