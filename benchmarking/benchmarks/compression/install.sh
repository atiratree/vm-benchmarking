#!/bin/bash
# common install file for all versions

set -eu

# download EPEL repository for postgres dependencies
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# add EPEL repos
yum -y install epel-release-latest-7.noarch.rpm

yum -y install transmission-cli pbzip2 pigz

yum clean all
rm -rf /var/cache/yum epel-release-latest-7.noarch.rpm

TMP_FILE=$(mktemp)
chmod +x "$TMP_FILE"
echo "pkill -f transmission-cli" > "$TMP_FILE"

# transmission will be killed
set +e

transmission-cli -f "$TMP_FILE" -w . "$DATA_TORRENT"
rm -f "$TMP_FILE"

set -e

echo "extracting data"
pbzip2 -d "$DATA_FILENAME_COMPRESSED"

echo "done"
