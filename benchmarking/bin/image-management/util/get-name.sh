#!/bin/bash

UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$UTIL_DIR/../../config.env"

DIR="${DIR:-}"
NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"
ID="$4"

if [ -z "$NAME" ]; then
	echo "name must be specified" >&2
	exit 1
fi

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
