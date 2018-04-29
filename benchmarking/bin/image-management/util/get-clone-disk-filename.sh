#!/bin/bash

IMAGE_UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="`realpath "$IMAGE_UTIL_DIR/../../util"`"
source "$UTIL_DIR/common.sh"

BASE_VM="$1"
NEW_VM="$2"

"$IMAGE_UTIL_DIR"/get-disk-filename.sh "$BASE_VM"  | sed  "s/$BASE_VM/$NEW_VM/"
