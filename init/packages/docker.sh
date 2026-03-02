#!/usr/bin/env bash
set -euo pipefail

REAL_USER="${SUDO_USER:-$USER}"
if id -nG "$REAL_USER" 2>/dev/null | grep -qw docker; then
    echo "    $REAL_USER already in docker group, skipping"
    exit 0
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$REAL_USER"
