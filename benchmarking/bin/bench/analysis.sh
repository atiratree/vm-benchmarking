#!/bin/bash

function log(){
	echo "$1" | tee "$VERBOSE_FILE" >> "$ANALYSIS"
}

function logDetailed(){
	echo "$1" | tee "$VERBOSE_FILE" >> "$DETAILED_ANALYSIS"
}


function logBoth(){
	log "$1"
	logDetailed "$1"
}

NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"
ANALYSIS_NAME="$4"

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_MANAGEMENT_DIR="`realpath $SCRIPTS_DIR/../image-management`"
UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
source "$SCRIPTS_DIR/../config.env"

BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../../benchmarks`"
RUN_DIR_PART="`DIR=TRUE "$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"
BENCHMARK_DIR="$BENCHMARKS_DIR/$NAME"
RUN_DIR="$BENCHMARKS_DIR/$RUN_DIR_PART"

ANALYSIS_SCRIPT="$BENCHMARK_DIR/analysis.sh"
ANALYSIS_DIR="$RUN_DIR/analysis"
RESULT_DIR="$RUN_DIR/out"

if [ -z "$NAME" ]; then
	echo "name must be specified" >&2
	exit 1
fi

if [ -z "$INSTALL_VERSION" ]; then
	echo "install version must be specified" >&2
	exit 2
fi

if [ -z "$RUN_VERSION" ]; then
	echo "run version must be specified" >&2
	exit 3
fi

if [ -z "$ANALYSIS_NAME" ]; then
	echo "analysis name must be specified" >&2
	exit 4
fi

if [ ! -d "$RESULT_DIR" ]; then
    echo "out directory does not exist" >&2
    exit 5
fi

if [ ! -e "$ANALYSIS_SCRIPT" ]; then
	echo "$ANALYSIS_SCRIPT must be specified" >&2
	exit 6
fi

mkdir -p "$ANALYSIS_DIR"

ANALYSIS="$ANALYSIS_DIR/$ANALYSIS_NAME"
DETAILED_ANALYSIS="$ANALYSIS_DIR/$ANALYSIS_NAME.detail"

SHOW_HEADER=""

> "$ANALYSIS"

"$UTIL_DIR/get-settings.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" | sed -e '1{/.*/d}; s/^/# /g' > "$DETAILED_ANALYSIS"
logDetailed "# --------------------"

echo -e "${GREEN}analyzing `"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"` into $ANALYSIS${NC}"

for OUT_DIR in  "$RESULT_DIR"/*; do
    if [ ! -d "$OUT_DIR" ]; then
		continue
	fi
	OUTPUT="$OUT_DIR/output"
	OUTPUT_RUN="$OUT_DIR/output-run"
	LIBVIRT_XML="$OUT_DIR/libvirt.xml"

	if [ -f "$OUTPUT" ]; then
		RETURN_CODE="`grep -e "failed with exit code" "$OUTPUT"`"
        if [ -n "$RETURN_CODE" ]; then
            logBoth "FAIL: $RETURN_CODE"
            continue
        fi
	fi

    if [ -f "$OUTPUT_RUN" ] && ! grep -q -e "benchmark.*success" "$OUTPUT_RUN"; then
        logBoth "FAIL: benchmark run not succesfull"
        continue
	fi

	if [ ! -f "$OUTPUT" -o ! -f "$OUTPUT_RUN" -o ! -f "$OUTPUT_RUN" ]; then
		logBoth "FAIL: not all expected files created"
		continue
	fi

    "$BENCHMARK_DIR"/analysis.sh "$OUTPUT" "$ANALYSIS" "$DETAILED_ANALYSIS"
    logDetailed "# --------------------"
done
