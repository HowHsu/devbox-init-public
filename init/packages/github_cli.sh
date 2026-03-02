#!/usr/bin/env bash
set -euo pipefail

if command -v gh &>/dev/null; then
    echo "    gh already installed, skipping"
    exit 0
fi
sudo mkdir -p /usr/share/keyrings
proxychains4 wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo proxychains4 apt-get update -qq
sudo proxychains4 apt-get install -y -qq gh
