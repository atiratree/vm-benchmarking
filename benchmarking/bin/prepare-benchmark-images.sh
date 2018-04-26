#!/bin/bash

fail_handler(){
	if [ $1 -ne 0 ]; then
	    echo -e "${RED}preparing $NAME $INSTALL_VERSION from $BASE_IMAGE failed${NC}"
	    if [ -z "$PARALLEL" ]; then
            echo "stopping other preparations..."
            exit $?
        fi
    fi
}

prepare_vm(){
	BASE_IMAGE="$1"
    NAME="$2"
    INSTALL_VERSION="$3"

    [ -z "$INSTALL_VERSION" ] && return 1

    "$BENCH_DIR/prepare-vm.sh" "$BASE_IMAGE" "$NAME" "$INSTALL_VERSION"
    fail_handler $?
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath "$SCRIPTS_DIR/../benchmarks/"`"
BENCH_DIR="$SCRIPTS_DIR/bench"
UTIL_DIR="$SCRIPTS_DIR/util"

source "$SCRIPTS_DIR/config.env"
source "$UTIL_DIR/common.sh"

PARALLEL="${PARALLEL:-}"

SUITE="$BENCHMARKS_DIR/benchmark-images.cfg"

if [  "$1" == "-v" ]; then
	export VERBOSE_FILE=/dev/tty
fi

if [ ! -e "$SUITE" ]; then
	echo "$SUITE must be specified" >&2
	exit 1
fi

LINES=`cat "$SUITE" | wc -l`
for LINE in `seq 1 $LINES`; do
    VAR="`get_line "$LINE"`" || continue
    if [ -z "$PARALLEL" ]; then
        prepare_vm $VAR
    else
        prepare_vm $VAR &
    fi
done

for JOB in `jobs -p`; do
    wait $JOB
done
