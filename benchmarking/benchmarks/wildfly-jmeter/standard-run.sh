#!/bin/bash

set -eu

./apache-jmeter-4.0/bin/jmeter -nongui \
  --testfile "daytrader.jmx" \
  -JHOST="$IP" \
  -JPORT="$JPORT" \
  -JDURATION="$JDURATION" \
  -JTOPUID="$JTOPUID" \
  -JSTOCKS="$JSTOCKS" \
  -JTHREADS="$JTHREADS"
