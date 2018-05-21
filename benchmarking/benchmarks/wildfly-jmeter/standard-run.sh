#!/bin/bash

set -eu

OUTPUT="/tmp/jmeter-output"

echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
echo "$IPV4_TCP_FIN_TIMEOUT" > /proc/sys/net/ipv4/tcp_fin_timeout

./apache-jmeter-$APACHE_JMETER_VERSION/bin/jmeter -nongui \
  --testfile "daytrader.jmx" \
  -JHOST="$IP" \
  -JPORT="$JPORT" \
  -JDURATION="$JDURATION" \
  -JTOPUID="$JTOPUID" \
  -JSTOCKS="$JSTOCKS" \
  -JTHREADS="$JTHREADS" \
  -l "$OUTPUT"

cat "$OUTPUT"
rm -f "$OUTPUT"
