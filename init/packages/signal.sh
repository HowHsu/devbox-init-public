#!/usr/bin/env bash
set -euo pipefail

if command -v signal-desktop &>/dev/null; then
    echo "    signal-desktop already installed, skipping"
    exit 0
fi
sudo mkdir -p /etc/apt/keyrings
proxychains4 curl -fsSL https://updates.signal.org/desktop/apt/keys.asc \
    | gpg --dearmor | sudo tee /etc/apt/keyrings/signal-desktop.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/signal-desktop.gpg] https://updates.signal.org/desktop/apt xenial main" \
    | sudo tee /etc/apt/sources.list.d/signal-desktop.list > /dev/null
sudo proxychains4 apt-get update -qq
sudo proxychains4 apt-get install -y signal-desktop
