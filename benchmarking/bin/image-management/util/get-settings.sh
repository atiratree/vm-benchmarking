#!/bin/bash

prepend_to_script(){
    SCRIPT="$1"
    SETTINGS="$2/settings.env"
    if [ -e "$SETTINGS" ]; then
        sed -e "/#!\/bin\/bash/r$SETTINGS" -i "$SCRIPT"
	fi
}

IMAGE_UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UTIL_DIR="`realpath $IMAGE_UTIL_DIR/../../util`"
source "$UTIL_DIR/common.sh"
source "$IMAGE_UTIL_DIR/../../config.env"
BENCHMARKS_DIR="`realpath $IMAGE_UTIL_DIR/../../../benchmarks`"


SCRIPT_FILE="${SCRIPT_FILE:-}"
POST_SCRIPT_FILE="${POST_SCRIPT_FILE:-}"
LEAVE_COMMENTS="${LEAVE_COMMENTS:-}"

NAME="$1"
INSTALL_VERSION="$2"
RUN_VERSION="$3"

assert_name "$NAME"

SCRIPT_WITH_ENV_FILE=$(mktemp /tmp/get-settings.XXXXXX)

if [ -e "$SCRIPT_FILE" ]; then
    cp "$SCRIPT_FILE" "$SCRIPT_WITH_ENV_FILE"
else
    echo "#!/bin/bash" > "$SCRIPT_WITH_ENV_FILE"
fi

if [ -n "$RUN_VERSION" ]; then
    PATH_PART="`DIR=TRUE "$IMAGE_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION" "$RUN_VERSION"`"
    prepend_to_script "$SCRIPT_WITH_ENV_FILE" "$BENCHMARKS_DIR/$PATH_PART"
fi

if [ -n "$INSTALL_VERSION" ]; then
    PATH_PART="`DIR=TRUE "$IMAGE_UTIL_DIR/get-name.sh" "$NAME" "$INSTALL_VERSION"`"
    prepend_to_script "$SCRIPT_WITH_ENV_FILE" "$BENCHMARKS_DIR/$PATH_PART"
fi

PATH_PART="`DIR=TRUE "$IMAGE_UTIL_DIR/get-name.sh" "$NAME"`"
prepend_to_script "$SCRIPT_WITH_ENV_FILE" "$BENCHMARKS_DIR/$PATH_PART"

if [ -e "$POST_SCRIPT_FILE" ]; then
    cat "$POST_SCRIPT_FILE" >> "$SCRIPT_WITH_ENV_FILE"
fi

if [ -z "$LEAVE_COMMENTS" ]; then
    sed -e '2,${/^#.*/d}; /^\s*$/d; 2,${s/^\s*#.*$//g};' "$SCRIPT_WITH_ENV_FILE"
else
    cat "$SCRIPT_WITH_ENV_FILE"
fi

rm -f "$SCRIPT_WITH_ENV_FILE"
