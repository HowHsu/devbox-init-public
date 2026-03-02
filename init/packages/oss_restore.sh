#!/usr/bin/env bash
set -euo pipefail

# Only restore paths required during bootstrap:
#   ssh_keys/           — SSH private key (needed for git clone, etc.)
#   trojan/             — trojan config.json (needed to start proxy)
#   docker_dev/images/trojan.image.tar.xz — trojan docker image (referenced via symlink)
bash "$SCRIPT_DIR/oss_restore.sh" ssh_keys trojan docker_dev/images/trojan.image.tar.xz
