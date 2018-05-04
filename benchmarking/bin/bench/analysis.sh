#!/bin/bash

function log(){
	echo "$1" | tee "$VERBOSE_FILE" >> "$ANALYSIS"
}

function log_detailed(){
	echo "$1" | tee "$VERBOSE_FILE" >> "$DETAILED_ANALYSIS"
}

function log_settings(){
	echo "$1" | sort | uniq | sed -e '/^\s*$/d; /^[^=]*=$/d; s/^/# /g' >> "$DETAILED_ANALYSIS"
}

function finish(){
	log "$1"
	log_detailed "$1"
	log_detailed "# --------------------"
}

NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"
ANALYSIS_NAME="$4"

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_MANAGEMENT_DIR="`realpath "$SCRIPTS_DIR/../image-management"`"
UTIL_DIR="`realpath "$SCRIPTS_DIR/../util"`"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
BENCH_UTIL_DIR="$SCRIPTS_DIR/util"

source "$UTIL_DIR/common.sh"

BENCHMARKS_DIR="`realpath "$SCRIPTS_DIR/../../benchmarks"`"
RUN_DIR_PART="`DIR=TRUE "$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`" || exit 1
BENCHMARK_DIR="$BENCHMARKS_DIR/$NAME"

INSTALL_DIR_PART="`DIR=TRUE "$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"
VERSIONED_INSTALL_DIR="$BENCHMARKS_DIR/$INSTALL_DIR_PART"

RUN_DIR="$BENCHMARKS_DIR/$RUN_DIR_PART"

ANALYSIS_SCRIPT="$BENCHMARK_DIR/analysis.sh"
VERSIONED_ANALYSIS_SCRIPT="$VERSIONED_INSTALL_DIR/analysis.sh"

if [ -f "$VERSIONED_ANALYSIS_SCRIPT" ]; then
    ANALYSIS_SCRIPT="$VERSIONED_ANALYSIS_SCRIPT"
fi

ANALYSIS_DIR="$RUN_DIR/analysis"
RESULT_DIR="$RUN_DIR/out"

assert_run "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"

if [ -z "$ANALYSIS_NAME" ]; then
	echo "analysis name must be specified" >&2
	exit 4
fi

if [ ! -f "$ANALYSIS_SCRIPT" ]; then
	echo "$ANALYSIS_SCRIPT must be specified" >&2
	exit 6
fi

mkdir -p "$ANALYSIS_DIR"

ANALYSIS="$ANALYSIS_DIR/$ANALYSIS_NAME"
DETAILED_ANALYSIS="$ANALYSIS_DIR/$ANALYSIS_NAME.detail"
ANALYSIS_USAGES_DIR="$ANALYSIS_DIR/$ANALYSIS_NAME""-USAGE"

rm -rf "$ANALYSIS_USAGES_DIR"

> "$ANALYSIS"
> "$DETAILED_ANALYSIS"
PRINT_HEADER=TRUE "$ANALYSIS_SCRIPT" "$ANALYSIS" "$DETAILED_ANALYSIS"

ALL_SETTINGS=""
ALL_GLOBAL_CONFIGS=""
for RUN_DIR in "$RESULT_DIR"/*; do
    if [ -f "$RUN_DIR/settings.env" ]; then
        ALL_SETTINGS="$ALL_SETTINGS`echo && cat "$RUN_DIR/settings.env"`"
    fi

    if [ -f "$RUN_DIR/global-config.env" ]; then
        ALL_GLOBAL_CONFIGS="$ALL_GLOBAL_CONFIGS`echo && cat "$RUN_DIR/global-config.env"`"
    fi
done

log_settings "$ALL_GLOBAL_CONFIGS"
log_detailed "#"
log_settings "$ALL_SETTINGS"
log_detailed "# --------------------"

echo -e "${BLUE}analyzing `"$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"` into $ANALYSIS_DIR as $ANALYSIS_NAME${NC}"


if [ ! -d "$RESULT_DIR" ]; then
    echo -e "${RED}out directory not found${NC}" >&2
    exit 0
fi

for OUT_DIR in  "$RESULT_DIR"/*; do
    if [ ! -d "$OUT_DIR" ]; then
		continue
	fi
	OUTPUT="$OUT_DIR/output"
	OUTPUT_RUN="$OUT_DIR/output-run"
	LIBVIRT_XML="$OUT_DIR/libvirt.xml"
	RESOURCE_USAGE="$OUT_DIR/resource-usage.svg"

	if [ -f "$RESOURCE_USAGE" ]; then
        mkdir -p "$ANALYSIS_USAGES_DIR"
        NUMBERED="` basename "$OUT_DIR"`"
        cp "$RESOURCE_USAGE" "$ANALYSIS_USAGES_DIR/resource-usage.$NUMBERED.svg"
	fi

	if [ -f "$OUTPUT" ]; then
		RETURN_CODE="`grep -e "failed with exit code" "$OUTPUT"`"
        if [ -n "$RETURN_CODE" ]; then
            finish "FAIL: `echo "$RETURN_CODE" | tail -1`"
            continue
        fi
	fi

    if [ -f "$OUTPUT_RUN" ]; then
        NO_CONNECT="`grep -e "Could not connect to" "$OUTPUT_RUN"`"
        if [ -n "$NO_CONNECT" ]; then
            finish "FAIL: $NO_CONNECT"
            continue
        fi
        NO_SUCCESS="`grep -e "benchmark.*success" "$OUTPUT_RUN"`"
        if [ -z "$NO_SUCCESS" ]; then
            finish "FAIL: benchmark run not successful"
            continue
        fi
	fi

	if [ ! -f "$OUTPUT" -o ! -f "$OUTPUT_RUN" -o ! -f "$OUTPUT_RUN" ]; then
		finish "FAIL: not all expected files created"
		continue
	fi

    "$ANALYSIS_SCRIPT" "$ANALYSIS" "$DETAILED_ANALYSIS" "$OUTPUT"
    log_detailed "# --------------------"
done
