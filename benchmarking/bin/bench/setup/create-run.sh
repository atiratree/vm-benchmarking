#!/bin/bash


SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="`realpath "$SCRIPTS_DIR/../.."`"
BENCHMARKS_DIR="`realpath "$BIN_DIR/../benchmarks/"`"
IMAGE_MANAGEMENT_DIR="$BIN_DIR/image-management"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
UTIL_DIR="$BIN_DIR/util"
source "$UTIL_DIR/common.sh"

BASE_RUN_NAME="${BASE_RUN_NAME:-1-baseline}"
NEW_RUN_NAME="$1"
LIBVIRT_XML_EXAMPLE="$2"

set -eu

if [ -z "$NEW_RUN_NAME" ]; then
    echo "new run name must be specified" >&2
    exit 1
fi

if [ -z "$LIBVIRT_XML_EXAMPLE" ]; then
    LIBVIRT_XML_EXAMPLE="$GENERATED_DIR/libvirt.xml.example.$NEW_RUN_NAME"
fi

if [ ! -f "$LIBVIRT_XML_EXAMPLE" ]; then
    echo "source libvirt.xml.example $LIBVIRT_XML_EXAMPLE does not exist" >&2
    exit 1
fi

supports_xml(){
    echo "$1" | grep -qvf "$SCRIPTS_DIR/.run_libvirtxml_ignore"
}

copy(){
    if [ -e "$1" ] && [ ! -e "$2" ]; then
        echo -e "${GREEN}$1${NC}"
        echo "coppied as $2"
        cp -d "$1" "$2"
    fi
}

create(){
    if [ ! -e "$1" ]; then
        echo "created $1"
        touch "$1"
    fi
}

create_runs(){
    BENCHMARK_DIR="$1"

    NAME="`basename "$BENCHMARK_DIR"`"

    for INSTALL_DIR in "$BENCHMARK_DIR/"install-v*; do
        if [ ! -d "$INSTALL_DIR" ]; then
            continue
        fi

        RUN_DIR="$INSTALL_DIR/run-v$BASE_RUN_NAME"
        NEW_RUN_DIR="$INSTALL_DIR/run-v$NEW_RUN_NAME"

        RUN="$RUN_DIR/run.sh"
        NEW_RUN="$NEW_RUN_DIR/run.sh"

        NEW_LIBVIRT_XML_EXAMPLE="$NEW_RUN_DIR/libvirt.xml.example"

        SETTINGS_EXAMPLE="$RUN_DIR/settings.env.example"
        NEW_SETTINGS_EXAMPLE="$NEW_RUN_DIR/settings.env.example"

        if [ ! -d "$RUN_DIR" ]; then
            echo -e "${RED}skipping $INSTALL_DIR: run-v$BASE_RUN_NAME does not exist${NC}"
            continue
        fi

        if [ ! -f "$RUN" ]; then
            echo -e "${RED}skipping $RUN ... does not exist${NC}"
            continue
        fi

        mkdir -p "$NEW_RUN_DIR"

        copy "$RUN" "$NEW_RUN"
        copy "$SETTINGS_EXAMPLE" "$NEW_SETTINGS_EXAMPLE"

        if supports_xml "$NAME"; then
            copy "$LIBVIRT_XML_EXAMPLE" "$NEW_LIBVIRT_XML_EXAMPLE"
            create "$NEW_LIBVIRT_XML_EXAMPLE"  # if copy failed
        fi
    done
}


for BENCHMARK_DIR in "$BENCHMARKS_DIR/"*; do
    if [ -d "$BENCHMARK_DIR" ]; then
        create_runs "$BENCHMARK_DIR"
    fi
done
