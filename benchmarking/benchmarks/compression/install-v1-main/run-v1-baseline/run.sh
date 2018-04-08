#!/bin/bash

set -eu

echo "compressing "$DATA_FILENAME" to bz2"
time -p pbzip2 -zq "$DATA_FILENAME"
sync

echo "decompressing $DATA_FILENAME_COMPRESSED"
time -p pbzip2 -dq "$DATA_FILENAME_COMPRESSED"
sync

echo "compressing "$DATA_FILENAME" to gz"
time -p pigz "$DATA_FILENAME"
sync

DATA_FILENAME_COMPRESSED="$DATA_FILENAME"".gz"

echo "decompressing $DATA_FILENAME_COMPRESSED"
time -p pigz -d "$DATA_FILENAME_COMPRESSED"
sleep 1

echo "done"
