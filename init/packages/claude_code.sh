#!/usr/bin/env bash
set -euo pipefail

if command -v claude &>/dev/null; then
    echo "    claude already installed, skipping"
    exit 0
fi
curl -fsSL --proxy socks5h://127.0.0.1:1081 https://cli.claude.ai/install.sh \
    | ALL_PROXY=socks5h://127.0.0.1:1081 bash
