#!/bin/bash

remove(){
    if [ -d "$1" ]; then
        echo "rm -rf $1"
        rm -rf "$1"
    fi
}

removeBenchmark(){
    BENCHMARK_DIR="$1"
    NAME="`basename "$BENCHMARK_DIR"`"
    for INSTALL_DIR in `ls -d "$BENCHMARK_DIR"install-v*/`; do
        if [  "$SELECT" == "--all" -o "$SELECT" == "--install" ]; then
           remove "$INSTALL_DIR""out"
        fi

        if [  "$SELECT" == "--all" -o "$SELECT" == "--vms" ]; then
           INSTALL_VERSION="`basename "$INSTALL_DIR" | cut -c 10-`"
           VM="`"$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"
           "$IMAGE_MANAGEMENT_DIR"/delete-vm.sh "$VM" > /dev/null 2>&1 && echo "removed $VM"
        fi

        for RUN_DIR in `ls -d "$INSTALL_DIR"run-v*/`; do
            if [  "$SELECT" == "--all" -o "$SELECT" == "--run" ]; then
                remove "$RUN_DIR""out"
            fi
            if [  "$SELECT" == "--all" -o "$SELECT" == "--analysis" ]; then
                remove "$RUN_DIR""analysis"
            fi
        done
    done
}

safeRemove(){
    read -p "Are you sure you want to delete $1? (y/n): " -n 1 -r
    echo
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "aborted"
        exit 0
    fi
}

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/../benchmarks/`"
IMAGE_MANAGEMENT_DIR="$SCRIPTS_DIR/image-management"
UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"

SELECT="$1"
NAME="$2"

if [  "$SELECT" == "--all" ]; then
   safeRemove "Analysis and Installed Benchmark Images"
elif [ "$SELECT" == "--vms" ]; then
   safeRemove "Installed Benchmark Images"
elif [ "$SELECT" == "--analysis" ]; then
   safeRemove "Analysis"
elif [  "$SELECT" != "--install" -a "$SELECT" != "--run" ]; then
    echo "clean.sh OPTION [NAME] "
    echo "  --all"
    echo "  --vms"
    echo "  --analysis"
    echo "  --install"
    echo "  --run"
    exit 1
fi



if [ -z "$NAME" ]; then
    for BENCHMARK_DIR in `ls -d "$BENCHMARKS_DIR"/*/`; do
        removeBenchmark "$BENCHMARK_DIR"
    done
else
    removeBenchmark "$BENCHMARKS_DIR/$NAME/"
fi
