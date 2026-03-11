#!/bin/bash
set -e

echo "Installing rapl-pl1-linear..."

install -m 755 rapl-pl1-linear.sh /usr/local/bin/rapl-pl1-linear.sh
install -m 644 rapl-pl1-linear.service /etc/systemd/system/rapl-pl1-linear.service

systemctl daemon-reload
systemctl enable --now rapl-pl1-linear

echo "Installation complete."
