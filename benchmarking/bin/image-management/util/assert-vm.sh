#!/bin/bash

UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$UTIL_DIR/../../config.env"

NAME="$1"

if [ -z "$NAME" ]; then
	echo "name of vm must be specified" >&2
	exit 1
fi

if ! virsh list --all | awk  '{print $2}' | grep -q --line-regexp --fixed-strings "$NAME"; then
	echo "$LIBVIRT_DEFAULT_URI: $NAME is not a valid vm" >&2
	exit 2
fi
	
exit 0
