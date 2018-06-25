#!/bin/bash

help(){
    echo "remove-run.sh RUN_NAME"
    echo
    echo "  -f, --force"
    echo "  -h, --help"
}


SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="`realpath "$SCRIPTS_DIR/../.."`"
BENCHMARKS_DIR="`realpath "$BIN_DIR/../benchmarks/"`"
SUITE_EXAMPLE="`realpath "$BENCHMARKS_DIR/benchmark-suite.cfg.example"`"
UTIL_DIR="$BIN_DIR/util"
source "$UTIL_DIR/common.sh"

POSITIONAL_ARGS=()
FORCE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force)
        FORCE="YES"
        shift
        ;;
        -h|--help)
        help
        exit 0
        ;;
        *)
        POSITIONAL_ARGS+=("$1") # save it in an array for later
        shift
        ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

RUN_NAME="$1"

set -eu

if [ -z "$RUN_NAME" ]; then
    echo "run name must be specified" >&2
    exit 1
fi

remove_runs(){
    BENCHMARK_DIR="$1"

    NAME="`basename "$BENCHMARK_DIR"`"

    for INSTALL_DIR in "$BENCHMARK_DIR/"install-v*; do
        if [ ! -d "$INSTALL_DIR" ]; then
            continue
        fi
        verbose_remove "$INSTALL_DIR/run-v$RUN_NAME"
    done
}

if safe_remove "all ${RED}run-v$RUN_NAME${NC} directories" "$FORCE"; then
    for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
        if [ -d "$BENCHMARK_DIR" ]; then
            remove_runs "$BENCHMARK_DIR"
        fi
    done
fi

# remove run
sed -i -E "/\s+$RUN_NAME\s+/d; /#.*$RUN_NAME/d" "$SUITE_EXAMPLE"
# remove superfluous empty lines
sed -i '/^$/N;/^\n$/D' "$SUITE_EXAMPLE"
# remove trailing empty lines
sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$SUITE_EXAMPLE"
