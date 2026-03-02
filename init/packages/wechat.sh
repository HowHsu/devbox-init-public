#!/usr/bin/env bash
set -euo pipefail

if command -v wechat &>/dev/null; then
    echo "    wechat already installed, skipping"
    exit 0
fi
trap 'rm -f /tmp/wechat.deb' EXIT
wget -q -O /tmp/wechat.deb "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb"
sudo dpkg -i /tmp/wechat.deb || sudo apt-get install -f -y -qq
rm -f /tmp/wechat.deb
trap - EXIT
