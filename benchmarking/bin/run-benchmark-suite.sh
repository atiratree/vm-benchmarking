#!/bin/bash

trap cleanup SIGINT
trap cleanup SIGTERM

cleanup(){
    echo "stopping child benchmark $ID with pid=$BENCH_CHILD_PROCESS"
    echo "cleaning up"

    if [ -n "$BENCH_CHILD_PROCESS" ]; then
        pkill -SIGTERM --parent "$BENCH_CHILD_PROCESS"
        kill -SIGTERM "$BENCH_CHILD_PROCESS"
        wait "$BENCH_CHILD_PROCESS"
    fi

    rm -f /tmp/benchmark-suite.*

    mkdir -p "$OUTPUT_DIR"
    echo "failed with return code 9" >> "$OUTPUT_DIR/output"
    BASE_VM="`"$UTIL_DIR"/get-name.sh "$NAME" "$INSTALL_VERSION"`"
    VM="`"$UTIL_DIR"/get-name.sh "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" "$ID"`"

    CLONED_DISK="`"$UTIL_DIR/get-clone-disk-filename.sh" "$BASE_VM" "$VM"`"
    sync # wait in case script is in the middle of creating image
    "$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$VM" "$CLONED_DISK"
    exit 3
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../benchmarks/`"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"
UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"

source "$SCRIPTS_DIR/config.env"

SUITE="$BENCHMARKS_DIR/benchmark-suite.cfg"

if [ ! -e "$SUITE" ]; then
	echo "$SUITE must be specified" >&2
	exit 1
fi

run-benchmark(){
    NAME="$1"
    INSTALL_VERSION="$2"
    RUN_VERSION="$3"
    TIMES="$4"
    ANALYSIS_NAME="$5"
    CLEAN_FLAG="$6"

    BENCHMARK_DIR="$BENCHMARKS_DIR/$NAME"

    if [ -z "$NAME" ] || [ -z "$TIMES" ] || [ ${NAME:0:1} == "#" ]; then
        return 2
    fi

    echo -e "${GREEN}running `"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"` $TIMES times${NC}"

    for i in `seq 1 "$TIMES"`; do

        ID="`"$UTIL_DIR/get-new-run-id.sh" "$NAME" "$INSTALL_VERSION"  "$RUN_VERSION"`"
        RUN_PART="`DIR=TRUE "$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" "$ID"`"
        OUTPUT_DIR="$BENCHMARKS_DIR/$RUN_PART"
        TMP_FILE=$(mktemp /tmp/benchmark-suite.XXXXXX)

        echo "running $ID"
        "$IMAGE_MANAGEMENT_DIR"/run-benchmark.sh "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" > >(tee "$VERBOSE_FILE"> "$TMP_FILE" 2>&1) &
        BENCH_CHILD_PROCESS=$!
        wait "$BENCH_CHILD_PROCESS" 2> /dev/null # reattach to benchmark and wait to finish
        BENCH_CHILD_PROCESS=""

        mkdir -p "$OUTPUT_DIR"
        RESULT_FILE="$OUTPUT_DIR/output-run"
        mv "$TMP_FILE" "$RESULT_FILE"
    done

    if [ -n  "$ANALYSIS_NAME" ]; then
        "$BENCHMARK_DIR"/analysis.sh "$INSTALL_VERSION" "$RUN_VERSION" "$ANALYSIS_NAME"
    fi

    if [ "$CLEAN_FLAG" == "clean" ]; then
         echo "cleaning up run directory"
        "$SCRIPTS_DIR"/clean.sh --run "$NAME" > "$VERBOSE_FILE"
    fi
}

lines=`cat "$SUITE" | wc -l`
for i in `seq 1 $lines`
    do
    variable="'$i""q;d' $SUITE"
    run-benchmark `eval sed "$variable"`
done
