#!/usr/bin/env bash
set -euo pipefail

if command -v google-chrome &>/dev/null; then
    echo "    google-chrome already installed, skipping"
    exit 0
fi
trap 'rm -f /tmp/google-chrome-stable.deb' EXIT
proxychains4 wget --progress=dot:mega -O /tmp/google-chrome-stable.deb \
    https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i /tmp/google-chrome-stable.deb || sudo apt-get install -f -y -qq
rm -f /tmp/google-chrome-stable.deb
trap - EXIT
