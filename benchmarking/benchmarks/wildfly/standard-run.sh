#!/bin/bash

set -eu

ulimit -n 8192
MAVEN_OPTS="-Xmx$JAVA_MAX_MEM""g"" -Xms$JAVA_MIN_MEM""g" ./wildfly-12.0.0.Final/integration-tests.sh install -DallTests
