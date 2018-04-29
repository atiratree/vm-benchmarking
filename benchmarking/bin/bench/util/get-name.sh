#!/bin/bash

BENCH_UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="`realpath "$BENCH_UTIL_DIR/../../util"`"
source "$UTIL_DIR/common.sh"

DIR="${DIR:-}"
NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"
ID="$4"

assert_name "$NAME"

if [ -z "$DIR" ]; then
	DISTRO_LEN=${#DISTRO}
	if [ ${NAME:0:$DISTRO_LEN} != "$DISTRO" ]; then
		NAME="$DISTRO""-$NAME"
	fi	
	if [ -n "$INSTALL_VERSION" ]; then
		NAME="$NAME""-iv$INSTALL_VERSION"
	fi
	if [ -n "$RUN_VERSION" ]; then
		NAME="$NAME""-rv$RUN_VERSION"
	fi
	if [ -n "$ID" ]; then
		NAME="$NAME""-$ID"
	fi
else
	if [ -n "$INSTALL_VERSION" ]; then
		NAME="$NAME""/install-v$INSTALL_VERSION"
	fi	
	if [ -n "$RUN_VERSION" ]; then
		NAME="$NAME""/run-v$RUN_VERSION"
	fi
	if [ -n "$ID" ]; then
		NAME="$NAME""/out/$ID"
	fi
fi

echo "$NAME"
