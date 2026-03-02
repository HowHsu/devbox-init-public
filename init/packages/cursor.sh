#!/usr/bin/env bash
set -euo pipefail

if command -v cursor &>/dev/null; then
    echo "    cursor already installed, skipping"
    exit 0
fi
sudo mkdir -p /etc/apt/keyrings

# Add Cursor's GPG key
proxychains curl -fsSL https://downloads.cursor.com/keys/anysphere.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/cursor.gpg > /dev/null

# Add the Cursor repository
echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/cursor.gpg] https://downloads.cursor.com/aptrepo stable main" | sudo tee /etc/apt/sources.list.d/cursor.list > /dev/null

sudo apt-get update -qq -o Acquire::https::Proxy=socks5h://127.0.0.1:1081
sudo apt-get install -y cursor -o Acquire::https::Proxy=socks5h://127.0.0.1:1081
