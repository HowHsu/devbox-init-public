#!/usr/bin/env bash
set -euo pipefail

if command -v claude &>/dev/null; then
    echo "    claude already installed, skipping"
    exit 0
fi
if ! curl -fsSL --connect-timeout 10 https://claude.ai/install.sh | bash; then
    echo "    Direct download failed, retrying with proxy..."
    curl -fsSL --proxy socks5h://127.0.0.1:1081 https://claude.ai/install.sh \
        | ALL_PROXY=socks5h://127.0.0.1:1081 bash
fi
