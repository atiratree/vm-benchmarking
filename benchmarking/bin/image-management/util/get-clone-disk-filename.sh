#!/bin/bash

IMAGE_UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$IMAGE_UTIL_DIR/../../config.env"

BASE_VM="$1"
NEW_VM="$2"

"$IMAGE_UTIL_DIR"/get-disk-filename.sh "$BASE_VM"  | sed  "s/$BASE_VM/$NEW_VM/"
