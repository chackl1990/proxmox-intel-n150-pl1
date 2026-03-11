#!/bin/bash
set -e

echo "Removing rapl-pl1-linear..."

systemctl stop rapl-pl1-linear || true
systemctl disable rapl-pl1-linear || true

rm -f /etc/systemd/system/rapl-pl1-linear.service
rm -f /usr/local/bin/rapl-pl1-linear.sh

systemctl daemon-reload

echo "Removed."
