#!/bin/bash

UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$UTIL_DIR/../../config.env"

BASE_VM="$1"
NEW_VM="$2"

"$UTIL_DIR"/get-disk-filename.sh "$BASE_VM"  | sed  "s/$BASE_VM/$NEW_VM/"
