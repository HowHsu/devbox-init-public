#!/usr/bin/env bash
set -euo pipefail

if command -v hexchat &>/dev/null; then
    echo "    hexchat already installed, skipping"
    exit 0
fi
sudo apt-get install -y -qq hexchat
