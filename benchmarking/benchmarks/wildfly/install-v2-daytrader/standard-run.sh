#!/bin/bash

set -eu

wait_for_condition(){
    OUT_FILE="$1"
    CONDITION="$2"

    while ! grep -q "WildFly Core.*$CONDITION" "$OUT_FILE"; do
        sleep 1
    done
    grep --color=never "WildFly Core.*$CONDITION" "$OUT_FILE"
}

echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
echo "$IPV4_TCP_FIN_TIMEOUT" > /proc/sys/net/ipv4/tcp_fin_timeout

WILDFLY_LOCATION="`realpath wildfly-12.0.0.Final/build/target/wildfly-12.0.0.Final`"
WILDFLY_OUT="/tmp/benchmark-output"
touch "$WILDFLY_OUT"
nohup "$WILDFLY_LOCATION/bin/standalone.sh" -c standalone-full.xml &> "$WILDFLY_OUT" &

wait_for_condition "$WILDFLY_OUT" "started"


echo "configuring DayTrader..."
curl -X POST "http://localhost:8080/config?action=updateConfig&\
RunTimeMode=1&\
JPALayer=1&\
OrderProcessingMode=0&\
WorkloadMix=1&\
WebInterface=1&\
MaxUsers=$USERS&\
MaxQuotes=$QUOTES&\
marketSummaryInterval=5&\
primIterations=1&\
EnablePublishQuotePriceChange=on&\
EnableLongRun=on"

echo "configured"
