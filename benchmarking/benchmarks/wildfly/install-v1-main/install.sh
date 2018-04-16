#!/bin/bash
# common install file for all versions

set -eu

# download test dependencies
./wildfly-12.0.0.Final/integration-tests.sh install -DallTests -DskipTests
