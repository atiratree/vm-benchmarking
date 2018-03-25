#!/bin/bash

trap cleanup SIGINT
trap cleanup SIGTERM

cleanup(){
    kill_current_benchmark 3 "cleaning up"
    rm -f /tmp/benchmark-suite.*
    exit 3
}

kill_current_benchmark(){
    EXIT_CODE="$1"
    REASON="$2"
    echo -e "${RED}stopping child benchmark $ID with pid=$BENCH_CHILD_PROCESS: $REASON${NC}"

    if [ -n "$BENCH_CHILD_PROCESS" ]; then
        pkill -SIGTERM --parent "$BENCH_CHILD_PROCESS"
        kill -SIGTERM "$BENCH_CHILD_PROCESS"
        wait "$BENCH_CHILD_PROCESS"
    fi

    mkdir -p "$OUTPUT_DIR"
    echo "failed with exit code $EXIT_CODE ($REASON)" >> "$OUTPUT_DIR/output"
    BASE_VM="`"$UTIL_DIR"/get-name.sh "$NAME" "$INSTALL_VERSION"`"
    VM="`"$UTIL_DIR"/get-name.sh "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" "$ID"`"

    CLONED_DISK="`"$UTIL_DIR/get-clone-disk-filename.sh" "$BASE_VM" "$VM"`"
    sync # wait in case script is in the middle of creating image
    "$IMAGE_MANAGEMENT_DIR/delete-vm.sh" "$VM" "$CLONED_DISK"
}

line_count(){
    wc -l "$1"  2> /dev/null |  cut -f1 -d' ' && [ ${PIPESTATUS[0]} -eq 0 ] || echo 0
}

wait_for_start(){
    PROCESS_PID="$1"
    while true; do
        sleep 1
        if ! ps -p "$PROCESS_PID" --no-headers > /dev/null || grep -q -e "running.*benchmark" "$TMP_FILE"; then
            break
        fi
    done
}

wait_for_benchmark(){
    # do not set too high or the process will hang longer after the benchmark has finished
    SLEEP_CONSTANT=20

    PROCESS_PID="$1"
    OUTPUT_FILE="$2"
    NO_OUTPUT_CHECK_MIN="$3"

    if [[ "$NO_OUTPUT_CHECK_MIN" =~ ^[0-9]+$ ]] && [ "$NO_OUTPUT_CHECK_MIN" -gt 0 ]; then
        wait_for_start "$PROCESS_PID"
        CURRENT_SLEEP=0
        MAX_SLEEP=$(($NO_OUTPUT_CHECK_MIN * 60)) # to seconds
        LAST_LINE_COUNT="`line_count "$OUTPUT_FILE"`"
        while true; do
            sleep "$SLEEP_CONSTANT"

            if ! ps -p "$PROCESS_PID" --no-headers > /dev/null; then
                break # process finished
            fi

            NEW_LINE_COUNT="`line_count "$OUTPUT_FILE"`"

            # check benchmark still responding after sleeping
            if [ "$LAST_LINE_COUNT" -eq "$NEW_LINE_COUNT" ];then
                CURRENT_SLEEP=$(($CURRENT_SLEEP + $SLEEP_CONSTANT))
            else
                CURRENT_SLEEP=0
            fi
            LAST_LINE_COUNT="$NEW_LINE_COUNT"

            if [ "$CURRENT_SLEEP" -gt "$MAX_SLEEP" ]; then
                # output same as last time for max sleep
                kill_current_benchmark 4 "benchmark stopped responding every $NO_OUTPUT_CHECK_MIN min"
                break
            fi
        done
    else
         wait "$PROCESS_PID" 2> /dev/null # reattach to benchmark and wait to finish
    fi
}

set_option(){
    OPTIONS="$1"
    OPTION="$2"
    REGEX="$OPTION=[^,]*"
    if [[ "$OPTIONS" =~ $REGEX ]]; then
        OPT="${BASH_REMATCH[0]}"
        export "$OPT"
    fi
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../benchmarks/`"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"
BENCH_DIR="$SCRIPTS_DIR/bench"
UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"

source "$SCRIPTS_DIR/config.env"

SUITE="$BENCHMARKS_DIR/benchmark-suite.cfg"

if [ ! -e "$SUITE" ]; then
	echo "$SUITE must be specified" >&2
	exit 1
fi

run_benchmark(){
    NAME="$1"
    INSTALL_VERSION="$2"
    RUN_VERSION="$3"
    TIMES="$4"
    ANALYSIS_NAME="$5"
    OPTIONS="$6"

    BENCHMARK_DIR="$BENCHMARKS_DIR/$NAME"

    if [ -z "$NAME" ] || [ -z "$ANALYSIS_NAME" ] || [ ${NAME:0:1} == "#" ]; then
        return 2
    fi

    echo -e "${GREEN}running `"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"` $TIMES times${NC}"

    for i in `seq 1 "$TIMES"`; do

        ID="`"$UTIL_DIR/get-new-run-id.sh" "$NAME" "$INSTALL_VERSION"  "$RUN_VERSION"`"
        RUN_PART="`DIR=TRUE "$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" "$ID"`"
        OUTPUT_DIR="$BENCHMARKS_DIR/$RUN_PART"
        TMP_FILE=$(mktemp /tmp/benchmark-suite.XXXXXX)

        echo "running $ID"
        set_option "$OPTIONS" "NO_OUTPUT_CHECK_MIN"
        "$BENCH_DIR"/run-benchmark.sh "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" > >(tee "$VERBOSE_FILE"> "$TMP_FILE" 2>&1) &
        BENCH_CHILD_PROCESS=$!
        wait_for_benchmark "$BENCH_CHILD_PROCESS" "$OUTPUT_DIR/output" "$NO_OUTPUT_CHECK_MIN"
        BENCH_CHILD_PROCESS=""

        mkdir -p "$OUTPUT_DIR"
        RESULT_FILE="$OUTPUT_DIR/output-run"
        mv "$TMP_FILE" "$RESULT_FILE"
    done

    "$BENCH_DIR"/analysis.sh  "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" "$ANALYSIS_NAME"

    set_option "$OPTIONS" "CLEAN_FLAG"
    if [ "$CLEAN_FLAG" == "clean" ]; then
         echo "cleaning up run directory"
        "$SCRIPTS_DIR"/clean.sh --run "$NAME" > "$VERBOSE_FILE"
    fi
}

lines=`cat "$SUITE" | wc -l`
for i in `seq 1 $lines`
    do
    variable="'$i""q;d' $SUITE"
    run_benchmark `eval sed "$variable"`
done
