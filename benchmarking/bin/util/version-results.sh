#!/bin/bash


SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath "$SCRIPTS_DIR/../../benchmarks/"`"
GENERATED_DIR="`realpath "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../generated"`"

BENCH_GIT_RESULTS="${BENCH_GIT_RESULTS:-/tmp/benchmark-run-results}"
BENCH_EDITABLE_CFG="$BENCH_GIT_RESULTS/benchmark-suite.editable-cfg"
BENCH_OUTPUT="$BENCH_GIT_RESULTS/benchmark-suite.output"
COMMIT_TIME="$BENCH_GIT_RESULTS/time"

INIT_GIT_SCRIPT="$GENERATED_DIR/init-git.sh"

MESSAGE="$1"
FORCE_REMOVE="${FORCE_REMOVE:-}"

if [ -z "$MESSAGE" ]; then
    echo "message must be specified" >&2
    exit 1
fi

if [ -d "$BENCH_GIT_RESULTS" ]; then
    pushd "$BENCH_GIT_RESULTS"
fi

if [ ! -d "$BENCH_GIT_RESULTS/.git" ] || ! git status &> /dev/null; then
    if [ -x "$INIT_GIT_SCRIPT" ]; then
        "$INIT_GIT_SCRIPT"
        if [ ! -d "$BENCH_GIT_RESULTS/.git" ] || ! git status &> /dev/null; then
            echo "$INIT_GIT_SCRIPT failed to produce valid $BENCH_GIT_RESULTS" >&2
            exit 2
        fi
        pushd "$BENCH_GIT_RESULTS"
    else
        echo "$BENCH_GIT_RESULTS must be initialized git directory (hint: use init-git.sh in /tmp for that)" >&2
        exit 2
    fi
fi
popd

copy_first_file_starts(){
    for file in "$1"*; do
        cp "$file" "$2" 2> /dev/null
        break
    done
}

copy_status(){
    copy_first_file_starts "/tmp/benchmark-suite.editable-cfg." "$BENCH_EDITABLE_CFG"
    copy_first_file_starts "/tmp/benchmark-suite.out." "$BENCH_OUTPUT"
}

cd "$BENCHMARKS_DIR"

if [ -z "$FORCE_REMOVE" ]; then
    find . -regex ".*analysis" -exec cp --parents -r {} "$BENCH_GIT_RESULTS" \;
    cd "$BENCH_GIT_RESULTS"
else
    cd "$BENCH_GIT_RESULTS"
    git rm -r '*'
fi

copy_status
date > "$COMMIT_TIME"
sync
git add -A

LAST_MESSAGE="`git log --pretty=oneline  --pretty=format:'%s' | head -1`"

if [ "$LAST_MESSAGE" == "$MESSAGE" ];then
    git commit --allow-empty --amend --no-edit
else
    git commit --allow-empty -m "$MESSAGE"
fi

git push -f origin master
