#!/usr/bin/env bash
set -euo pipefail

if command -v cursor &>/dev/null; then
    echo "    cursor already installed, skipping"
    exit 0
fi
sudo mkdir -p /etc/apt/keyrings
proxychains4 curl -fsSL https://downloads.cursor.com/aptrepo/cursor-signing-key.asc \
    | gpg --dearmor | sudo tee /etc/apt/keyrings/cursor.gpg > /dev/null
echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/cursor.gpg] https://downloads.cursor.com/aptrepo stable main" \
    | sudo tee /etc/apt/sources.list.d/cursor.list > /dev/null
sudo proxychains4 apt-get update -qq
sudo proxychains4 apt-get install -y cursor
