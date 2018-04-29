#!/bin/bash

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_UTIL_DIR="$SCRIPTS_DIR/util"
UTIL_DIR="`realpath "$SCRIPTS_DIR/../util"`"
source "$UTIL_DIR/common.sh"

NAME="$1"
DISK_FILENAME="$2"


if [ -z "$NAME" ]; then
	echo "name of vm must be specified" >&2
	exit 1
fi

echo -e "${GREEN}$LIBVIRT_DEFAULT_URI: deleting $NAME${NC}"

if [ -z "$DISK_FILENAME" ]; then
    DISK_FILENAME="`"$IMAGE_UTIL_DIR"/get-disk-filename.sh "$NAME"`"
fi

virsh destroy "$NAME" 2> /dev/null
virsh undefine "$NAME"
virsh vol-delete "$DISK_FILENAME"
