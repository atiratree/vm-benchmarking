#!/bin/bash
# common install file for all versions

set -eu

wait_for_condition(){
    OUT_FILE="$1"
    CONDITION="$2"

    while ! grep -q "WildFly Core.*$CONDITION" "$OUT_FILE"; do
        sleep 1
    done
    grep --color=never "WildFly Core.*$CONDITION" "$OUT_FILE"
}

stop_server(){
    SERVER_PID="$1"
    SERVER_OUT="$2"
    echo "terminating server: ..."
    pkill -SIGTERM --parent "$SERVER_PID"
    kill -SIGTERM "$SERVER_PID"

    wait "$SERVER_PID"
    wait_for_condition "$SERVER_OUT" "stopped"
}

# install
yum -y install mariadb-server git

yum clean all
rm -rf /var/cache/yum

# initialize mariadb
systemctl enable --now  mariadb

mysql <<< "create database tradedb; \
    grant all on tradedb.* to daytrader@'localhost' identified by 'daytrader'; \
    grant all on tradedb.* to daytrader@'%' identified by 'daytrader';"

WILDFLY_LOCATION="`realpath wildfly-12.0.0.Final/build/target/wildfly-12.0.0.Final`"

MARIA_DB_LIB_LOCATION="$WILDFLY_LOCATION/modules/org/mariadb/jdbc/main"
mkdir -p "$MARIA_DB_LIB_LOCATION"

wget --directory-prefix="$MARIA_DB_LIB_LOCATION" https://downloads.mariadb.com/Connectors/java/connector-java-2.2.3/mariadb-java-client-2.2.3.jar
mv "/tmp/dependencies/module.xml" "$MARIA_DB_LIB_LOCATION"
mv -f "/tmp/dependencies/standalone-full.xml" "$WILDFLY_LOCATION/standalone/configuration"

git clone https://github.com/jamesfalkner/jboss-daytrader.git
cd jboss-daytrader/

mvn install
cd
cp "jboss-daytrader/javaee6/assemblies/daytrader-ear/target/daytrader-ear-3.0-SNAPSHOT.ear" "$WILDFLY_LOCATION/standalone/deployments/"
rm -rf jboss-daytrader

sed -ire  "s/Xms\S*/Xms$JAVA_MIN_MEM/g; \
    s/Xmx\S*/Xmx$JAVA_MAX_MEM/g; \
    s/XX:MetaspaceSize=\S*/XX:MetaspaceSize=$JAVA_MIN_METASPACE_MEM/g; \
    s/\-XX:MaxMetaspaceSize=\S*//g;" "$WILDFLY_LOCATION/bin/standalone.conf"

set +e # killing servers

SERVER_OUT=$(mktemp)
"$WILDFLY_LOCATION/bin/standalone.sh" -c standalone-full.xml &> "$SERVER_OUT" &
SERVER_PID=$!
wait_for_condition "$SERVER_OUT" "started"

echo "buildDBTables..."
curl "http://localhost:8080/config?action=buildDBTables"
stop_server "$SERVER_PID" "$SERVER_OUT"

# restart server to trigger db table changes

"$WILDFLY_LOCATION/bin/standalone.sh" -c standalone-full.xml &> "$SERVER_OUT" &
SERVER_PID=$!
wait_for_condition "$SERVER_OUT" "started"


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

echo "buildDB..."
curl "http://localhost:8080/config?action=buildDB"

stop_server "$SERVER_PID" "$SERVER_OUT"
rm -f "$SERVER_OUT"

firewall-cmd --zone=public --add-port=8080/tcp --permanent
# systemctl restart firewalld.service


echo "done"
