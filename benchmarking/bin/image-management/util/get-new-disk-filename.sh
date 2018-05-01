#!/bin/bash

IMAGE_UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="`realpath "$IMAGE_UTIL_DIR/../../util"`"
source "$UTIL_DIR/common.sh"

POOL_LOCATION="${POOL_LOCATION:-}"
BASE_VM="${BASE_VM:-}"

NEW_VM="$1"

if [ -z "$NEW_VM" ]; then
    echo "NEW_VM must be specified" >&2
    exit 1
fi

if [ -z "$IMAGE_FORMAT" ]; then
    echo "IMAGE_FORMAT must be specified" >&2
    exit 2
fi

if [ -n "$POOL_LOCATION" ]; then
    echo "`echo "$POOL_LOCATION" | sed 's/\/*$//'`/$NEW_VM.$IMAGE_FORMAT"
elif [ -n "$BASE_VM" ]; then
    "$IMAGE_UTIL_DIR"/get-disk-filename.sh "$BASE_VM"  | sed  "s/.[a-zA-Z0-9]+$/.$IMAGE_FORMAT/; s/$BASE_VM/$NEW_VM/"
else
    echo "POOL_LOCATION or BASE_VM must be specified" >&2
    exit 3
fi
