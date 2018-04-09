#!/bin/bash

set -eu

run(){
    RUN="$1"
    sync
    echo "running $RUN"
    "./$RUN"
}

cd NPB3.3.1/NPB3.3-OMP/bin/
export OMP_NUM_THREADS="$THREADS"
# touch timer.flag

DC_REGEX="dc\..\.x"
RUN_DC=""

for BENCHMARK in `ls`; do
    if [ "$BENCHMARK" == "timer.flag" ]; then
        continue
    fi

    if [[ "$BENCHMARK" =~ $DC_REGEX ]]; then
        RUN_DC="${BASH_REMATCH[0]}"
        continue
    fi

    run "$BENCHMARK"
done

# run disk intensive DC benchmark last
if [ -n "$RUN_DC" ]; then
    run "$RUN_DC"
fi
