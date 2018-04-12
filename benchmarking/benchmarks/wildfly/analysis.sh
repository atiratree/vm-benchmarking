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
PRINT_HEADER="${PRINT_HEADER:-}"

BLACLISTED_ENTRIES="$SCRIPTS_DIR/analysis-blacklisted-entries"

ANALYSIS="$1"
DETAILED_ANALYSIS="$2"
OUTPUT="$3"

if [ ! -f "$ANALYSIS" ]; then
	echo "file for analysis result must be specified" >&2
	exit 1
fi

if [ -n "$PRINT_HEADER" ]; then
    log "# all tests runtime (in seconds) without tests setup"
    exit 0
fi

if [ ! -f "$DETAILED_ANALYSIS" ]; then
	echo "file for detailed analysis result must be specified" >&2
	exit 2
fi

if [ ! -f "$OUTPUT" ]; then
	echo "file for analysis must be specified" >&2
	exit 3
fi

FAILED=""
FAILED_PARSE=""

REGEX="Time elapsed: ([0-9.]+) sec"

TIME=0

ELAPSED_TIMES="`grep -e 'Time elapsed:' "$OUTPUT"`"

if [ -f "$BLACLISTED_ENTRIES" ]; then
    TMP_FILE=$(mktemp)
    sed -e '/^#.*/d; /^\s*$/d; s/^\s*#.*$//g;' "$BLACLISTED_ENTRIES" > "$TMP_FILE"
    if [ -s  "$TMP_FILE" ]; then
        ELAPSED_TIMES="`echo  "$ELAPSED_TIMES" | grep -v -f "$TMP_FILE"`"
    fi
    rm -f "$TMP_FILE"
fi

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
done <<< "$ELAPSED_TIMES"


if [ -n "$FAILED" ]; then
    log "FAIL: tests were not successful: $FAILED"
    exit 4
fi

if [ -n "$FAILED_PARSE" ]; then
    log "FAIL: could not parse result: $FAILED_PARSE"
    exit 5
fi

log "$TIME"
