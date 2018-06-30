#!/bin/bash

show_help(){
    echo "create-run.sh RUN_NAME [LIBVIRT_XML_EXAMPLE]"
    echo
    echo "  -h, --help"
}


SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="`realpath "$SCRIPTS_DIR/../.."`"
BENCHMARKS_DIR="`realpath "$BIN_DIR/../benchmarks/"`"
SUITE_EXAMPLE="`realpath "$BENCHMARKS_DIR/benchmark-suite.cfg.example"`"
IMAGE_MANAGEMENT_DIR="$BIN_DIR/image-management"
IMAGE_UTIL_DIR="$IMAGE_MANAGEMENT_DIR/util"
UTIL_DIR="$BIN_DIR/util"
source "$UTIL_DIR/common.sh"

run_exists(){
    grep "$1" -q "$SUITE_EXAMPLE"
}

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
        show_help
        exit 0
        ;;
        *)
        POSITIONAL_ARGS+=("$1") # save it in an array for later
        shift
        ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

BASE_RUN_NAME="${BASE_RUN_NAME:-1-baseline}"
NAME_MAX_LENGTH=35

NEW_RUN_NAME="$1"
LIBVIRT_XML_EXAMPLE="$2"

set -eu

if [ -z "$NEW_RUN_NAME" ]; then
    echo "run name must be specified" >&2
    exit 1
fi

if [ "`echo "$NEW_RUN_NAME" | wc -c`" -gt "$NAME_MAX_LENGTH" ]; then
    echo "run name should not exceed $NAME_MAX_LENGTH characters" >&2
    exit 2
fi

if echo "$NEW_RUN_NAME" | grep "\s" -q; then
    echo "run name should not have whitespace characters" >&2
    exit 3
fi

if run_exists "$NEW_RUN_NAME"; then
    echo "$NEW_RUN_NAME already exists!"
    exit 4
fi

if [ -z "$LIBVIRT_XML_EXAMPLE" ]; then
    LIBVIRT_XML_EXAMPLE="$GENERATED_DIR/libvirt.xml.example.$NEW_RUN_NAME"
fi

if [ ! -f "$LIBVIRT_XML_EXAMPLE" ]; then
    echo "source libvirt.xml.example $LIBVIRT_XML_EXAMPLE does not exist" >&2
    exit 5
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

echo
echo -n "updating $SUITE_EXAMPLE ... "
BASE_RUN="1-baseline"
echo >> "$SUITE_EXAMPLE"
PADDED_LENGTH=$((NAME_MAX_LENGTH + 1))
NEW_RUN_NAME_PADDED="`printf "%-$PADDED_LENGTH""s" "$NEW_RUN_NAME"`"
grep "$BASE_RUN" "$SUITE_EXAMPLE" | sed -E "s/$BASE_RUN\s+([0-9]+)/$NEW_RUN_NAME_PADDED\1/g; s/$BASE_RUN/$NEW_RUN_NAME/g" >> "$SUITE_EXAMPLE"

if run_exists "$NEW_RUN_NAME"; then
    echo -e "${GREEN}DONE${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi
