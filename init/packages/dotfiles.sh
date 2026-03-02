#!/usr/bin/env bash
set -euo pipefail

if [ ! -d "$DOTFILES_DEST/.git" ]; then
    rm -rf "$DOTFILES_DEST"
    git clone git@github.com:HowHsu/dotfiles.git "$DOTFILES_DEST"
fi
bash "$DOTFILES_DEST/deploy.sh"
