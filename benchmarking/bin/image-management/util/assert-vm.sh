#!/bin/bash

IMAGE_UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="`realpath "$IMAGE_UTIL_DIR/../../util"`"
source "$UTIL_DIR/common.sh"

NAME="$1"

assert_name "$NAME"

if ! virsh list --all | awk  '{print $2}' | grep -q --line-regexp --fixed-strings "$NAME"; then
	echo "$LIBVIRT_DEFAULT_URI: $NAME is not a valid vm" >&2
	exit 2
fi
	
exit 0
