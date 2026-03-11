#!/bin/bash
set -e

REPO="https://raw.githubusercontent.com/chackl1990/proxmox-intel-n150-pl1/main"

echo "Installing rapl-pl1-linear..."

echo "Downloading controller script..."
wget -qO /usr/local/bin/rapl-pl1-linear.sh "$REPO/rapl-pl1-linear.sh"

echo "Downloading systemd service..."
wget -qO /etc/systemd/system/rapl-pl1-linear.service "$REPO/rapl-pl1-linear.service"

chmod +x /usr/local/bin/rapl-pl1-linear.sh

echo "Reloading systemd..."
systemctl daemon-reload

echo "Enabling service..."
systemctl enable --now rapl-pl1-linear.service

echo "Installation complete."
