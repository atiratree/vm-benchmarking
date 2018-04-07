#!/bin/bash

if type sar &> /dev/null; then
    sar -o /tmp/sar-report -r -P ALL -u ALL  -b  1 > /dev/null
else
    echo "sar is not available" >&2
    exit 1
fi
