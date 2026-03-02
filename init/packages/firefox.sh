#!/usr/bin/env bash
set -euo pipefail

if command -v firefox &>/dev/null; then
    echo "    firefox already installed, skipping"
    exit 0
fi
sudo mkdir -p /etc/apt/keyrings
proxychains4 wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg \
    | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
sudo tee /etc/apt/preferences.d/mozilla > /dev/null <<'PINEOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
PINEOF
sudo proxychains4 apt-get update -qq
sudo proxychains4 apt-get install -y firefox
