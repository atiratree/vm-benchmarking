#!/bin/bash

help(){
    echo "prepare-benchmark-images.sh [OPTIONS] [NAME]"
    echo
    echo "  -v, --verbose"
    echo "  -p, --parallel"
    echo "  -h, --help"
}

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

source "$UTIL_DIR/common.sh"

POSITIONAL_ARGS=()
for ARG in $@; do
    case $ARG in
        -v|--verbose)
        export VERBOSE_FILE=/dev/tty
        shift
        ;;
        -p|--parallel)
        PARALLEL="YES"
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

SUITE="$BENCHMARKS_DIR/benchmark-images.cfg"

if [ ! -e "$SUITE" ]; then
	echo "$SUITE must be specified" >&2
	exit 1
fi

LINES=`cat "$SUITE" | wc -l`
for LINE in `seq 1 $LINES`; do
    VAR="`get_line "$SUITE" "$LINE"`" || continue
    if [ -z "$PARALLEL" ]; then
        prepare_vm $VAR
    else
        prepare_vm $VAR &
    fi
done

for JOB in `jobs -p`; do
    wait $JOB
done
