#!/bin/bash

if type sadf &> /dev/null; then
    sadf -g /tmp/sar-report -- -r -P ALL -u ALL -b > /tmp/sar-report.svg
else
    echo "sadf is not available" >&2
    exit 1
fi
