#!/usr/bin/env bash
set -euo pipefail

if command -v claude &>/dev/null; then
    echo "    claude already installed, skipping"
    exit 0
fi
if ! curl -fsSL --connect-timeout 10 https://claude.ai/install.sh | bash; then
    echo "    Direct download failed, retrying with proxy..."
    proxychains4 bash -c "curl -fsSL https://claude.ai/install.sh | bash"
fi
