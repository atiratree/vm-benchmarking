#!/bin/bash

trap cleanup SIGTERM SIGINT

cleanup(){
    kill_current_benchmark 3 "cleaning up"
    rm -f /tmp/benchmark-suite.*
    exit 3
}

kill_current_benchmark(){
    EXIT_CODE="$1"
    REASON="$2"
    echo
    echo -e "${RED}stopping child benchmark $ID with pid=$BENCH_CHILD_PROCESS: $REASON${NC}"

    if [ -n "$BENCH_CHILD_PROCESS" ]; then
        pkill -SIGTERM --parent "$BENCH_CHILD_PROCESS"
        kill -SIGTERM "$BENCH_CHILD_PROCESS"
        wait "$BENCH_CHILD_PROCESS"
    fi

    if [ -n "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        echo "failed with exit code $EXIT_CODE ($REASON)" >> "$OUTPUT_DIR/output"
    fi
    rm -f "/tmp/get-settings.*" "/tmp/benchmark-run.*"
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
         # reattach to benchmark and wait to finish
         wait "$PROCESS_PID" 2> /dev/null
    fi
}

finish_suite_run(){
    U_LINE="$1"
    sed -i -e "$U_LINE"'s/^/# /' "$SUITE"
}

update_suite_run(){
    U_LINE="$1"
    U_TIMES="$2"
    U_ACCEPTED="$3"

    F_OUT="$U_TIMES"",ACCEPTED=$U_ACCEPTED"
    AWK_TMP_FILE=$(mktemp /tmp/benchmark-suite.out.XXXXXX)
    awk 'BEGIN { OFS="    "}; '"FNR==$U_LINE{"'$4="'"$F_OUT"'"};{print $0}' "$SUITE" > "$AWK_TMP_FILE"
    mv "$AWK_TMP_FILE" "$SUITE"
}

run_benchmark(){
    NAME="$1"
    INSTALL_VERSION="$2"
    RUN_VERSION="$3"
    ANALYSIS_NAME="$4"
    OPTIONS="$5"

    set_option "$OPTIONS" "MANAGED_BY_VM"

    ID="`"$BENCH_UTIL_DIR/get-new-run-id.sh" "$NAME" "$INSTALL_VERSION"  "$RUN_VERSION"`"
    RUN_PART="`DIR=TRUE "$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" "$ID"`"
    OUTPUT_DIR="$BENCHMARKS_DIR/$RUN_PART"

    if [ -n "$MANAGED_BY_VM" ]; then
       MANAGED_ID="`"$BENCH_UTIL_DIR/get-new-run-id.sh" "$MANAGED_BY_VM" "$INSTALL_VERSION"  "$RUN_VERSION"`"
       MANAGED_RUN_PART="`DIR=TRUE "$BENCH_UTIL_DIR/get-name.sh" "$MANAGED_BY_VM" "$INSTALL_VERSION" "$RUN_VERSION" "$MANAGED_ID"`"
       MANAGED_OUTPUT_DIR="$BENCHMARKS_DIR/$MANAGED_RUN_PART"
    fi

    TMP_FILE=$(mktemp /tmp/benchmark-suite.out.XXXXXX)

    echo -n "running $ID ..."
    START=`date +%s`
    set_option "$OPTIONS" "NO_OUTPUT_CHECK_MIN"
    "$BENCH_DIR"/run-benchmark.sh "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" "$OPTIONS" > >(tee "$VERBOSE_FILE"> "$TMP_FILE" 2>&1) &
    BENCH_CHILD_PROCESS=$!
    wait_for_benchmark "$BENCH_CHILD_PROCESS" "$OUTPUT_DIR/output" "$NO_OUTPUT_CHECK_MIN"
    END=`date +%s`
    echo -e "${BLUE} finished in $((END-START))s${NC}"
    BENCH_CHILD_PROCESS=""

    mkdir -p "$OUTPUT_DIR"
    RESULT_FILE="$OUTPUT_DIR/output-run"

    if [ -n "$MANAGED_BY_VM" ]; then
        mkdir -p "$MANAGED_OUTPUT_DIR"
        MANAGED_RESULT_FILE="$MANAGED_OUTPUT_DIR/output-run"
        cp "$TMP_FILE" "$MANAGED_RESULT_FILE"
    fi
    mv "$TMP_FILE" "$RESULT_FILE"

    "$BENCH_DIR"/analysis.sh  "$NAME" "$INSTALL_VERSION" "$RUN_VERSION" "$ANALYSIS_NAME" &> /dev/null || echo -e "${RED}skipping analysis${NC}"
    if [ -n "$MANAGED_BY_VM" ]; then
        "$BENCH_DIR"/analysis.sh  "$MANAGED_BY_VM" "$INSTALL_VERSION" "$RUN_VERSION" "$ANALYSIS_NAME" &> /dev/null || echo -e "${RED}skipping MANAGED_BY_VM analysis${NC}"
    fi
}

run_benchmark_times(){
    LINE="$1"
    NAME="$2"
    INSTALL_VERSION="$3"
    RUN_VERSION="$4"
    TIMES_FIELDS="$5"
    ANALYSIS_NAME="$6"
    OPTIONS="$7"

    BENCHMARK_DIR="$BENCHMARKS_DIR/$NAME"

    if [ -z "$ANALYSIS_NAME"  ]; then
        return 3
    fi

    RUN_BENCH_NAME="`"$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"
    RUN_BENCH_DIR="$BENCHMARKS_DIR/`DIR=TRUE "$BENCH_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"

    mkdir -p "$RUN_BENCH_DIR"
    if [ ! -d "$RUN_BENCH_DIR" ]; then
        echo "skipping $RUN_BENCH_DIR: directory does not exist" >&2
        return 3
    fi

    echo -e "${GREEN}running $RUN_BENCH_NAME  OPTIONS: $OPTIONS${NC}"

    while true; do
        # update TIMES and ACCEPTED FROM FILE
        R_LINE="`get_line "$LINE"`" || break
        TIMES_FIELDS="`echo "$R_LINE" | awk '{print $4}'`"

        set_option_by_position  "$TIMES_FIELDS" "TIMES" 0
        set_option  "$TIMES_FIELDS" "ACCEPTED"

        if [ -z "$ACCEPTED" ]; then
            ACCEPTED=0
        fi

        REGEX="[0-9]+"
        if [[ ! "$TIMES" =~ $REGEX ]] || [ "$TIMES" -le 0 ]; then
           break
        fi
        update_suite_run "$LINE" "$((TIMES - 1))" "$((ACCEPTED + 1))"

        run_benchmark $NAME $INSTALL_VERSION $RUN_VERSION $ANALYSIS_NAME $OPTIONS
    done


    set_option "$OPTIONS" "CLEAN"
    if [ "$CLEAN" == "yes" ]; then
         echo -e "${RED}cleaning up run directory${NC}"
        "$SCRIPTS_DIR"/clean.sh --run "$NAME" "$INSTALL_VERSION" > "$VERBOSE_FILE"
    fi
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath "$SCRIPTS_DIR/../benchmarks/"`"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"
BENCH_DIR="$SCRIPTS_DIR/bench"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
BENCH_UTIL_DIR="$BENCH_DIR/util"
UTIL_DIR="$SCRIPTS_DIR/util"

source "$SCRIPTS_DIR/config.env"
source "$UTIL_DIR/common.sh"

SUITE_ORIGIN="$BENCHMARKS_DIR/benchmark-suite.cfg"

if [  "$1" == "-v" ]; then
	export VERBOSE_FILE=/dev/tty
fi

if [ ! -e "$SUITE_ORIGIN" ]; then
	echo "$SUITE_ORIGIN must be specified" >&2
	exit 1
fi

if [ "`cat "$SUITE_ORIGIN" | wc -l`" -eq 0 ]; then
	echo "$SUITE_ORIGIN empty" >&2
	exit 2
fi

SUITE=$(mktemp /tmp/benchmark-suite.editable-cfg.XXXXXX)
echo "# This is editable config:" >> "$SUITE"
echo "# You can append new benchmark runs to this file and edit TIMES column in active benchmark " >> "$SUITE"
echo >> "$SUITE"
cat "$SUITE_ORIGIN" >> "$SUITE"

LINE=1

while [ "$LINE" -le "`cat "$SUITE" | wc -l`" ]; do
    VAR="`get_line "$LINE"`"

    if [ $? -ne 0 ]; then
        LINE=$((LINE + 1))
        continue
    fi

    run_benchmark_times "$LINE" $VAR

    finish_suite_run "$LINE"

    LINE=$((LINE + 1))
done

rm -f "$SUITE"
