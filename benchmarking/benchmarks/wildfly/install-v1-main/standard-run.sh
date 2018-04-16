#!/bin/bash

set -eu

ulimit -n 8192
MAVEN_OPTS="-Xmx$JAVA_MAX_MEM -Xms$JAVA_MIN_MEM" ./wildfly-12.0.0.Final/integration-tests.sh install -DallTests
