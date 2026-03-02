#!/usr/bin/env bash
#
# Bootstrap script for Ubuntu 24.04 dev environment setup.
# Two phases: Phase 1 (no proxy), Phase 2 (proxy via proxychains).
#
# Software installed (see packages/ for individual install scripts):
#
# Phase 1 — No proxy needed:
#   base_packages:  rclone, git, curl, wget, build-essential, git-lfs,
#                   xz-utils, ca-certificates, gnupg, software-properties-common,
#                   apt-transport-https, tmux, vim, proxychains, netcat-openbsd,
#                   docker.io
#   docker:         enable docker service, add user to docker group
#   hexchat:        apt-get install (Ubuntu source) (GUI)
#   wechat:         .deb from dldir1v6.qq.com (GUI)
#   oss_restore:    rclone encrypted restore from Aliyun OSS
#   dotfiles:       git clone git@github.com:HowHsu/dotfiles.git + deploy.sh
#   trojan:         docker image from OSS backup, container on port 1081
#
# Phase 2 — Proxy available:
#   github_cli:     apt source https://cli.github.com/packages
#   firefox:        apt source https://packages.mozilla.org/apt (GUI)
#   chrome:         .deb from dl.google.com (GUI)
#   claude_code:    install script from https://cli.claude.ai/install.sh
#   cursor:         apt source https://downloads.cursor.com/aptrepo (GUI)
#   signal:         apt source https://updates.signal.org/desktop/apt (GUI)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
export OSS_DIR="${OSS_DIR:-$HOME/oss}"
PRIVATE_KEY_SRC="$OSS_DIR/ssh_keys/id_rsa"
SSH_DIR="$HOME/.ssh"
export DOCKER_DEV_DEST="${DOCKER_DEV_DEST:-$HOME/docker_dev}"
export DOTFILES_DEST="${DOTFILES_DEST:-$HOME/dotfiles}"

# --- Fix any broken dpkg state from previous interrupted runs ---
sudo dpkg --configure -a 2>/dev/null || true
sudo apt-get install -f -y -qq 2>/dev/null || {
    # Force-remove packages stuck with "reinst-required" flag (R in 3rd column of dpkg -l)
    dpkg -l | awk 'NR>=6 && $1 ~ /R/{print $2}' | xargs -r sudo dpkg --remove --force-remove-reinstreq
    sudo apt-get install -f -y -qq
}

# --- Step tracking ---
STATE_FILE="$SCRIPT_DIR/bootstrap_done"
if [ ! -f "$STATE_FILE" ]; then
    echo "ERROR: $STATE_FILE not found" >&2
    exit 1
fi

step_done() { grep -q "^$1 true$" "$STATE_FILE"; }
mark_done() { sed -i "s/^$1 false$/$1 true/" "$STATE_FILE"; }

run_step() {
    local step=$1
    if ! step_done "$step"; then
        echo "==> Running $step..."
        bash "$SCRIPT_DIR/packages/$step.sh"
        mark_done "$step"
    else
        echo "==> $step already done, skipping"
    fi
}

run_gui_step() {
    [[ "$INSTALL_GUI" == "true" ]] && run_step "$1"
}

echo "Select installation mode:"
echo "  1) Desktop  — full install with GUI apps"
echo "  2) Server   — skip GUI apps (Chrome, Firefox, Cursor, etc.)"
read -rp "Enter choice [1/2]: " mode_choice
case "$mode_choice" in
    2) INSTALL_GUI=false ;;
    *) INSTALL_GUI=true ;;
esac

# ============================================================
# Phase 1 — No proxy needed
# ============================================================

run_step base_packages
run_step docker
run_gui_step hexchat
run_gui_step wechat
run_step oss_restore

# --- SSH key setup (inline, idempotent, no step tracking) ---
echo "==> Setting up SSH private key..."
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
if [ ! -f "$SSH_DIR/id_rsa" ]; then
    cp "$PRIVATE_KEY_SRC" "$SSH_DIR/id_rsa"
    chmod 600 "$SSH_DIR/id_rsa"
    echo "    Copied $PRIVATE_KEY_SRC -> $SSH_DIR/id_rsa"
else
    echo "    $SSH_DIR/id_rsa already exists, skipping"
fi

run_step dotfiles
run_step trojan

# ============================================================
# Phase 2 — Proxy available via proxychains
# ============================================================

# Verify proxy is reachable before proceeding
if ! nc -z 127.0.0.1 1081 2>/dev/null; then
    echo "ERROR: Proxy not available on port 1081, cannot proceed with Phase 2" >&2
    exit 1
fi

run_step github_cli
run_gui_step firefox
run_gui_step chrome
run_step claude_code
run_gui_step cursor
run_gui_step signal

echo "==> Bootstrap complete!"
