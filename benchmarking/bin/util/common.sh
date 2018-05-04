#!/bin/bash

export GREEN='\033[0;32m'
export RED='\033[0;31m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

GENERATED_DIR="`realpath "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../generated"`"
GLOBAL_CONFIG="`realpath "$GENERATED_DIR/../../benchmarks/global-config.env"`"

export ID_RSA="$GENERATED_DIR/id_rsa"

export SYSTAT_FILENAME="sysstat-v11.7.2.tar.gz"

export IP_4_REGEX='[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'


if [ -f "$GLOBAL_CONFIG" ]; then
    for CONF in `sed -e "/^#.*/d; /^\s*$/d; /^\s*#.*$/d; s/[\"\']*//g" "$GLOBAL_CONFIG"`; do
        CONFIG_VARIABLE="`echo "$CONF" | sed 's/=.*//'`"
        if ! env | grep -q "^$CONFIG_VARIABLE="; then
            export $CONF
        fi
    done
fi

if [ -n "$LIBVIRT_URI" ]; then
    export LIBVIRT_DEFAULT_URI="$LIBVIRT_URI"
fi

# common functions

export SSH="ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null"  -i "$ID_RSA""
export SCP="scp -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null"  -i "$ID_RSA""

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
    if [ -e "$1" ]; then
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
