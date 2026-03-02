#!/usr/bin/env bash
set -euo pipefail

if id -nG | grep -qw docker; then
    echo "    user already in docker group, skipping"
    exit 0
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
