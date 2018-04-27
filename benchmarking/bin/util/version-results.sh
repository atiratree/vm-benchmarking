#!/bin/bash


SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath "$SCRIPTS_DIR/../../benchmarks/"`"

BENCH_GIT_RESULTS="${BENCH_GIT_RESULTS:-/tmp/benchmark-run-results}"
BENCH_EDITABLE_CFG="$BENCH_GIT_RESULTS/benchmark-suite.editable-cfg"
BENCH_OUTPUT="$BENCH_GIT_RESULTS/benchmark-suite.output"
COMMIT_TIME="$BENCH_GIT_RESULTS/time"

MESSAGE="$1"
FORCE_REMOVE="${FORCE_REMOVE:-}"

if [ -z "$MESSAGE" ]; then
    echo "message must be specified" >&2
    exit 1
fi

if [ ! -d "$BENCH_GIT_RESULTS/.git" ]; then
    echo "$BENCH_GIT_RESULTS must be initialized git directory" >&2
    exit 2
fi

cd "$BENCHMARKS_DIR"

if [ -z "$FORCE_REMOVE" ]; then
    find . -regex ".*analysis" -exec cp --parents -r {} "$BENCH_GIT_RESULTS" \;

    cp /tmp/benchmark-suite.editable-cfg.* "$BENCH_EDITABLE_CFG" 2> /dev/null
    cp /tmp/benchmark-suite.output "$BENCH_OUTPUT" 2> /dev/null

    cd "$BENCH_GIT_RESULTS"
    git add -A
else
    cd "$BENCH_GIT_RESULTS"
    git rm -r '*'
fi

date > "$COMMIT_TIME"
git add "$COMMIT_TIME"

LAST_MESSAGE="`git log --pretty=oneline  --pretty=format:'%s' | head -1`"

if [ "$LAST_MESSAGE" == "$MESSAGE" ];then
    git commit --allow-empty --amend --no-edit
else
    git commit --allow-empty -m "$MESSAGE"
fi

git push -f origin master
