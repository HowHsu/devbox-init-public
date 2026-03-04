#!/usr/bin/env bash
set -euo pipefail

if command -v gh &>/dev/null; then
    echo "    gh already installed, skipping"
    exit 0
fi
sudo mkdir -p -m 755 /etc/apt/keyrings
KEYRING_TMP=$(mktemp)
proxychains wget -qO "$KEYRING_TMP" https://cli.github.com/packages/githubcli-archive-keyring.gpg
# Validate: GPG binary keyring starts with 0x99 or 0x98 (packet header), not HTML
if ! xxd -l 1 "$KEYRING_TMP" 2>/dev/null | grep -qE '(98|99)'; then
    echo "ERROR: Downloaded keyring is not a valid GPG file (got HTML error page?)"
    cat "$KEYRING_TMP" | head -3
    rm -f "$KEYRING_TMP"
    exit 1
fi
sudo cp "$KEYRING_TMP" /etc/apt/keyrings/githubcli-archive-keyring.gpg
rm -f "$KEYRING_TMP"
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update -qq -o Acquire::https::Proxy=socks5h://127.0.0.1:1081
sudo apt-get install -y -qq gh -o Acquire::https::Proxy=socks5h://127.0.0.1:1081
