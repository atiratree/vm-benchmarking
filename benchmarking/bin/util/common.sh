#!/bin/bash

# common functions

set_option(){
    CM_OPTIONS="$1"
    CM_OPTION="$2"
    CM_REGEX="$CM_OPTION=[^,]*"
    if [[ "$CM_OPTIONS" =~ $CM_REGEX ]]; then
        CM_OPT="${BASH_REMATCH[0]}"
        export "$CM_OPT"
    else
        unset "$CM_OPTION"
    fi
}

assert_name(){
    if [ -z "$1" ]; then
        echo "name must be specified" >&2
        exit 1
    fi
}

assert_install(){
    assert_name "$1"
    if [ -z "$2" ]; then
        echo "install version must be specified" >&2
        exit 2
    fi
}

assert_run(){
    assert_install "$1"  "$2"
    if [ -z "$3" ]; then
        echo "run version must be specified" >&2
        exit 3
    fi
}
