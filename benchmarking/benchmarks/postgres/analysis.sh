#!/bin/bash

GREEN='\033[0;32m'
NC='\033[0m' # No Color
VERBOSE_FILE="${VERBOSE_FILE:-/dev/null}"

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function log(){
	echo "$1" | tee "$VERBOSE_FILE" >> "$ANALYSIS"
}

INSTALL_VERSION="$1"
RUN_VERSION="$2"
ANALYSIS_NAME="$3"


BENCHMARKS_DIR="`realpath $SCRIPTS_DIR/install-v$INSTALL_VERSION`"
RESULT_DIR="$BENCHMARKS_DIR/run-v$RUN_VERSION/out"
if [ -z "$INSTALL_VERSION" ]; then
	echo "install version must be specified" >&2
	exit 1
fi

if [ -z "$RUN_VERSION" ]; then
	echo "run version must be specified" >&2
	exit 2
fi

if [ -z "$ANALYSIS_NAME" ]; then
	echo "analysis name must be specified" >&2
	exit 3
fi


ANALYSIS="$RESULT_DIR/$ANALYSIS_NAME"

echo "# transactions per second" | tee "$VERBOSE_FILE" > "$ANALYSIS"


echo -e "${GREEN}analyzing iv$INSTALL_VERSION-rv$RUN_VERSION into $ANALYSIS${NC}"

for OUT_DIR in  "$RESULT_DIR"/*/; do
	OUTPUT="$OUT_DIR/output"
	OUTPUT_RUN="$OUT_DIR/output-run"
	LIBVIRT_XML="$OUT_DIR/libvirt.xml"

	if [ ! -f "$OUTPUT" -o ! -f "$OUTPUT_RUN" -o ! -f "$OUTPUT_RUN" ]; then
		log "FAIL: not all expected files created"
		continue
	fi

	if grep -q -e "failed with return code" "$OUTPUT"; then
		log "FAIL: `cat $OUTPUT`"
		continue
	fi

	if ! grep -q -e "benchmark.*success" "$OUTPUT_RUN"; then
		log "FAIL: benchmark run not succesfull"
		continue
	fi

	TRANSACTIONS="`grep -oe "transactions actually processed: [0-9]*/" "$OUTPUT" | grep -o "[0-9]*"`"
	TRANSACTION_PER_SECOND=`grep -oe "tps = [0-9.]* (including connections establishing)" "$OUTPUT" | grep -o "[0-9.]*"`

	log "$TRANSACTION_PER_SECOND"
done
