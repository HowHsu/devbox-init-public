#!/usr/bin/env bash
set -euo pipefail

if command -v claude &>/dev/null; then
    echo "    claude already installed, skipping"
    exit 0
fi
proxychains4 curl -fsSL https://cli.claude.ai/install.sh | proxychains4 bash
