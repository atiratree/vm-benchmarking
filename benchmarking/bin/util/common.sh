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

set_option_by_position(){
    CM_OPTIONS="$1"
    CM_OPTION="$2"
    CM_OPTION_NUMBER="$3"

    CM_ARRAY=(${CM_OPTIONS//,/ })
    CM_OPT="${CM_ARRAY[$CM_OPTION_NUMBER]}"

    if [ -n "$CM_OPT" ]; then
        export "$CM_OPTION"="$CM_OPT"
    else
        unset "$CM_OPTION"
    fi
}

safe_remove(){
    SR_WHAT="$1"
    SR_FORCE="$2"

    echo -e -n "Are you sure you want to delete $SR_WHAT? (y/n): "
    if [ -z "$SR_FORCE" ]; then
        read -n 1 -r
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            echo -e ". skipping $SR_WHAT..."
            return 1
        fi
    else
         echo -e -n "y (forced)"
    fi
    echo
}

verbose_remove(){
    if [ -d "$1" ]; then
        echo "rm -rf $1"
        rm -rf "$1"
    fi
}

get_line(){
    G_VAR="`sed "s/^\s*//; $1""q; d" "$SUITE" 2> /dev/null`"

    if [ -z "$G_VAR" -o "${G_VAR:0:1}" == "#" ]; then
        return 1
    fi
    echo "$G_VAR"
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
