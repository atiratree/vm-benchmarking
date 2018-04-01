#!/bin/bash

prependToScript(){
    SCRIPT="$1"
    SETTINGS="$2/settings.env"
    if [ -e "$SETTINGS" ]; then
        sed -e "/#!\/bin\/bash/r$SETTINGS" -i "$SCRIPT"
	fi
}

UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$UTIL_DIR/../../config.env"
BENCHMARKS_DIR="`realpath $UTIL_DIR/../../../benchmarks`"


SCRIPT_FILE="${SCRIPT_FILE:-}"
POST_SCRIPT_FILE="${POST_SCRIPT_FILE:-}"
LEAVE_COMMENTS="${LEAVE_COMMENTS:-}"

NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"


if [ -z "$NAME" ]; then
	echo "name must be specified" >&2
	exit 1
fi

SCRIPT_WITH_ENV_FILE=$(mktemp /tmp/get-settings.XXXXXX)

if [ -e "$SCRIPT_FILE" ]; then
    cp "$SCRIPT_FILE" "$SCRIPT_WITH_ENV_FILE"
else
    echo "#!/bin/bash" > "$SCRIPT_WITH_ENV_FILE"
fi

if [ -n "$RUN_VERSION" ]; then
    PATH_PART="`DIR=TRUE "$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"
    prependToScript "$SCRIPT_WITH_ENV_FILE" "$BENCHMARKS_DIR/$PATH_PART"
fi

if [ -n "$INSTALL_VERSION" ]; then
    PATH_PART="`DIR=TRUE "$UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"
    prependToScript "$SCRIPT_WITH_ENV_FILE" "$BENCHMARKS_DIR/$PATH_PART"
fi

PATH_PART="`DIR=TRUE "$UTIL_DIR/get-name.sh" "$NAME"`"
prependToScript "$SCRIPT_WITH_ENV_FILE" "$BENCHMARKS_DIR/$PATH_PART"

if [ -e "$POST_SCRIPT_FILE" ]; then
    cat "$POST_SCRIPT_FILE" >> "$SCRIPT_WITH_ENV_FILE"
fi

if [ -z "$LEAVE_COMMENTS" ]; then
    sed -e '2,${/^#.*/d}; /^\s*$/d; 2,${s/#.*$//g};' "$SCRIPT_WITH_ENV_FILE"
else
    cat "$SCRIPT_WITH_ENV_FILE"
fi

rm -f "$SCRIPT_WITH_ENV_FILE"
