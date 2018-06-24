#!/bin/bash

UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$UTIL_DIR/common.sh"

POSTFIX="postfix.service"

BODY="$1"
SUBJECT="$2"

if [ -z "$NOTIFICATION_EMAIL_ADDRESS" ]; then
    echo "no NOTIFICATION_EMAIL_ADDRESS was specified" >&2
    exit 1
fi

if [ -z "$BODY" ]; then
    echo "body must be specified" >&2
    exit 2
fi

if ! systemctl is-active "$POSTFIX" -q; then
    if ! systemctl start "$POSTFIX" -q; then
        echo "could not start $POSTFIX"
        exit 3
    fi
fi

echo "$BODY" | mail -s "$SUBJECT" "$NOTIFICATION_EMAIL_ADDRESS"
